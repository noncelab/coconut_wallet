import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/providers/node_provider.dart';

abstract class FeeBumpingViewModel extends ChangeNotifier {
  final TransactionRecord _transaction;
  final NodeProvider _nodeProvider;
  final WalletProvider _walletProvider;
  final SendInfoProvider _sendInfoProvider;
  final int _walletId;
  final Utxo? _currentUtxo;

  final List<FeeInfoWithLevel> _feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];
  bool _isRecommendedFeesFetchSuccess =
      true; // 화면이 전환되는 시점에 순간적으로 수수료 조회 실패가 뜨는것 처럼 보이기 대문에 기본값을 true 설정
  bool _isLowerFeeError = false;

  TransactionRecord get transaction => _transaction;
  WalletProvider get walletProvider => _walletProvider;
  SendInfoProvider get sendInfoProvider => _sendInfoProvider;
  WalletListItemBase get walletListItemBase => _walletListItemBase;
  int get walletId => _walletId;
  List<FeeInfoWithLevel> get feeInfos => _feeInfos;

  bool get isRecommendedFeesFetchSuccess => _isRecommendedFeesFetchSuccess;
  bool get isLowerFeeError => _isLowerFeeError;

  late WalletListItemBase _walletListItemBase;

  FeeBumpingViewModel(
    this._transaction,
    this._walletId,
    this._nodeProvider,
    this._sendInfoProvider,
    this._walletProvider,
    this._currentUtxo,
  ) {
    _walletListItemBase = _walletProvider.getWalletById(_walletId);
    _sendInfoProvider.setWalletId(_walletId);
    _setRecommendedFees(); // 현재 수수료 계산
  }

  void updateProvider() {
    notifyListeners();
  }

  void setLowerFeeError(bool value) {
    _isLowerFeeError = value;
    notifyListeners();
  }

  int? getRecommendedFeeRate() {
    return _feeInfos[1].satsPerVb;
  }

  Future<void> _setRecommendedFees() async {
    final recommendedFeesResult = await _nodeProvider.getRecommendedFees();
    if (recommendedFeesResult.isFailure) {
      _isRecommendedFeesFetchSuccess = false;
      notifyListeners();
      return;
    }

    final recommendedFees = recommendedFeesResult.value;

    _feeInfos[0].satsPerVb = recommendedFees.fastestFee;
    _feeInfos[1].satsPerVb = recommendedFees.halfHourFee;
    _feeInfos[2].satsPerVb = recommendedFees.hourFee;
    _isRecommendedFeesFetchSuccess = true;
    notifyListeners();
  }

  void setTxWaitingForSign(String transaction) {
    _sendInfoProvider.setTxWaitingForSign(transaction);
  }

  void updateSendInfoProvider(int newTxFeeRate) {
    bool isMultisig =
        walletListItemBase.walletType == WalletType.multiSignature;
    bool isMaxMode = walletProvider.getWalletBalance(_walletId).confirmed ==
        UnitUtil.bitcoinToSatoshi(transaction.amount!.toDouble());
    debugPrint('isMaxMode : $isMaxMode');
    debugPrint('transaction.amount : ${transaction.amount!.toDouble()}');
    debugPrint('newTxFeeRate : $newTxFeeRate');
    debugPrint('sendInfoProvider feeRate : ${sendInfoProvider.feeRate}');
    debugPrint(
        'sendInfoProvider estimatedFee : ${sendInfoProvider.estimatedFee}');
    debugPrint('sendInfoProvider isMultisig : ${sendInfoProvider.isMultisig}');

    _sendInfoProvider.setFeeRate(newTxFeeRate);
    _sendInfoProvider.setAmount(transaction.amount!.toDouble());
    _sendInfoProvider.setIsMaxMode(isMaxMode);
    _sendInfoProvider.setIsMultisig(isMultisig);
  }
}
