import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/electrum_enums.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_exceptions.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_transport.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_types.dart';
import 'package:flutter/foundation.dart';

enum BitBox02SignStep { idle, connecting, signing, done, error }

enum BitBox02DeviceStatus { disconnected, locked, ready }

class BitBox02SignViewModel extends ChangeNotifier {
  static const Duration _connectTimeout = Duration(seconds: 30);
  static const Duration _signTimeout = Duration(seconds: 120);

  BitBox02SignStep _step = BitBox02SignStep.idle;
  BitBox02DeviceStatus _deviceStatus = BitBox02DeviceStatus.disconnected;
  String _statusMessage = 'Ready to sign';
  String? _errorMessage;
  bool _mockMode = false;
  BitBox02Device? _device;
  String _signedPsbt = '';
  bool _isSigning = false;
  String? _fingerprint;
  Timer? _timeoutTimer;

  final String psbtBase64;
  final String walletName;
  final String transport;

  BitBox02SignViewModel({
    required this.psbtBase64,
    required this.walletName,
    this.transport = 'usb',
    bool mockMode = false,
  }) {
    _mockMode = mockMode;
    _probeDeviceStatus();
  }

  BitBox02SignStep get step => _step;
  BitBox02DeviceStatus get deviceStatus => _deviceStatus;
  String get statusMessage => _statusMessage;
  String? get errorMessage => _errorMessage;
  bool get mockMode => _mockMode;
  String get signedPsbt => _signedPsbt;
  bool get isSigning => _isSigning;
  String? get fingerprint => _fingerprint;

  void setMockMode(bool value) {
    _mockMode = value;
    notifyListeners();
  }

  void _probeDeviceStatus() {
    if (BitBox02Device.lastConnected != null) {
      _deviceStatus = BitBox02DeviceStatus.locked;
      _device = BitBox02Device.lastConnected;
      final fp = _device!.cachedFingerprint;
      if (fp != null) {
        _fingerprint = fp;
      }
    } else {
      _deviceStatus = BitBox02DeviceStatus.disconnected;
    }
  }

  Future<void> signTransaction({BitBox02Device? existingDevice}) async {
    if (_isSigning) return;

    _isSigning = true;
    _errorMessage = null;
    _cancelTimeout();

    if (_mockMode) {
      await _signMock();
      _isSigning = false;
      return;
    }

    try {
      _setState(BitBox02SignStep.connecting, status: 'Connecting to BitBox02...');
      _startTimeout(_connectTimeout, 'Connection timed out');

      await BitBox02Device.setLoggerEnabled(true);

      if (existingDevice != null) {
        _device = existingDevice;
      } else {
        _device = await BitBox02Device.connect(transport: BitBox02Transport.resolve(preferred: transport));

        _setState(BitBox02SignStep.connecting, status: 'Check your BitBox02 — enter PIN to unlock if prompted');

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
        } catch (e) {
          _fingerprint = null;
          debugPrint('BB02_SIGN rootFingerprint FAILED: $e');
        }

        _setState(BitBox02SignStep.connecting, status: 'Device ready — preparing transaction data...');
        _deviceStatus = BitBox02DeviceStatus.ready;
      }

      final nt = NetworkType.currentNetworkType;
      final coin = nt.isTestnet ? BitBox02Coin.tbtc : BitBox02Coin.btc;

      // Fetch and inject NonWitnessUtxo (previous transactions) for each input.
      // BitBox02 requires full previous transactions for non-Taproot inputs.
      try {
        final psbtParsed = Psbt.parse(psbtBase64);
        final unsignedTx = psbtParsed.unsignedTransaction;
        if (unsignedTx != null && unsignedTx.inputs.isNotEmpty) {
          final prefs = SharedPrefsRepository();
          final serverName = prefs.getString(SharedPrefKeys.kElectrumServerName);
          final customHost = prefs.getString(SharedPrefKeys.kCustomElectrumHost);
          final customPort = prefs.getInt(SharedPrefKeys.kCustomElectrumPort);
          final customSsl = prefs.getBool(SharedPrefKeys.kCustomElectrumIsSsl);

          String electrumHost;
          int electrumPort;
          bool electrumSsl;

          if (serverName == 'CUSTOM') {
            electrumHost = customHost;
            electrumPort = customPort;
            electrumSsl = customSsl;
          } else if (serverName.isNotEmpty) {
            final defServer = DefaultElectrumServer.fromServerType(serverName);
            electrumHost = defServer.server.host;
            electrumPort = defServer.server.port;
            electrumSsl = defServer.server.ssl;
          } else {
            final net = NetworkType.currentNetworkType;
            final defServer =
                net == NetworkType.mainnet ? DefaultElectrumServer.coconut : DefaultElectrumServer.regtest;
            electrumHost = defServer.server.host;
            electrumPort = defServer.server.port;
            electrumSsl = defServer.server.ssl;
          }

          debugPrint('BB02_SIGN electrum: $electrumHost:$electrumPort ssl=$electrumSsl');

          final electrum = ElectrumService();
          try {
            final connected = await electrum.connect(electrumHost, electrumPort, ssl: electrumSsl);
            if (!connected) {
              debugPrint('BB02_SIGN electrum connect failed');
            } else {
              for (int i = 0; i < unsignedTx.inputs.length; i++) {
                final txid = unsignedTx.inputs[i].transactionHash;
                debugPrint('BB02_SIGN fetching prevtx[$i]: $txid');
                try {
                  final rawTxHex = await electrum.getTransaction(txid);
                  await _device!.setPrevTxHex(i, rawTxHex);
                  debugPrint('BB02_SIGN prevtx[$i] loaded (${rawTxHex.length} chars)');
                } catch (e) {
                  debugPrint('BB02_SIGN prevtx[$i] fetch failed: $e');
                }
              }
            }
          } finally {
            electrum.close();
          }
        }
      } catch (e) {
        debugPrint('BB02_SIGN prevtx injection failed: $e');
      }

      _cancelTimeout();
      _setState(BitBox02SignStep.signing, status: 'Check amount, address, and fee on the device screen');
      _startTimeout(_signTimeout, 'Signing timed out');

      final psbtBytes = base64Decode(psbtBase64);
      final cleanPsbt = _cleanPsbt(psbtBytes);
      debugPrint(
        'BB02_SIGN clean hex (first 120): ${cleanPsbt.sublist(0, cleanPsbt.length < 120 ? cleanPsbt.length : 120).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}',
      );
      debugPrint('BB02_SIGN coin: ${coin.name} (${coin.value})');

      final signed = await _device!.btcSignPSBT(psbtBytes: cleanPsbt, coin: coin);
      _signedPsbt = base64Encode(signed);

      _cancelTimeout();
      _setState(BitBox02SignStep.done, status: 'Transaction signed');
    } on BitBox02ConnectException catch (e) {
      _cancelTimeout();
      _errorMessage = e.message;
      _setState(BitBox02SignStep.error, status: 'Connection failed');
    } on BitBox02SignException catch (e) {
      _cancelTimeout();
      _errorMessage = e.message;
      _setState(BitBox02SignStep.error, status: 'Signing failed');
    } on BitBox02InitException catch (e) {
      _cancelTimeout();
      _errorMessage = e.message;
      _setState(BitBox02SignStep.error, status: 'Initialization failed');
    } catch (e) {
      _cancelTimeout();
      _errorMessage = e.toString();
      _setState(BitBox02SignStep.error, status: 'Unexpected error');
    }

    _isSigning = false;
  }

  Future<void> _signMock() async {
    _setState(BitBox02SignStep.connecting, status: 'Connecting to BitBox02 (mock)...');
    await Future.delayed(const Duration(seconds: 1));

    _setState(
      BitBox02SignStep.signing,
      status: 'Please verify the transaction on your BitBox02...\nCheck amount, address, and fee on the device screen.',
    );
    await Future.delayed(const Duration(seconds: 3));

    _signedPsbt = base64Encode(utf8.encode('signed_transaction_mock'));
    _setState(BitBox02SignStep.done, status: 'Transaction signed (mock)');
  }

  void _setState(BitBox02SignStep step, {required String status}) {
    _step = step;
    _statusMessage = status;
    notifyListeners();
  }

  void _startTimeout(Duration duration, String message) {
    _cancelTimeout();
    _timeoutTimer = Timer(duration, () {
      if (!_isSigning) return;
      debugPrint('BB02_SIGN timeout: $message');
      _errorMessage = message;
      _setState(BitBox02SignStep.error, status: message);
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
    _statusMessage = 'Ready to sign';
    _errorMessage = null;
    _isSigning = false;
    _signedPsbt = '';
    _fingerprint = null;
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
