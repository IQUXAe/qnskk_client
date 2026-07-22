import 'package:matrix/matrix.dart';

const qnskkHomeserver = 'https://api.qnskk.top';
const qnskkHomeserverHost = 'api.qnskk.top';
const qnskkMatrixDomain = 'qnskk.top';

Uri qnskkHomeserverUri() {
  return Uri.https(qnskkHomeserverHost, '');
}

Future<void> ensureQnskkHomeserver(Client client) async {
  await client.checkHomeserver(qnskkHomeserverUri(), fetchAuthMetadata: false);
}

bool isQnskkUserId(String userId) {
  if (!userId.isValidMatrixIdStrict() || userId.sigil != '@') return false;
  final domain = userId.domain;
  return domain == qnskkMatrixDomain || domain == qnskkHomeserverHost;
}

String? qnskkUserIdFromInput(String input) {
  final text = input.trim().toLowerCase();
  if (text.isEmpty) return null;

  if (text.isValidMatrixIdStrict() && text.sigil == '@') {
    return isQnskkUserId(text) ? text : null;
  }

  final localpart = text.startsWith('@') ? text.substring(1) : text;
  if (localpart.isEmpty || localpart.contains(':')) return null;

  final userId = '@$localpart:$qnskkMatrixDomain';
  return isQnskkUserId(userId) ? userId : null;
}

String qnskkUserSearchTerm(String input) {
  final userId = qnskkUserIdFromInput(input);
  return userId?.localpart ?? input.trim();
}

String qnskkDisplayUserId(String userId) {
  if (!isQnskkUserId(userId)) return userId;
  final localpart = userId.localpart ?? userId;
  return localpart.startsWith('@') ? localpart : '@$localpart';
}

bool isQnskkRoomAlias(String alias) {
  if (!alias.isValidMatrixIdStrict() || alias.sigil != '#') return false;
  final domain = alias.domain;
  return domain == qnskkMatrixDomain || domain == qnskkHomeserverHost;
}

String? qnskkRoomAliasFromInput(String input) {
  final text = input.trim().toLowerCase();
  if (text.isEmpty) return null;

  if (text.isValidMatrixIdStrict() && text.sigil == '#') {
    return isQnskkRoomAlias(text) ? text : null;
  }

  final localpart = text.startsWith('#') ? text.substring(1) : text;
  if (localpart.isEmpty || localpart.contains(':')) return null;

  final alias = '#$localpart:$qnskkMatrixDomain';
  return isQnskkRoomAlias(alias) ? alias : null;
}
