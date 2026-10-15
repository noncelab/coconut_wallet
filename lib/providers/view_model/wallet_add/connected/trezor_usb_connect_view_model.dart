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
  passphraseEnabling, // 1-1: enabling passphrase on device (loading)
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
  int _connectionAttempt = 0;
  Future<String> Function()? _pairingCallback;
  bool _isConnecting = false;
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

  /// Populates this viewmodel from an already-connected [TrezorDevice.lastConnected]
  /// session and jumps straight to [TrezorUsbConnectStep.connected], skipping the
  /// pairing flow entirely. Returns true if a resumable session was found.
  bool resumeFromExistingSession() {
    final device = TrezorDevice.lastConnected;
    final cachedXpub = device?.cachedXpub;
    if (_disposed || device == null || cachedXpub == null || cachedXpub.isEmpty) return false;
    _device = device;
    _xpub = cachedXpub;
    _fingerprint = device.cachedFingerprint ?? '';
    _setState(TrezorUsbConnectStep.connected);
    return true;
  }

  Future<void> connect() async {
    if (_disposed || _isConnecting || isConnected) return;
    final attempt = ++_connectionAttempt;
    bool isCancelled() => _disposed || attempt != _connectionAttempt;
    _isConnecting = true;
    _setState(TrezorUsbConnectStep.connecting);
    _errorMessage = null;
    Future<String> callback() async {
      if (isCancelled()) return '';
      final completer = Completer<String>();
      _pairingCodeCompleter = completer;
      _setState(TrezorUsbConnectStep.pairing);
      final code = await completer.future;
      if (identical(_pairingCodeCompleter, completer)) _pairingCodeCompleter = null;
      if (!isCancelled()) _setState(TrezorUsbConnectStep.connecting);
      return code;
    }

    _pairingCallback = callback;
    try {
      final device = await TrezorDevice.connect(
        transport: TrezorTransport.usb,
        pairingCodeRequested: callback,
        isCancelled: isCancelled,
      );
      if (isCancelled()) {
        await device.disconnect();
        return;
      }
      _device = device;
      TrezorDevice.lastConnected = _device;
      debugPrint(
        'TREZOR_USB connected passphraseProtection=${_device!.passphraseProtection} '
        'alwaysOnDevice=${_device!.passphraseAlwaysOnDevice} '
        'supportsOnDeviceEntry=${_device!.supportsPassphraseEntry} '
        'usesThp=${_device!.usesThp}',
      );

      await _ensureMinStepDuration(const Duration(milliseconds: 1500));
      if (isCancelled()) return;
      _setState(TrezorUsbConnectStep.passphraseUseQuestion);
    } on TrezorPairingCodeWrongException catch (e) {
      if (isCancelled()) return;
      _errorMessage = e.message;
      _isPairingCodeWrong = true;
      await _disconnectDevice();
      _setState(TrezorUsbConnectStep.error);
    } on TrezorPairingException catch (e) {
      if (isCancelled()) return;
      _errorMessage = e.message;
      await _disconnectDevice();
      _setState(TrezorUsbConnectStep.error);
    } catch (error) {
      if (isCancelled()) return;
      _errorMessage = error.toString();
      await _disconnectDevice();
      _setState(TrezorUsbConnectStep.error);
    } finally {
      if (attempt == _connectionAttempt) {
        _pairingCallback = null;
        _isConnecting = false;
      }
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
  ///
  /// If passphraseProtection is already enabled on the device, proceed to passphrase entry.
  /// If not, first call applySettings to enable it — the user must confirm on the device.
  /// The user cannot skip this step after choosing to use passphrase.
  Future<void> selectUsePassphrase() async {
    final device = _device;
    if (_disposed || device == null) return;
    final attempt = _connectionAttempt;
    bool isCancelled() => _disposed || attempt != _connectionAttempt;
    if (!device.passphraseProtection) {
      _setState(TrezorUsbConnectStep.passphraseEnabling);
      try {
        await device.applySettings(usePassphrase: true);
        if (isCancelled()) return;
      } catch (error) {
        if (isCancelled()) return;
        _errorMessage = error.toString();
        await _disconnectDevice();
        _setState(TrezorUsbConnectStep.error);
        return;
      }
      // After enabling, update the device flag so downstream logic works correctly
      device.passphraseProtection = true;
    }
    if (device.passphraseAlwaysOnDevice) {
      _setState(TrezorUsbConnectStep.passphraseOnDevice);
    } else if (!device.supportsPassphraseEntry) {
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
    final device = _device;
    if (_disposed || device == null) return;
    final attempt = _connectionAttempt;
    bool isCancelled() => _disposed || attempt != _connectionAttempt;
    try {
      await device.createSession(type: type, value: value);
      if (isCancelled()) return;
      await _ensureMinStepDuration(const Duration(milliseconds: 1500));
      if (isCancelled()) return;
      await _proceedToXpub();
    } catch (error) {
      if (isCancelled()) return;
      _errorMessage = error.toString();
      await _disconnectDevice();
      _setState(TrezorUsbConnectStep.error);
    }
  }

  /// Step 6: getXPub + getFingerprint → connected.
  Future<void> _proceedToXpub() async {
    final device = _device;
    if (_disposed || device == null) return;
    final attempt = _connectionAttempt;
    bool isCancelled() => _disposed || attempt != _connectionAttempt;
    _setState(TrezorUsbConnectStep.passphraseProcessing);
    try {
      final network = NetworkType.currentNetworkType;
      final keypath = network.isTestnet ? "m/84'/1'/0'" : "m/84'/0'/0'";
      final xpub = await device.getXPub(keypath: keypath, network: network.toString());
      if (isCancelled()) return;
      _xpub = xpub;
      device.cachedXpub = _xpub;
      final fingerprint = await device.getFingerprint();
      if (isCancelled()) return;
      _fingerprint = fingerprint;
      device.cachedFingerprint = _fingerprint;
      await _ensureMinStepDuration(const Duration(milliseconds: 1000));
      if (isCancelled()) return;
      _setState(TrezorUsbConnectStep.connected);
    } catch (error) {
      if (isCancelled()) return;
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
    _cancelConnection();
    _disconnectDevice().catchError((_) {});
  }

  void _cancelConnection() {
    _connectionAttempt++;
    _isConnecting = false;
    final pinCompleter = _pinCompleter;
    if (pinCompleter != null && !pinCompleter.isCompleted) pinCompleter.complete('');
    _pinCompleter = null;
    _pin = '';
    _pendingPassphraseResponse = null;
    final completer = _pairingCodeCompleter;
    if (completer != null && !completer.isCompleted) completer.complete('');
    _pairingCodeCompleter = null;
    final callback = _pairingCallback;
    _pairingCallback = null;
    if (callback != null && identical(TrezorDevice.onPairingCodeRequested, callback)) {
      TrezorDevice.cancel().catchError((_) {});
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
    _cancelConnection();
    await _disconnectDevice();
    _xpub = '';
    _fingerprint = '';
    _errorMessage = null;
    _setState(TrezorUsbConnectStep.idle);
  }

  void reset() {
    _cancelConnection();
    _device?.disconnect().catchError((_) {});
    _device = null;
    _step = TrezorUsbConnectStep.idle;
    _errorMessage = null;
    _isPairingCodeWrong = false;
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
    _cancelConnection();
    if (_step != TrezorUsbConnectStep.connected) {
      _device?.disconnect().catchError((_) {});
    }
    _device = null;
    super.dispose();
  }
}
