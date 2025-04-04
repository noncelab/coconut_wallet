import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';

class SettingsViewModel extends ChangeNotifier {
  late final AuthProvider _authProvider;
  late final PreferenceProvider _preferenceProvider;
  late final WalletProvider _walletProvider;

  bool get isSetPin => _authProvider.isSetPin;
  bool get isSetBiometrics => _authProvider.isSetBiometrics;
  bool get isBalanceHidden => _preferenceProvider.isBalanceHidden;
  bool get canCheckBiometrics => _authProvider.canCheckBiometrics;

  SettingsViewModel(this._authProvider, this._preferenceProvider, this._walletProvider);

  Future<bool> authenticateWithBiometrics({bool isSave = false}) async {
    return await _authProvider.authenticateWithBiometrics(isSave: isSave);
  }

  Future<void> saveIsSetBiometrics(bool value) async {
    await _authProvider.saveIsSetBiometrics(value);
  }

  void changeIsBalanceHidden(bool value) {
    _preferenceProvider.changeIsBalanceHidden(value);
  }

  void deletePin() {
    _walletProvider.decryptWalletSecureData();
    _authProvider.deletePin();
  }
}
