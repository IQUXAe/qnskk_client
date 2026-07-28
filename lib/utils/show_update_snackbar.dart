import 'package:fluffychat/utils/update_checker.dart';
import 'package:fluffychat/widgets/update_banner.dart';
import 'package:flutter/material.dart';

abstract class UpdateNotifier {
  static final ValueNotifier<UpdateCheckerResult?> softUpdateNotifier =
      ValueNotifier<UpdateCheckerResult?>(null);

  static Future<void> showUpdateDialog(BuildContext context) async {
    final result = await UpdateChecker.instance.checkForUpdates();
    if (!context.mounted) return;

    if (result.type == UpdateType.hard) {
      softUpdateNotifier.value = null;
      await MandatoryUpdateDialog.show(context, result);
    } else if (result.type == UpdateType.soft) {
      softUpdateNotifier.value = result;
    } else {
      softUpdateNotifier.value = null;
    }
  }

  static void dismissSoftUpdate() {
    softUpdateNotifier.value = null;
  }
}
