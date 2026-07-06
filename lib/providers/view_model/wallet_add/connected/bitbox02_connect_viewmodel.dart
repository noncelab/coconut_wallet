import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_exceptions.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_transport.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_types.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/third_party_util.dart';
import 'package:flutter/foundation.dart';

enum BitBox02ConnectStep { idle, scanning, pairing, paired, error }

class BitBox02ConnectViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;

  BitBox02ConnectViewModel(this._walletProvider);

  BitBox02ConnectStep _step = BitBox02ConnectStep.idle;
  String _statusMessage = '';
  String _pairingCode = '';
  BitBox02Device? _device;
  String? _errorMessage;
  // bool _mockMode = false;
  String _xpub = '';
  String _fingerprint = '';
  String _transport = 'usb';

  BitBox02ConnectStep get step => _step;
  String get statusMessage => _statusMessage;
  String get pairingCode => _pairingCode;
  BitBox02Device? get device => _device;
  String? get errorMessage => _errorMessage;
  bool get isPaired => _step == BitBox02ConnectStep.paired;
  // bool get mockMode => _mockMode;
  String get xpub => _xpub;
  String get fingerprint => _fingerprint;
  String get transport => _transport;

  // void setMockMode(bool value) {
  //   _mockMode = value;
  //   notifyListeners();
  // }

  void _setState(BitBox02ConnectStep step, {String? status}) {
    _step = step;
    if (status != null) _statusMessage = status;
    notifyListeners();
  }

  Future<void> connect({required String transport, String configJson = '', String? host, int? port}) async {
    if (_step == BitBox02ConnectStep.pairing) {
      return; // Already in progress
    }
    if (_step == BitBox02ConnectStep.paired) {
      return; // Already connected
    }

    final resolvedTransport = BitBox02Transport.resolve(preferred: transport);

    // if (_mockMode) {
    //   await _connectMock();
    //   return;
    // }

    _transport = resolvedTransport;

    try {
      _device = await BitBox02Device.connect(
        transport: resolvedTransport,
        configJson: configJson,
        host: host,
        port: port,
      );

      if (configJson.isNotEmpty) {
        await _device!.loadConfig(configJson);
      }

      _setState(BitBox02ConnectStep.pairing, status: 'Initializing...');
      await _device!.init();
      await _device!.channelHashVerify(ok: true);

      _setState(BitBox02ConnectStep.paired, status: 'BitBox02 connected');
      BitBox02Device.lastConnected = _device;
      await retrieveXPub(silent: true);
    } on BitBox02ConnectException catch (e) {
      _errorMessage = e.message;
      _setState(BitBox02ConnectStep.error, status: 'Connection failed');
    } on BitBox02InitException catch (e) {
      _errorMessage = e.message;
      _setState(BitBox02ConnectStep.error, status: 'Initialization failed');
    } catch (e) {
      _errorMessage = e.toString();
      _setState(BitBox02ConnectStep.error, status: 'Unexpected error');
    }
  }

  Future<void> restoreWallet() async {
    if (_device == null || _step != BitBox02ConnectStep.paired) {
      _errorMessage = 'Device not paired. Connect first.';
      notifyListeners();
      return;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      await _device!.restoreFromMnemonic();
      _setState(BitBox02ConnectStep.paired, status: 'Wallet restored');
    } on Exception catch (e) {
      _errorMessage = e.toString();
      _setState(BitBox02ConnectStep.error, status: 'Restore failed');
    }
  }

  Future<void> createWallet({int seedLen = 32}) async {
    if (_device == null || _step != BitBox02ConnectStep.paired) {
      _errorMessage = 'Device not paired. Connect first.';
      notifyListeners();
      return;
    }

    _errorMessage = null;
    notifyListeners();

    try {
      await _device!.setPassword(seedLen: seedLen);
      _setState(BitBox02ConnectStep.paired, status: 'Wallet created');
    } on Exception catch (e) {
      _errorMessage = e.toString();
      _setState(BitBox02ConnectStep.error, status: 'Create failed');
    }
  }

  // Future<void> _connectMock() async {
  //   _errorMessage = null;
  //   _device = null;

  //   await Future.delayed(const Duration(seconds: 1));

  //   _setState(BitBox02ConnectStep.pairing, status: 'Initializing Noise handshake...');
  //   await Future.delayed(const Duration(seconds: 2));

  //   _setState(BitBox02ConnectStep.paired, status: 'BitBox02 paired (mock)');
  //   await retrieveXPub(silent: true);
  // }

  bool _isRetrievingXPub = false;

  /// [silent]이 true이면 실패 시 error 상태로 전환하지 않고 paired(xpub 없음) 상태로 되돌려,
  /// 시드가 없는 새 기기에서도 수동 Continue/시드 설정 버튼이 계속 보이도록 한다.
  Future<void> retrieveXPub({bool silent = false}) async {
    if (_isRetrievingXPub) return;
    _isRetrievingXPub = true;
    _errorMessage = null;

    try {
      // if (_mockMode) {
      //   await _retrieveXPubMock();
      //   return;
      // }

      final nt = NetworkType.currentNetworkType;
      final isTestnet = nt.isTestnet;
      final coin = isTestnet ? BitBox02Coin.tbtc : BitBox02Coin.btc;
      final xpubType = isTestnet ? BitBox02XPubType.vpub : BitBox02XPubType.zpub;
      final keypath = isTestnet ? "m/84'/1'/0'" : "m/84'/0'/0'";

      try {
        final xpub = await _device!.btcXPub(keypath: keypath, coin: coin, xpubType: xpubType, display: false);
        _xpub = xpub;
        _fingerprint = await _device!.rootFingerprint();
        _device!.cachedFingerprint = _fingerprint;
        _setState(BitBox02ConnectStep.paired, status: 'XPub retrieved');
      } on Exception catch (e) {
        if (silent) {
          _setState(BitBox02ConnectStep.paired, status: 'BitBox02 connected');
        } else {
          _errorMessage = e.toString();
          _setState(BitBox02ConnectStep.error, status: 'XPub retrieval failed');
        }
      }
    } finally {
      _isRetrievingXPub = false;
    }
  }

  // Future<void> _retrieveXPubMock() async {
  //   await Future.delayed(const Duration(seconds: 2));
  //   final isTestnet = NetworkType.currentNetworkType.isTestnet;
  //   if (isTestnet) {
  //     _xpub =
  //         'vpub5ZUp3fZ5qRUehB8c5Gmu2SuCQaD57jbostKFDExNdU55KQZEaXMpk7g32SDMGyJki7p7xjMdXaCeQmrvrsVTfntGu7Jd8WpsAdjDk357J7B';
  //     _fingerprint = '3c3204a6';
  //   } else {
  //     _xpub =
  //         'zpub6rFR7y4Q2AijBEmxxF2kQvKxGxUJhRbBuS4dELnv7bwG1eJgGAG8PkZvqMHZoVrWgDHniCwQ6NXRiSmcrhYjXaZ4RqFZNx5KDPZqpn2VVX8';
  //     _fingerprint = 'a1b2c3d4';
  //   }
  //   _setState(BitBox02ConnectStep.paired, status: 'XPub retrieved (mock)');
  // }

  Future<ResultOfSyncFromVault> addToWalletList() async {
    final walletAddService = WalletAddService();
    final name = getNextThirdPartyWalletName(
      WalletImportSource.bitbox02,
      _walletProvider.walletItemList.map((e) => e.name).toList(),
    );
    final wallet = walletAddService.createExtendedPublicKeyWallet(
      _xpub,
      name,
      _fingerprint,
      walletImportSource: WalletImportSource.bitbox02,
    );
    return _walletProvider.syncFromThirdParty(wallet);
  }

  Future<void> disconnect() async {
    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
      _device = null;
    }
    BitBox02Device.lastConnected = null;
    _setState(BitBox02ConnectStep.idle, status: '');
  }

  void reset() {
    _step = BitBox02ConnectStep.idle;
    _statusMessage = '';
    _pairingCode = '';
    _device = null;
    _errorMessage = null;
    _xpub = '';
    _fingerprint = '';
    BitBox02Device.lastConnected = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _device = null;
    super.dispose();
  }
}
