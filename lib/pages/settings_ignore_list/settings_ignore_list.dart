// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/qnskk_homeserver.dart';
import 'package:fluffychat/widgets/future_loading_dialog.dart';
import 'package:flutter/material.dart';

import '../../widgets/matrix.dart';
import 'settings_ignore_list_view.dart';

class SettingsIgnoreList extends StatefulWidget {
  final String? initialUserId;

  const SettingsIgnoreList({super.key, this.initialUserId});

  @override
  SettingsIgnoreListController createState() => SettingsIgnoreListController();
}

class SettingsIgnoreListController extends State<SettingsIgnoreList> {
  final TextEditingController controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initialUserId = widget.initialUserId;
    if (initialUserId != null) {
      controller.text = initialUserId;
    }
  }

  String? errorText;

  void ignoreUser(BuildContext context) {
    final userId = qnskkUserIdFromInput(controller.text);
    if (controller.text.trim().isEmpty) return;
    if (userId == null) {
      setState(() {
        errorText = L10n.of(context).invalidInput;
      });
      return;
    }
    setState(() {
      errorText = null;
    });

    final client = Matrix.of(context).client;
    showFutureLoadingDialog(
      context: context,
      future: () => client.ignoreUser(userId),
    );
    setState(() {});
    controller.clear();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SettingsIgnoreListView(this);
}
