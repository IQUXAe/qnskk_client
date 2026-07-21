import 'package:fluffychat/utils/tunnel_key_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    TunnelKeyManager.useInMemoryStorageForTests = true;
    await TunnelKeyManager.instance.resetForTesting();
  });

  group('TunnelKeyManager', () {
    test('clientPublicKey returns 32-byte key', () async {
      final key = await TunnelKeyManager.instance.clientPublicKey;
      expect(key.length, 32);
    });

    test('clientPublicKey returns the same key on subsequent calls', () async {
      final first = await TunnelKeyManager.instance.clientPublicKey;
      final second = await TunnelKeyManager.instance.clientPublicKey;
      expect(first, equals(second));
    });

    test('rotateKeys produces a different keypair', () async {
      final first = await TunnelKeyManager.instance.clientPublicKey;
      // rotateKeys needs a server URI, but we can test that it clears state
      // by calling rotateKeys with a dummy URL (it will fail the HTTP call
      // but the keypair should be regenerated).
      try {
        await TunnelKeyManager.instance.rotateKeys('http://localhost:9999');
      } catch (_) {}
      final second = await TunnelKeyManager.instance.clientPublicKey;
      expect(first, isNot(equals(second)));
      expect(second.length, 32);
    });
  });
}
