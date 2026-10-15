import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_exceptions.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/third_party_util.dart';
import 'package:flutter/foundation.dart';

enum TrezorBleConnectStep {
  idle,
  connecting,
  pairing,
  passphraseUseQuestion,
  passphraseEnabling,
  passphraseSourceSelection,
  passphraseInput,
  passphraseOnDevice,
  passphraseConfirm,
  passphraseProcessing,
  paired,
  error,
}

class TrezorBleConnectViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;

  TrezorBleConnectViewModel(this._walletProvider);

  TrezorBleConnectStep _step = TrezorBleConnectStep.idle;
  TrezorDevice? _device;
  String? _errorDescription;
  String? _errorMessage;
  List<String>? _peerRemovedPairingSteps;
  String _xpub = '';
  String _fingerprint = '';
  String _deviceLabel = '';
  bool _isConnecting = false;
  bool _disposed = false;
  int _connectionAttempt = 0;
  Future<String> Function()? _pairingCallback;
  bool _isPairingCodeWrong = false;
  bool _isPermissionDenied = false;

  Completer<String>? _pairingCodeCompleter;
  String? _pairingErrorMessage;

  String? get pairingErrorMessage => _pairingErrorMessage;
  bool get isPairingCodeWrong => _isPairingCodeWrong;
  bool get isPermissionDenied => _isPermissionDenied;

  void consumePairingCodeWrong() {
    _isPairingCodeWrong = false;
  }

  void consumePermissionDenied() {
    _isPermissionDenied = false;
  }

  // Called when pairing failed for other reasons.
  void Function()? onPairingFailed;

  TrezorBleConnectStep get step => _step;
  String? get errorDescription => _errorDescription;
  String? get errorMessage => _errorMessage;
  List<String>? get peerRemovedPairingSteps => _peerRemovedPairingSteps;
  bool get isPaired => _step == TrezorBleConnectStep.paired;
  bool get isConnecting => _isConnecting;
  String get xpub => _xpub;
  String get fingerprint => _fingerprint;
  String get deviceLabel => _deviceLabel;
  bool get supportsPassphraseEntry => _device?.supportsPassphraseEntry ?? false;
  bool get passphraseAlwaysOnDevice => _device?.passphraseAlwaysOnDevice ?? false;
  bool get usesThp => _device?.usesThp ?? false;

  void _setState(TrezorBleConnectStep step) {
    if (_disposed) return;
    _step = step;
    notifyListeners();
  }

  Future<String> waitForPairingCode() async {
    if (_disposed) return '';
    _pairingErrorMessage = null;
    final completer = Completer<String>();
    _pairingCodeCompleter = completer;
    _setState(TrezorBleConnectStep.pairing);
    final code = await completer.future;
    if (identical(_pairingCodeCompleter, completer)) _pairingCodeCompleter = null;
    return code;
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
    final completer = _pairingCodeCompleter;
    if (completer != null && !completer.isCompleted) completer.complete('');
    _pairingCodeCompleter = null;
    final callback = _pairingCallback;
    _pairingCallback = null;
    if (callback != null && identical(TrezorDevice.onPairingCodeRequested, callback)) {
      TrezorDevice.cancel().catchError((_) {});
    }
  }

  /// Populates this viewmodel from an already-connected [TrezorDevice.lastConnected]
  /// session and jumps straight to [TrezorBleConnectStep.paired], skipping the
  /// pairing flow entirely. Returns true if a resumable session was found.
  bool resumeFromExistingSession() {
    final device = TrezorDevice.lastConnected;
    final cachedXpub = device?.cachedXpub;
    if (_disposed || device == null || cachedXpub == null || cachedXpub.isEmpty) return false;
    _device = device;
    _deviceLabel = device.label;
    _xpub = cachedXpub;
    _fingerprint = device.cachedFingerprint ?? '';
    _setState(TrezorBleConnectStep.paired);
    return true;
  }

  Future<void> connect() async {
    debugPrint(
      'TREZOR_BLE_CONNECT connect start: step=${_step.name} isConnecting=$_isConnecting '
      'lastConnected=${TrezorDevice.lastConnected != null}',
    );
    if (_disposed || _isConnecting || _step == TrezorBleConnectStep.paired) {
      debugPrint('TREZOR_BLE_CONNECT connect skipped: already connecting or paired');
      return;
    }

    final attempt = ++_connectionAttempt;
    bool isCancelled() => _disposed || attempt != _connectionAttempt;
    _isConnecting = true;
    _errorMessage = null;
    _errorDescription = null;
    _pairingErrorMessage = null;
    _peerRemovedPairingSteps = null;
    _isPairingCodeWrong = false;
    _isPermissionDenied = false;
    if (!_disposed) notifyListeners();

    try {
      Future<String> callback() async => isCancelled() ? '' : await waitForPairingCode();
      _pairingCallback = callback;
      _setState(TrezorBleConnectStep.connecting);
      final device = await TrezorDevice.connect(pairingCodeRequested: callback, isCancelled: isCancelled);
      if (isCancelled()) {
        await device.disconnect();
        return;
      }
      _device = device;
      _deviceLabel = _device!.label;
      TrezorDevice.lastConnected = _device;
      debugPrint(
        'TREZOR_BLE_CONNECT connected: id=${_device!.id} label="${_device!.label}" '
        'transport=${_device!.transport.name} passphraseProtection=${_device!.passphraseProtection} '
        'lastConnectedSame=${identical(TrezorDevice.lastConnected, _device)}',
      );

      _setState(TrezorBleConnectStep.passphraseUseQuestion);
    } on TrezorPairingCodeWrongException {
      if (isCancelled()) return;
      _errorMessage = null;
      _pairingCodeCompleter = null;
      _isPairingCodeWrong = true;
      if (!_disposed) notifyListeners();
    } on TrezorConnectException catch (e) {
      if (isCancelled()) return;
      if (e.code == 'PERMISSION_DENIED') {
        _errorMessage = null;
        _isPermissionDenied = true;
        _step = TrezorBleConnectStep.idle;
        if (!_disposed) notifyListeners();
      } else if (e.code == 'BLE_DISABLED') {
        _errorMessage = t.wallet_connect_screen.common.ble_off;
        onPairingFailed?.call();
        _setState(TrezorBleConnectStep.error);
      } else if (e.code == 'PEER_REMOVED_PAIRING') {
        // iOS only
        _errorDescription = t.wallet_connect_screen.guide_trezor.ios_peer_removed_pairing.title;
        _errorMessage = t.wallet_connect_screen.guide_trezor.ios_peer_removed_pairing.description;
        _peerRemovedPairingSteps = [
          t.wallet_connect_screen.guide_trezor.ios_peer_removed_pairing.step1,
          t.wallet_connect_screen.guide_trezor.ios_peer_removed_pairing.step2,
          t.wallet_connect_screen.guide_trezor.ios_peer_removed_pairing.step3,
        ];
        onPairingFailed?.call();
        _setState(TrezorBleConnectStep.error);
      } else if (e.message.contains('Encryption is insufficient')) {
        // 페어링 중간에 중단된 경우
        _errorDescription = t.wallet_connect_screen.guide_trezor.pairing_aborted.title;
        _errorMessage = null;
        _peerRemovedPairingSteps = null;
        onPairingFailed?.call();
        _setState(TrezorBleConnectStep.error);
      } else {
        _errorMessage = null;
        onPairingFailed?.call();
        _setState(TrezorBleConnectStep.error);
      }
    } on TrezorPairingException {
      if (isCancelled()) return;
      _errorMessage = null;
      onPairingFailed?.call();
      _setState(TrezorBleConnectStep.error);
    } catch (e) {
      if (isCancelled()) return;
      _errorMessage = null;
      onPairingFailed?.call();
      _setState(TrezorBleConnectStep.error);
    } finally {
      if (attempt == _connectionAttempt) {
        _pairingCallback = null;
        _isConnecting = false;
        if (!_disposed) notifyListeners();
      }
    }
  }

  bool _isRetrievingXPub = false;

  Future<void> retrieveXPub() => _retrieveXPub(silent: false);

  Future<void> _retrieveXPub({bool silent = false}) async {
    if (_disposed || _isRetrievingXPub || _device == null) return;
    final device = _device!;
    final attempt = _connectionAttempt;
    bool isCancelled() => _disposed || attempt != _connectionAttempt;
    _isRetrievingXPub = true;
    _errorMessage = null;

    try {
      final nt = NetworkType.currentNetworkType;
      final isTestnet = nt.isTestnet;
      final keypath = isTestnet ? "m/84'/1'/0'" : "m/84'/0'/0'";

      try {
        final xpub = await device.getXPub(keypath: keypath, network: nt.toString());
        if (isCancelled()) return;
        _xpub = xpub;
        device.cachedXpub = _xpub;
        final fingerprint = await device.getFingerprint();
        if (isCancelled()) return;
        _fingerprint = fingerprint;
        device.cachedFingerprint = _fingerprint;
        debugPrint(
          'TREZOR_BLE_CONNECT xpub retrieved: id=${device.id} '
          'xpubLength=${_xpub.length} fingerprint=$_fingerprint '
          'cachedXpub=${device.cachedXpub != null} cachedFingerprint=${device.cachedFingerprint != null}',
        );
        _setState(TrezorBleConnectStep.paired);
      } on Exception {
        if (isCancelled()) return;
        if (silent) {
          _errorMessage = t.wallet_connect_screen.guide_trezor.error.title;
          _setState(TrezorBleConnectStep.paired);
        } else {
          _errorMessage = t.wallet_connect_screen.guide_trezor.error.title;
          _setState(TrezorBleConnectStep.error);
        }
      }
    } finally {
      _isRetrievingXPub = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<ResultOfSyncFromVault> addToWalletList() async {
    final walletAddService = WalletAddService();
    final existingNames = _walletProvider.walletItemList.map((e) => e.name).toList();
    final String name;
    if (_deviceLabel.isNotEmpty) {
      name = _resolveNameWithBase(_deviceLabel, existingNames);
    } else {
      name = getNextThirdPartyWalletName(WalletImportSource.trezor, existingNames);
    }
    final wallet = walletAddService.createExtendedPublicKeyWallet(
      _xpub,
      name,
      _fingerprint,
      walletImportSource: WalletImportSource.trezor,
    );
    return _walletProvider.syncFromThirdParty(wallet);
  }

  String _resolveNameWithBase(String baseName, List<String> existingNames) {
    final regex = RegExp('^${RegExp.escape(baseName)}(?: (\\d+))?\$');
    final takenNumbers = <int>{};
    for (final n in existingNames) {
      final match = regex.firstMatch(n);
      if (match != null) {
        final g = match.group(1);
        takenNumbers.add(g == null ? 1 : (int.tryParse(g) ?? 1));
      }
    }
    if (!takenNumbers.contains(1)) return baseName;
    int next = 2;
    while (takenNumbers.contains(next)) {
      next++;
    }
    return '$baseName $next';
  }

  Future<TrezorPassphraseResponse> requestPassphrase(bool onDevice) {
    return Future.value(const TrezorPassphraseResponse(TrezorPassphraseType.standard));
  }

  // -- New passphrase flow step methods --

  /// Step 1: User chose not to use passphrase.
  Future<void> selectNoPassphrase() async {
    await _createSessionAndProceed(TrezorPassphraseType.standard);
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
      _setState(TrezorBleConnectStep.passphraseEnabling);
      try {
        await device.applySettings(usePassphrase: true);
        if (isCancelled()) return;
      } catch (error) {
        if (isCancelled()) return;
        _errorMessage = null;
        await _disconnectDevice();
        _setState(TrezorBleConnectStep.error);
        return;
      }
      device.passphraseProtection = true;
    }
    if (device.passphraseAlwaysOnDevice) {
      _setState(TrezorBleConnectStep.passphraseOnDevice);
    } else if (!device.supportsPassphraseEntry) {
      _setState(TrezorBleConnectStep.passphraseInput);
    } else {
      _setState(TrezorBleConnectStep.passphraseSourceSelection);
    }
  }

  /// Step 3: User chose app entry → go to step 4-1.
  void selectAppEntry() {
    _setState(TrezorBleConnectStep.passphraseInput);
  }

  /// Step 3: User chose device entry → go to step 4-2.
  Future<void> selectDeviceEntry() async {
    _setState(TrezorBleConnectStep.passphraseOnDevice);
    await _createSessionAndProceed(TrezorPassphraseType.onDevice);
  }

  /// Step 4-1: User submitted passphrase from app.
  Future<void> submitPassphraseValue(String value) async {
    _setState(TrezorBleConnectStep.passphraseConfirm);
    await _createSessionAndProceed(TrezorPassphraseType.hidden, value: value);
  }

  /// Internal: call createSession then proceed to getXPub.
  Future<void> _createSessionAndProceed(TrezorPassphraseType type, {String value = ''}) async {
    final device = _device;
    if (_disposed || device == null) return;
    final attempt = _connectionAttempt;
    bool isCancelled() => _disposed || attempt != _connectionAttempt;
    try {
      await device.createSession(type: type, value: value);
      if (isCancelled()) return;
    } catch (error) {
      if (isCancelled()) return;
      _errorMessage = null;
      await _disconnectDevice();
      _setState(TrezorBleConnectStep.error);
      return;
    }
    _setState(TrezorBleConnectStep.passphraseProcessing);
    await _retrieveXPub(silent: true);
  }

  Future<void> _disconnectDevice() async {
    final device = _device;
    _device = null;
    if (device != null) {
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }

  Future<void> disconnect() async {
    _cancelConnection();
    await _disconnectDevice();
    _setState(TrezorBleConnectStep.idle);
  }

  void reset() {
    _cancelConnection();
    debugPrint(
      'TREZOR_BLE_CONNECT reset: step=${_step.name} device=${_device != null} '
      'lastConnected=${TrezorDevice.lastConnected != null} xpub=${_xpub.isNotEmpty} fingerprint=${_fingerprint.isNotEmpty}',
    );
    // Disconnect the actual BLE session before clearing references,
    // otherwise connect() cannot reach lastConnected to disconnect it.
    _device?.disconnect().catchError((_) {});
    _device = null;
    _step = TrezorBleConnectStep.idle;
    _errorMessage = null;
    _errorDescription = null;
    _peerRemovedPairingSteps = null;
    _isPairingCodeWrong = false;
    _isPermissionDenied = false;
    _xpub = '';
    _fingerprint = '';
    _deviceLabel = '';
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelConnection();
    if (_step != TrezorBleConnectStep.paired) {
      if (_device != null) {
        _device!.disconnect().catchError((_) {});
      }
    }
    _device = null;
    super.dispose();
  }
}
