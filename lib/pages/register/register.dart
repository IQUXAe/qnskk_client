
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/qnskk_homeserver.dart';
import 'package:fluffychat/utils/qnskk_invite_config.dart';
import 'package:fluffychat/utils/qnskk_recovery_passphrase.dart';
import 'package:fluffychat/utils/tunnel_http_client.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

import 'register_view.dart';

class Register extends StatefulWidget {
  final Client client;
  const Register({required this.client, super.key});

  @override
  RegisterController createState() => RegisterController();
}

class RegisterController extends State<Register> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController inviteController = TextEditingController();

  bool loading = false;
  bool showPassword = false;
  bool checkingInviteConfig = true;
  bool inviteRequired = false;

  String? usernameError;
  String? passwordError;
  String? inviteError;

  @override
  void initState() {
    super.initState();
    _fetchInviteConfig();
  }

  Future<void> _fetchInviteConfig() async {
    final homeserverUrl =
        widget.client.homeserver?.toString() ?? 'https://api.qnskk.top';
    final config = await QnskkInviteConfig.fetch(homeserverUrl);
    if (!mounted) return;
    setState(() {
      inviteRequired = config.inviteRequired;
      checkingInviteConfig = false;
    });
  }

  void toggleShowPassword() =>
      setState(() => showPassword = !loading && !showPassword);

  Future<void> register() async {
    // Sanitize username: strip leading @, domain suffix, lowercase.
    var username = usernameController.text.trim().toLowerCase();
    if (username.startsWith('@')) username = username.substring(1);
    if (username.contains(':')) username = username.split(':').first;
    final password = passwordController.text;
    final inviteCode = inviteController.text.trim();
    final isRu = Localizations.localeOf(context).languageCode == 'ru';

    if (username.isEmpty) {
      setState(() => usernameError = L10n.of(context).pleaseEnterYourUsername);
      return;
    }
    setState(() => usernameError = null);

    if (password.length < 8) {
      setState(() => passwordError = 'Password must be at least 8 characters');
      return;
    }
    setState(() => passwordError = null);

    if (inviteRequired && inviteCode.isEmpty) {
      setState(() => inviteError = isRu
          ? 'Введите код приглашения'
          : 'Please enter an invite code');
      return;
    }
    setState(() => inviteError = null);

    setState(() => loading = true);

    try {
      await ensureQnskkHomeserver(widget.client);

      // Attach invite code to the tunnel transport before calling SDK register.
      // The TunnelHttpClient will pick it up for the next OPTIONS send and then
      // clear it automatically.
      if (inviteRequired && inviteCode.isNotEmpty) {
        final tunnelClient =
            widget.client.httpClient as TunnelHttpClient?;
        tunnelClient?.pendingInviteCode = inviteCode;
      }

      await widget.client.register(
        username: username,
        password: password,
        auth: AuthenticationData(type: 'm.login.dummy'),
        initialDeviceDisplayName: PlatformInfos.appDisplayName,
      );

      if (!mounted) return;
      final matrix = Matrix.of(context);
      if (!widget.client.isLogged()) {
        await widget.client.login(
          LoginType.mLoginPassword,
          identifier: AuthenticationUserIdentifier(user: username),
          password: password,
          initialDeviceDisplayName: PlatformInfos.appDisplayName,
        );
      }

      if (!matrix.widget.clients.contains(widget.client)) {
        matrix.widget.clients.add(widget.client);
      }

      final userId = widget.client.userID?.toString();
      if (userId != null) {
        await QnskkRecoveryPassphrase.rememberPassword(
          userId: userId,
          password: password,
        );
      }

      if (mounted) context.go('/backup');
    } on MatrixException catch (e) {
      setState(() {
        if (e.error == MatrixError.M_USER_IN_USE) {
          usernameError = 'Username already taken';
        } else if (e.error == MatrixError.M_INVALID_USERNAME) {
          usernameError = 'Invalid username';
        } else if (e.errorMessage.contains('invite') ||
            e.errorMessage.contains('Invite') ||
            e.errorMessage.contains('M_FORBIDDEN')) {
          inviteError = isRu
              ? 'Неверный или исчерпанный код приглашения'
              : 'Invalid or exhausted invite code';
        } else {
          passwordError = e.errorMessage;
        }
        loading = false;
      });
    } catch (e) {
      final str = e.toString();
      // Handle server-returned invite error (403 from tunnel interceptor)
      if (str.contains('M_FORBIDDEN') ||
          str.contains('Invite code') ||
          str.contains('invite code')) {
        setState(() {
          inviteError = isRu
              ? 'Неверный или исчерпанный код приглашения'
              : 'Invalid or exhausted invite code';
          loading = false;
        });
        return;
      }
      final isTunnelOrNetwork = str.contains('Tunnel error') ||
          str.contains('ClientException') ||
          str.contains('SocketException') ||
          str.contains('Connection refused') ||
          str.contains('Connection reset') ||
          str.contains('Connection timed out') ||
          str.contains('HandshakeException') ||
          str.contains('http error response');
      setState(() {
        passwordError = isTunnelOrNetwork
            ? (isRu
                ? 'Ошибка соединения с сервером QNSKK. Проверьте подключение к сети.'
                : 'Connection error to QNSKK server. Check your network connection.')
            : str;
        loading = false;
      });
    }
  }

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    inviteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RegisterView(this);
}
