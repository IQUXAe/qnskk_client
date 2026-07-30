// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/widgets/layouts/max_width_body.dart';
import 'package:flutter/material.dart';

class SettingsTerms extends StatelessWidget {
  const SettingsTerms({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isColumnMode = FluffyThemes.isColumnMode(context);
    final locale = Localizations.localeOf(context).languageCode;
    final isRu = locale == 'ru';

    final sections = isRu ? _sectionsRu : _sectionsEn;

    return Scaffold(
      appBar: AppBar(
        title: Text(isRu ? 'Условия использования' : 'Terms of Use'),
        automaticallyImplyLeading: !isColumnMode,
        centerTitle: isColumnMode,
      ),
      body: MaxWidthBody(
        withScrolling: false,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          children: [
            // Header card
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConfig.borderRadius),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRu
                                ? 'Пользовательское соглашение'
                                : 'End User Agreement',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isRu
                                ? 'Правила использования сервиса QNSKK Project (api.qnskk.top).'
                                : 'Terms governing use of the QNSKK Project service (api.qnskk.top).',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            ...sections.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return _TermsSection(
                number: '${i + 1}',
                title: s[0],
                content: s[1],
              );
            }),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

const _sectionsRu = [
  [
    'Принятие условий',
    'Регистрация учетной записи, авторизация или любое использование клиентского приложения QNSKK означает ваше полное и безоговорочное согласие с настоящими Условиями использования.',
  ],
  [
    'Отказ от гарантий (AS IS)',
    'Сервис QNSKK предоставляется на условиях «КАК ЕСТЬ» («AS IS») и «ПО МЕРЕ ДОСТУПНОСТИ» («AS AVAILABLE»). Администрация сервиса не дает явных или подразумеваемых гарантий непрерывной работы в условиях внешних сетевых блокировок, сбоев магистральных провайдеров или нештатных ситуаций.',
  ],
  [
    'Ограничение ответственности',
    '1. Пользователь несет персональную ответственность за сохранность своих учетных данных и пароля.\n2. Ввиду применения сквозного шифрования (E2EE), администрация сервиса не обладает технической возможностью восстановить зашифрованные сообщения в случае утери пользователем своего пароля.\n3. Администрация не несет ответственности за любые косвенные убытки, возникшие в результате использования или невозможности использования сервиса.',
  ],
  [
    'Правила допустимого использования (AUP)',
    'Категорически запрещается использовать сервис для:\n• Проведения спам-атак, автоматизированной рассылки или дестабилизации работы серверов (DDoS).\n• Распространения вредоносного программного обеспечения или реализации сетевых атак.\n• Совершения противоправных действий, нарушающих законодательство ЕС/ФРГ.\n\nПри выявлении злоупотреблений аккаунт нарушителя может быть заблокирован без предварительного уведомления.',
  ],
  [
    'Применимое право',
    'Настоящие условия и любые возникающие споры регулируются материальным правом Федеративной Республики Германия (ЕС), за исключением норм международного частного права.',
  ],
];

const _sectionsEn = [
  [
    'Acceptance of Terms',
    'Registering an account, logging in or using the QNSKK client application in any way constitutes your full and unconditional acceptance of these Terms of Use.',
  ],
  [
    'Disclaimer of Warranties (AS IS)',
    'The QNSKK service is provided "AS IS" and "AS AVAILABLE". The service administration makes no express or implied warranties of uninterrupted availability in the event of external network restrictions, upstream provider failures or other extraordinary circumstances.',
  ],
  [
    'Limitation of Liability',
    '1. The user is solely responsible for the security of their credentials and password.\n2. Due to end-to-end encryption (E2EE), the service administration has no technical ability to recover encrypted messages if the user loses their password.\n3. The administration is not liable for any indirect damages arising from the use or inability to use the service.',
  ],
  [
    'Acceptable Use Policy (AUP)',
    'It is strictly prohibited to use the service for:\n• Spam campaigns, automated mass messaging or server destabilization (DDoS).\n• Distribution of malware or execution of network attacks.\n• Any unlawful activities violating applicable EU/German law.\n\nUpon detection of infrastructure abuse, the offending account may be suspended without prior notice.',
  ],
  [
    'Governing Law',
    'These terms and any disputes arising from them are governed by the substantive law of the Federal Republic of Germany (EU), excluding rules of private international law.',
  ],
];

class _TermsSection extends StatelessWidget {
  final String number;
  final String title;
  final String content;

  const _TermsSection({
    required this.number,
    required this.title,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConfig.borderRadius),
          side: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        number,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SelectableText(
                content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
