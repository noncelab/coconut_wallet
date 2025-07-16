import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/dust_constants.dart';
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
    if (walletType == WalletType.multiSignature && multisigConfig == null) {
      throw Exception('MultisigConfig is required for multisignature wallet');
    }

    final addressType = _getAddressType(walletType);

    return _selectOptimalUtxosCommon(
      utxoList: utxoList,
      paymentMap: paymentMap,
      feeRate: feeRate,
      addressType: addressType,
      multisigConfig: multisigConfig,
      isFeeSubtractedFromAmount: isFeeSubtractedFromAmount,
    );
  }

  static AddressType _getAddressType(WalletType walletType) {
    switch (walletType) {
      case WalletType.singleSignature:
        return AddressType.p2wpkh;
      case WalletType.multiSignature:
        return AddressType.p2wsh;
      default:
        throw Exception('Unsupported Wallet Type: $walletType');
    }
  }

  /// UtxoSelector에서 Utxo 선택하는 기준으로 정렬
  static List<UtxoState> sortUtxos(List<UtxoState> utxoList) {
    return utxoList..sort((a, b) => b.amount.compareTo(a.amount));
  }

  static List<UtxoState> _getUnspentUtxosSortedByAmountDesc(List<UtxoState> utxoList) {
    return sortUtxos(utxoList.where((u) => u.status == UtxoStatus.unspent).toList());
  }

  static _selectOptimalUtxosCommon({
    required List<UtxoState> utxoList,
    required Map<String, int> paymentMap,
    required double feeRate,
    required AddressType addressType,
    MultisigConfig? multisigConfig,
    bool isFeeSubtractedFromAmount = false,
  }) {
    List<UtxoState> unspentUtxos = _getUnspentUtxosSortedByAmountDesc(utxoList);
    int totalSendAmount = paymentMap.values.reduce((a, b) => a + b);
    List<UtxoState> selectedInputs = [];
    int totalInputAmount = 0;

    final VirtualByteInfo virtualByteInfo = _calculateVirtualBytes(
      addressType: addressType,
      numOutputs: paymentMap.length + 1, // change output 포함
      multisigConfig: multisigConfig,
    );

    double virtualByte = virtualByteInfo.baseVirtualByte;
    double addedVbytePerInput = virtualByteInfo.addedVBytePerInput;
    int estimatedFee = (virtualByte * feeRate).ceil();
    int dust = getDustThreshold(addressType);

    // UTXO 선택 로직
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

    // 보내는 금액에서 제외하는 경우, amount 충분한지 확인
    if (isFeeSubtractedFromAmount && paymentMap.entries.last.value - estimatedFee <= dust) {
      throw SendAmountTooLowException(
          message: 'Last output amount is too small to cover fee.', estimatedFee: estimatedFee);
    }

    return UtxoSelectionResult(selectedInputs, estimatedFee);
  }

  static int getDustThreshold(AddressType addressType) {
    if (addressType.isTaproot) {
      return DustThresholds.taproot;
    }

    final threshold = DustThresholds.thresholds[addressType];
    if (threshold == null) {
      throw Exception('Unsupported Address Type: $addressType');
    }
    return threshold;
  }

  static VirtualByteInfo _calculateVirtualBytes({
    required AddressType addressType,
    required int numOutputs,
    MultisigConfig? multisigConfig,
  }) {
    double baseVirtualByte, virtualByteWith1Input;

    if (addressType == AddressType.p2wpkh) {
      baseVirtualByte = WalletUtility.estimateVirtualByte(addressType, 0, numOutputs);
      virtualByteWith1Input = WalletUtility.estimateVirtualByte(addressType, 1, numOutputs);
    } else if (addressType == AddressType.p2wsh) {
      if (multisigConfig == null) {
        throw ArgumentError('MultisigConfig is required for P2WSH');
      }
      baseVirtualByte = WalletUtility.estimateVirtualByte(
        addressType,
        0,
        numOutputs,
        requiredSignature: multisigConfig.requiredSignature,
        totalSigner: multisigConfig.totalSigner,
      );
      virtualByteWith1Input = WalletUtility.estimateVirtualByte(
        addressType,
        1,
        numOutputs,
        requiredSignature: multisigConfig.requiredSignature,
        totalSigner: multisigConfig.totalSigner,
      );
    } else {
      throw ArgumentError('Unsupported AddressType: $addressType');
    }

    final addedVBytePerInput = virtualByteWith1Input - baseVirtualByte;
    return VirtualByteInfo(
      baseVirtualByte: baseVirtualByte,
      addedVBytePerInput: addedVBytePerInput,
    );
  }
}

class VirtualByteInfo {
  final double baseVirtualByte;
  final double addedVBytePerInput;

  const VirtualByteInfo({
    required this.baseVirtualByte,
    required this.addedVBytePerInput,
  });
}
