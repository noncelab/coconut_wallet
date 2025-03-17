import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/fee_bumping/fee_bumping_view_model.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

class CpfpViewModel extends FeeBumpingViewModel {
  double _newTxSize = 0; // 새 거래의 크기
  double _originalTxSize = 0; // 기존 거래의 크기
  int _originalFee = 0; // 기존 거래의 총 수수료
  double newTxFeeRate = 0; // 새 거래의 수수료율
  double totalRequiredFee = 0; // 새로운 총 수수료
  double newTxFee = 0; // 새 거래의 수수료
  int _recommendFeeRate = 0; // 추천 수수료

  Transaction? generateTx;
  CpfpViewModel(
    super._transaction,
    super._walletId,
    super._nodeProvider,
    super._sendInfoProvider,
    super._walletProvider,
    super._currentUtxo,
    super._addressRepository,
    super._utxoRepository,
  ) {
    Logger.log('CpfpViewModel created');
  }

  int? get recommendedFeeRate => getRecommendedFeeRate(); // 추천 수수료율 (보통 속도)

  int get recommendFeeRate =>
      _recommendFeeRate; // 추천 수수료 e.g) '추천 수수료: ${recommendFeeRate}sats/vb 이상

  double get newTxSize => _newTxSize;

  Future<String> generateUnsignedPsbt() async {
    // List<UtxoState> utxoPool = walletProvider.getUtxoList(walletId);
    String recipientAddress =
        walletProvider.getReceiveAddress(walletId).address;
    int satsPerVb = sendInfoProvider.feeRate!;
    WalletBase wallet = walletListItemBase.walletBase;

    debugPrint('''
========== CPFP Transaction Info ==========
- _newTxSize: $_newTxSize vB
- _originalFee: $_originalFee sats
- _originalTxSize: $_originalTxSize vB
- totalRequiredFee: $totalRequiredFee sats
- newTxFee: $newTxFee sats
- newTxFeeRate: $newTxFeeRate sats/vB
--------------------------------------------
- Input Addresses: 
  ${transaction.inputAddressList.map((e) => e.address).join('\n  ')}
--------------------------------------------
- Output Addresses: 
  ${transaction.outputAddressList.map((e) => e.address).join('\n  ')}
--------------------------------------------
- Transaction vSize: ${transaction.vSize} vB
============================================
''');
    generateTx = Transaction.forSweep(
        [currentUtxo!], recipientAddress, satsPerVb, wallet);
    debugPrint('''
========== Generated Transaction Info ==========
- transactionHash: ${generateTx!.transactionHash}
--------------------------------------------
- Inputs: 
  ${generateTx!.inputs.map((e) => e.toString())}
- totalInputAmount: ${generateTx!.totalInputAmount}
--------------------------------------------
- Outputs: 
  ${generateTx!.outputs.map((e) => e.toString())}
''');

    return Psbt.fromTransaction(generateTx!, walletListItemBase.walletBase)
        .serialize();
  }

  String getCpfpFeeInfo() {
    /* 기존 거래의 크기 (vB)	originalTxSize
    새 거래의 크기 (vB)	newTxSize
    추천 수수료율 (sat/vB)	recommendedFeeRate
    기존 거래의 총 수수료 (sat)	originalFee
    새로운 총 수수료 (sat)	totalRequiredFee
    새 거래의 수수료 (sat)	newTxFee
    새 거래의 수수료율 (sat/vB)	newTxFeeRate */
    String inequalitySign =
        newTxFeeRate % 1 == 0 ? "=" : "≈"; // 소수로 떨어지면 근사값 기호로 적용
    setRecommendFeeRate();

    return t.transaction_fee_bumping_screen.recommend_fee_info_cpfp
        .replaceAll("{newTxSize}", _formatNumber(_newTxSize.toDouble()))
        .replaceAll("{recommendedFeeRate}",
            _formatNumber((recommendedFeeRate ?? 0).toDouble()))
        .replaceAll(
            "{originalTxSize}", _formatNumber(_originalTxSize.toDouble()))
        .replaceAll("{originalFee}", _formatNumber(_originalFee.toDouble()))
        .replaceAll(
            "{totalRequiredFee}", _formatNumber(totalRequiredFee.toDouble()))
        .replaceAll("{newTxFee}", _formatNumber(newTxFee.toDouble()))
        .replaceAll("{newTxFeeRate}", _formatNumber(newTxFeeRate))
        .replaceAll("{inequalitySign}", inequalitySign);
  }

  @override
  void setRecommendFeeRate() {
    if (newTxFeeRate.isNaN || newTxFeeRate.isInfinite) {
      _recommendFeeRate = 0;
      return;
    }
    _recommendFeeRate = (newTxFeeRate % 1 == 0
            ? newTxFeeRate.toInt()
            : newTxFeeRate.ceil().toInt()) +
        1;
  }

  @override
  void initializeGenerateTx() {
    generateTx = Transaction.forSweep(
        [currentUtxo!],
        walletProvider.getReceiveAddress(walletId).address,
        feeInfos[1].satsPerVb!,
        walletListItemBase.walletBase);

    _newTxSize = generateTx?.getVirtualByte() ?? 0;
    _originalFee = transaction.fee!;
    // _originalTxSize = _originalFee / transaction.feeRate;
    _originalTxSize = transaction.vSize.toDouble();
    totalRequiredFee =
        (_originalTxSize + _newTxSize) * (recommendedFeeRate ?? 0);
    newTxFee = totalRequiredFee - _originalFee;

    newTxFeeRate = newTxFee / _newTxSize;
    setRecommendFeeRate();
  }

  @override
  void updateSendInfoProvider(int newTxFeeRate) {
    super.updateSendInfoProvider(newTxFeeRate);
    // bool isMaxMode = walletProvider.getWalletBalance(_walletId).confirmed ==
    //     UnitUtil.bitcoinToSatoshi(transaction.amount!.toDouble());
    sendInfoProvider
        .setAmount(transaction.amount!.toDouble()); // TODO CPFP 금액 설정
  }

  @override
  int getTotalEstimatedFee(int newFeeRate) {
    return (_newTxSize * newFeeRate).ceil();
  }

  String _formatNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }
}
