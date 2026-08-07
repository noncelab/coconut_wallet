import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_exceptions.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_transport.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_types.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/third_party_util.dart';
import 'package:flutter/foundation.dart';

enum BitBox02ConnectStep { idle, pairing, paired, error }

class BitBox02ConnectViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;

  BitBox02ConnectViewModel(this._walletProvider);

  BitBox02ConnectStep _step = BitBox02ConnectStep.idle;
  String _pairingCode = '';
  BitBox02Device? _device;
  String? _errorMessage;
  String? _errorDescription;
  List<String>? _errorSteps;
  // bool _mockMode = false;
  String _xpub = '';
  String _fingerprint = '';
  String _transport = 'usb';
  bool _isConnecting = false;

  BitBox02ConnectStep get step => _step;
  String get pairingCode => _pairingCode;
  BitBox02Device? get device => _device;
  String? get errorMessage => _errorMessage;
  String? get errorDescription => _errorDescription;
  List<String>? get errorSteps => _errorSteps;
  bool get isPaired => _step == BitBox02ConnectStep.paired;
  bool get isConnecting => _isConnecting;
  // bool get mockMode => _mockMode;
  String get xpub => _xpub;
  String get fingerprint => _fingerprint;
  String get transport => _transport;
  String get deviceName => _device?.name ?? '';

  // void setMockMode(bool value) {
  //   _mockMode = value;
  //   notifyListeners();
  // }

  void _setState(BitBox02ConnectStep step) {
    _step = step;
    notifyListeners();
  }

  /// Populates this viewmodel from an already-connected [BitBox02Device.lastConnected]
  /// session and jumps straight to [BitBox02ConnectStep.paired], skipping the
  /// pairing flow entirely. Returns true if a resumable session was found.
  bool resumeFromExistingSession() {
    final device = BitBox02Device.lastConnected;
    final cachedXpub = device?.cachedXpub;
    if (device == null || cachedXpub == null || cachedXpub.isEmpty) return false;
    _device = device;
    _xpub = cachedXpub;
    _fingerprint = device.cachedFingerprint ?? '';
    _transport = device.transport;
    _setState(BitBox02ConnectStep.paired);
    return true;
  }

  Future<void> connect({required String transport, String configJson = '', String? host, int? port}) async {
    if (_isConnecting || _step == BitBox02ConnectStep.paired) return;

    // Disconnect any previously active session before starting a new one.
    if (BitBox02Device.lastConnected != null) {
      try {
        await BitBox02Device.lastConnected!.disconnect();
      } catch (_) {}
      BitBox02Device.lastConnected = null;
    }

    final resolvedTransport = BitBox02Transport.resolve(preferred: transport);

    _transport = resolvedTransport;
    _isConnecting = true;
    _errorDescription = null;
    _errorSteps = null;
    _errorMessage = null;
    _xpub = '';
    _fingerprint = '';
    _setState(BitBox02ConnectStep.pairing);

    try {
      _device = await BitBox02Device.connect(
        transport: resolvedTransport,
        configJson: configJson,
        host: host,
        port: port,
      );

      _setState(BitBox02ConnectStep.pairing);
      await _device!.init();
      await _device!.channelHashVerify(ok: true);

      _setState(BitBox02ConnectStep.paired);
      BitBox02Device.lastConnected = _device;
      await retrieveXPub(silent: true);
    } on BitBox02ConnectException catch (e) {
      _errorMessage = e.message;
      _setState(BitBox02ConnectStep.error);
    } on BitBox02InitException catch (e) {
      _errorMessage = e.message;
      // BLE connection succeeded but init failed — the BitBox02 BLE stack is
      // stale (auto-disconnected). Noise credentials are still valid.
      // Show "power cycle" guidance without clearing config.
      if (resolvedTransport == 'ble') {
        _errorDescription = t.wallet_connect_screen.guide_bitbox02.ble_init_retry.title;
        _errorMessage = t.wallet_connect_screen.guide_bitbox02.ble_init_retry.description;
        _errorSteps = [
          t.wallet_connect_screen.guide_bitbox02.ble_init_retry.step1,
          t.wallet_connect_screen.guide_bitbox02.init.ble_step2,
          t.wallet_connect_screen.guide_bitbox02.init.ble_step3(btn: t.wallet_connect_screen.guide_bitbox02.btn.retry),
        ];
      }
      _setState(BitBox02ConnectStep.error);
    } catch (e) {
      _errorMessage = e.toString();
      _setState(BitBox02ConnectStep.error);
    } finally {
      _isConnecting = false;
      notifyListeners();
    }
  }

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
        _device!.cachedXpub = xpub;
        _fingerprint = await _device!.rootFingerprint();
        _device!.cachedFingerprint = _fingerprint;
        _setState(BitBox02ConnectStep.paired);
      } on Exception catch (e) {
        debugPrint('BB02: retrieveXPub failed: $e');
        if (silent) {
          // Check if the device is still reachable. If btcXPub failed because
          // the device has no seed, deviceInitialized() will still succeed and
          // we stay in paired state. If the pairing was rejected on the device
          // (user pressed X), the device is gone — transition to error.
          try {
            await _device!.deviceInitialized();
            _setState(BitBox02ConnectStep.paired);
          } catch (_) {
            _errorMessage = e.toString();
            _setState(BitBox02ConnectStep.error);
          }
        } else {
          _errorMessage = e.toString();
          _setState(BitBox02ConnectStep.error);
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
    final existingNames = _walletProvider.walletItemList.map((e) => e.name).toList();
    final baseName = deviceName;
    final name =
        baseName.isEmpty
            ? getNextThirdPartyWalletName(WalletImportSource.bitbox02, existingNames)
            : _resolveNameWithBase(baseName, existingNames);
    final wallet = walletAddService.createExtendedPublicKeyWallet(
      _xpub,
      name,
      _fingerprint,
      walletImportSource: WalletImportSource.bitbox02,
    );
    return _walletProvider.syncFromThirdParty(wallet);
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

  Future<void> disconnect() async {
    if (_device != null) {
      try {
        await _device!.disconnect();
      } catch (_) {}
      _device = null;
    }
    BitBox02Device.lastConnected = null;
    _setState(BitBox02ConnectStep.idle);
  }

  void reset() {
    _step = BitBox02ConnectStep.idle;
    _pairingCode = '';
    _device = null;
    _errorMessage = null;
    _errorDescription = null;
    _errorSteps = null;
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
