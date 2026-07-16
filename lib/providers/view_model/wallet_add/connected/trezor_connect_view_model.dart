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

enum TrezorConnectStep { idle, connecting, pairing, paired, error }

class TrezorConnectViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;

  TrezorConnectViewModel(this._walletProvider);

  TrezorConnectStep _step = TrezorConnectStep.idle;
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

  TrezorConnectStep get step => _step;
  String? get errorDescription => _errorDescription;
  String? get errorMessage => _errorMessage;
  List<String>? get peerRemovedPairingSteps => _peerRemovedPairingSteps;
  bool get isPaired => _step == TrezorConnectStep.paired;
  bool get isConnecting => _isConnecting;
  String get xpub => _xpub;
  String get fingerprint => _fingerprint;
  String get deviceLabel => _deviceLabel;

  void _setState(TrezorConnectStep step) {
    if (_disposed) return;
    _step = step;
    notifyListeners();
  }

  Future<String> waitForPairingCode() async {
    _pairingErrorMessage = null;
    _pairingCodeCompleter = Completer<String>();
    _setState(TrezorConnectStep.pairing);
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

  Future<void> connect() async {
    if (_isConnecting || _step == TrezorConnectStep.paired) return;

    _isConnecting = true;
    _errorMessage = null;
    _errorDescription = null;
    _pairingErrorMessage = null;
    _peerRemovedPairingSteps = null;
    _isPairingCodeWrong = false;
    _isPermissionDenied = false;
    if (!_disposed) notifyListeners();

    try {
      TrezorDevice.onPairingCodeRequested = () async {
        return await waitForPairingCode();
      };
      _setState(TrezorConnectStep.connecting);
      _device = await TrezorDevice.connect();
      _deviceLabel = _device!.label;

      _setState(TrezorConnectStep.paired);
      TrezorDevice.lastConnected = _device;
      await _retrieveXPub(silent: true);
    } on TrezorPairingCodeWrongException catch (e) {
      _errorMessage = e.message;
      _pairingCodeCompleter = null;
      _isPairingCodeWrong = true;
      if (!_disposed) notifyListeners();
    } on TrezorConnectException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        _errorMessage = e.message;
        _isPermissionDenied = true;
        _step = TrezorConnectStep.idle;
        if (!_disposed) notifyListeners();
      } else if (e.code == 'BLE_DISABLED') {
        _errorMessage = t.wallet_connect_screen.common.ble_off;
        onPairingFailed?.call();
        _setState(TrezorConnectStep.error);
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
        _setState(TrezorConnectStep.error);
      } else if (e.message.contains('Encryption is insufficient')) {
        // 페어링 중간에 중단된 경우
        _errorDescription = t.wallet_connect_screen.guide_trezor.pairing_aborted.title;
        _errorMessage = e.message;
        _peerRemovedPairingSteps = null;
        onPairingFailed?.call();
        _setState(TrezorConnectStep.error);
      } else {
        _errorMessage = e.message;
        onPairingFailed?.call();
        _setState(TrezorConnectStep.error);
      }
    } on TrezorPairingException catch (e) {
      _errorMessage = e.message;
      onPairingFailed?.call();
      _setState(TrezorConnectStep.error);
    } catch (e) {
      _errorMessage = e.toString();
      onPairingFailed?.call();
      _setState(TrezorConnectStep.error);
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
        _fingerprint = await _device!.getFingerprint();
        _device!.cachedFingerprint = _fingerprint;
        _setState(TrezorConnectStep.paired);
      } on Exception catch (e) {
        if (silent) {
          _errorMessage = e.toString();
          _setState(TrezorConnectStep.paired);
        } else {
          _errorMessage = e.toString();
          _setState(TrezorConnectStep.error);
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
    while (takenNumbers.contains(next)) next++;
    return '$baseName $next';
  }

  Future<void> disconnect() async {
    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
      _device = null;
    }
    TrezorDevice.lastConnected = null;
    _setState(TrezorConnectStep.idle);
  }

  void reset() {
    _step = TrezorConnectStep.idle;
    _device = null;
    _errorMessage = null;
    _errorDescription = null;
    _peerRemovedPairingSteps = null;
    _isPairingCodeWrong = false;
    _isPermissionDenied = false;
    _xpub = '';
    _fingerprint = '';
    _deviceLabel = '';
    TrezorDevice.lastConnected = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    if (_step != TrezorConnectStep.paired) {
      TrezorDevice.cancel().catchError((_) {});
      if (_device != null) {
        _device!.disconnect().catchError((_) {});
      }
    }
    _device = null;
    super.dispose();
  }
}
