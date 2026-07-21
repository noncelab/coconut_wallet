import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/third_party_util.dart';
import 'package:flutter/foundation.dart';

enum TrezorUsbConnectStep { idle, connecting, pinEntry, connected, error }

class TrezorUsbConnectViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;

  TrezorUsbConnectViewModel(this._walletProvider);

  TrezorUsbConnectStep _step = TrezorUsbConnectStep.idle;
  TrezorDevice? _device;
  String _xpub = '';
  String _fingerprint = '';
  String? _errorMessage;
  bool _disposed = false;
  Completer<String?>? _pinCompleter;
  String _pin = '';

  TrezorUsbConnectStep get step => _step;
  String get xpub => _xpub;
  String get fingerprint => _fingerprint;
  String get deviceLabel => _device?.label ?? '';
  String get deviceModel => _device?.model ?? '';
  String? get errorMessage => _errorMessage;
  bool get isConnected => _step == TrezorUsbConnectStep.connected;
  String get pin => _pin;

  Future<void> connect() async {
    if (_step == TrezorUsbConnectStep.connecting) return;
    _setState(TrezorUsbConnectStep.connecting);
    _errorMessage = null;
    try {
      _device = await TrezorDevice.connect(transport: TrezorTransport.usb);
      TrezorDevice.lastConnected = _device;
      final network = NetworkType.currentNetworkType;
      final keypath = network.isTestnet ? "m/84'/1'/0'" : "m/84'/0'/0'";
      _xpub = await _device!.getXPub(keypath: keypath, network: network.toString());
      _device!.cachedXpub = _xpub;
      _fingerprint = await _device!.getFingerprint();
      _device!.cachedFingerprint = _fingerprint;
      _setState(TrezorUsbConnectStep.connected);
    } catch (error) {
      _errorMessage = error.toString();
      await _disconnectDevice();
      _setState(TrezorUsbConnectStep.error);
    }
  }

  String? findMatchingTrezorWalletName(String xpub) {
    for (final wallet in _walletProvider.walletItemList) {
      if (wallet.walletImportSource != WalletImportSource.trezor || wallet is! SinglesigWalletItem) continue;
      if (wallet.extendedPublicKey == xpub) return wallet.name;
    }
    return null;
  }

  Future<ResultOfSyncFromVault> addToWalletList() async {
    final service = WalletAddService();
    final existingNames = _walletProvider.walletItemList.map((wallet) => wallet.name).toList();
    final baseName = deviceLabel.isEmpty ? '' : deviceLabel;
    final name =
        baseName.isEmpty
            ? getNextThirdPartyWalletName(WalletImportSource.trezor, existingNames)
            : _resolveNameWithBase(baseName, existingNames);
    final wallet = service.createExtendedPublicKeyWallet(
      _xpub,
      name,
      _fingerprint,
      walletImportSource: WalletImportSource.trezor,
    );
    return _walletProvider.syncFromThirdParty(wallet);
  }

  Future<String?> requestPin() {
    _pin = '';
    _pinCompleter = Completer<String?>();
    _setState(TrezorUsbConnectStep.pinEntry);
    return _pinCompleter!.future;
  }

  void onPinKeyTap(String value) {
    if (value == '<') {
      if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
        notifyListeners();
      }
      return;
    }
    if (value.isEmpty) return;
    if (_pin.length >= 50) return;
    _pin += value;
    notifyListeners();
  }

  void submitPin() {
    final pin = _pin;
    _pin = '';
    _pinCompleter?.complete(pin);
    _pinCompleter = null;
    _setState(TrezorUsbConnectStep.connecting);
  }

  void cancelPin() {
    _pin = '';
    _pinCompleter?.complete('');
    _pinCompleter = null;
    _setState(TrezorUsbConnectStep.connecting);
  }

  Future<void> disconnect() async {
    await _disconnectDevice();
    TrezorDevice.lastConnected = null;
    _xpub = '';
    _fingerprint = '';
    _errorMessage = null;
    _setState(TrezorUsbConnectStep.idle);
  }

  void reset() {
    _errorMessage = null;
    _setState(TrezorUsbConnectStep.idle);
  }

  String _resolveNameWithBase(String baseName, List<String> existingNames) {
    final regex = RegExp('^${RegExp.escape(baseName)}(?: (\\d+))?\$');
    final taken = <int>{};
    for (final name in existingNames) {
      final match = regex.firstMatch(name);
      if (match == null) continue;
      taken.add(match.group(1) == null ? 1 : int.tryParse(match.group(1)!) ?? 1);
    }
    if (!taken.contains(1)) return baseName;
    var suffix = 2;
    while (taken.contains(suffix)) {
      suffix++;
    }
    return '$baseName $suffix';
  }

  Future<void> _disconnectDevice() async {
    final device = _device;
    _device = null;
    if (device != null) await device.disconnect();
  }

  void _setState(TrezorUsbConnectStep step) {
    if (_disposed) return;
    _step = step;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pinCompleter?.complete('');
    _pinCompleter = null;
    if (_step != TrezorUsbConnectStep.connected) {
      TrezorDevice.cancel().catchError((_) {});
      _device?.disconnect().catchError((_) {});
    }
    _device = null;
    super.dispose();
  }
}
