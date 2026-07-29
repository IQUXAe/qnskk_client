// SPDX-FileCopyrightText: 2019-Present Contributors to QNSKK
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:ui';

abstract class AppConfig {
  static const Color primaryColor = Color(0xFF261386);

  static const Color chatColor = primaryColor;
  static const double messageFontSize = 16.0;
  static const bool enableRegistration = true;
  static const bool hideTypingUsernames = false;

  static const String inviteLinkPrefix = 'https://matrix.to/#/';
  static const String deepLinkPrefix = 'org.iquxae.qnskk://chat/';
  static const String schemePrefix = 'matrix:';
  static const String pushNotificationsChannelId = 'qnskk_push';
  static const String pushNotificationsAppId = 'org.iquxae.qnskk';
  static const double borderRadius = 18.0;
  static const double spaceBorderRadius = 11.0;
  static const double columnWidth = 360.0;

  static const String enablePushTutorial = '';
  static const String encryptionTutorial = '';
  static const String startChatTutorial = '';
  static const String howDoIGetStickersTutorial = '';
  static const String appId = 'org.iquxae.qnskk';
  static const String appOpenUrlScheme = 'org.iquxae.qnskk';
  static const String appSsoUrlScheme = 'org.iquxae.qnskk.auth';

  static const String projectName = 'QNSKK Project';
  static const String primaryDeveloper = 'IQUXAe';
  static const String clientBase = 'FluffyChat (Christian Kußowski & Contributors)';
  static const String serverBase = 'Conduit Matrix Homeserver (Timo Koster, Famedly & Contributors)';
  static const String clientSourceCodeUrl = 'https://github.com/IQUXAe/qnskk_client';
  static const String clientLicenseName = 'GNU Affero General Public License v3.0 (AGPLv3)';
  static const String serverLicenseName = 'Closed-Source / Proprietary (Закрытый исходный код)';
  static const String serverLocationRegion = 'Germany (EU / ФРГ)';

  static const String sourceCodeUrl = clientSourceCodeUrl;
  static const String supportUrl = '';
  static const String changelogUrl = '';
  static const String helpUrl = '';

  static const Set<String> defaultReactions = {'👍', '❤️', '😂', '😮', '😢'};

  static final Uri newIssueUrl = Uri();

  static const String mainIsolatePortName = 'main_isolate';
  static const String pushIsolatePortName = 'push_isolate';
  static const String pushHelperCrashReportKey = 'push_helper_crash_report';
}
