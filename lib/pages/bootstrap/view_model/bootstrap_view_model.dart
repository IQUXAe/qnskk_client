// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';
import 'dart:math';

import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/error_reporter.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/qnskk_recovery_passphrase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';

import 'bootstrap_state.dart';

class BootstrapViewModel extends ValueNotifier<BootstrapViewModelState> {
  final Client client;
  final bool reset;

  final TextEditingController enterPassphraseController =
      TextEditingController();
  final TextEditingController newPassphraseController = TextEditingController();
  final TextEditingController repeatPassphraseController =
      TextEditingController();
  bool _autoRecoveryAttempted = false;
  bool _autoResetAttempted = false;

  bool _disposed = false;

  BootstrapViewModel({required this.client, required this.reset})
    : super(BootstrapViewModelState()..reset = reset) {
    _init();
  }

  @override
  void dispose() {
    _disposed = true;
    enterPassphraseController.dispose();
    newPassphraseController.dispose();
    repeatPassphraseController.dispose();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  void _checkCanCreatePassphrase([_]) {
    final passphrase = newPassphraseController.text;
    value.newPassphraseEqualsRepeatPassphrase =
        passphrase.isNotEmpty && passphrase == repeatPassphraseController.text;
    value.newPassphraseLongEnough = passphrase.length >= 12;
    value.newPassphraseUpperAndLowerCase =
        passphrase.contains(RegExp(r'[A-Z]')) &&
        passphrase.contains(RegExp(r'[a-z]'));
    value.newPassphraseSpecialCharacters = passphrase.contains(
      RegExp(r'[!@#$%^&*(),.?":{}|<>]'),
    );
    value.newPassphraseNumbers = passphrase.contains(RegExp(r'\d'));
    notifyListeners();
  }

  Future<void> _init() async {
    final state = value.cryptoIdentityState = await client
        .getCryptoIdentityState();
    newPassphraseController.addListener(_checkCanCreatePassphrase);
    repeatPassphraseController.addListener(_checkCanCreatePassphrase);
    enterPassphraseController.addListener(_passphraseEntered);
    if (state.initialized) {
      if (state.connected) return notifyListeners();

      if (supportsSecureStorage) {
        try {
          final keyFromSecureStorage = await FlutterSecureStorage().read(
            key: _secureStorageKey,
          );
          if (keyFromSecureStorage != null) {
            enterPassphraseController.text = keyFromSecureStorage;
          }
        } catch (e, s) {
          Logs().e('Unable to read key from secure storage', e, s);
        }
      }
    }
    notifyListeners();
  }

  void _passphraseEntered() {
    final passphraseEntered = enterPassphraseController.text.isNotEmpty;
    if (value.passphraseEntered != passphraseEntered) {
      value.passphraseEntered = passphraseEntered;
      notifyListeners();
    }
  }

  Future<void> setPassphrase(String passphrase, BuildContext context) async {
    if (passphrase.isEmpty) return;
    value.isLoading = true;
    notifyListeners();
    try {
      final qnskkPassphrase = await _deriveQnskkPassphrase(passphrase);
      await client.initCryptoIdentity(
        passphrase: qnskkPassphrase,
        wipeCrossSigning: !reset,
        wipeKeyBackup: !reset,
        wipeSecureStorage: !reset,
        setupMasterKey: !reset,
        setupSelfSigningKey: !reset,
        setupUserSigningKey: !reset,
      );
      value.cryptoIdentityState = await client.getCryptoIdentityState();
      value.isLoading = false;
      if (supportsSecureStorage &&
          value.cryptoIdentityState?.connected == true) {
        await FlutterSecureStorage().write(
          key: _secureStorageKey,
          value: passphrase,
        );
      }
      if (context.mounted) {
        context.go('/rooms');
        return;
      }
    } catch (e, s) {
      if (!context.mounted) return;
      ErrorReporter(
        context,
        'Unable to init crypto identity',
      ).onErrorCallback(e, s);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toLocalizedString(context))));
      value.isLoading = false;
    }
    notifyListeners();
  }

  Future<void> tryAutoRecovery(BuildContext context) async {
    if (_autoRecoveryAttempted || value.isLoading || value.reset) return;

    final state = value.cryptoIdentityState;
    final userId = client.userID?.toString();
    if (state == null || state.connected || userId == null) return;

    final passphrase = QnskkRecoveryPassphrase.take(userId);
    if (passphrase == null) return;

    _autoRecoveryAttempted = true;
    value.isLoading = true;
    notifyListeners();

    try {
      if (state.initialized) {
        try {
          await client.restoreCryptoIdentity(passphrase);
        } on InvalidPassphraseException catch (_) {
          await client.initCryptoIdentity(
            passphrase: passphrase,
            wipeCrossSigning: true,
            wipeKeyBackup: true,
            wipeSecureStorage: true,
            setupMasterKey: true,
            setupSelfSigningKey: true,
            setupUserSigningKey: true,
          );
        }
      } else {
        await client.initCryptoIdentity(
          passphrase: passphrase,
          wipeCrossSigning: true,
          wipeKeyBackup: true,
          wipeSecureStorage: true,
          setupMasterKey: true,
          setupSelfSigningKey: true,
          setupUserSigningKey: true,
        );
      }
      value.cryptoIdentityState = await client.getCryptoIdentityState();
      value.isLoading = false;
      notifyListeners();
    } catch (e, s) {
      value.isLoading = false;
      value.unlockWithError = e;
      notifyListeners();
      if (context.mounted) {
        ErrorReporter(
          context,
          'Unable to auto restore crypto identity',
        ).onErrorCallback(e, s);
      } else {
        Logs().w('Unable to auto restore crypto identity', e, s);
      }
    }
  }

  Future<void> performAutomaticReset(BuildContext context) async {
    if (_autoResetAttempted || value.isLoading) return;

    final userId = client.userID?.toString();
    if (userId == null) return;

    _autoResetAttempted = true;
    value.isLoading = true;
    notifyListeners();

    try {
      var passphrase = QnskkRecoveryPassphrase.take(userId);

      if (passphrase == null && supportsSecureStorage) {
        try {
          passphrase =
              await FlutterSecureStorage().read(key: _secureStorageKey);
        } catch (e, s) {
          Logs().w(
            'Unable to read passphrase from secure storage for reset',
            e,
            s,
          );
        }
      }

      if (passphrase == null) {
        final randomBytes = List<int>.generate(
          32,
          (_) => Random().nextInt(256),
        );
        passphrase = base64Url.encode(randomBytes).replaceAll('=', '');
      }

      await client.initCryptoIdentity(
        passphrase: passphrase,
        wipeCrossSigning: true,
        wipeKeyBackup: true,
        wipeSecureStorage: true,
        setupMasterKey: true,
        setupSelfSigningKey: true,
        setupUserSigningKey: true,
      );

      if (supportsSecureStorage) {
        await FlutterSecureStorage().write(
          key: _secureStorageKey,
          value: passphrase,
        );
      }

      value.cryptoIdentityState = await client.getCryptoIdentityState();
      value.isLoading = false;
      notifyListeners();

      if (context.mounted) {
        goToRoomsPageAfterSuccess(context);
      }
    } catch (e, s) {
      value.isLoading = false;
      notifyListeners();
      if (context.mounted) {
        ErrorReporter(
          context,
          'Unable to reset crypto identity',
        ).onErrorCallback(e, s);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toLocalizedString(context))),
        );
      }
    }
  }

  bool get supportsSecureStorage =>
      PlatformInfos.isMobile || PlatformInfos.isDesktop;

  Future<void> unlock(BuildContext context) async {
    final password = enterPassphraseController.text;
    if (password.isEmpty) return;

    value.unlockWithError = null;
    value.isLoading = true;
    notifyListeners();
    try {
      await _restoreCryptoIdentity(password);
      value.isLoading = false;
      value.cryptoIdentityState = await client.getCryptoIdentityState();
      if (supportsSecureStorage &&
          value.cryptoIdentityState?.connected == true) {
        await FlutterSecureStorage().write(
          key: _secureStorageKey,
          value: password,
        );
      }
      notifyListeners();
      return;
    } catch (e, s) {
      if (e is! InvalidPassphraseException) {
        const errorMessage = 'Unexpected error on unlock passphrase';
        if (context.mounted) {
          ErrorReporter(context, errorMessage).onErrorCallback(e, s);
        } else {
          Logs().wtf(errorMessage, e, s);
        }
      }
      value.isLoading = false;
      value.unlockWithError = e;
      notifyListeners();
      if (supportsSecureStorage) {
        await FlutterSecureStorage().delete(key: _secureStorageKey);
      }
      return;
    }
  }

  Future<void> _restoreCryptoIdentity(String password) async {
    final qnskkPassphrase = await _deriveQnskkPassphrase(password);
    await client.restoreCryptoIdentity(qnskkPassphrase);
  }

  Future<String> _deriveQnskkPassphrase(String password) async {
    final userId = client.userID?.toString();
    if (userId == null) {
      throw StateError(
        'Cannot derive QNSKK recovery passphrase without user ID',
      );
    }
    return QnskkRecoveryPassphrase.derive(userId: userId, password: password);
  }

  void goToRoomsPageAfterSuccess(BuildContext context) {
    for (final room in client.rooms) {
      final lastEvent = room.lastEvent;
      if (lastEvent == null ||
          lastEvent.messageType != MessageTypes.BadEncrypted ||
          lastEvent.content['can_request_session'] != true) {
        continue;
      }
      final sessionId = lastEvent.content.tryGet<String>('session_id');
      final senderKey = lastEvent.content.tryGet<String>('sender_key');
      if (sessionId != null && senderKey != null) {
        client.encryption?.keyManager.maybeAutoRequest(
          room.id,
          sessionId,
          senderKey,
        );
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: Duration(seconds: 5),
        showCloseIcon: true,
        backgroundColor: Colors.green.shade700,
        content: Text(
          L10n.of(context).youAreReadyToStart,
          style: TextStyle(color: Colors.white),
        ),
      ),
    );
    context.go('/rooms');
  }

  void toggleObscureText() {
    value.obscureText = !value.obscureText;
    notifyListeners();
  }

  void startResetAccount() {
    value.reset = true;
    notifyListeners();
  }

  String get _secureStorageKey => 'ssss_recovery_key_${client.userID}';
}
