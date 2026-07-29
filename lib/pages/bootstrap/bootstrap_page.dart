// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/pages/bootstrap/view_model/bootstrap_view_model.dart';
import 'package:fluffychat/pages/bootstrap/widgets/new_passphrase_view.dart';
import 'package:fluffychat/pages/bootstrap/widgets/restore_bootstrap_view.dart';
import 'package:fluffychat/widgets/layouts/login_scaffold.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:fluffychat/widgets/view_model_builder.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class BootstrapPage extends StatelessWidget {
  final bool reset;
  const BootstrapPage({required this.reset, super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder(
      create: () =>
          BootstrapViewModel(client: Matrix.of(context).client, reset: reset),
      builder: (context, viewModel, _) {
        final cryptoIdentityState = viewModel.value.cryptoIdentityState;
        final showLoading =
            cryptoIdentityState == null || viewModel.value.isLoading;
        if (reset) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => viewModel.performAutomaticReset(context),
          );
        } else if (cryptoIdentityState?.connected == true) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => viewModel.goToRoomsPageAfterSuccess(context),
          );
        } else if (cryptoIdentityState != null) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => viewModel.tryAutoRecovery(context),
          );
        }

        final title = showLoading
            ? L10n.of(context).loadingPleaseWait
            : viewModel.value.reset
            ? L10n.of(context).resetCryptoIdentity
            : cryptoIdentityState.initialized
            ? L10n.of(context).restoreCryptoIdentity
            : L10n.of(context).setUpCryptoIdentity;

        return LoginScaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            leading: reset
                ? CloseButton(onPressed: () => context.go('/rooms'))
                : null,
            title: Text(title),
          ),

          body: showLoading
              ? Center(child: CircularProgressIndicator.adaptive())
              : (!cryptoIdentityState.initialized || viewModel.value.reset)
              ? NewPassphraseView(viewModel)
              : RestoreBootstrapView(viewModel),
        );
      },
    );
  }
}
