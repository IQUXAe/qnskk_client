import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/widgets/layouts/login_scaffold.dart';
import 'package:flutter/material.dart';

import 'register.dart';

class RegisterView extends StatelessWidget {
  final RegisterController controller;

  const RegisterView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final homeserver = controller.widget.client.homeserver
        ?.toString()
        .replaceFirst('https://', '');

    return LoginScaffold(
      appBar: AppBar(
        leading: controller.loading ? null : const Center(child: BackButton()),
        automaticallyImplyLeading: !controller.loading,
        title: Text(L10n.of(context).createNewAccount),
      ),
      body: AutofillGroup(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            Center(
              child: Hero(
                tag: 'info-logo',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(128),
                  child: Image.asset(
                    './assets/logo/mini/logo_mini.png',
                    width: 128,
                    height: 128,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (homeserver != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  homeserver,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.colorScheme.secondary,
                    fontSize: 14,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                readOnly: controller.loading,
                autocorrect: false,
                autofocus: true,
                controller: controller.usernameController,
                textInputAction: TextInputAction.next,
                autofillHints:
                    controller.loading ? null : [AutofillHints.newUsername],
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.account_box_outlined),
                  errorText: controller.usernameError,
                  errorStyle: const TextStyle(color: Colors.orange),
                  hintText: 'username',
                  labelText: 'Username',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: TextField(
                readOnly: controller.loading,
                autocorrect: false,
                autofillHints:
                    controller.loading ? null : [AutofillHints.newPassword],
                controller: controller.passwordController,
                textInputAction: TextInputAction.go,
                obscureText: !controller.showPassword,
                onSubmitted: (_) => controller.register(),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outlined),
                  errorText: controller.passwordError,
                  errorStyle: const TextStyle(color: Colors.orange),
                  suffixIcon: IconButton(
                    onPressed: controller.toggleShowPassword,
                    icon: Icon(
                      controller.showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                  hintText: '******',
                  labelText: L10n.of(context).password,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                ),
                onPressed: controller.loading ? null : controller.register,
                child: controller.loading
                    ? const LinearProgressIndicator()
                    : Text(L10n.of(context).createNewAccount),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
