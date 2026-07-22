// SPDX-FileCopyrightText: 2019-Present Christian Kußowski
// SPDX-FileCopyrightText: 2019-Present Contributors to FluffyChat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

class BootstrapViewModelState {
  bool isLoading = false;
  Object? unlockWithError;
  ({bool connected, bool initialized})? cryptoIdentityState;
  bool reset = false;
  bool obscureText = true;

  bool newPassphraseEqualsRepeatPassphrase = false;
  bool newPassphraseLongEnough = false;
  bool newPassphraseUpperAndLowerCase = false;
  bool newPassphraseSpecialCharacters = false;
  bool newPassphraseNumbers = false;
  bool passphraseEntered = false;
}
