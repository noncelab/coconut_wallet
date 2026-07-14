import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_exceptions.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/third_party_util.dart';
import 'package:flutter/foundation.dart';

enum TrezorConnectStep { idle, connecting, pairing, paired, error }

class TrezorConnectViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;

  TrezorConnectViewModel(this._walletProvider);

  TrezorConnectStep _step = TrezorConnectStep.idle;
  String _statusMessage = '';
  TrezorDevice? _device;
  String? _errorMessage;
  String _xpub = '';
  String _fingerprint = '';
  String _deviceLabel = '';
  bool _isConnecting = false;
  bool _disposed = false;

  Completer<String>? _pairingCodeCompleter;
  String? _pairingErrorMessage;

  String? get pairingErrorMessage => _pairingErrorMessage;

  // Called when pairing failed for other reasons.
  void Function()? onPairingFailed;

  TrezorConnectStep get step => _step;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  bool get isPaired => _step == TrezorConnectStep.paired;
  bool get isConnecting => _isConnecting;
  String get xpub => _xpub;
  String get fingerprint => _fingerprint;
  String get deviceLabel => _deviceLabel;

  void _setState(TrezorConnectStep step, {String? status}) {
    if (_disposed) return;
    _step = step;
    if (status != null) _statusMessage = status;
    notifyListeners();
  }

  Future<String> waitForPairingCode() async {
    _pairingErrorMessage = null;
    _pairingCodeCompleter = Completer<String>();
    _setState(TrezorConnectStep.pairing, status: 'Pairing...');
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
    _pairingErrorMessage = null;
    notifyListeners();

    try {
      TrezorDevice.onPairingCodeRequested = () async {
        return await waitForPairingCode();
      };
      _setState(TrezorConnectStep.connecting, status: 'Scanning...');
      _device = await TrezorDevice.connect();
      _deviceLabel = _device!.label;

      _setState(TrezorConnectStep.paired, status: 'Trezor connected');
      await _retrieveXPub(silent: true);
    } on TrezorPairingCodeWrongException catch (e) {
      _errorMessage = e.message;
      _pairingErrorMessage = e.message;
      _pairingCodeCompleter = null;
      _setState(TrezorConnectStep.error, status: 'Wrong pairing code');
    } on TrezorConnectException catch (e) {
      _errorMessage = e.message;
      onPairingFailed?.call();
      _setState(TrezorConnectStep.error, status: 'Connection failed');
    } on TrezorPairingException catch (e) {
      _errorMessage = e.message;
      onPairingFailed?.call();
      _setState(TrezorConnectStep.error, status: 'Pairing failed');
    } catch (e) {
      _errorMessage = e.toString();
      onPairingFailed?.call();
      _setState(TrezorConnectStep.error, status: 'Unexpected error');
    } finally {
      _isConnecting = false;
      notifyListeners();
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
        _setState(TrezorConnectStep.paired, status: 'XPub retrieved');
      } on Exception catch (e) {
        if (silent) {
          _errorMessage = e.toString();
          _setState(TrezorConnectStep.paired, status: 'Trezor connected');
        } else {
          _errorMessage = e.toString();
          _setState(TrezorConnectStep.error, status: 'XPub retrieval failed');
        }
      }
    } finally {
      _isRetrievingXPub = false;
      notifyListeners();
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
    _setState(TrezorConnectStep.idle, status: '');
  }

  void reset() {
    _step = TrezorConnectStep.idle;
    _statusMessage = '';
    _device = null;
    _errorMessage = null;
    _xpub = '';
    _fingerprint = '';
    _deviceLabel = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    TrezorDevice.cancel().catchError((_) {});
    if (_device != null) {
      _device!.disconnect().catchError((_) {});
      _device = null;
    }
    super.dispose();
  }
}
