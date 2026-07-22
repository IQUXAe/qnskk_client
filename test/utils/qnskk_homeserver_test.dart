import 'package:fluffychat/utils/qnskk_homeserver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QNSKK local identifiers', () {
    test('normalizes short usernames to local Matrix user IDs', () {
      expect(qnskkUserIdFromInput('test1'), '@test1:qnskk.top');
      expect(qnskkUserIdFromInput('@test1'), '@test1:qnskk.top');
      expect(
        qnskkUserIdFromInput('@test1:qnskk.top'),
        '@test1:qnskk.top',
      );
      expect(
        qnskkUserIdFromInput('@test1:api.qnskk.top'),
        '@test1:api.qnskk.top',
      );
    });

    test('rejects foreign Matrix user IDs', () {
      expect(qnskkUserIdFromInput('@test1:matrix.org'), isNull);
      expect(qnskkUserIdFromInput('test1:matrix.org'), isNull);
    });

    test('uses short display names for local users only', () {
      expect(qnskkDisplayUserId('@test1:qnskk.top'), '@test1');
      expect(qnskkDisplayUserId('@test1:api.qnskk.top'), '@test1');
      expect(qnskkDisplayUserId('@test1:matrix.org'), '@test1:matrix.org');
    });

    test('normalizes short room aliases to local aliases', () {
      expect(qnskkRoomAliasFromInput('general'), '#general:qnskk.top');
      expect(qnskkRoomAliasFromInput('#general'), '#general:qnskk.top');
      expect(
        qnskkRoomAliasFromInput('#general:qnskk.top'),
        '#general:qnskk.top',
      );
      expect(
        qnskkRoomAliasFromInput('#general:api.qnskk.top'),
        '#general:api.qnskk.top',
      );
    });

    test('rejects foreign room aliases', () {
      expect(qnskkRoomAliasFromInput('#general:matrix.org'), isNull);
      expect(qnskkRoomAliasFromInput('general:matrix.org'), isNull);
    });
  });
}
