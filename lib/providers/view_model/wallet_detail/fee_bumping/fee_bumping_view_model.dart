import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

enum TransactionType {
  forSweep,
  forSinglePayment,
  forBatchPayment,
}

abstract class FeeBumpingViewModel extends ChangeNotifier {
  final TransactionRecord _transaction;
  final NodeProvider _nodeProvider;
  final WalletProvider _walletProvider;
  final SendInfoProvider _sendInfoProvider;
  final AddressRepository _addressRepository;
  final int _walletId;
  final Utxo? _currentUtxo;

  final List<FeeInfoWithLevel> _feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];
  bool _isRecommendedFeesFetchSuccess =
      true; // 화면이 전환되는 시점에 순간적으로 수수료 조회 실패가 뜨는것 처럼 보이기 때문에 기본값을 true 설정
  bool _isLowerFeeError = false;

  late WalletListItemBase _walletListItemBase;
  FeeBumpingViewModel(
    this._transaction,
    this._walletId,
    this._nodeProvider,
    this._sendInfoProvider,
    this._walletProvider,
    this._currentUtxo,
    this._addressRepository,
  ) {
    _walletListItemBase = _walletProvider.getWalletById(_walletId);
    _sendInfoProvider.setWalletId(_walletId);
    _setRecommendedFees(); // 현재 수수료 계산
  }
  Utxo? get currentUtxo => _currentUtxo;
  List<FeeInfoWithLevel> get feeInfos => _feeInfos;
  bool get isLowerFeeError => _isLowerFeeError;
  bool get isRecommendedFeesFetchSuccess => _isRecommendedFeesFetchSuccess;
  SendInfoProvider get sendInfoProvider => _sendInfoProvider;

  TransactionRecord get transaction => _transaction;
  int get walletId => _walletId;

  WalletListItemBase get walletListItemBase => _walletListItemBase;

  WalletProvider get walletProvider => _walletProvider;

  AddressRepository get addressRepository => _addressRepository;

  int? getRecommendedFeeRate() {
    return _feeInfos[1].satsPerVb;
  }

  void setLowerFeeError(bool value) {
    _isLowerFeeError = value;
    notifyListeners();
  }

  void setTxWaitingForSign(String transaction) {
    _sendInfoProvider.setTxWaitingForSign(transaction);
  }

  void updateProvider() {
    _onFeeUpdated();
    notifyListeners();
  }

  void _onFeeUpdated() {
    if (feeInfos[1].satsPerVb != null) {
      Logger.log('현재 수수료(보통) 업데이트 됨 >> ${feeInfos[1].satsPerVb}');
      initializeGenerateTx();
    } else {
      setRecommendFeeRate();
    }
  }

  // abstract 메서드
  void initializeGenerateTx();
  void getTotalEstimatedFee(int newFeeRate);
  void setRecommendFeeRate();

  void updateSendInfoProvider(int newTxFeeRate) {
    bool isMultisig =
        walletListItemBase.walletType == WalletType.multiSignature;
    sendInfoProvider.setFeeRate(newTxFeeRate);
    sendInfoProvider.setIsMultisig(isMultisig);
    sendInfoProvider.setIsMaxMode(false);
  }

  TransactionType? getTransactionType() {
    int inputCount = transaction.inputAddressList.length;
    int outputCount = transaction.outputAddressList.length;

    if (inputCount >= 1 && outputCount == 1) {
      return TransactionType.forSweep; // 여러 개의 UTXO를 하나의 주소로 보내는 경우
    } else if (inputCount >= 1 && outputCount == 2) {
      return TransactionType.forSinglePayment; // 하나의 수신자 + 잔돈 주소
    } else if (inputCount >= 1 && outputCount > 2) {
      return TransactionType.forBatchPayment; // 여러 개의 수신자가 있는 경우
    }

    return null;
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
    initializeGenerateTx();

    notifyListeners();
  }
}
