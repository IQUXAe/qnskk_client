import 'package:matrix/matrix.dart';

const qnskkHomeserver = 'https://api.qnskk.top';
const qnskkHomeserverHost = 'api.qnskk.top';

Uri qnskkHomeserverUri() {
  return Uri.https(qnskkHomeserverHost, '');
}

Future<void> ensureQnskkHomeserver(Client client) async {
  await client.checkHomeserver(qnskkHomeserverUri(), fetchAuthMetadata: false);
}
