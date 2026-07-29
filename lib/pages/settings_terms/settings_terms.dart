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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Условия использования'),
        automaticallyImplyLeading: !isColumnMode,
        centerTitle: isColumnMode,
      ),
      body: MaxWidthBody(
        withScrolling: false,
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
                            'Пользовательское соглашение',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Правила использования сервиса QNSKK Project (api.qnskk.top).',
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

            _TermsSection(
              number: '1',
              title: 'Принятие условий',
              content:
                  'Регистрация учетной записи, авторизация или любое использование клиентского приложения QNSKK означает ваше полное и безоговорочное согласие с настоящими Условиями использования.',
            ),

            _TermsSection(
              number: '2',
              title: 'Отказ от гарантий (Disclaimers)',
              content:
                  'Сервис QNSKK предоставляется на условиях «КАК ЕСТЬ» («AS IS») и «ПО МЕРЕ ДОСТУПНОСТИ» («AS AVAILABLE»). Администрация сервиса не дает явных или подразумеваемых гарантий непрерывной работы в условиях внешних сетевых блокировок, сбоев магистральных провайдеров или нештатных ситуаций.',
            ),

            _TermsSection(
              number: '3',
              title: 'Ограничение ответственности',
              content:
                  '1. Пользователь несет персональную ответственность за сохранность своих учетных данных и пароля.\n'
                  '2. Ввиду применения сквозного шифрования (E2EE), администрация сервиса не обладает технической возможностью восстановить зашифрованные сообщения в случае утери пользователем своего пароля.\n'
                  '3. Администрация не несет ответственности за любые косвенные убытки, возникшие в результате использования или невозможности использования сервиса.',
            ),

            _TermsSection(
              number: '4',
              title: 'Правила допустимого использования (AUP)',
              content:
                  'Категорически запрещается использовать сервис для:\n'
                  '• Проведения спам-атак, автоматизированной рассылки или дестабилизации работы серверов (DDoS).\n'
                  '• Распространения вредоносного программного обеспечения или реализации сетевых атак.\n'
                  '• Совершения противоправных действий, нарушающих действующее законодательство ЕC/ФРГ.\n\n'
                  'При выявлении злоупотреблений сетевой инфраструктурой аккаунт нарушителя может быть заблокирован без предварительного уведомления.',
            ),

            _TermsSection(
              number: '5',
              title: 'Применимое право',
              content:
                  'Настоящие условия и любые возникающие споры регулируются материальным правом Федеративной Республики Германия (Германия, ЕС), за исключением норм международного частного права.',
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

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
