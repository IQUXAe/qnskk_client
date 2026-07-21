import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/qnskk_homeserver.dart';
import 'package:fluffychat/utils/qnskk_recovery_passphrase.dart';
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
  bool loading = false;
  bool showPassword = false;
  String? usernameError;
  String? passwordError;

  void toggleShowPassword() =>
      setState(() => showPassword = !loading && !showPassword);

  Future<void> register() async {
    final username = usernameController.text.trim();
    final password = passwordController.text;

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

    setState(() => loading = true);

    try {
      await ensureQnskkHomeserver(widget.client);
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
        } else {
          passwordError = e.errorMessage;
        }
        loading = false;
      });
    } catch (e) {
      setState(() {
        passwordError = e.toString();
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) => RegisterView(this);
}
