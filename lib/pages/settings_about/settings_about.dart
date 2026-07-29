// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/layouts/max_width_body.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SettingsAbout extends StatefulWidget {
  const SettingsAbout({super.key});

  @override
  State<SettingsAbout> createState() => _SettingsAboutState();
}

class _SettingsAboutState extends State<SettingsAbout> {
  String _version = '...';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final ver = await PlatformInfos.getVersion();
    if (mounted) {
      setState(() {
        _version = ver;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isColumnMode = FluffyThemes.isColumnMode(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).about),
        automaticallyImplyLeading: !isColumnMode,
        centerTitle: isColumnMode,
      ),
      body: ListTileTheme(
        iconColor: theme.colorScheme.onSurface,
        child: MaxWidthBody(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            children: [
              // Header Card
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Image.asset(
                        'assets/logo/mini/logo_mini.png',
                        height: 72,
                        width: 72,
                        errorBuilder: (context, error, stackTrace) => Icon(
                          Icons.shield_outlined,
                          size: 72,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AppConfig.projectName,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Версия $_version',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Высокозащищенная система обмена сообщениями, построенная на базе открытого сетевого протокола Matrix с применением сквозного шифрования (E2EE) и механизмов маскировки структуры трафика.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Section: Architecture & Authors
              const _SectionHeader(title: 'Архитектура и разработчики'),
              const SizedBox(height: 8),

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.code_rounded),
                      title: const Text('Основной разработчик'),
                      subtitle: Text(AppConfig.primaryDeveloper),
                    ),
                    Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
                    const ListTile(
                      leading: Icon(Icons.hub_outlined),
                      title: Text('Сетевой протокол'),
                      subtitle: Text('Matrix Protocol Foundation (spec.matrix.org)'),
                    ),
                    Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
                    ListTile(
                      leading: const Icon(Icons.phone_android_outlined),
                      title: const Text('Клиентское приложение'),
                      subtitle: Text('Создано на основе ${AppConfig.clientBase}'),
                    ),
                    Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
                    ListTile(
                      leading: const Icon(Icons.dns_outlined),
                      title: const Text('Серверная инфраструктура'),
                      subtitle: Text('Создана на основе ${AppConfig.serverBase}'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section: Source Code & Licenses
              const _SectionHeader(title: 'Исходный код и лицензирование'),
              const SizedBox(height: 8),

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.open_in_new_rounded),
                      title: const Text('Клиентский репозиторий'),
                      subtitle: Text('${AppConfig.clientSourceCodeUrl}\nЛицензия: ${AppConfig.clientLicenseName}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => launchUrlString(AppConfig.clientSourceCodeUrl),
                    ),
                    Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
                    ListTile(
                      leading: const Icon(Icons.lock_outline_rounded),
                      title: const Text('Серверная часть и Edge Proxy'),
                      subtitle: Text(AppConfig.serverLicenseName),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section: Legal Documents
              const _SectionHeader(title: 'Правовые документы'),
              const SizedBox(height: 8),

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.shield_moon_outlined),
                      title: const Text('Политика конфиденциальности'),
                      subtitle: Text('Защита данных GDPR / DSGVO (${AppConfig.serverLocationRegion})'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.go('/settings/privacy'),
                    ),
                    Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
                    ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: const Text('Условия использования'),
                      subtitle: const Text('Пользовательское соглашение и отказ от гарантий'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.go('/settings/terms'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section: License text dropdown
              const _SectionHeader(title: 'Текст лицензии AGPL-3.0'),
              const SizedBox(height: 8),

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: ExpansionTile(
                  leading: const Icon(Icons.gavel_outlined),
                  title: const Text('Лицензия AGPL-3.0'),
                  subtitle: Text(AppConfig.clientLicenseName),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: SelectableText(
                          _agpl3Text,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Section: Packages & System
              const _SectionHeader(title: 'Зависимости и системные компоненты'),
              const SizedBox(height: 8),

              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.collections_bookmark_outlined),
                      title: const Text('Лицензии сторонних пакетов'),
                      subtitle: const Text('Просмотр лицензий используемых Flutter-библиотек'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: AppConfig.projectName,
                        applicationVersion: _version,
                      ),
                    ),
                    Divider(height: 1, color: theme.dividerColor.withValues(alpha: 0.5)),
                    ListTile(
                      leading: const Icon(Icons.terminal_outlined),
                      title: Text(L10n.of(context).logs),
                      subtitle: const Text('Системные журналы отладки приложения'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => context.go('/logs'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.primary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

const String _agpl3Text = '''
GNU AFFERO GENERAL PUBLIC LICENSE
Version 3, 19 November 2007

Copyright (C) 2007 Free Software Foundation, Inc. <https://fsf.org/>
Everyone is permitted to copy and distribute verbatim copies of this license document, but changing it is not allowed.

Preamble

The GNU Affero General Public License is a free, copyleft license for software and other kinds of works, specifically designed to ensure cooperation with the community in the case of network server software.

The licenses for most software and other practical works are designed to take away your freedom to share and change the works. By contrast, the GNU General Public License is intended to guarantee your freedom to share and change all versions of a program--to make sure it remains free software for all its users.

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.
''';
