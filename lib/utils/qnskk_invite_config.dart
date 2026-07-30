// SPDX-FileCopyrightText: QNSKK Project
// SPDX-License-Identifier: Proprietary

import 'dart:convert';

import 'package:http/http.dart' as http;

/// Fetches the QNSKK invite configuration from the homeserver.
class QnskkInviteConfig {
  final bool inviteRequired;

  const QnskkInviteConfig({required this.inviteRequired});

  static const _configPath = '/_qnskk/invite/config';

  /// Fetches invite config directly (GET — no tunnel needed).
  /// Returns [inviteRequired]=false on any error (fail-open for UX).
  static Future<QnskkInviteConfig> fetch(String homeserverUrl) async {
    try {
      final uri = Uri.parse('$homeserverUrl$_configPath');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return QnskkInviteConfig(
          inviteRequired: data['invite_required'] as bool? ?? false,
        );
      }
    } catch (_) {
      // Network error or server doesn't support invite system — fail open.
    }
    return const QnskkInviteConfig(inviteRequired: false);
  }
}
