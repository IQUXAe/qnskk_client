// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/themes.dart';
import 'package:fluffychat/widgets/layouts/max_width_body.dart';
import 'package:flutter/material.dart';

class SettingsPrivacy extends StatelessWidget {
  const SettingsPrivacy({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isColumnMode = FluffyThemes.isColumnMode(context);
    final locale = Localizations.localeOf(context).languageCode;
    final isRu = locale == 'ru';

    final sections = isRu ? _sectionsRu : _sectionsEn;

    return Scaffold(
      appBar: AppBar(
        title: Text(isRu ? 'Политика конфиденциальности' : 'Privacy Policy'),
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
                      Icons.shield_moon_outlined,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'GDPR / DSGVO',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isRu
                                ? 'Серверы QNSKK расположены в Германии (ЕС) и строго соответствуют регламенту EU GDPR.'
                                : 'QNSKK servers are located in Germany (EU) and fully comply with EU GDPR.',
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
              return _PrivacySection(
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
    'Оператор и юрисдикция',
    'Оператором сервиса является QNSKK Project (api.qnskk.top). Серверная инфраструктура физически размещена в сертифицированных дата-центрах на территории Федеративной Республики Германия. Обработка персональных данных осуществляется в соответствии с Общим регламентом по защите данных ЕС (GDPR / DSGVO) и законодательством ФРГ о защите данных.',
  ],
  [
    'Сквозное шифрование (E2EE)',
    'Все личные и групповые сообщения, файлы и вложения шифруются непосредственно на устройстве отправителя с использованием протоколов Olm и Megolm до отправки в сеть. Оператор сервера, провайдеры связи и любые третьи лица не имеют технических средств или ключей для расшифровки содержимого ваших сообщений.',
  ],
  [
    'Категории обрабатываемых данных',
    '• Учетная запись: системный идентификатор (MXID), псевдоним пользователя и защищенный хеш пароля.\n• Метаданные туннеля: сетевые запросы передаются через криптографический Edge Proxy в зашифрованном виде без сохранения журналов IP-адресов или истории физических подключений.\n• Отсутствие сторонней аналитики: QNSKK не использует Google Analytics, Яндекс.Метрику, рекламу или рекламные идентификаторы.',
  ],
  [
    'Правовые основания обработки (Art. 6 GDPR)',
    'Обработка данных осуществляется на основании Art. 6(1)(b) GDPR (необходимость для исполнения соглашения о предоставлении сервиса) и Art. 6(1)(f) GDPR (законный интерес в обеспечении защищенности и стабильности сетевой инфраструктуры).',
  ],
  [
    'Права пользователей (Art. 15–21 GDPR)',
    'Вы имеете полное право на:\n• Доступ к своим данным и экспорт сессионных ключей (Art. 15 GDPR).\n• Безотзывное удаление учетной записи и всех связанных с ней данных («Право на забвение», Art. 17 GDPR).\n• Сброс криптографической идентичности и обновление ключей в любой момент.',
  ],
  [
    'Передача данных третьим лицам',
    'Оператор QNSKK категорически не продает, не передает и не предоставляет доступ к данным пользователей коммерческим компаниям, рекламным агентствам или брокерам данных.',
  ],
];

const _sectionsEn = [
  [
    'Operator & Jurisdiction',
    'The service is operated by QNSKK Project (api.qnskk.top). The server infrastructure is physically hosted in certified data centers in the Federal Republic of Germany. Personal data is processed in accordance with the EU General Data Protection Regulation (GDPR / DSGVO) and German data protection law.',
  ],
  [
    'End-to-End Encryption (E2EE)',
    'All private and group messages, files and attachments are encrypted directly on the sender\'s device using the Olm and Megolm protocols before being transmitted over the network. The server operator, network providers and any third parties have no technical means or keys to decrypt the content of your messages.',
  ],
  [
    'Categories of Processed Data',
    '• Account: system identifier (MXID), user display name and a secured password hash.\n• Tunnel metadata: network requests are forwarded through a cryptographic Edge Proxy in encrypted form — no IP address logs or physical connection history are stored.\n• No third-party analytics: QNSKK does not use Google Analytics, advertising SDKs or advertising identifiers.',
  ],
  [
    'Legal Basis for Processing (Art. 6 GDPR)',
    'Data processing is carried out under Art. 6(1)(b) GDPR (necessity for the performance of the service agreement) and Art. 6(1)(f) GDPR (legitimate interest in ensuring the security and stability of the network infrastructure).',
  ],
  [
    'User Rights (Art. 15–21 GDPR)',
    'You have the full right to:\n• Access your data and export session keys (Art. 15 GDPR).\n• Irrevocable deletion of your account and all associated server-side data ("Right to Erasure", Art. 17 GDPR).\n• Reset your cryptographic identity and rotate keys at any time.',
  ],
  [
    'Disclosure to Third Parties',
    'The QNSKK operator does not sell, transfer or grant access to user data to commercial companies, advertising agencies or data brokers.',
  ],
];

class _PrivacySection extends StatelessWidget {
  final String number;
  final String title;
  final String content;

  const _PrivacySection({
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
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        number,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onPrimaryContainer,
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
