import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateType {
  none,
  soft,
  hard,
}

class UpdateManifest {
  final String latestVersion;
  final int versionCode;
  final int minRequiredCode;
  final Map<String, String> changelog;
  final Map<String, String> assets;

  UpdateManifest({
    required this.latestVersion,
    required this.versionCode,
    required this.minRequiredCode,
    required this.changelog,
    required this.assets,
  });

  factory UpdateManifest.fromJson(Map<String, dynamic> json) {
    final changelogMap = <String, String>{};
    if (json['changelog'] is Map) {
      (json['changelog'] as Map).forEach((k, v) {
        changelogMap[k.toString()] = v.toString();
      });
    }

    final assetsMap = <String, String>{};
    if (json['assets'] is Map) {
      (json['assets'] as Map).forEach((k, v) {
        assetsMap[k.toString()] = v.toString();
      });
    }

    return UpdateManifest(
      latestVersion: json['latest_version'] as String? ?? '1.0.0',
      versionCode: (json['version_code'] as num?)?.toInt() ?? 0,
      minRequiredCode: (json['min_required_code'] as num?)?.toInt() ?? 0,
      changelog: changelogMap,
      assets: assetsMap,
    );
  }

  String getChangelog(String localeCode) {
    if (changelog.containsKey(localeCode)) {
      return changelog[localeCode]!;
    }
    final lang = localeCode.split('_').first.toLowerCase();
    if (changelog.containsKey(lang)) {
      return changelog[lang]!;
    }
    return changelog['en'] ?? changelog['ru'] ?? '';
  }

  String? getAssetUrlForAbi(String abi) {
    if (assets.containsKey(abi)) {
      return assets[abi];
    }
    return assets['universal'] ?? assets.values.firstOrNull;
  }
}

class UpdateCheckerResult {
  final UpdateType type;
  final UpdateManifest? manifest;
  final String? targetAbi;
  final String? downloadUrl;
  final int currentVersionCode;

  UpdateCheckerResult({
    required this.type,
    this.manifest,
    this.targetAbi,
    this.downloadUrl,
    required this.currentVersionCode,
  });
}

class UpdateChecker {
  UpdateChecker._();
  static final UpdateChecker instance = UpdateChecker._();

  static const String _defaultManifestUrl = String.fromEnvironment(
    'QNSKK_UPDATE_MANIFEST_URL',
    defaultValue:
        'https://github.com/IQUXAe/qnskk_client/releases/latest/download/version.json',
  );

  UpdateCheckerResult? _cachedResult;
  UpdateCheckerResult? get cachedResult => _cachedResult;

  /// Detects the target CPU ABI for Android (arm64-v8a, armeabi-v7a, or universal).
  Future<String> getDeviceAbi() async {
    if (kIsWeb) return 'universal';
    if (Platform.isAndroid) {
      try {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        final abis = androidInfo.supportedAbis;
        if (abis.contains('arm64-v8a')) {
          return 'arm64-v8a';
        } else if (abis.contains('armeabi-v7a')) {
          return 'armeabi-v7a';
        }
      } catch (e) {
        debugPrint('QNSKK Update: Error detecting Android ABI: $e');
      }
    }
    return 'universal';
  }

  /// Verifies if GitHub / external internet is reachable before showing update UI.
  Future<bool> isExternalInternetReachable() async {
    if (kIsWeb) return true;
    try {
      final socket = await Socket.connect(
        'github.com',
        443,
        timeout: const Duration(seconds: 3),
      );
      socket.destroy();
      return true;
    } catch (_) {
      try {
        final socket = await Socket.connect(
          'api.github.com',
          443,
          timeout: const Duration(seconds: 3),
        );
        socket.destroy();
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  /// Detects whether active connection is via cellular (mobile data).
  Future<bool> isMobileDataConnection() async {
    if (kIsWeb) return false;
    try {
      final interfaces = await NetworkInterface.list();
      for (final interface in interfaces) {
        final name = interface.name.toLowerCase();
        if (name.contains('rmnet') ||
            name.contains('ccmni') ||
            name.contains('pdp') ||
            name.contains('cellular') ||
            name.contains('mobile') ||
            name.contains('lte')) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Performs full check for updates.
  Future<UpdateCheckerResult> checkForUpdates({String? manifestUrl}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;

      final isReachable = await isExternalInternetReachable();
      if (!isReachable) {
        debugPrint(
          'QNSKK Update: External internet / GitHub is not reachable. Skipping update prompt.',
        );
        _cachedResult = UpdateCheckerResult(
          type: UpdateType.none,
          currentVersionCode: currentCode,
        );
        return _cachedResult!;
      }

      final url = Uri.parse(manifestUrl ?? _defaultManifestUrl);
      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        _cachedResult = UpdateCheckerResult(
          type: UpdateType.none,
          currentVersionCode: currentCode,
        );
        return _cachedResult!;
      }

      final jsonMap = jsonDecode(response.body) as Map<String, dynamic>;
      final manifest = UpdateManifest.fromJson(jsonMap);

      final abi = await getDeviceAbi();
      final downloadUrl = manifest.getAssetUrlForAbi(abi);

      var type = UpdateType.none;
      if (currentCode > 0) {
        if (currentCode < manifest.minRequiredCode) {
          type = UpdateType.hard;
        } else if (currentCode < manifest.versionCode) {
          type = UpdateType.soft;
        }
      }

      _cachedResult = UpdateCheckerResult(
        type: type,
        manifest: manifest,
        targetAbi: abi,
        downloadUrl: downloadUrl,
        currentVersionCode: currentCode,
      );
      return _cachedResult!;
    } catch (e, s) {
      debugPrint('QNSKK Update: Error checking for updates: $e\n$s');
      _cachedResult = UpdateCheckerResult(
        type: UpdateType.none,
        currentVersionCode: 0,
      );
      return _cachedResult!;
    }
  }

  /// Downloads the APK file to temporary cache and triggers installation.
  /// Reports download progress (0.0 to 1.0) via [onProgress].
  Future<bool> downloadAndInstallUpdate(
    String downloadUrl, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final uri = Uri.parse(downloadUrl);
      final client = http.Client();
      final request = http.Request('GET', uri);
      final response = await client.send(request);

      if (response.statusCode != 200) {
        debugPrint(
          'QNSKK Update: Download failed with status ${response.statusCode}',
        );
        return false;
      }

      final contentLength = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/qnskk_update.apk');

      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      final sink = apkFile.openWrite();
      var downloaded = 0;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloaded += chunk.length;
        if (contentLength > 0 && onProgress != null) {
          onProgress(downloaded / contentLength);
        }
      }
      await sink.close();
      client.close();

      if (!await apkFile.exists() || await apkFile.length() == 0) {
        debugPrint('QNSKK Update: Downloaded file is empty or missing');
        return false;
      }

      onProgress?.call(1.0);

      // Launch native Android installer via MethodChannel if on Android
      if (!kIsWeb && Platform.isAndroid) {
        try {
          const channel = MethodChannel('org.iquxae.qnskk/installer');
          final success = await channel.invokeMethod<bool>('installApk', {
            'filePath': apkFile.path,
          });
          if (success == true) return true;
        } catch (e) {
          debugPrint(
            'QNSKK Update: Native installer error: $e. Falling back to url_launcher',
          );
        }
      }

      // Fallback for non-Android or if native install fails
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return false;
    } catch (e, s) {
      debugPrint('QNSKK Update: Download/Install error: $e\n$s');
      return false;
    }
  }

  /// Triggers the download/installation of the release APK.
  Future<bool> startUpdate(
    String downloadUrl, {
    void Function(double progress)? onProgress,
  }) async {
    return downloadAndInstallUpdate(downloadUrl, onProgress: onProgress);
  }
}
