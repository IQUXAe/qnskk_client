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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Политика конфиденциальности'),
        automaticallyImplyLeading: !isColumnMode,
        centerTitle: isColumnMode,
      ),
      body: MaxWidthBody(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          children: [
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
                            'Защита данных (GDPR / DSGVO)',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Серверы QNSKK расположены в Германии (Европейский союз) и строго соответствуют регламенту EU GDPR (DSGVO).',
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

            _PrivacySection(
              number: '1',
              title: 'Оператор и юрисдикция',
              content:
                  'Оператором сервиса является QNSKK Project (api.qnskk.top). Серверная инфраструктура физически размещена в сертифицированных дата-центрах на территории Федеративной Республики Германия. Обработка персональных данных осуществляется в соответствии с Общим регламентом по защите данных ЕС (GDPR / DSGVO) и законодательством ФРГ о защите данных.',
            ),

            _PrivacySection(
              number: '2',
              title: 'Сквозное шифрование и сквозная приватность (E2EE)',
              content:
                  'Все личные и групповые сообщения, файлы и вложения шифруются непосредственно на устройстве отправителя с использованием протоколов Olm и Megolm до отправки в сеть. Оператор сервера, провайдеры связи и любые третьи лица не имеют технических средств или ключей для расшифровки содержимого ваших сообщений.',
            ),

            _PrivacySection(
              number: '3',
              title: 'Категории обрабатываемых данных',
              content:
                  '• Учетная запись: системный идентификатор (MXID), псевдоним пользователя и защищенный хеш пароля.\n'
                  '• Метаданные туннеля: сетевые запросы передаются через криптографический Edge Proxy в зашифрованном виде без сохранения журналов IP-адресов или истории физических подключений.\n'
                  '• Отсутствие сторонней аналитики: QNSKK не использует метрики Google Analytics, Яндекс.Метрику, рекламу или рекламные идентификаторы.',
            ),

            _PrivacySection(
              number: '4',
              title: 'Правовые основания обработки (Art. 6 GDPR)',
              content:
                  'Обработка данных осуществляется на основании Art. 6(1)(b) GDPR (необходимость для исполнения соглашения о предоставлении сервиса) и Art. 6(1)(f) GDPR (законный интерес в обеспечении защищенности и стабильности сетевой инфраструктуры).',
            ),

            _PrivacySection(
              number: '5',
              title: 'Права пользователей (Art. 15–21 GDPR)',
              content:
                  'Вы имеете полное право на:\n'
                  '• Доступ к своим данным и экспорт сессионных ключей (Art. 15 GDPR).\n'
                  '• Безотзывное удаление учетной записи и всех связанных с ней сервером данных («Право на забвение», Art. 17 GDPR).\n'
                  '• Сброс криптографической идентичности и обновление ключей в любой момент.',
            ),

            _PrivacySection(
              number: '6',
              title: 'Передача данных третьим лицам',
              content:
                  'Оператор QNSKK категорически не продает, не передает и не предоставляет доступ к данным пользователей коммерческим компаниям, рекламным агентствам или брокерам данных.',
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.only(bottom: 16.0),
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
                  height: 1.45,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
