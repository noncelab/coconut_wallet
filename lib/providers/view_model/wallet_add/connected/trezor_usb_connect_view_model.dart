import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_exceptions.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/third_party_util.dart';
import 'package:flutter/foundation.dart';

enum TrezorUsbConnectStep {
  idle,
  connecting,
  pinEntry,
  pairing,
  passphraseUseQuestion, // 1: use passphrase?
  passphraseSourceSelection, // 3: where to enter?
  passphraseInput, // 4-1: enter passphrase in app
  passphraseOnDevice, // 4-2: enter on Trezor
  passphraseConfirm, // 5: confirm on device (loading)
  passphraseProcessing, // 6: loading + getXPub
  connected,
  error,
}

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
  Completer<String>? _pairingCodeCompleter;
  String _pin = '';
  bool _isPairingCodeWrong = false;
  TrezorPassphraseResponse? _pendingPassphraseResponse;
  DateTime _stepEnteredAt = DateTime.now();

  TrezorUsbConnectStep get step => _step;
  String get xpub => _xpub;
  String get fingerprint => _fingerprint;
  String get deviceLabel => _device?.label ?? '';
  String get deviceModel => _device?.model ?? '';
  String? get errorMessage => _errorMessage;
  bool get isConnected => _step == TrezorUsbConnectStep.connected;
  String get pin => _pin;
  bool get isPairingCodeWrong => _isPairingCodeWrong;
  bool get passphraseAlwaysOnDevice => _device?.passphraseAlwaysOnDevice ?? false;
  bool get supportsPassphraseEntry => _device?.supportsPassphraseEntry ?? false;
  bool get passphraseProtection => _device?.passphraseProtection ?? false;
  bool get usesThp => _device?.usesThp ?? false;

  Future<void> connect() async {
    if (_step == TrezorUsbConnectStep.connecting) return;
    _setState(TrezorUsbConnectStep.connecting);
    _errorMessage = null;
    TrezorDevice.onPairingCodeRequested = () async {
      _pairingCodeCompleter = Completer<String>();
      _setState(TrezorUsbConnectStep.pairing);
      final code = await _pairingCodeCompleter!.future;
      _pairingCodeCompleter = null;
      _setState(TrezorUsbConnectStep.connecting);
      return code;
    };
    try {
      _device = await TrezorDevice.connect(transport: TrezorTransport.usb);
      TrezorDevice.lastConnected = _device;
      debugPrint(
        'TREZOR_USB connected passphraseProtection=${_device!.passphraseProtection} '
        'alwaysOnDevice=${_device!.passphraseAlwaysOnDevice} '
        'supportsOnDeviceEntry=${_device!.supportsPassphraseEntry} '
        'usesThp=${_device!.usesThp}',
      );

      await _ensureMinStepDuration(const Duration(milliseconds: 1500));
      if (_device!.passphraseProtection) {
        _setState(TrezorUsbConnectStep.passphraseUseQuestion);
      } else {
        await _proceedToXpub();
      }
    } on TrezorPairingCodeWrongException catch (e) {
      _errorMessage = e.message;
      _isPairingCodeWrong = true;
      await _disconnectDevice();
      _setState(TrezorUsbConnectStep.error);
    } on TrezorPairingException catch (e) {
      _errorMessage = e.message;
      await _disconnectDevice();
      _setState(TrezorUsbConnectStep.error);
    } catch (error) {
      _errorMessage = error.toString();
      await _disconnectDevice();
      _setState(TrezorUsbConnectStep.error);
    } finally {
      TrezorDevice.onPairingCodeRequested = null;
    }
  }

  // -- New passphrase flow step methods --

  /// Step 1: User chose not to use passphrase.
  Future<void> selectNoPassphrase() async {
    if (_device!.usesThp) {
      await _createSessionAndProceed(TrezorPassphraseType.standard);
    } else {
      _pendingPassphraseResponse = const TrezorPassphraseResponse(TrezorPassphraseType.standard);
      await _proceedToXpub();
    }
  }

  /// Step 1: User chose to use passphrase → go to step 2/3.
  void selectUsePassphrase() {
    if (_device!.passphraseAlwaysOnDevice) {
      _setState(TrezorUsbConnectStep.passphraseOnDevice);
    } else if (!_device!.supportsPassphraseEntry) {
      _setState(TrezorUsbConnectStep.passphraseInput);
    } else {
      _setState(TrezorUsbConnectStep.passphraseSourceSelection);
    }
  }

  /// Step 3: User chose app entry → go to step 4-1.
  void selectAppEntry() {
    _setState(TrezorUsbConnectStep.passphraseInput);
  }

  /// Step 3: User chose device entry → go to step 4-2.
  Future<void> selectDeviceEntry() async {
    _setState(TrezorUsbConnectStep.passphraseOnDevice);
    if (_device!.usesThp) {
      await _createSessionAndProceed(TrezorPassphraseType.onDevice);
    } else {
      _pendingPassphraseResponse = const TrezorPassphraseResponse(TrezorPassphraseType.onDevice);
      await _proceedToXpub();
    }
  }

  /// Step 4-1: User submitted passphrase from app.
  Future<void> submitPassphraseValue(String value) async {
    if (_device!.usesThp) {
      _setState(TrezorUsbConnectStep.passphraseConfirm);
      await _createSessionAndProceed(TrezorPassphraseType.hidden, value: value);
    } else {
      _pendingPassphraseResponse = TrezorPassphraseResponse(TrezorPassphraseType.hidden, value: value);
      await _proceedToXpub();
    }
  }

  /// Internal: call createSession (THP only) then proceed to getXPub.
  Future<void> _createSessionAndProceed(TrezorPassphraseType type, {String value = ''}) async {
    try {
      await _device!.createSession(type: type, value: value);
      await _ensureMinStepDuration(const Duration(milliseconds: 1500));
      await _proceedToXpub();
    } catch (error) {
      _errorMessage = error.toString();
      await _disconnectDevice();
      _setState(TrezorUsbConnectStep.error);
    }
  }

  /// Step 6: getXPub + getFingerprint → connected.
  Future<void> _proceedToXpub() async {
    _setState(TrezorUsbConnectStep.passphraseProcessing);
    try {
      final network = NetworkType.currentNetworkType;
      final keypath = network.isTestnet ? "m/84'/1'/0'" : "m/84'/0'/0'";
      _xpub = await _device!.getXPub(keypath: keypath, network: network.toString());
      _device!.cachedXpub = _xpub;
      _fingerprint = await _device!.getFingerprint();
      _device!.cachedFingerprint = _fingerprint;
      await _ensureMinStepDuration(const Duration(milliseconds: 1000));
      _setState(TrezorUsbConnectStep.connected);
    } catch (error) {
      _errorMessage = error.toString();
      await _disconnectDevice();
      _setState(TrezorUsbConnectStep.error);
    }
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

  void consumePairingCodeWrong() {
    _isPairingCodeWrong = false;
  }

  void submitPairingCode(String code) {
    if (_pairingCodeCompleter != null && !_pairingCodeCompleter!.isCompleted) {
      _pairingCodeCompleter!.complete(code);
    }
  }

  void cancelPairing() {
    if (_pairingCodeCompleter != null && !_pairingCodeCompleter!.isCompleted) {
      _pairingCodeCompleter!.complete('');
    }
  }

  Future<TrezorPassphraseResponse> requestPassphrase(bool onDevice) {
    if (_pendingPassphraseResponse != null) {
      final response = _pendingPassphraseResponse!;
      _pendingPassphraseResponse = null;
      return Future.value(response);
    }
    return Future.value(const TrezorPassphraseResponse(TrezorPassphraseType.standard));
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
    _xpub = '';
    _fingerprint = '';
    _errorMessage = null;
    _setState(TrezorUsbConnectStep.idle);
  }

  void reset() {
    _device?.disconnect().catchError((_) {});
    _device = null;
    _step = TrezorUsbConnectStep.idle;
    _errorMessage = null;
    _isPairingCodeWrong = false;
    _pairingCodeCompleter = null;
    _pin = '';
    _pinCompleter?.complete('');
    _pinCompleter = null;
    _pendingPassphraseResponse = null;
    _xpub = '';
    _fingerprint = '';
    if (!_disposed) notifyListeners();
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
    _stepEnteredAt = DateTime.now();
    notifyListeners();
  }

  Future<void> _ensureMinStepDuration(Duration minDuration) async {
    final elapsed = DateTime.now().difference(_stepEnteredAt);
    if (elapsed < minDuration) {
      await Future.delayed(minDuration - elapsed);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _pinCompleter?.complete('');
    _pinCompleter = null;
    final pairingCompleter = _pairingCodeCompleter;
    if (pairingCompleter != null && !pairingCompleter.isCompleted) {
      pairingCompleter.complete('');
    }
    _pairingCodeCompleter = null;
    TrezorDevice.onPairingCodeRequested = null;
    if (_step != TrezorUsbConnectStep.connected) {
      TrezorDevice.cancel().catchError((_) {});
      _device?.disconnect().catchError((_) {});
    }
    _device = null;
    super.dispose();
  }
}
