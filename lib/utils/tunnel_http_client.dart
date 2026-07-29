import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;
import 'package:just_zstd/just_zstd.dart';
import 'package:matrix/matrix_api_lite/utils/logs.dart';

import 'tunnel_key_manager.dart';

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

class _EncryptedBytes {
  final Uint8List nonce;
  final Uint8List ciphertext;

  _EncryptedBytes({required this.nonce, required this.ciphertext});
}

class _MediaChunkPayload {
  final int index;
  final Uint8List bytes;

  _MediaChunkPayload({required this.index, required this.bytes});
}

class _MediaChunkBatchPayload {
  final List<_MediaChunkPayload> chunks;
  final Uint8List encryptionKey;

  _MediaChunkBatchPayload({required this.chunks, required this.encryptionKey});
}

class _EncryptedMediaChunk {
  final int index;
  final Uint8List nonce;
  final Uint8List ciphertext;

  _EncryptedMediaChunk({
    required this.index,
    required this.nonce,
    required this.ciphertext,
  });
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

Future<List<_EncryptedMediaChunk>> _encryptMediaChunkBatch(
  _MediaChunkBatchPayload payload,
) async {
  final encryptedChunks = <_EncryptedMediaChunk>[];
  for (final chunk in payload.chunks) {
    final encrypted = await _encryptBytes(chunk.bytes, payload.encryptionKey);
    encryptedChunks.add(
      _EncryptedMediaChunk(
        index: chunk.index,
        nonce: encrypted.nonce,
        ciphertext: encrypted.ciphertext,
      ),
    );
  }
  return encryptedChunks;
}

Uint8List _randomBytes(int length) {
  final bytes = Uint8List(length);
  final random = Random.secure();
  for (var i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

Future<_EncryptedBytes> _encryptBytes(
  Uint8List data,
  Uint8List encryptionKey,
) async {
  final chacha20 = Chacha20.poly1305Aead();
  final nonce = _randomBytes(12);
  final secretBox = await chacha20.encrypt(
    data,
    secretKey: SecretKey(encryptionKey),
    nonce: nonce,
  );
  final full = Uint8List.fromList(secretBox.concatenation());
  return _EncryptedBytes(
    nonce: Uint8List.fromList(full.sublist(0, 12)),
    ciphertext: Uint8List.fromList(full.sublist(12)),
  );
}

/// HTTP client that tunnels POST/PUT/DELETE requests through OPTIONS
/// with ChaCha20-Poly1305 encryption and zstd compression.
class TunnelHttpClient extends http.BaseClient {
  final http.Client _inner;
  Uint8List _encryptionKey;
  Uint8List _clientPublicKey;
  final String? _serverUri;
  bool _isRefreshingKeys = false;

  static const int maxHeaderValueSize = 31 * 1024;
  static const int maxOriginalBodySize = 100 * 1024 * 1024;
  static const int minChunkSize = 12 * 1024;
  static const int maxChunkSize = 20 * 1024;

  static const String headerPayload = 'x-qnskk-tunnel-payload';
  static const String headerNonce = 'x-qnskk-nonce';
  static const String headerChunkIndex = 'x-qnskk-chunk-index';
  static const String headerChunkTotal = 'x-qnskk-chunk-total';
  static const String headerClientPubkey = 'x-qnskk-client-pubkey';
  static const String headerMediaOp = 'x-qnskk-media-op';
  static const String headerMediaSession = 'x-qnskk-media-session';
  static const String headerMediaIndex = 'x-qnskk-media-index';
  static const String headerMediaPayload = 'x-qnskk-media-payload';

  static const int _mediaChunkSize = 16 * 1024;
  static const int _mediaEncryptBatchChunks = 64;
  static const int _maxMediaParallelChunks = 8;
  static const int _mediaChunkMaxAttempts = 4;
  static const Duration _mediaChunkRetryBaseDelay = Duration(milliseconds: 250);

  static final Random _random = Random.secure();

  TunnelHttpClient({
    required http.Client inner,
    required Uint8List encryptionKey,
    required Uint8List clientPublicKey,
    String? serverUri,
  }) : assert(encryptionKey.length == 32),
       assert(clientPublicKey.length == 32),
       _inner = inner,
       _encryptionKey = encryptionKey,
       _clientPublicKey = clientPublicKey,
       _serverUri = serverUri;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final method = request.method.toUpperCase();
    if (method == 'GET' || method == 'HEAD' || method == 'OPTIONS') {
      return _inner.send(request);
    }

    try {
      return await _tunnelRequest(request);
    } catch (e, s) {
      if (e is http.ClientException &&
          _shouldAttemptKeyRotation(e) &&
          _serverUri != null &&
          !_isRefreshingKeys) {
        Logs().w(
          'Tunnel auth/session error encountered (${e.message}). Attempting key rotation with $_serverUri...',
        );
        try {
          await _rotateAndApplyKeys();
          return await _tunnelRequest(request);
        } catch (retryErr, retryStack) {
          Logs().e('Key rotation retry failed', retryErr, retryStack);
        }
      }
      if (e is http.ClientException) rethrow;
      Logs().w('Tunnel request failed before receiving a response', e, s);
      throw http.ClientException('Tunnel request failed: $e', request.url);
    }
  }

  bool _shouldAttemptKeyRotation(http.ClientException e) {
    final msg = e.message.toLowerCase();
    return msg.contains('403') ||
        msg.contains('400') ||
        msg.contains('bad tunnel mac') ||
        msg.contains('replayed tunnel request') ||
        msg.contains('invalid tunnel client key');
  }

  Future<void> _rotateAndApplyKeys() async {
    if (_serverUri == null || _isRefreshingKeys) return;
    _isRefreshingKeys = true;
    try {
      final newSecret =
          await TunnelKeyManager.instance.rotateKeys(_serverUri!);
      final newPubkey = await TunnelKeyManager.instance.clientPublicKey;
      _encryptionKey = newSecret;
      _clientPublicKey = newPubkey;
    } finally {
      _isRefreshingKeys = false;
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
    if (_isMatrixMediaUpload(request)) {
      return _mediaUploadRequest(request, bodyBytes);
    }

    final headers = <String, String>{};
    request.headers.forEach((key, value) {
      if (key.toLowerCase() != 'host') headers[key] = value;
    });
    final originalMethod = request.method;
    final originalPath =
        request.url.path +
        (request.url.hasQuery ? '?${request.url.query}' : '');
    final encryptionKey = Uint8List.fromList(_encryptionKey);

    // Heavy work (JSON build + zstd + encrypt) in background isolate.
    final result = await Isolate.run(
      () => _compressAndEncrypt(
        _IsolatePayload(
          bodyBytes: bodyBytes,
          method: originalMethod,
          path: originalPath,
          headers: headers,
          encryptionKey: encryptionKey,
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

  bool _isMatrixMediaUpload(http.BaseRequest request) {
    if (request.method.toUpperCase() != 'POST') return false;
    final path = request.url.path;
    return path.endsWith('/_matrix/media/v3/upload') ||
        path.endsWith('/_matrix/media/r0/upload') ||
        path.endsWith('/_matrix/client/v1/media/upload');
  }

  Future<http.StreamedResponse> _mediaUploadRequest(
    http.BaseRequest request,
    Uint8List bodyBytes,
  ) async {
    final session = base64UrlNoPad(_randomBytes(18));
    const chunkSize = _mediaChunkSize;
    final chunkTotal = max(1, (bodyBytes.length + chunkSize - 1) ~/ chunkSize);
    final headers = <String, String>{};
    request.headers.forEach((key, value) {
      if (key.toLowerCase() != 'host') headers[key] = value;
    });

    final initPayload = <String, dynamic>{
      'session': session,
      'path':
          request.url.path +
          (request.url.hasQuery ? '?${request.url.query}' : ''),
      'headers': headers,
      'total_size': bodyBytes.length,
      'chunk_size': chunkSize,
      'chunk_total': chunkTotal,
      if (request.url.queryParameters['filename'] != null)
        'filename': request.url.queryParameters['filename'],
      if (request.headers['content-type'] != null)
        'content_type': request.headers['content-type'],
    };

    final init = await _encryptBytes(
      Uint8List.fromList(utf8.encode(jsonEncode(initPayload))),
      _encryptionKey,
    );
    final initResponse = await _inner.send(
      _buildMediaRequest(
        url: request.url,
        op: 'init',
        session: session,
        nonce: init.nonce,
        payload: init.ciphertext,
      ),
    );
    await _validateMediaInitResponse(request.url, initResponse);

    try {
      for (
        var start = 0;
        start < chunkTotal;
        start += _mediaEncryptBatchChunks
      ) {
        final end = min(start + _mediaEncryptBatchChunks, chunkTotal);
        final batch = <_MediaChunkPayload>[];
        for (var index = start; index < end; index++) {
          final chunkStart = index * chunkSize;
          final chunkEnd = min(chunkStart + chunkSize, bodyBytes.length);
          batch.add(
            _MediaChunkPayload(
              index: index,
              bytes: Uint8List.fromList(
                Uint8List.sublistView(bodyBytes, chunkStart, chunkEnd),
              ),
            ),
          );
        }

        final encryptionKey = Uint8List.fromList(_encryptionKey);
        final encryptedChunks = await Isolate.run(
          () => _encryptMediaChunkBatch(
            _MediaChunkBatchPayload(
              chunks: batch,
              encryptionKey: encryptionKey,
            ),
          ),
        );

        for (
          var sendStart = 0;
          sendStart < encryptedChunks.length;
          sendStart += _maxMediaParallelChunks
        ) {
          final sendEnd = min(
            sendStart + _maxMediaParallelChunks,
            encryptedChunks.length,
          );
          final futures = <Future<http.StreamedResponse>>[];
          for (final chunk in encryptedChunks.sublist(sendStart, sendEnd)) {
            futures.add(
              _sendEncryptedMediaChunk(
                request.url,
                session,
                chunk.index,
                chunk.nonce,
                chunk.ciphertext,
              ),
            );
          }
          final responses = await Future.wait(futures);
          for (final response in responses) {
            await response.stream.drain();
            if (response.statusCode != 202) {
              throw http.ClientException(
                'Media tunnel chunk failed',
                request.url,
              );
            }
          }
        }
      }

      final commit = await _encryptBytes(
        Uint8List.fromList(utf8.encode(jsonEncode({'session': session}))),
        _encryptionKey,
      );
      return _validateMediaCommitResponse(
        request.url,
        await _inner.send(
          _buildMediaRequest(
            url: request.url,
            op: 'commit',
            session: session,
            nonce: commit.nonce,
            payload: commit.ciphertext,
          ),
        ),
      );
    } catch (_) {
      await _abortMediaUpload(request.url, session);
      rethrow;
    }
  }

  Future<http.StreamedResponse> _sendEncryptedMediaChunk(
    Uri url,
    String session,
    int index,
    Uint8List nonce,
    Uint8List ciphertext,
  ) async {
    Object? lastError;
    StackTrace? lastStackTrace;

    for (var attempt = 1; attempt <= _mediaChunkMaxAttempts; attempt++) {
      try {
        final response = await _inner.send(
          _buildMediaRequest(
            url: url,
            op: 'chunk',
            session: session,
            index: index,
            nonce: nonce,
            payload: ciphertext,
          ),
        );
        if (response.statusCode == 202) {
          return response;
        }

        await response.stream.drain();
        lastError = http.ClientException(
          'Media tunnel chunk $index failed with HTTP ${response.statusCode}',
          url,
        );
      } catch (e, s) {
        lastError = e;
        lastStackTrace = s;
      }

      if (attempt < _mediaChunkMaxAttempts) {
        await Future<void>.delayed(_mediaRetryDelay(attempt));
      }
    }

    if (lastError is http.ClientException) {
      throw lastError;
    }
    Error.throwWithStackTrace(
      http.ClientException('Media tunnel chunk $index failed: $lastError', url),
      lastStackTrace ?? StackTrace.current,
    );
  }

  Duration _mediaRetryDelay(int attempt) {
    final jitterMs = _random.nextInt(120);
    return _mediaChunkRetryBaseDelay * (1 << (attempt - 1)) +
        Duration(milliseconds: jitterMs);
  }

  Future<void> _validateMediaInitResponse(
    Uri url,
    http.StreamedResponse response,
  ) async {
    final bodyBytes = await response.stream.toBytes();
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Media tunnel init failed with HTTP ${response.statusCode}',
        url,
      );
    }
    if (bodyBytes.isEmpty) {
      throw http.ClientException(
        'Media tunnel init returned empty HTTP 200 response',
        url,
      );
    }
  }

  Future<http.StreamedResponse> _validateMediaCommitResponse(
    Uri url,
    http.StreamedResponse response,
  ) async {
    final bodyBytes = await response.stream.toBytes();
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Media tunnel commit failed with HTTP ${response.statusCode}',
        url,
      );
    }
    if (bodyBytes.isEmpty) {
      throw http.ClientException(
        'Media tunnel commit returned empty HTTP 200 response',
        url,
      );
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(bodyBytes),
      response.statusCode,
      contentLength: bodyBytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  Future<void> _abortMediaUpload(Uri url, String session) async {
    try {
      final response = await _inner.send(
        _buildMediaRequest(
          url: url,
          op: 'abort',
          session: session,
          nonce: Uint8List(0),
          payload: Uint8List(0),
        ),
      );
      await response.stream.drain();
    } catch (_) {
      // Best-effort cleanup only; keep the original upload error.
    }
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
      return _validateTunnelResponse(
        url,
        await _sendSingleChunk(url, chunks.first, nonce, chunks.length),
      );
    }
    return _validateTunnelResponse(
      url,
      await _sendMultipleChunks(url, chunks, nonce),
    );
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

  Future<http.StreamedResponse> _validateTunnelResponse(
    Uri url,
    http.StreamedResponse response,
  ) async {
    final bodyBytes = await response.stream.toBytes();
    if (response.statusCode == 202) {
      throw http.ClientException(
        'Tunnel ended with an intermediate HTTP 202 response',
        url,
      );
    }

    if (response.statusCode >= 400) {
      // Check if this is a valid Matrix JSON error response from origin homeserver
      bool isMatrixJson = false;
      if (bodyBytes.isNotEmpty) {
        try {
          final decoded = jsonDecode(utf8.decode(bodyBytes));
          if (decoded is Map &&
              (decoded.containsKey('errcode') || decoded.containsKey('error'))) {
            isMatrixJson = true;
          }
        } catch (_) {}
      }

      if (!isMatrixJson) {
        final bodyStr = bodyBytes.isNotEmpty ? utf8.decode(bodyBytes) : '';
        throw http.ClientException(
          'Tunnel error (HTTP ${response.statusCode}): $bodyStr',
          url,
        );
      }
    }

    if (bodyBytes.isEmpty &&
        response.statusCode >= 200 &&
        response.statusCode < 300) {
      throw http.ClientException(
        'Tunnel returned empty HTTP ${response.statusCode} response; '
        'request likely did not reach the QNSKK origin. '
        'headers=${_debugHeaders(response.headers)}',
        url,
      );
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(bodyBytes),
      response.statusCode,
      contentLength: bodyBytes.length,
      request: response.request,
      headers: response.headers,
      isRedirect: response.isRedirect,
      persistentConnection: response.persistentConnection,
      reasonPhrase: response.reasonPhrase,
    );
  }

  String _debugHeaders(Map<String, String> headers) {
    final safeHeaders = <String, String>{};
    for (final entry in headers.entries) {
      final name = entry.key.toLowerCase();
      if (name == 'authorization' || name == 'cookie' || name == 'set-cookie') {
        continue;
      }
      safeHeaders[name] = entry.value;
    }
    return safeHeaders.toString();
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

  http.Request _buildMediaRequest({
    required Uri url,
    required String op,
    required String session,
    required Uint8List nonce,
    required Uint8List payload,
    int? index,
  }) {
    final request = http.Request('OPTIONS', url.replace(path: '/_qnskk/media'));
    request.headers[headerClientPubkey] = base64UrlNoPad(_clientPublicKey);
    request.headers[headerMediaOp] = op;
    request.headers[headerMediaSession] = session;
    if (nonce.isNotEmpty) request.headers[headerNonce] = base64UrlNoPad(nonce);
    if (payload.isNotEmpty) {
      request.headers[headerMediaPayload] = base64UrlNoPad(payload);
    }
    if (index != null) request.headers[headerMediaIndex] = index.toString();
    assert(
      request.headers[headerMediaPayload] == null ||
          request.headers[headerMediaPayload]!.length <= maxHeaderValueSize,
    );
    return request;
  }

  @override
  void close() => _inner.close();
}
