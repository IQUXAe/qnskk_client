import 'package:fluffychat/utils/update_checker.dart';
import 'package:flutter/material.dart';

/// Clean, non-intrusive soft update banner card shown at the top of the rooms list.
class SoftUpdateBannerWidget extends StatefulWidget {
  final UpdateCheckerResult updateResult;
  final VoidCallback onDismiss;

  const SoftUpdateBannerWidget({
    required this.updateResult,
    required this.onDismiss,
    super.key,
  });

  @override
  State<SoftUpdateBannerWidget> createState() => _SoftUpdateBannerWidgetState();
}

class _SoftUpdateBannerWidgetState extends State<SoftUpdateBannerWidget> {
  bool _isDownloading = false;

  Future<void> _handleUpdateClick(BuildContext context) async {
    final downloadUrl = widget.updateResult.downloadUrl;
    if (downloadUrl == null || downloadUrl.isEmpty) return;

    final isMobileData = await UpdateChecker.instance.isMobileDataConnection();
    if (isMobileData && context.mounted) {
      final confirmMobile = await showDialog<bool>(
        context: context,
        builder: (context) {
          final isRu = Localizations.localeOf(context).languageCode == 'ru';
          return AlertDialog(
            title: Text(
              isRu ? 'Скачивание через мобильную сеть' : 'Download over mobile data',
            ),
            content: Text(
              isRu
                  ? 'Вы подключены к мобильному интернету. Загрузить обновление?'
                  : 'You are connected to mobile network. Download update?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(isRu ? 'Отмена' : 'Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(isRu ? 'Скачать' : 'Download'),
              ),
            ],
          );
        },
      );

      if (confirmMobile != true) return;
    }

    setState(() => _isDownloading = true);
    await UpdateChecker.instance.startUpdate(downloadUrl);
    if (mounted) {
      setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manifest = widget.updateResult.manifest;
    if (manifest == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final changelog = manifest.getChangelog(locale);
    final isRu = locale == 'ru';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isRu
                      ? 'Доступно обновление QNSKK ${manifest.latestVersion}'
                      : 'QNSKK ${manifest.latestVersion} update available',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onDismiss,
                tooltip: isRu ? 'Закрыть' : 'Dismiss',
              ),
            ],
          ),
          if (changelog.isNotEmpty) ...[
            const SizedBox(height: 8.0),
            Text(
              changelog,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 12.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: widget.onDismiss,
                child: Text(isRu ? 'Позже' : 'Later'),
              ),
              const SizedBox(width: 8.0),
              FilledButton(
                onPressed: _isDownloading
                    ? null
                    : () => _handleUpdateClick(context),
                child: _isDownloading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isRu ? 'Обновить' : 'Update'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Unclosable mandatory update dialog shown when current version code < min_required_code.
class MandatoryUpdateDialog extends StatefulWidget {
  final UpdateCheckerResult updateResult;

  const MandatoryUpdateDialog({
    required this.updateResult,
    super.key,
  });

  static Future<void> show(BuildContext context, UpdateCheckerResult result) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => MandatoryUpdateDialog(updateResult: result),
    );
  }

  @override
  State<MandatoryUpdateDialog> createState() => _MandatoryUpdateDialogState();
}

class _MandatoryUpdateDialogState extends State<MandatoryUpdateDialog> {
  bool _isDownloading = false;

  Future<void> _handleUpdateClick(BuildContext context) async {
    final downloadUrl = widget.updateResult.downloadUrl;
    if (downloadUrl == null || downloadUrl.isEmpty) return;

    final isMobileData = await UpdateChecker.instance.isMobileDataConnection();
    if (isMobileData && context.mounted) {
      final confirmMobile = await showDialog<bool>(
        context: context,
        builder: (context) {
          final isRu = Localizations.localeOf(context).languageCode == 'ru';
          return AlertDialog(
            title: Text(
              isRu ? 'Скачивание через мобильную сеть' : 'Download over mobile data',
            ),
            content: Text(
              isRu
                  ? 'Вы подключены к мобильному интернету. Загрузить обновление?'
                  : 'You are connected to mobile network. Download update?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(isRu ? 'Отмена' : 'Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(isRu ? 'Скачать' : 'Download'),
              ),
            ],
          );
        },
      );

      if (confirmMobile != true) return;
    }

    setState(() => _isDownloading = true);
    await UpdateChecker.instance.startUpdate(downloadUrl);
    if (mounted) {
      setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final manifest = widget.updateResult.manifest;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final isRu = locale == 'ru';
    final changelog = manifest?.getChangelog(locale) ?? '';

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(
          isRu ? 'Требуется обновление' : 'Update Required',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isRu
                  ? 'Установленная версия приложения устарела. Для продолжения работы необходимо установить версию ${manifest?.latestVersion ?? ''}.'
                  : 'Installed application version is out of date. Please install version ${manifest?.latestVersion ?? ''} to continue.',
              style: theme.textTheme.bodyMedium,
            ),
            if (changelog.isNotEmpty) ...[
              const SizedBox(height: 12.0),
              Text(
                isRu ? 'Изменения:' : 'Changelog:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                changelog,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isDownloading
                  ? null
                  : () => _handleUpdateClick(context),
              child: _isDownloading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      isRu ? 'Обновить QNSKK' : 'Update QNSKK',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
