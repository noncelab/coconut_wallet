import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/fee_bumping/fee_bumping_view_model.dart';
import 'package:coconut_wallet/utils/logger.dart';

class CpfpViewModel extends FeeBumpingViewModel {
  double _newTxSize = 0; // 새 거래의 크기
  double _originalTxSize = 0; // 기존 거래의 크기
  int _originalFee = 0; // 기존 거래의 총 수수료
  double newTxFeeRate = 0; // 새 거래의 수수료율
  double totalRequiredFee = 0; // 새로운 총 수수료
  double newTxFee = 0; // 새 거래의 수수료

  int? get recommendedFeeRate => getRecommendedFeeRate(); // 추천 수수료율 (보통 속도)
  int get recommendFeeRate =>
      getRecommendFeeRate(); // 추천 수수료 e.g) '추천 수수료: ${recommendFeeRate}sats/vb 이상

  Transaction? generateTx;

  CpfpViewModel(
    super._transaction,
    super._walletId,
    super._nodeProvider,
    super._sendInfoProvider,
    super._walletProvider,
    super._currentUtxo,
  ) {
    Logger.log('CpfpViewModel created');
    addListener(_onFeeUpdated);
  }

  /// `feeInfos[1].satsPerVb` 값이 변경되면 실행됨
  void _onFeeUpdated() {
    if (feeInfos[1].satsPerVb != null) {
      Logger.log('현재 수수료(보통) 업데이트 됨 >> ${feeInfos[1].satsPerVb}');
      initializeGenerateTx();
    }
  }

  void initializeGenerateTx() {
//     List<String> myAddresses = walletProvider.getAllAddresses(walletId);

// // 기존 트랜잭션의 output 중 내 주소와 일치하는 output을 찾음
//     TransactionAddress? myOutputAddress =
//         transaction.outputAddressList.firstWhere(
//       (output) => myAddresses.contains(output.address),
//       orElse: () => null, // 만약 없으면 null 반환
//     );
    print('walletProvider.getUtxoList(walletId): ');
    generateTx = Transaction.forSweep(
        walletProvider.getUtxoList(walletId),
        walletProvider.getReceiveAddress(walletId).address,
        feeInfos[1].satsPerVb!,
        walletListItemBase.walletBase);

    _newTxSize = generateTx?.getVirtualByte() ?? 0;
    _originalFee = transaction.amount!;
    _originalTxSize = _originalFee / transaction.feeRate;
    totalRequiredFee =
        (_originalTxSize + _newTxSize) * (recommendedFeeRate ?? 0);
    newTxFee = totalRequiredFee - _originalFee;

    newTxFeeRate = newTxFee / _newTxSize;
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

  int getRecommendFeeRate() {
    if (newTxFeeRate.isNaN || newTxFeeRate.isInfinite) {
      return 0;
    }
    return newTxFeeRate % 1 == 0
        ? newTxFeeRate.toInt()
        : newTxFeeRate.ceil().toInt();
  }

  String _formatNumber(double value) {
    return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
  }

  Future<String> generateUnsignedPsbt() async {
    List<UtxoState> utxoPool = walletProvider.getUtxoList(walletId);
    String recipientAddress =
        walletProvider.getReceiveAddress(walletId).address;
    int satsPerVb = sendInfoProvider.feeRate!;
    WalletBase wallet = walletListItemBase.walletBase;

    generateTx =
        Transaction.forSweep(utxoPool, recipientAddress, satsPerVb, wallet);

    return Psbt.fromTransaction(generateTx!, walletListItemBase.walletBase)
        .serialize();
  }
}
