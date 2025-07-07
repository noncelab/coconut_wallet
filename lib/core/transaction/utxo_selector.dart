import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/fee_estimator.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_config.dart';

class UtxoSelector {
  static List<UtxoState> selectOptimalUtxos(
      List<UtxoState> utxoList, Map<String, int> paymentMap, double feeRate, WalletType walletType,
      {MultisigConfig? multisigConfig,
      bool isFeeSubtractedFromAmount = false,
      bool isConsolidation = false}) {
    if (walletType == WalletType.singleSignature) {
      return _selectOptimalUtxosOfP2wpkh(utxoList, paymentMap, feeRate,
          isFeeSubtractedFromAmount: isFeeSubtractedFromAmount);
    } else if (walletType == WalletType.multiSignature) {
      if (multisigConfig == null) {
        throw Exception('MultisigConfig is required for multisignature wallet');
      }
      return _selectOptimalUtxosOfP2wsh(
        utxoList,
        paymentMap,
        feeRate,
        multisigConfig,
        isFeeSubtractedFromAmount: isFeeSubtractedFromAmount,
      );
    } else {
      throw Exception('Unsupported Wallet Type');
    }
  }

  static List<UtxoState> _getUnspentUtxosSortedByAmountDesc(List<UtxoState> utxoList) {
    return utxoList.where((u) => u.status == UtxoStatus.unspent).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  static List<UtxoState> _selectOptimalUtxosOfP2wpkh(
      List<UtxoState> utxoList, Map<String, int> paymentMap, double feeRate,
      {bool isFeeSubtractedFromAmount = false}) {
    List<UtxoState> unspentUtxos = _getUnspentUtxosSortedByAmountDesc(utxoList);
    int totalSendAmount = paymentMap.values.reduce((a, b) => a + b);
    List<UtxoState> selectedInputs = [];
    int totalInputAmount = 0;
    final feeEstimator = P2wpkhFeeEstimator(
        numInputs: 0, numOutputs: paymentMap.length + 1, feeRate: feeRate); // change output 있다고 가정
    int estimatedFee = feeEstimator.estimatedFee;
    int dust = getDustThreshold(AddressType.p2wpkh);
    for (UtxoState input in unspentUtxos) {
      totalInputAmount += input.amount;
      selectedInputs.add(input);
      feeEstimator.updateNumInputs(selectedInputs.length);
      estimatedFee = feeEstimator.estimatedFee;
      if (!isFeeSubtractedFromAmount) {
        // TODO: 기존 로직과의 차이: dust보다 큰 값이 남는지 체크 안해보는 중. change Output이 없도록 트랜잭션을 만들 수가 있음
        if (totalInputAmount > totalSendAmount + estimatedFee) {
          break;
        }
      } else {
        if (totalInputAmount >= totalSendAmount) {
          break;
        }
      }

      // 마지막 for loop인지 확인
      if (input == unspentUtxos.last) {
        throw Exception('Not enough amount for sending.');
      }
    }

    if (isFeeSubtractedFromAmount && paymentMap.entries.last.value - estimatedFee <= dust) {
      throw Exception('Last output amount is too small to cover fee.');
    }

    return selectedInputs;
  }

  static List<UtxoState> _selectOptimalUtxosOfP2wsh(List<UtxoState> utxoList,
      Map<String, int> paymentMap, double feeRate, MultisigConfig multisigConfig,
      {bool isFeeSubtractedFromAmount = false}) {
    List<UtxoState> unspentUtxos = _getUnspentUtxosSortedByAmountDesc(utxoList);
    int totalSendAmount = paymentMap.values.reduce((a, b) => a + b);
    List<UtxoState> selectedInputs = [];
    int totalInputAmount = 0;
    final feeEstimator = P2wshFeeEstimator(
        numInputs: 0,
        numOutputs: paymentMap.length + 1,
        feeRate: feeRate,
        threshold: multisigConfig.threshold,
        totalSignature: multisigConfig.totalSignature); // change output 있다고 가정
    int estimatedFee = feeEstimator.estimatedFee;
    int dust = getDustThreshold(AddressType.p2wsh);
    for (UtxoState input in unspentUtxos) {
      totalInputAmount += input.amount;
      selectedInputs.add(input);
      feeEstimator.updateNumInputs(selectedInputs.length);
      estimatedFee = feeEstimator.estimatedFee;
      if (!isFeeSubtractedFromAmount) {
        // TODO: 기존 로직과의 차이: dust보다 큰 값이 남는지 체크 안해보는 중. change Output이 없도록 트랜잭션을 만들 수가 있음
        if (totalInputAmount > totalSendAmount + estimatedFee) {
          break;
        }
      } else {
        if (totalInputAmount >= totalSendAmount) {
          break;
        }
      }

      // 마지막 for loop인지 확인
      if (input == unspentUtxos.last) {
        throw Exception('Not enough amount for sending.');
      }
    }

    if (isFeeSubtractedFromAmount && paymentMap.entries.last.value - estimatedFee <= dust) {
      throw Exception('Last output amount is too small to cover fee.');
    }

    return selectedInputs;
  }

  static int getDustThreshold(AddressType addressType) {
    if (addressType == AddressType.p2wpkh) {
      return 294;
    } else if (addressType == AddressType.p2wsh || addressType.isTaproot) {
      return 330;
    } else if (addressType == AddressType.p2pkh) {
      return 546;
    } else if (addressType == AddressType.p2sh) {
      return 888;
    } else if (addressType == AddressType.p2wpkhInP2sh) {
      return 273;
    } else {
      throw Exception('Unsupported Address Type');
    }
  }
}
