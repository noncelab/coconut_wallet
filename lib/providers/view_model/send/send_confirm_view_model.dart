import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/extensions/double_extensions.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_ble_connectivity_service.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter/material.dart';

class SendConfirmViewModel extends ChangeNotifier {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;
  late WalletItemBase _walletListItemBase;
  Psbt? _unsignedPsbt;
  int? _totalUsedAmount;
  late final double _totalSendAmount;

  SendConfirmViewModel(this._sendInfoProvider, this._walletProvider) {
    _walletListItemBase = _walletProvider.getWalletById(_sendInfoProvider.walletId!);
    _setTotalSendAmount();
  }

  int? get estimatedFee => _unsignedPsbt?.fee;
  String get walletName => _walletListItemBase.name;
  String? get txWaitingForSign => _sendInfoProvider.txWaitingForSign;
  int? get totalUsedAmount => _totalUsedAmount;
  Transaction? get transaction => _sendInfoProvider.transaction;
  List<int> get externalOutputAmounts =>
      transaction?.outputs.where((output) => output.isChangeOutput != true).map((output) => output.amount).toList() ??
      [];
  List<int> get changeOutputAmounts =>
      transaction?.outputs.where((output) => output.isChangeOutput == true).map((output) => output.amount).toList() ??
      [];
  List<int?> get inputAmounts =>
      _unsignedPsbt?.inputs.map((input) => input.witnessUtxo?.amount).toList() ??
      List<int?>.filled(transaction?.inputs.length ?? 0, null);
  double? get totalSendAmount => _totalSendAmount; // BTC
  WalletImportSource get walletImportSource => _walletListItemBase.walletImportSource;

  String get walletFingerprint {
    final wallet = _walletListItemBase.walletBase;
    if (wallet is SingleSignatureWallet) return wallet.keyStore.masterFingerprint;
    return '';
  }

  bool get isSingleSigWallet => _walletListItemBase.walletType == WalletType.singleSignature;

  String? get walletExtendedPublicKey {
    final wallet = _walletListItemBase.walletBase;
    if (wallet is SingleSignatureWallet) return wallet.keyStore.extendedPublicKey.serialize();
    return null;
  }

  /// Returns the import source of a currently connected hardware device whose
  /// cached xpub matches the current wallet, or null if none is connected.
  Future<WalletImportSource?> findConnectedMatchingDevice() async {
    final xpub = walletExtendedPublicKey;
    if (xpub == null) return null;

    final trezorDevice = TrezorDevice.lastConnected;
    if (trezorDevice != null && trezorDevice.cachedXpub == xpub) {
      final connected = await TrezorBleConnectivityService.isDeviceConnected(trezorDevice.transport);
      if (connected) return WalletImportSource.trezor;
    }

    final bitboxDevice = BitBox02Device.lastConnected;
    if (bitboxDevice != null && bitboxDevice.cachedXpub == xpub) {
      final connected = await BitBox02Device.isConnected();
      if (connected) return WalletImportSource.bitbox02;
    }

    return null;
  }

  void _setTotalSendAmount() {
    final externalOutputAmountSum = externalOutputAmounts.fold<int>(0, (sum, amount) => sum + amount);
    _totalSendAmount = UnitUtil.convertSatoshiToBitcoin(externalOutputAmountSum).roundTo8Digits();
  }

  Future<void> setEstimatedFeeAndTotalUsedAmount() async {
    _unsignedPsbt = await _generateUnsignedPsbt();
    _totalUsedAmount = UnitUtil.convertBitcoinToSatoshi(_totalSendAmount) + _unsignedPsbt!.fee;
    notifyListeners();
  }

  /// coconut_lib이 PSBT 글로벌 맵에 붙이는 coconut 전용 proprietary 필드(BIP-174 0xfc)의 키
  static const String _coconutProprietaryGlobalKey = 'fc07636f636f6e757401';

  Future<Psbt> _generateUnsignedPsbt() async {
    assert(_sendInfoProvider.transaction != null);
    final psbt = Psbt.fromTransaction(_sendInfoProvider.transaction!, _walletListItemBase.walletBase);
    // Passport Core의 PSBT 파서가 이 proprietary 필드를 unknown 필드로 간주해
    // PSBT 전체를 거부하는 문제(PSBT Invalid: unknown error) 회피.
    // Prime은 필드 유무와 무관하게 서명 가능하므로 Passport는 이 필드 없는 포맷으로 통일
    if (walletImportSource == WalletImportSource.passport) {
      (psbt.psbtMap['global'] as Map).remove(_coconutProprietaryGlobalKey);
    }
    return psbt;
  }

  void setTxWaitingForSign() {
    assert(_unsignedPsbt != null);
    _sendInfoProvider.setTxWaitingForSign(_unsignedPsbt!.serialize());
  }
}
