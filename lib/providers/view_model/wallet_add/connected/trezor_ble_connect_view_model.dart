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
    _pairingErrorMessage = null;
    _pairingCodeCompleter = Completer<String>();
    _setState(TrezorBleConnectStep.pairing);
    final code = await _pairingCodeCompleter!.future;
    _pairingCodeCompleter = null;
    return code;
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

  /// Populates this viewmodel from an already-connected [TrezorDevice.lastConnected]
  /// session and jumps straight to [TrezorBleConnectStep.paired], skipping the
  /// pairing flow entirely. Returns true if a resumable session was found.
  bool resumeFromExistingSession() {
    final device = TrezorDevice.lastConnected;
    final cachedXpub = device?.cachedXpub;
    if (device == null || cachedXpub == null || cachedXpub.isEmpty) return false;
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
    if (_isConnecting || _step == TrezorBleConnectStep.paired) {
      debugPrint('TREZOR_BLE_CONNECT connect skipped: already connecting or paired');
      return;
    }

    _isConnecting = true;
    _errorMessage = null;
    _errorDescription = null;
    _pairingErrorMessage = null;
    _peerRemovedPairingSteps = null;
    _isPairingCodeWrong = false;
    _isPermissionDenied = false;
    if (!_disposed) notifyListeners();

    try {
      // Disconnect any previously active BLE session before starting a new one.
      await TrezorDevice.lastConnected?.disconnect();

      TrezorDevice.onPairingCodeRequested = () async {
        return await waitForPairingCode();
      };
      _setState(TrezorBleConnectStep.connecting);
      _device = await TrezorDevice.connect();
      _deviceLabel = _device!.label;
      TrezorDevice.lastConnected = _device;
      debugPrint(
        'TREZOR_BLE_CONNECT connected: id=${_device!.id} label="${_device!.label}" '
        'transport=${_device!.transport.name} passphraseProtection=${_device!.passphraseProtection} '
        'lastConnectedSame=${identical(TrezorDevice.lastConnected, _device)}',
      );

      _setState(TrezorBleConnectStep.passphraseUseQuestion);
    } on TrezorPairingCodeWrongException catch (e) {
      _errorMessage = e.message;
      _pairingCodeCompleter = null;
      _isPairingCodeWrong = true;
      if (!_disposed) notifyListeners();
    } on TrezorConnectException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        _errorMessage = e.message;
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
        _errorMessage = e.message;
        _peerRemovedPairingSteps = null;
        onPairingFailed?.call();
        _setState(TrezorBleConnectStep.error);
      } else {
        _errorMessage = e.message;
        onPairingFailed?.call();
        _setState(TrezorBleConnectStep.error);
      }
    } on TrezorPairingException catch (e) {
      _errorMessage = e.message;
      onPairingFailed?.call();
      _setState(TrezorBleConnectStep.error);
    } catch (e) {
      _errorMessage = e.toString();
      onPairingFailed?.call();
      _setState(TrezorBleConnectStep.error);
    } finally {
      _isConnecting = false;
      if (!_disposed) notifyListeners();
    }
  }

  bool _isRetrievingXPub = false;

  Future<void> retrieveXPub() => _retrieveXPub(silent: false);

  Future<void> _retrieveXPub({bool silent = false}) async {
    if (_isRetrievingXPub || _device == null) return;
    _isRetrievingXPub = true;
    _errorMessage = null;

    try {
      final nt = NetworkType.currentNetworkType;
      final isTestnet = nt.isTestnet;
      final keypath = isTestnet ? "m/84'/1'/0'" : "m/84'/0'/0'";

      try {
        _xpub = await _device!.getXPub(keypath: keypath, network: nt.toString());
        _device!.cachedXpub = _xpub;
        _fingerprint = await _device!.getFingerprint();
        _device!.cachedFingerprint = _fingerprint;
        debugPrint(
          'TREZOR_BLE_CONNECT xpub retrieved: id=${_device!.id} '
          'xpubLength=${_xpub.length} fingerprint=$_fingerprint '
          'cachedXpub=${_device!.cachedXpub != null} cachedFingerprint=${_device!.cachedFingerprint != null}',
        );
        _setState(TrezorBleConnectStep.paired);
      } on Exception catch (e) {
        if (silent) {
          _errorMessage = e.toString();
          _setState(TrezorBleConnectStep.paired);
        } else {
          _errorMessage = e.toString();
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
    if (!_device!.passphraseProtection) {
      _setState(TrezorBleConnectStep.passphraseEnabling);
      try {
        await _device!.applySettings(usePassphrase: true);
      } catch (error) {
        _errorMessage = error.toString();
        await _disconnectDevice();
        _setState(TrezorBleConnectStep.error);
        return;
      }
      _device!.passphraseProtection = true;
    }
    if (_device!.passphraseAlwaysOnDevice) {
      _setState(TrezorBleConnectStep.passphraseOnDevice);
    } else if (!_device!.supportsPassphraseEntry) {
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
    try {
      await _device!.createSession(type: type, value: value);
    } catch (error) {
      _errorMessage = error.toString();
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
    await _disconnectDevice();
    _setState(TrezorBleConnectStep.idle);
  }

  void reset() {
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
    if (_step != TrezorBleConnectStep.paired) {
      TrezorDevice.cancel().catchError((_) {});
      if (_device != null) {
        _device!.disconnect().catchError((_) {});
      }
    }
    _device = null;
    super.dispose();
  }
}
