import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

Uint8List _decodeBase64UrlNoPad(String value) {
  var padded = value;
  while (padded.length % 4 != 0) {
    padded += '=';
  }
  return Uint8List.fromList(base64Url.decode(padded));
}

bool _constantTimeBytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Manages the X25519 keypair and derived shared secret used by the tunnel
/// client.
///
/// On first launch a new X25519 keypair is generated.  The client then
/// performs a one-time key exchange with the server via `GET
/// /tunnel/exchange?client_pubkey=…` (unencrypted, over HTTPS through the
/// CDN).  Both sides derive an identical 32-byte shared secret using ECDH,
/// which is then used as the ChaCha20-Poly1305 key for all tunneled traffic.
class TunnelKeyManager {
  TunnelKeyManager._();

  static final TunnelKeyManager instance = TunnelKeyManager._();

  static const _secureStorage = FlutterSecureStorage();

  // Secure-storage keys.
  static const _skClientPrivate = 'qnskk.tunnel.client_private_key';
  static const _skClientPublic = 'qnskk.tunnel.client_public_key';
  static const _skSharedSecret = 'qnskk.tunnel.shared_secret';

  // Derived from edge-proxy.toml's development private key. Production builds
  // must pass the deployment key via:
  // --dart-define=QNSKK_SERVER_PUBKEY=<base64url-no-pad-x25519-public-key>
  static const _pinnedServerPublicKeyB64 = String.fromEnvironment(
    'QNSKK_SERVER_PUBKEY',
    defaultValue: 'U-JqauVwOoK2rh6DxBvFgFZTalL6diibcpkyMXC5PnQ',
  );

  static final X25519 _x25519 = X25519();
  static final Map<String, String> _inMemoryStorageForTests = {};

  @visibleForTesting
  static bool useInMemoryStorageForTests = false;

  /// Cached keypair and shared secret.
  SimpleKeyPair? _keyPair;
  Uint8List? _clientPublicKey;
  Uint8List? _sharedSecret;

  /// Returns the 32-byte client public key (cached after first load).
  Future<Uint8List> get clientPublicKey async {
    if (_clientPublicKey != null) return _clientPublicKey!;
    final kp = await _getOrCreateKeyPair();
    final pk = await kp.extractPublicKey();
    _clientPublicKey = Uint8List.fromList(pk.bytes);
    return _clientPublicKey!;
  }

  /// Returns the 32-byte shared secret, performing key exchange if needed.
  ///
  /// [serverUri] is the base URL of the edge proxy (e.g.
  /// `https://api.qnskk.top`).
  Future<Uint8List> getOrCreateSharedSecret(String serverUri) async {
    if (_sharedSecret != null) return _sharedSecret!;

    // Try loading from storage first.
    final stored = await _readSharedSecret();
    if (stored != null) {
      _sharedSecret = stored;
      return stored;
    }

    // Need to exchange keys.
    return exchangeKeys(serverUri);
  }

  /// Performs the X25519 key exchange with the server.
  ///
  /// Sends `GET /tunnel/exchange?client_pubkey=<base64url>` and receives the
  /// server's public key.  Both sides then compute the shared secret.
  Future<Uint8List> exchangeKeys(String serverUri) async {
    final clientPk = await clientPublicKey;
    final clientPkB64 = base64Url.encode(clientPk).replaceAll('=', '');

    final uri = Uri.parse(
      '$serverUri/tunnel/exchange',
    ).replace(queryParameters: {'client_pubkey': clientPkB64});

    final response = await http.get(uri).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw TunnelKeyExchangeException(
        'Key exchange failed: HTTP ${response.statusCode}: ${response.body}',
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final serverPkB64 = json['server_pubkey'] as String?;
    if (serverPkB64 == null || serverPkB64.isEmpty) {
      throw const TunnelKeyExchangeException(
        'Key exchange failed: missing server_pubkey in response',
      );
    }

    final serverPk = _decodeBase64UrlNoPad(serverPkB64);
    if (serverPk.length != 32) {
      throw TunnelKeyExchangeException(
        'Key exchange failed: server_pubkey must be 32 bytes, got ${serverPk.length}',
      );
    }
    final pinnedServerPk = _decodeBase64UrlNoPad(_pinnedServerPublicKeyB64);
    if (pinnedServerPk.length != 32) {
      throw TunnelKeyExchangeException(
        'Key exchange failed: pinned server public key must be 32 bytes, got ${pinnedServerPk.length}',
      );
    }
    if (!_constantTimeBytesEqual(serverPk, pinnedServerPk)) {
      throw const TunnelKeyExchangeException(
        'Key exchange failed: server public key mismatch',
      );
    }

    // Derive shared secret: X25519(client_private, server_public).
    final kp = await _getOrCreateKeyPair();
    final shared = await _x25519.sharedSecretKey(
      keyPair: kp,
      remotePublicKey: SimplePublicKey(serverPk, type: KeyPairType.x25519),
    );
    final ss = Uint8List.fromList(await shared.extractBytes());

    await _writeSharedSecret(ss);
    _sharedSecret = ss;
    return ss;
  }

  /// Forces a fresh keypair and key exchange.
  Future<Uint8List> rotateKeys(String serverUri) async {
    _keyPair = null;
    _clientPublicKey = null;
    _sharedSecret = null;
    await _clearStoredKeys();
    final kp = await _generateAndStoreKeyPair();
    final pk = await kp.extractPublicKey();
    _clientPublicKey = Uint8List.fromList(pk.bytes);
    return exchangeKeys(serverUri);
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    _keyPair = null;
    _clientPublicKey = null;
    _sharedSecret = null;
    await _clearStoredKeys();
  }

  // ---------------------------------------------------------------------------
  // Keypair management
  // ---------------------------------------------------------------------------

  Future<SimpleKeyPair> _getOrCreateKeyPair() async {
    if (_keyPair != null) return _keyPair!;

    final stored = await _readKeyPair();
    if (stored != null) {
      _keyPair = stored;
      return stored;
    }

    return _generateAndStoreKeyPair();
  }

  Future<SimpleKeyPair> _generateAndStoreKeyPair() async {
    final kp = await _x25519.newKeyPair();
    final pk = await kp.extractPublicKey();
    final skBytes = Uint8List.fromList(await kp.extractPrivateKeyBytes());
    final pkBytes = Uint8List.fromList(pk.bytes);

    await _writeKeyPair(skBytes, pkBytes);
    _keyPair = kp;
    return kp;
  }

  Future<SimpleKeyPair?> _readKeyPair() async {
    Uint8List? sk;
    try {
      final v = await _secureStorage.read(key: _skClientPrivate);
      if (v != null && v.isNotEmpty) sk = _decodeBase64UrlNoPad(v);
    } catch (_) {
      if (useInMemoryStorageForTests) {
        final v = _inMemoryStorageForTests[_skClientPrivate];
        if (v != null && v.isNotEmpty) sk = _decodeBase64UrlNoPad(v);
      }
    }
    if (sk == null) return null;

    return _x25519.newKeyPairFromSeed(sk);
  }

  Future<void> _writeKeyPair(Uint8List sk, Uint8List pk) async {
    final skB64 = base64Url.encode(sk);
    final pkB64 = base64Url.encode(pk);
    try {
      await _secureStorage.write(key: _skClientPrivate, value: skB64);
      await _secureStorage.write(key: _skClientPublic, value: pkB64);
    } catch (e) {
      if (!useInMemoryStorageForTests) {
        throw TunnelKeyStorageException('Secure key storage failed: $e');
      }
      _inMemoryStorageForTests[_skClientPrivate] = skB64;
      _inMemoryStorageForTests[_skClientPublic] = pkB64;
    }
  }

  // ---------------------------------------------------------------------------
  // Shared-secret persistence
  // ---------------------------------------------------------------------------

  Future<Uint8List?> _readSharedSecret() async {
    try {
      final v = await _secureStorage.read(key: _skSharedSecret);
      if (v != null && v.isNotEmpty) {
        final bytes = _decodeBase64UrlNoPad(v);
        if (bytes.length == 32) return Uint8List.fromList(bytes);
      }
    } catch (_) {
      if (useInMemoryStorageForTests) {
        final v = _inMemoryStorageForTests[_skSharedSecret];
        if (v != null && v.isNotEmpty) {
          final bytes = _decodeBase64UrlNoPad(v);
          if (bytes.length == 32) return Uint8List.fromList(bytes);
        }
      }
    }
    return null;
  }

  Future<void> _writeSharedSecret(Uint8List ss) async {
    final encoded = base64Url.encode(ss);
    try {
      await _secureStorage.write(key: _skSharedSecret, value: encoded);
    } catch (e) {
      if (!useInMemoryStorageForTests) {
        throw TunnelKeyStorageException('Secure key storage failed: $e');
      }
      _inMemoryStorageForTests[_skSharedSecret] = encoded;
    }
  }

  Future<void> _clearStoredKeys() async {
    try {
      await _secureStorage.delete(key: _skClientPrivate);
      await _secureStorage.delete(key: _skClientPublic);
      await _secureStorage.delete(key: _skSharedSecret);
    } catch (e) {
      if (!useInMemoryStorageForTests) {
        throw TunnelKeyStorageException(
          'Secure key storage cleanup failed: $e',
        );
      }
    }
    _inMemoryStorageForTests.clear();
  }
}

class TunnelKeyExchangeException implements Exception {
  final String message;
  const TunnelKeyExchangeException(this.message);
  @override
  String toString() => 'TunnelKeyExchangeException: $message';
}

class TunnelKeyStorageException implements Exception {
  final String message;
  const TunnelKeyStorageException(this.message);

  @override
  String toString() => 'TunnelKeyStorageException: $message';
}
