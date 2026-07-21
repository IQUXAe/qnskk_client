import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:just_zstd/just_zstd.dart';

String base64UrlNoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

class _IsolatePayload {
  final Uint8List bodyBytes;
  final String method;
  final String path;
  final Map<String, String> headers;
  final Uint8List encryptionKey;

  _IsolatePayload({
    required this.bodyBytes,
    required this.method,
    required this.path,
    required this.headers,
    required this.encryptionKey,
  });
}

class _IsolateResult {
  final Uint8List nonce;
  final Uint8List ciphertext;

  _IsolateResult({required this.nonce, required this.ciphertext});
}

/// Builds JSON, compresses, and encrypts in a background isolate.
Future<_IsolateResult> _compressAndEncrypt(_IsolatePayload payload) async {
  final bodyB64 = payload.bodyBytes.isNotEmpty
      ? base64Url.encode(payload.bodyBytes).replaceAll('=', '')
      : null;

  final jsonMap = <String, dynamic>{
    'method': payload.method,
    'path': payload.path,
    'headers': payload.headers,
  };
  if (bodyB64 != null) jsonMap['body'] = bodyB64;

  final jsonBytes = utf8.encode(jsonEncode(jsonMap));
  final compressed = const ZstdEncoder().encodeBytes(
    Uint8List.fromList(jsonBytes),
  );

  final chacha20 = Chacha20.poly1305Aead();
  final nonce = _randomBytes(12);

  final secretBox = await chacha20.encrypt(
    compressed,
    secretKey: SecretKey(payload.encryptionKey),
    nonce: nonce,
  );

  final full = Uint8List.fromList(secretBox.concatenation());
  return _IsolateResult(
    nonce: Uint8List.fromList(full.sublist(0, 12)),
    ciphertext: Uint8List.fromList(full.sublist(12)),
  );
}

Uint8List _randomBytes(int length) {
  final bytes = Uint8List(length);
  final random = Random.secure();
  for (var i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

/// HTTP client that tunnels POST/PUT/DELETE requests through OPTIONS
/// with ChaCha20-Poly1305 encryption and zstd compression.
class TunnelHttpClient extends http.BaseClient {
  final http.Client _inner;
  final Uint8List _encryptionKey;
  final Uint8List _clientPublicKey;

  static const int maxHeaderValueSize = 31 * 1024;
  static const int maxOriginalBodySize = 100 * 1024 * 1024;
  static const int minChunkSize = 12 * 1024;
  static const int maxChunkSize = 20 * 1024;

  static const String headerPayload = 'x-qnskk-tunnel-payload';
  static const String headerNonce = 'x-qnskk-nonce';
  static const String headerChunkIndex = 'x-qnskk-chunk-index';
  static const String headerChunkTotal = 'x-qnskk-chunk-total';
  static const String headerClientPubkey = 'x-qnskk-client-pubkey';

  static final Random _random = Random.secure();

  TunnelHttpClient({
    required http.Client inner,
    required Uint8List encryptionKey,
    required Uint8List clientPublicKey,
  }) : assert(encryptionKey.length == 32),
       assert(clientPublicKey.length == 32),
       _inner = inner,
       _encryptionKey = encryptionKey,
       _clientPublicKey = clientPublicKey;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final method = request.method.toUpperCase();
    if (method == 'GET' || method == 'HEAD' || method == 'OPTIONS') {
      return _inner.send(request);
    }

    try {
      return await _tunnelRequest(request);
    } catch (e) {
      if (e is http.ClientException) rethrow;
      throw http.ClientException('Tunnel request failed', request.url);
    }
  }

  Future<http.StreamedResponse> _tunnelRequest(http.BaseRequest request) async {
    final bodyBytes = await _readBody(request);
    if (bodyBytes.lengthInBytes > maxOriginalBodySize) {
      throw http.ClientException(
        'Tunnel request body exceeds 100 MiB limit',
        request.url,
      );
    }

    final headers = <String, String>{};
    request.headers.forEach((key, value) {
      if (key.toLowerCase() != 'host') headers[key] = value;
    });

    // Heavy work (JSON build + zstd + encrypt) in background isolate.
    final result = await Isolate.run(
      () => _compressAndEncrypt(
        _IsolatePayload(
          bodyBytes: bodyBytes,
          method: request.method,
          path:
              request.url.path +
              (request.url.hasQuery ? '?${request.url.query}' : ''),
          headers: headers,
          encryptionKey: _encryptionKey,
        ),
      ),
    );

    // bodyBytes no longer needed — allow GC.
    final chunks = _splitIntoChunks(result.ciphertext);
    return _sendTunnelRequest(
      url: request.url,
      chunks: chunks,
      nonce: result.nonce,
    );
  }

  Future<Uint8List> _readBody(http.BaseRequest request) async {
    if (request is http.Request) return request.bodyBytes;
    if (request is http.StreamedRequest) {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in request.finalize()) {
        builder.add(chunk);
      }
      return builder.toBytes();
    }
    return Uint8List(0);
  }

  List<Uint8List> _splitIntoChunks(Uint8List data) {
    if (data.length <= minChunkSize) return [data];

    final chunks = <Uint8List>[];
    var offset = 0;
    while (offset < data.length) {
      final remaining = data.length - offset;
      final upper = maxChunkSize < remaining ? maxChunkSize : remaining;
      final lower = minChunkSize < upper ? minChunkSize : upper;
      final size = lower + _random.nextInt(upper - lower + 1);
      chunks.add(Uint8List.sublistView(data, offset, offset + size));
      offset += size;
    }
    return chunks;
  }

  Future<http.StreamedResponse> _sendTunnelRequest({
    required Uri url,
    required List<Uint8List> chunks,
    required Uint8List nonce,
  }) async {
    if (chunks.length == 1) {
      return _sendSingleChunk(url, chunks.first, nonce, chunks.length);
    }
    return _sendMultipleChunks(url, chunks, nonce);
  }

  Future<http.StreamedResponse> _sendSingleChunk(
    Uri url,
    Uint8List chunk,
    Uint8List nonce,
    int total,
  ) {
    return _inner.send(_buildChunkRequest(url, chunk, nonce, 0, total));
  }

  /// Sends chunks sequentially so the last chunk deterministically receives
  /// the reconstructed Matrix response from the edge proxy.
  Future<http.StreamedResponse> _sendMultipleChunks(
    Uri url,
    List<Uint8List> chunks,
    Uint8List nonce,
  ) async {
    final total = chunks.length;

    for (var i = 0; i < total; i++) {
      final response = await _inner.send(
        _buildChunkRequest(url, chunks[i], nonce, i, total),
      );

      if (i == total - 1) {
        return response;
      }

      if (response.statusCode != 202) {
        return response;
      }
      await response.stream.drain();
    }

    throw StateError('No chunks sent');
  }

  http.Request _buildChunkRequest(
    Uri url,
    Uint8List chunk,
    Uint8List nonce,
    int index,
    int total,
  ) {
    final request = http.Request('OPTIONS', url);
    request.headers[headerClientPubkey] = base64UrlNoPad(_clientPublicKey);
    request.headers[headerPayload] = base64UrlNoPad(chunk);
    request.headers[headerNonce] = base64UrlNoPad(nonce);
    request.headers[headerChunkIndex] = index.toString();
    request.headers[headerChunkTotal] = total.toString();
    assert(request.headers[headerPayload]!.length <= maxHeaderValueSize);
    return request;
  }

  @override
  void close() => _inner.close();
}
