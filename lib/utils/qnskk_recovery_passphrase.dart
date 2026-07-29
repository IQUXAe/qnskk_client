import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

String _base64UrlNoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

abstract class QnskkRecoveryPassphrase {
  static final Map<String, String> _pendingPassphrases = {};
  static const _storage = FlutterSecureStorage();

  static Future<void> rememberPassword({
    required String userId,
    required String password,
  }) async {
    final derived = await derive(
      userId: userId,
      password: password,
    );
    _pendingPassphrases[userId] = derived;
    try {
      await _storage.write(
        key: 'qnskk_recovery_passphrase_$userId',
        value: derived,
      );
    } catch (_) {}
  }

  static String? take(String userId) => _pendingPassphrases[userId];

  static Future<String?> getOrRestore(String userId) async {
    if (_pendingPassphrases.containsKey(userId)) {
      return _pendingPassphrases[userId];
    }
    try {
      final stored = await _storage.read(key: 'qnskk_recovery_passphrase_$userId');
      if (stored != null) {
        _pendingPassphrases[userId] = stored;
        return stored;
      }
    } catch (_) {}
    return null;
  }

  static bool has(String userId) => _pendingPassphrases.containsKey(userId);

  static Future<String> derive({
    required String userId,
    required String password,
  }) async {
    final algorithm = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 210000,
      bits: 256,
    );
    final key = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: utf8.encode('qnskk-recovery-v1\x00$userId'),
    );
    return _base64UrlNoPad(await key.extractBytes());
  }
}
