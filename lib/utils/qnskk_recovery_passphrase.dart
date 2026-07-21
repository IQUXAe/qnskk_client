import 'dart:convert';

import 'package:cryptography/cryptography.dart';

String _base64UrlNoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

abstract class QnskkRecoveryPassphrase {
  static final Map<String, String> _pendingPassphrases = {};

  static Future<void> rememberPassword({
    required String userId,
    required String password,
  }) async {
    _pendingPassphrases[userId] = await derive(
      userId: userId,
      password: password,
    );
  }

  static String? take(String userId) => _pendingPassphrases.remove(userId);

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
