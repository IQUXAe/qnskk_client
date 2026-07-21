import 'package:fluffychat/utils/qnskk_recovery_passphrase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QnskkRecoveryPassphrase', () {
    test('derive is stable for the same user and password', () async {
      final first = await QnskkRecoveryPassphrase.derive(
        userId: '@alice:api.qnskk.top',
        password: 'correct horse battery staple',
      );
      final second = await QnskkRecoveryPassphrase.derive(
        userId: '@alice:api.qnskk.top',
        password: 'correct horse battery staple',
      );

      expect(first, second);
      expect(first, isNot(contains('=')));
      expect(first, hasLength(43));
    });

    test('derive changes when user or password changes', () async {
      final base = await QnskkRecoveryPassphrase.derive(
        userId: '@alice:api.qnskk.top',
        password: 'correct horse battery staple',
      );
      final otherUser = await QnskkRecoveryPassphrase.derive(
        userId: '@bob:api.qnskk.top',
        password: 'correct horse battery staple',
      );
      final otherPassword = await QnskkRecoveryPassphrase.derive(
        userId: '@alice:api.qnskk.top',
        password: 'different password',
      );

      expect(base, isNot(otherUser));
      expect(base, isNot(otherPassword));
    });

    test('rememberPassword stores only the derived passphrase once', () async {
      const userId = '@carol:api.qnskk.top';
      const password = 'plain account password';
      final expected = await QnskkRecoveryPassphrase.derive(
        userId: userId,
        password: password,
      );

      await QnskkRecoveryPassphrase.rememberPassword(
        userId: userId,
        password: password,
      );

      expect(QnskkRecoveryPassphrase.has(userId), isTrue);
      final stored = QnskkRecoveryPassphrase.take(userId);
      expect(stored, expected);
      expect(stored, isNot(password));
      expect(QnskkRecoveryPassphrase.has(userId), isFalse);
      expect(QnskkRecoveryPassphrase.take(userId), isNull);
    });
  });
}
