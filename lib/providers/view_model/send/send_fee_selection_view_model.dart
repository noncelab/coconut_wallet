import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/recommend_fee_service.dart';
import 'package:flutter/material.dart';

class SendFeeSelectionViewModel extends ChangeNotifier {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;
  late final WalletListItemBase _walletListItemBase;
  late int _confirmedBalance;
  late int _unconfirmedBalance;
  late int? _bitcoinPriceKrw;
  late bool _isMultisigWallet;
  late bool _isMaxMode;
  late int _walletId;
  late double _amount;
  late String _recipientAddress;
  late bool? _isNetworkOn;

  SendFeeSelectionViewModel(this._sendInfoProvider, this._walletProvider,
      this._bitcoinPriceKrw, this._isNetworkOn) {
    _walletListItemBase =
        _walletProvider.getWalletById(_sendInfoProvider.walletId!);
    _confirmedBalance = _walletListItemBase.walletFeature.getBalance();
    _unconfirmedBalance =
        _walletListItemBase.walletFeature.getUnconfirmedBalance();
    _isMultisigWallet =
        _walletListItemBase.walletType == WalletType.multiSignature;
    _bitcoinPriceKrw = _bitcoinPriceKrw;
    _walletId = _sendInfoProvider.walletId!;
    _amount = _sendInfoProvider.amount!;
    _isMaxMode = _confirmedBalance ==
        UnitUtil.bitcoinToSatoshi(_sendInfoProvider.amount!);
    _recipientAddress = _sendInfoProvider.receipientAddress!;
    _isNetworkOn = isNetworkOn;

    _updateSendInfoProvider(_isMultisigWallet, _isMaxMode);
    _isMaxMode = _confirmedBalance == UnitUtil.bitcoinToSatoshi(_amount);
  }

  double get amount => _amount;
  int? get bitcoinPriceKrw => _bitcoinPriceKrw;
  int get confirmedBalance => _confirmedBalance;
  bool get isMaxMode => _isMaxMode;
  bool get isMultisigWallet => _isMultisigWallet;
  bool get isNetworkOn => _isNetworkOn == true;
  String get recipientAddress => _recipientAddress;
  int get unconfirmedBalance => _unconfirmedBalance;
  int get walletId => _walletId;

  Future<int?> estimateFee(int satsPerVb) async {
    return await _walletListItemBase.walletFeature.estimateFee(
        _recipientAddress, UnitUtil.bitcoinToSatoshi(amount), satsPerVb);
  }

  Future<int?> estimateFeeWithMaximum(int satsPerVb) async {
    return await _walletListItemBase.walletFeature
        .estimateFeeWithMaximum(_recipientAddress, satsPerVb);
  }

  Future<RecommendedFee?> fetchRecommendedFees() async {
    try {
      RecommendedFee recommendedFee =
          await RecommendFeeService.getRecommendFee();

      /// 포우 월렛은 수수료를 너무 낮게 보내서 1시간 이상 트랜잭션이 펜딩되는 것을 막는 방향으로 구현하자고 결정되었습니다.
      /// 따라서 트랜잭션 전송 시점에, 네트워크 상 최소 수수료 값 미만으로는 수수료를 설정할 수 없게 해야 합니다.
      Result<int, CoconutError>? minimumFeeResult =
          await _walletProvider.getMinimumNetworkFeeRate();
      if (minimumFeeResult != null &&
          minimumFeeResult.isSuccess &&
          minimumFeeResult.value != null) {
        return RecommendedFee(
            recommendedFee.fastestFee,
            recommendedFee.halfHourFee,
            recommendedFee.hourFee,
            recommendedFee.economyFee,
            minimumFeeResult.value!);
      }

      //RecommendedFee recommendedFee = RecommendedFee(20, 19, 12, 3, 3);
      return recommendedFee;
    } catch (e) {
      return null;
    }
  }

  double getAmount(int estimatedFee) {
    return _isMaxMode
        ? UnitUtil.satoshiToBitcoin(_confirmedBalance - estimatedFee)
        : amount;
  }

  bool isBalanceEnough(int? estimatedFee) {
    if (estimatedFee == null || estimatedFee == 0) return false;
    if (_isMaxMode) return (confirmedBalance - estimatedFee) > dustLimit;

    return (UnitUtil.bitcoinToSatoshi(amount) + estimatedFee) <=
        confirmedBalance;
  }

  setAmount(double amount) {
    _sendInfoProvider.setAmount(amount);
  }

  void setBitcoinPriceKrw(int price) {
    _bitcoinPriceKrw = price;
    notifyListeners();
  }

  setEstimatedFee(int estimatedFee) {
    _sendInfoProvider.setEstimatedFee(estimatedFee);
  }

  setFeeRate(int feeRate) {
    _sendInfoProvider.setFeeRate(feeRate);
  }

  void setIsNetworkOn(bool? isNetworkOn) {
    _isNetworkOn = isNetworkOn;
    notifyListeners();
  }

  void _updateSendInfoProvider(bool isMultisig, bool isMaxMode) {
    _sendInfoProvider.setIsMultisig(_isMultisigWallet);
    _sendInfoProvider.setIsMaxMode(_isMaxMode);
  }
}
