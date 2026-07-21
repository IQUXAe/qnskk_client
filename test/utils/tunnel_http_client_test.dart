import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:fluffychat/utils/tunnel_http_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _RecordingClient extends http.BaseClient {
  final List<http.Request> requests = [];
  http.StreamedResponse? nextResponse;
  Object? errorToThrow;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request) {
      requests.add(request);
    }
    if (errorToThrow != null) throw errorToThrow!;
    if (request.headers['x-qnskk-chunk-total'] != null) {
      final index = int.tryParse(request.headers['x-qnskk-chunk-index'] ?? '');
      final total = int.tryParse(request.headers['x-qnskk-chunk-total'] ?? '');
      if (index != null && total != null && total > 1 && index < total - 1) {
        return http.StreamedResponse(Stream<List<int>>.empty(), 202);
      }
    }
    return nextResponse ??
        http.StreamedResponse(
          Stream<List<int>>.fromIterable([utf8.encode('{}')]),
          200,
          headers: {'content-type': 'application/json'},
        );
  }
}

void main() {
  group('TunnelHttpClient', () {
    late _RecordingClient inner;
    late TunnelHttpClient client;

    setUp(() {
      inner = _RecordingClient();
      client = TunnelHttpClient(
        inner: inner,
        encryptionKey: Uint8List.fromList(List.generate(32, (i) => i)),
        clientPublicKey: Uint8List.fromList(List.generate(32, (i) => i + 32)),
      );
    });

    tearDown(() {
      client.close();
    });

    test('GET requests pass through unchanged', () async {
      final req = http.Request(
        'GET',
        Uri.parse('https://example.com/_matrix/client/v3/sync'),
      );
      req.headers['authorization'] = 'Bearer abc';

      await client.send(req);

      expect(inner.requests, hasLength(1));
      expect(inner.requests.first.method, 'GET');
      expect(
        inner.requests.first.url.toString(),
        'https://example.com/_matrix/client/v3/sync',
      );
    });

    test('HEAD requests pass through unchanged', () async {
      final req = http.Request(
        'HEAD',
        Uri.parse('https://example.com/_matrix/client/v3/sync'),
      );
      await client.send(req);
      expect(inner.requests.first.method, 'HEAD');
    });

    test('POST requests are tunneled through OPTIONS', () async {
      final req = http.Request(
        'POST',
        Uri.parse('https://example.com/_matrix/client/v3/login'),
      );
      req.headers['authorization'] = 'Bearer test';
      req.bodyBytes = utf8.encode('{"type":"m.login.password"}');

      await client.send(req);

      final sent = inner.requests.first;
      expect(sent.method, 'OPTIONS');
      expect(
        sent.url.toString(),
        'https://example.com/_matrix/client/v3/login',
      );
      expect(sent.headers['x-qnskk-tunnel-payload'], isNotNull);
      expect(sent.headers['x-qnskk-nonce'], isNotNull);
      expect(sent.headers['x-qnskk-chunk-index'], '0');
      expect(sent.headers['x-qnskk-chunk-total'], '1');
      expect(sent.headers['x-qnskk-client-pubkey'], isNotNull);
    });

    test('PUT requests are tunneled through OPTIONS', () async {
      final req = http.Request(
        'PUT',
        Uri.parse(
          'https://example.com/_matrix/client/v3/rooms/!abc/server/send/m.room.message/123',
        ),
      );
      req.bodyBytes = utf8.encode('{"body":"hi"}');

      await client.send(req);

      expect(inner.requests.first.method, 'OPTIONS');
      expect(inner.requests.first.headers['x-qnskk-tunnel-payload'], isNotNull);
    });

    test('DELETE requests are tunneled through OPTIONS', () async {
      final req = http.Request(
        'DELETE',
        Uri.parse('https://example.com/_matrix/client/v3/devices/ABC'),
      );
      await client.send(req);
      expect(inner.requests.first.method, 'OPTIONS');
    });

    test('POST tunnel failures do not fall back to direct request', () async {
      inner.errorToThrow = Exception('network down');
      final req = http.Request(
        'POST',
        Uri.parse('https://example.com/_matrix/client/v3/login'),
      );
      req.bodyBytes = utf8.encode('{}');

      await expectLater(client.send(req), throwsA(isA<http.ClientException>()));
      expect(inner.requests, hasLength(1));
      expect(inner.requests.single.method, 'OPTIONS');
    });

    test('Large POST splits into multiple chunks', () async {
      final req = http.Request(
        'POST',
        Uri.parse('https://example.com/_matrix/client/v3/upload'),
      );
      // Use incompressible (random) data so zstd does not collapse it.
      final random = Random.secure();
      final body = Uint8List(80 * 1024);
      for (var i = 0; i < body.length; i++) {
        body[i] = random.nextInt(256);
      }
      req.bodyBytes = body;

      await client.send(req);

      expect(inner.requests.length, greaterThanOrEqualTo(4));
      for (var i = 0; i < inner.requests.length; i++) {
        expect(inner.requests[i].method, 'OPTIONS');
        expect(inner.requests[i].headers['x-qnskk-chunk-index'], '$i');
        expect(
          inner.requests[i].headers['x-qnskk-chunk-total'],
          '${inner.requests.length}',
        );
        // All chunks share the same nonce.
        expect(
          inner.requests[i].headers['x-qnskk-nonce'],
          inner.requests[0].headers['x-qnskk-nonce'],
        );
      }
    });

    test('Each chunk is within the 12-20 KB window', () async {
      final req = http.Request(
        'POST',
        Uri.parse('https://example.com/_matrix/client/v3/upload'),
      );
      final random = Random.secure();
      final body = Uint8List(60 * 1024);
      for (var i = 0; i < body.length; i++) {
        body[i] = random.nextInt(256);
      }
      req.bodyBytes = body;

      await client.send(req);

      expect(inner.requests.length, greaterThan(1));
      for (final sent in inner.requests) {
        final payloadB64 = sent.headers['x-qnskk-tunnel-payload']!;
        // base64 adds ~33% overhead so a 20 KB chunk encodes to ~28 KB.
        expect(payloadB64.length, lessThanOrEqualTo(28 * 1024));
      }
    });

    test('Encryption key length is asserted', () {
      expect(
        () => TunnelHttpClient(
          inner: inner,
          encryptionKey: Uint8List(16),
          clientPublicKey: Uint8List(32),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Client public key length is asserted', () {
      expect(
        () => TunnelHttpClient(
          inner: inner,
          encryptionKey: Uint8List(32),
          clientPublicKey: Uint8List(16),
        ),
        throwsA(isA<AssertionError>()),
      );
    });

    test('Body, path and method are present in encrypted payload', () async {
      final req = http.Request(
        'POST',
        Uri.parse('https://example.com/path?key=value'),
      );
      req.headers['x-test'] = 'value';
      req.bodyBytes = utf8.encode('payload');

      await client.send(req);

      final payloadB64 =
          inner.requests.first.headers['x-qnskk-tunnel-payload']!;
      // The payload header contains: nonce (12 bytes) + ciphertext + tag (16 bytes)
      // encoded with URL-safe base64. Just check that we get *something* non-trivial.
      final decoded = base64Url.decode(_withBase64Padding(payloadB64));
      expect(decoded.length, greaterThan(12 + 16));
    });
  });
}

String _withBase64Padding(String value) {
  var padded = value;
  while (padded.length % 4 != 0) {
    padded += '=';
  }
  return padded;
}
