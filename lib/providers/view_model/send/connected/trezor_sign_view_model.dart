import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/prev_tx_fetcher.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_exceptions.dart';
import 'package:flutter/foundation.dart';

enum TrezorSignStep { idle, signing, pairing, done, error }

enum TrezorSignSubStatus { waiting, connectingDevice, confirmOnDevice }

class TrezorSignViewModel extends ChangeNotifier {
  static const Duration _signTimeout = Duration(seconds: 120);

  TrezorSignStep _step = TrezorSignStep.idle;
  TrezorSignSubStatus _subStatus = TrezorSignSubStatus.waiting;
  String? _errorMessage;
  TrezorDevice? _device;
  String _signedPsbt = '';
  bool _isSigning = false;
  String? _fingerprint;
  Timer? _timeoutTimer;
  Completer<String>? _pairingCodeCompleter;
  bool _isPairingCodeWrong = false;
  bool _disposed = false;

  final String psbtBase64;
  final String walletName;
  final String walletFingerprint;
  final WalletProvider _walletProvider;

  String? _matchedWalletName;
  bool _isWalletMismatch = false;
  String? _mismatchedWalletName;

  TrezorSignViewModel({
    required this.psbtBase64,
    required this.walletName,
    this.walletFingerprint = '',
    required WalletProvider walletProvider,
  }) : _walletProvider = walletProvider {
    _probeDeviceStatus();
  }

  TrezorSignStep get step => _step;
  TrezorSignSubStatus get subStatus => _subStatus;
  String? get errorMessage => _errorMessage;
  String get signedPsbt => _signedPsbt;
  bool get isSigning => _isSigning;
  String? get fingerprint => _fingerprint;
  bool get isPairingCodeWrong => _isPairingCodeWrong;
  String? get matchedWalletName => _matchedWalletName;
  bool get isWalletMismatch => _isWalletMismatch;
  String? get mismatchedWalletName => _mismatchedWalletName;

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

  void _probeDeviceStatus() {
    final last = TrezorDevice.lastConnected;
    if (last == null) return;
    _device = last;
    if (last.cachedFingerprint != null) _fingerprint = last.cachedFingerprint;
  }

  Future<void> probeWalletMismatch() async {
    if (_device == null) return;
    try {
      final nt = NetworkType.currentNetworkType;
      final isTestnet = nt.isTestnet;
      final keypath = isTestnet ? "m/84'/1'/0'" : "m/84'/0'/0'";
      final deviceXpub = await _device!.getXPub(keypath: keypath, network: nt.toString());

      final matchedName = _findMatchingTrezorWalletName(deviceXpub);
      if (matchedName == null) {
        _isWalletMismatch = true;
        _mismatchedWalletName = null;
      } else if (matchedName != walletName) {
        _isWalletMismatch = true;
        _mismatchedWalletName = matchedName;
      } else {
        _isWalletMismatch = false;
        _mismatchedWalletName = null;
      }
      if (!_disposed) notifyListeners();
    } catch (e) {
      _isWalletMismatch = false;
    }
  }

  String? _findMatchingTrezorWalletName(String xpub) {
    for (final wallet in _walletProvider.walletItemList) {
      if (wallet.walletImportSource != WalletImportSource.trezor) continue;
      if (wallet is! SinglesigWalletItem) continue;
      if (wallet.extendedPublicKey == xpub) {
        return wallet.name;
      }
    }
    return null;
  }

  Future<void> signTransaction() async {
    if (_isSigning) return;

    _isSigning = true;
    _errorMessage = null;
    _cancelTimeout();

    try {
      _setState(TrezorSignStep.signing, subStatus: TrezorSignSubStatus.connectingDevice);
      _startTimeout(const Duration(seconds: 30), 'Connection timed out');

      final nt = NetworkType.currentNetworkType;

      if (_device != null) {
        _cancelTimeout();
        _fingerprint = _device!.cachedFingerprint;
      } else {
        _device = null;
        TrezorDevice.lastConnected = null;

        TrezorDevice.onPairingCodeRequested = () async {
          _pairingCodeCompleter = Completer<String>();
          _setState(TrezorSignStep.pairing);
          _cancelTimeout();
          final code = await _pairingCodeCompleter!.future;
          _pairingCodeCompleter = null;
          _setState(TrezorSignStep.signing, subStatus: TrezorSignSubStatus.connectingDevice);
          _startTimeout(const Duration(seconds: 30), 'Connection timed out');
          return code;
        };

        _device = await TrezorDevice.connect();
        _fingerprint = await _device!.getFingerprint();
        _device!.cachedFingerprint = _fingerprint;

        final isTestnet = nt.isTestnet;
        final keypath = isTestnet ? "m/84'/1'/0'" : "m/84'/0'/0'";
        final deviceXpub = await _device!.getXPub(keypath: keypath, network: nt.toString());

        final matchedName = _findMatchingTrezorWalletName(deviceXpub);
        if (matchedName != null && matchedName != walletName) {
          _matchedWalletName = matchedName;
          throw TrezorSignException(
            'WALLET_MISMATCH',
            t.trezor_sign_screen.device_mismatch_other_wallet(wallet_name: matchedName),
          );
        }
        if (matchedName == null) {
          throw TrezorSignException('FINGERPRINT_MISMATCH', t.trezor_sign_screen.device_mismatch);
        }
      }

      final network = nt.toString();

      // Fetch and inject NonWitnessUtxo (previous transactions) for each input.
      // Trezor requires full previous transactions for ALL inputs to verify
      // input amounts and prevent fee attacks.
      await PrevTxFetcher.fetchAndInject(
        psbtBase64: psbtBase64,
        onPrevTxHex: (i, rawTxHex) => _device!.setPrevTxHex(i, rawTxHex),
      );

      _cancelTimeout();
      _setState(TrezorSignStep.signing, subStatus: TrezorSignSubStatus.confirmOnDevice);
      _startTimeout(_signTimeout, 'Signing timed out');

      _signedPsbt = await _device!.signTransaction(psbtBase64: psbtBase64, network: network);

      _cancelTimeout();
      _setState(TrezorSignStep.done);
    } on TrezorConnectException catch (e) {
      _cancelTimeout();
      _errorMessage = e.message;
      TrezorDevice.lastConnected = null;
      _setState(TrezorSignStep.error);
    } on TrezorSignException catch (e) {
      _cancelTimeout();
      _errorMessage = e.message;
      _setState(TrezorSignStep.error);
    } on TrezorPairingCodeWrongException catch (e) {
      _cancelTimeout();
      _errorMessage = e.message;
      _pairingCodeCompleter = null;
      _isPairingCodeWrong = true;
      _setState(TrezorSignStep.error);
    } on TrezorPairingException catch (e) {
      _cancelTimeout();
      _errorMessage = e.message;
      TrezorDevice.lastConnected = null;
      _setState(TrezorSignStep.error);
    } catch (e) {
      _cancelTimeout();
      _errorMessage = e.toString();
      TrezorDevice.lastConnected = null;
      _setState(TrezorSignStep.error);
    }

    _isSigning = false;
  }

  void _setState(TrezorSignStep step, {TrezorSignSubStatus subStatus = TrezorSignSubStatus.waiting}) {
    _step = step;
    _subStatus = subStatus;
    notifyListeners();
  }

  void _startTimeout(Duration duration, String message) {
    _cancelTimeout();
    _timeoutTimer = Timer(duration, () {
      if (!_isSigning) return;
      debugPrint('TREZOR_SIGN timeout: $message');
      _errorMessage = message;
      TrezorDevice.lastConnected = null;
      _setState(TrezorSignStep.error);
      _isSigning = false;
    });
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  void reset() {
    _cancelTimeout();
    _pairingCodeCompleter = null;
    _isPairingCodeWrong = false;
    _step = TrezorSignStep.idle;
    _subStatus = TrezorSignSubStatus.waiting;
    _errorMessage = null;
    _isSigning = false;
    _signedPsbt = '';
    _fingerprint = null;
    _matchedWalletName = null;
    _isWalletMismatch = false;
    _mismatchedWalletName = null;
    _probeDeviceStatus();
    notifyListeners();
  }

  Future<void> disconnect() async {
    _cancelTimeout();
    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
      _device = null;
    }
  }

  @override
  void dispose() {
    _cancelTimeout();
    _disposed = true;
    _device = null;
    super.dispose();
  }
}
