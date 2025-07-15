import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/core/exceptions/transaction_creation/transaction_creation_exception.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_config.dart';

class UtxoSelectionResult {
  final List<UtxoState> selectedUtxos;
  final int estimatedFee;

  UtxoSelectionResult(this.selectedUtxos, this.estimatedFee);
}

class UtxoSelector {
  static UtxoSelectionResult selectOptimalUtxos(
      List<UtxoState> utxoList, Map<String, int> paymentMap, double feeRate, WalletType walletType,
      {MultisigConfig? multisigConfig, bool isFeeSubtractedFromAmount = false}) {
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

  /// UtxoSelector에서 Utxo 선택하는 기준으로 정렬
  static List<UtxoState> sortUtxos(List<UtxoState> utxoList) {
    return utxoList..sort((a, b) => b.amount.compareTo(a.amount));
  }

  static List<UtxoState> _getUnspentUtxosSortedByAmountDesc(List<UtxoState> utxoList) {
    return sortUtxos(utxoList.where((u) => u.status == UtxoStatus.unspent).toList());
  }

  static UtxoSelectionResult _selectOptimalUtxosOfP2wpkh(
      List<UtxoState> utxoList, Map<String, int> paymentMap, double feeRate,
      {bool isFeeSubtractedFromAmount = false}) {
    List<UtxoState> unspentUtxos = _getUnspentUtxosSortedByAmountDesc(utxoList);
    int totalSendAmount = paymentMap.values.reduce((a, b) => a + b);
    List<UtxoState> selectedInputs = [];
    int totalInputAmount = 0;
    double virtualByte = WalletUtility.estimateVirtualByte(
        AddressType.p2wpkh, 0, paymentMap.length + 1); // change output 있다고 가정
    double virtualByte2 =
        WalletUtility.estimateVirtualByte(AddressType.p2wpkh, 1, paymentMap.length + 1);
    double addedVbytePerInput = virtualByte2 - virtualByte;
    int estimatedFee = (virtualByte * feeRate).ceil();
    int dust = getDustThreshold(AddressType.p2wpkh);
    for (int i = 0; i < unspentUtxos.length; i++) {
      totalInputAmount += unspentUtxos[i].amount;
      selectedInputs.add(unspentUtxos[i]);
      estimatedFee = ((virtualByte + addedVbytePerInput * (i + 1)) * feeRate).ceil();
      if (!isFeeSubtractedFromAmount) {
        // TODO: 기존 로직과의 차이: dust보다 큰 값이 남는지 체크 안해보는 중. change Output이 없도록 트랜잭션을 만들 수가 있음
        if (totalInputAmount >= totalSendAmount + estimatedFee) {
          break;
        }
      } else {
        if (totalInputAmount >= totalSendAmount) {
          break;
        }
      }

      // 마지막 for loop인지 확인
      if (i == unspentUtxos.length - 1) {
        throw InsufficientBalanceException(estimatedFee: estimatedFee);
      }
    }

    if (isFeeSubtractedFromAmount && paymentMap.entries.last.value - estimatedFee <= dust) {
      throw SendAmountTooLowException(
          message: 'Last output amount is too small to cover fee.', estimatedFee: estimatedFee);
    }

    return UtxoSelectionResult(selectedInputs, estimatedFee);
  }

  static UtxoSelectionResult _selectOptimalUtxosOfP2wsh(List<UtxoState> utxoList,
      Map<String, int> paymentMap, double feeRate, MultisigConfig multisigConfig,
      {bool isFeeSubtractedFromAmount = false}) {
    List<UtxoState> unspentUtxos = _getUnspentUtxosSortedByAmountDesc(utxoList);
    int totalSendAmount = paymentMap.values.reduce((a, b) => a + b);
    List<UtxoState> selectedInputs = [];
    int totalInputAmount = 0;
    double virtualByte = WalletUtility.estimateVirtualByte(
        AddressType.p2wsh, 0, paymentMap.length + 1,
        requiredSignature: multisigConfig.requiredSignature,
        totalSigner: multisigConfig.totalSigner); // change output 있다고 가정
    double virtualByte2 = WalletUtility.estimateVirtualByte(
        AddressType.p2wsh, 1, paymentMap.length + 1,
        requiredSignature: multisigConfig.requiredSignature,
        totalSigner: multisigConfig.totalSigner);
    double addedVbytePerInput = virtualByte2 - virtualByte;
    int estimatedFee = (virtualByte * feeRate).ceil();
    int dust = getDustThreshold(AddressType.p2wsh);
    for (int i = 0; i < unspentUtxos.length; i++) {
      totalInputAmount += unspentUtxos[i].amount;
      selectedInputs.add(unspentUtxos[i]);
      estimatedFee = ((virtualByte + addedVbytePerInput * (i + 1)) * feeRate).ceil();
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
      if (i == unspentUtxos.length - 1) {
        throw InsufficientBalanceException(estimatedFee: estimatedFee);
      }
    }

    if (isFeeSubtractedFromAmount && paymentMap.entries.last.value - estimatedFee <= dust) {
      throw SendAmountTooLowException(message: 'Last output amount is too small to cover fee.');
    }

    return UtxoSelectionResult(selectedInputs, estimatedFee);
  }

  /// TODO: 값 static const로 변경
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
