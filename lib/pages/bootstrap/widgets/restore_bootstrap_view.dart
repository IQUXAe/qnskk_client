// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/bootstrap/view_model/bootstrap_view_model.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/show_ok_cancel_alert_dialog.dart';
import 'package:flutter/material.dart';

class RestoreBootstrapView extends StatelessWidget {
  final BootstrapViewModel viewModel;

  const RestoreBootstrapView(this.viewModel, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text(
          L10n.of(context).restoreBootstrapEmptyDevicesDescription,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        TextField(
          readOnly: viewModel.value.isLoading,
          obscureText: viewModel.value.obscureText,
          controller: viewModel.enterPassphraseController,
          minLines: 1,
          maxLines: 1,
          onSubmitted: (_) => viewModel.unlock(context),
          decoration: InputDecoration(
            hintText: L10n.of(context).password,
            prefixIcon: IconButton(
              icon: Icon(
                viewModel.value.obscureText
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: viewModel.toggleObscureText,
            ),
            errorText: viewModel.value.unlockWithError?.toLocalizedString(
              context,
            ),
            errorMaxLines: 4,
            suffixIcon: viewModel.value.isLoading
                ? SizedBox.square(
                    dimension: 32,
                    child: Center(
                      child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppConfig.borderRadius / 2,
                        ),
                      ),
                    ),
                    onPressed: viewModel.value.passphraseEntered
                        ? () => viewModel.unlock(context)
                        : null,
                    child: Text(L10n.of(context).unlock),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () async {
            final consent = await showOkCancelAlertDialog(
              context: context,
              title: L10n.of(context).warning,
              message: L10n.of(context).resetAccountWarning,
              isDestructive: true,
              okLabel: L10n.of(context).resetAccount,
            );
            if (consent != OkCancelResult.ok) return;
            if (!context.mounted) return;
            viewModel.startResetAccount();
          },
          style: TextButton.styleFrom(foregroundColor: theme.colorScheme.error),
          child: Text(L10n.of(context).resetAccount),
        ),
      ],
    );
  }
}
