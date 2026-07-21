import 'package:matrix/matrix.dart';

const qnskkHomeserver = 'https://api.qnskk.top';
const qnskkHomeserverHost = 'api.qnskk.top';

Uri qnskkHomeserverUri() {
  return Uri.https(qnskkHomeserverHost, '');
}

Future<void> ensureQnskkHomeserver(Client client) async {
  await client.checkHomeserver(qnskkHomeserverUri(), fetchAuthMetadata: false);
}

bool isQnskkUserId(String userId) {
  return userId.isValidMatrixIdStrict() &&
      userId.sigil == '@' &&
      userId.domain == qnskkHomeserverHost;
}

String? qnskkUserIdFromInput(String input) {
  final text = input.trim().toLowerCase();
  if (text.isEmpty) return null;

  if (text.isValidMatrixIdStrict() && text.sigil == '@') {
    return isQnskkUserId(text) ? text : null;
  }

  final localpart = text.startsWith('@') ? text.substring(1) : text;
  if (localpart.isEmpty || localpart.contains(':')) return null;

  final userId = '@$localpart:$qnskkHomeserverHost';
  return isQnskkUserId(userId) ? userId : null;
}

String qnskkUserSearchTerm(String input) {
  final userId = qnskkUserIdFromInput(input);
  return userId?.localpart ?? input.trim();
}

String qnskkDisplayUserId(String userId) {
  return isQnskkUserId(userId) ? userId.localpart ?? userId : userId;
}

bool isQnskkRoomAlias(String alias) {
  return alias.isValidMatrixIdStrict() &&
      alias.sigil == '#' &&
      alias.domain == qnskkHomeserverHost;
}

String? qnskkRoomAliasFromInput(String input) {
  final text = input.trim().toLowerCase();
  if (text.isEmpty) return null;

  if (text.isValidMatrixIdStrict() && text.sigil == '#') {
    return isQnskkRoomAlias(text) ? text : null;
  }

  final localpart = text.startsWith('#') ? text.substring(1) : text;
  if (localpart.isEmpty || localpart.contains(':')) return null;

  final alias = '#$localpart:$qnskkHomeserverHost';
  return isQnskkRoomAlias(alias) ? alias : null;
}
