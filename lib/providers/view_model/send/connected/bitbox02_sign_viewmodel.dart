import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/prev_tx_fetcher.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_exceptions.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_connectivity_service.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_transport.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_types.dart';
import 'package:coconut_wallet/utils/transaction_intent_validator.dart';
import 'package:flutter/foundation.dart';

enum BitBox02SignStep { idle, signing, done, error }

enum BitBox02SignSubStatus { waiting, connectingDevice, checkPairing, preparingData, confirmOnDevice }

class BitBox02SignViewModel extends ChangeNotifier {
  static const Duration _connectTimeout = Duration(seconds: 30);
  static const Duration _signTimeout = Duration(seconds: 120);

  BitBox02SignStep _step = BitBox02SignStep.idle;
  BitBox02SignSubStatus _subStatus = BitBox02SignSubStatus.waiting;
  String? _errorMessage;
  BitBox02Device? _device;
  String _signedPsbt = '';
  bool _isSigning = false;
  String? _fingerprint;
  Timer? _timeoutTimer;

  final String psbtBase64;
  final String walletName;
  final String walletFingerprint;
  final String transport;
  final WalletProvider _walletProvider;

  String? _matchedWalletName;
  bool _isWalletMismatch = false;
  String? _mismatchedWalletName;

  BitBox02SignViewModel({
    required this.psbtBase64,
    required this.walletName,
    this.walletFingerprint = '',
    this.transport = 'usb',
    required WalletProvider walletProvider,
  }) : _walletProvider = walletProvider {
    _probeDeviceStatus();
  }

  BitBox02SignStep get step => _step;
  BitBox02SignSubStatus get subStatus => _subStatus;
  String? get errorMessage => _errorMessage;
  String get signedPsbt => _signedPsbt;
  bool get isSigning => _isSigning;
  String? get fingerprint => _fingerprint;
  bool get isWalletMismatch => _isWalletMismatch;
  String? get mismatchedWalletName => _mismatchedWalletName;
  String? get matchedWalletName => _matchedWalletName;

  void _probeDeviceStatus() {
    final last = BitBox02Device.lastConnected;
    if (last == null) return;
    _device = last;
    final fp = last.cachedFingerprint;
    if (fp != null) _fingerprint = fp;
  }

  /// Check if the connected device's fingerprint matches the target wallet.
  /// Called after the screen is built (like Trezor's probeWalletMismatch).
  Future<void> probeWalletMismatch() async {
    if (_device == null) return;
    final fp = _fingerprint;
    if (fp == null || fp.isEmpty) return;

    final matchedName = _walletProvider.findWalletNameByFingerprint(fp);
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
    _matchedWalletName = matchedName;
    notifyListeners();
  }

  Future<void> signTransaction({BitBox02Device? existingDevice}) async {
    if (_isSigning) return;

    _isSigning = true;
    _errorMessage = null;
    _cancelTimeout();

    try {
      _setState(BitBox02SignStep.signing, subStatus: BitBox02SignSubStatus.connectingDevice);
      _startTimeout(_connectTimeout, 'Connection timed out');

      await BitBox02Device.setLoggerEnabled(true);

      if (existingDevice != null) {
        _device = existingDevice;
      } else if (_device != null && await BitBox02ConnectivityService.isDeviceConnected()) {
        // Device is already paired and physically connected — skip re-pairing.
        _cancelTimeout();
        _fingerprint = _device!.cachedFingerprint;
        _setState(BitBox02SignStep.signing, subStatus: BitBox02SignSubStatus.preparingData);
      } else {
        _device = null;
        BitBox02Device.lastConnected = null;
        final resolvedTransport = BitBox02Transport.resolve(preferred: transport);
        _device = await BitBox02Device.connect(transport: resolvedTransport);

        _setState(BitBox02SignStep.signing, subStatus: BitBox02SignSubStatus.checkPairing);

        await _device!.init();
        await _device!.channelHashVerify(ok: true);

        final initialized = await _device!.deviceInitialized();
        debugPrint('BB02_SIGN device initialized: $initialized');

        if (!initialized) {
          debugPrint('BB02_SIGN restoring mnemonic...');
          await _device!.restoreFromMnemonic();
          debugPrint('BB02_SIGN restore done');
        }

        try {
          final fp = await _device!.rootFingerprint();
          _fingerprint = fp;
          _device!.cachedFingerprint = fp;
          debugPrint('BB02_SIGN rootFingerprint ok: $fp');
          if (walletFingerprint.isNotEmpty && fp.toLowerCase() != walletFingerprint.toLowerCase()) {
            throw BitBox02SignException('FINGERPRINT_MISMATCH', t.bitbox02_sign_screen.device_mismatch);
          }
        } catch (e) {
          if (e is BitBox02SignException) rethrow;
          _fingerprint = null;
          debugPrint('BB02_SIGN rootFingerprint FAILED: $e');
        }

        _setState(BitBox02SignStep.signing, subStatus: BitBox02SignSubStatus.preparingData);
      }

      final nt = NetworkType.currentNetworkType;
      final coin = nt.isTestnet ? BitBox02Coin.tbtc : BitBox02Coin.btc;

      // Fetch and inject NonWitnessUtxo (previous transactions) for each input.
      // BitBox02 requires full previous transactions for non-Taproot inputs.
      await PrevTxFetcher.fetchAndInject(
        psbtBase64: psbtBase64,
        onPrevTxHex: (i, rawTxHex) => _device!.setPrevTxHex(i, rawTxHex),
      );

      _cancelTimeout();
      _setState(BitBox02SignStep.signing, subStatus: BitBox02SignSubStatus.confirmOnDevice);
      _startTimeout(_signTimeout, 'Signing timed out');

      final psbtBytes = base64Decode(psbtBase64);
      final cleanPsbt = _cleanPsbt(psbtBytes);
      debugPrint(
        'BB02_SIGN clean hex (first 120): ${cleanPsbt.sublist(0, cleanPsbt.length < 120 ? cleanPsbt.length : 120).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
      );
      debugPrint('BB02_SIGN coin: ${coin.name} (${coin.value})');

      final signed = await _device!.btcSignPSBT(psbtBytes: cleanPsbt, coin: coin);
      _signedPsbt = base64Encode(signed);
      final unsignedPsbt = Psbt.parse(psbtBase64);
      final returnedPsbt = Psbt.parse(_signedPsbt);
      TransactionIntentValidator.ensureMatches(unsignedPsbt.unsignedTransaction, returnedPsbt.unsignedTransaction);

      _cancelTimeout();
      _setState(BitBox02SignStep.done);
    } on TransactionIntentMismatchException catch (e) {
      _cancelTimeout();
      _signedPsbt = '';
      _errorMessage = '${t.alert.signed_psbt.wrong_send_info}\n(${e.result.fieldPath})';
      _setState(BitBox02SignStep.error);
    } on BitBox02ConnectException catch (e) {
      _cancelTimeout();
      _errorMessage = e.message;
      BitBox02Device.lastConnected = null; // 연결 실패 → 기기가 분리된 것으로 간주
      _setState(BitBox02SignStep.error);
    } on BitBox02SignException catch (e) {
      _cancelTimeout();
      _errorMessage = e.message;
      _setState(BitBox02SignStep.error);
    } on BitBox02InitException catch (e) {
      _cancelTimeout();
      _errorMessage = e.message;
      BitBox02Device.lastConnected = null; // 초기화 실패 → 재연결 필요
      _setState(BitBox02SignStep.error);
    } catch (e) {
      _cancelTimeout();
      _errorMessage = e.toString();
      BitBox02Device.lastConnected = null;
      _setState(BitBox02SignStep.error);
    }

    _isSigning = false;
  }

  void _setState(BitBox02SignStep step, {BitBox02SignSubStatus subStatus = BitBox02SignSubStatus.waiting}) {
    _step = step;
    _subStatus = subStatus;
    notifyListeners();
  }

  void _startTimeout(Duration duration, String message) {
    _cancelTimeout();
    _timeoutTimer = Timer(duration, () {
      if (!_isSigning) return;
      debugPrint('BB02_SIGN timeout: $message');
      _errorMessage = message;
      BitBox02Device.lastConnected = null; // 타임아웃 → 기기가 응답하지 않음
      _setState(BitBox02SignStep.error);
      _isSigning = false;
    });
  }

  void _cancelTimeout() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  void reset() {
    _cancelTimeout();
    _step = BitBox02SignStep.idle;
    _subStatus = BitBox02SignSubStatus.waiting;
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

  Future<void> disconnectForReconnect() async {
    await disconnect();
    BitBox02Device.lastConnected = null;
    _isWalletMismatch = false;
    _mismatchedWalletName = null;
    _matchedWalletName = null;
    _fingerprint = null;
    _errorMessage = null;
    _setState(BitBox02SignStep.idle);
  }

  @override
  void dispose() {
    _cancelTimeout();
    _device = null;
    super.dispose();
  }
}

/// Strips proprietary 0xFC keypairs from PSBT global map so btcd parser accepts it.
Uint8List _cleanPsbt(Uint8List psbt) {
  if (psbt.length < 6 || psbt[0] != 0x70) return psbt;

  int pos = 5;
  final buf = BytesBuilder(copy: false);

  while (pos < psbt.length && psbt[pos] != 0x00) {
    final kpStart = pos;
    final keyLen = _csRead(psbt, pos);
    if (keyLen.$1 <= 0 || keyLen.$2 + keyLen.$1 > psbt.length) {
      debugPrint('BB02_CLEAN: bad keyLen at pos=$pos');
      return psbt;
    }
    final keyTypePos = keyLen.$2;
    final keyType = psbt[keyTypePos];
    pos = keyLen.$2 + keyLen.$1;

    final valLen = _csRead(psbt, pos);
    if (valLen.$2 + valLen.$1 > psbt.length) {
      debugPrint('BB02_CLEAN: bad valLen at pos=$pos');
      return psbt;
    }
    pos = valLen.$2 + valLen.$1;

    if (keyType != 0xfc) {
      buf.add(psbt.sublist(kpStart, pos));
    }
  }

  if (pos >= psbt.length || psbt[pos] != 0x00) {
    debugPrint('BB02_CLEAN: no separator at pos=$pos byte=${pos < psbt.length ? psbt[pos] : -1}');
    return psbt;
  }

  final result = Uint8List(5 + buf.length + (psbt.length - pos));
  result.setAll(0, psbt.sublist(0, 5));
  final kept = buf.takeBytes();
  result.setAll(5, kept);
  result.setAll(5 + kept.length, psbt.sublist(pos));
  return result;
}

(int, int) _csRead(Uint8List d, int p) {
  if (p >= d.length) return (0, p);
  final b = d[p];
  if (b < 0xfd) return (b, p + 1);
  if (b == 0xfd && p + 2 < d.length) return (d[p + 1] | (d[p + 2] << 8), p + 3);
  if (b == 0xfe && p + 4 < d.length) return (d[p + 1] | (d[p + 2] << 8) | (d[p + 3] << 16) | (d[p + 4] << 24), p + 5);
  return (0, p);
}
