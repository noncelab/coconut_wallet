import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/dust_constants.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/core/exceptions/transaction_creation/transaction_creation_exception.dart';
import 'package:coconut_wallet/model/taproot_script_path_config.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_config.dart';
import 'package:coconut_wallet/utils/logger.dart';

class UtxoSelectionResult {
  final List<UtxoState> selectedUtxos;
  final int estimatedFee;

  UtxoSelectionResult(this.selectedUtxos, this.estimatedFee);
}

class UtxoSelector {
  static UtxoSelectionResult selectOptimalUtxos(
    List<UtxoState> utxoList,
    Map<String, int> paymentMap,
    double feeRate,
    WalletType walletType, {
    MultisigConfig? multisigConfig,
    TaprootScriptPathConfig? taprootConfig,
    TaprootSpendType? taprootSpendType,
    bool isFeeSubtractedFromAmount = false,
  }) {
    if (walletType == WalletType.multiSignature && multisigConfig == null) {
      throw Exception('MultisigConfig is required for multisignature wallet');
    }
    if (walletType == WalletType.taproot && taprootSpendType == TaprootSpendType.scriptPath && taprootConfig == null) {
      throw Exception('TaprootConfig is required for taproot wallet when script path spending');
    }

    return _selectOptimalUtxosCommon(
      utxoList: utxoList,
      paymentMap: paymentMap,
      feeRate: feeRate,
      addressType: walletType.addressType,
      multisigConfig: multisigConfig,
      taprootConfig: taprootConfig,
      taprootSpendType: taprootSpendType,
      isFeeSubtractedFromAmount: isFeeSubtractedFromAmount,
    );
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
    TaprootScriptPathConfig? taprootConfig,
    TaprootSpendType? taprootSpendType,
    bool isFeeSubtractedFromAmount = false,
  }) {
    List<UtxoState> unspentUtxos = _getUnspentUtxosSortedByAmountDesc(utxoList);
    int totalSendAmount = paymentMap.values.reduce((a, b) => a + b);
    List<UtxoState> selectedInputs = [];
    int totalInputAmount = 0;

    final int totalOutputBytes = _computeTotalOutputBytes(paymentMap, addressType);

    final VirtualByteInfo virtualByteInfo = _calculateVirtualBytes(
      addressType: addressType,
      numOutputs: paymentMap.length + 1, // change output 포함
      totalOutputBytes: totalOutputBytes,
      multisigConfig: multisigConfig,
      taprootConfig: taprootConfig,
      taprootSpendType: taprootSpendType,
    );

    double virtualByte = virtualByteInfo.baseVirtualByte;
    double addedVbytePerInput = virtualByteInfo.addedVBytePerInput;
    int estimatedFee = (virtualByte * feeRate).ceil();
    //int dust = getDustThreshold(addressType); // '받는 주소' 기준의 dust threshold 고려는 추후 필요시 적용

    // UTXO 선택 로직
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

    // 보내는 금액에서 제외하는 경우, amount 충분한지 확인
    if (isFeeSubtractedFromAmount && paymentMap.entries.last.value - estimatedFee <= addressType.dustThreshold) {
      throw SendAmountTooLowException(
        message: 'Last output amount is too small to cover fee.',
        estimatedFee: estimatedFee,
      );
    }

    return UtxoSelectionResult(selectedInputs, estimatedFee);
  }

  static VirtualByteInfo _calculateVirtualBytes({
    required AddressType addressType,
    required int numOutputs,
    int? totalOutputBytes,
    MultisigConfig? multisigConfig,
    TaprootScriptPathConfig? taprootConfig,
    TaprootSpendType? taprootSpendType,
  }) {
    double baseVirtualByte, virtualByteWith1Input;

    if (addressType == AddressType.p2wpkh) {
      baseVirtualByte = WalletUtility.estimateVirtualByte(
        addressType,
        0,
        numOutputs,
        totalOutputBytes: totalOutputBytes,
      );
      virtualByteWith1Input = WalletUtility.estimateVirtualByte(
        addressType,
        1,
        numOutputs,
        totalOutputBytes: totalOutputBytes,
      );
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
        totalOutputBytes: totalOutputBytes,
      );
      virtualByteWith1Input = WalletUtility.estimateVirtualByte(
        addressType,
        1,
        numOutputs,
        requiredSignature: multisigConfig.requiredSignature,
        totalSigner: multisigConfig.totalSigner,
        totalOutputBytes: totalOutputBytes,
      );
    } else if (addressType == AddressType.p2tr) {
      if (taprootSpendType == null) {
        throw ArgumentError('TaprootSpendType is required for P2TR');
      }
      if (taprootSpendType == TaprootSpendType.scriptPath && taprootConfig == null) {
        throw ArgumentError('TaprootConfig is required for P2TR when script path sending');
      }

      final bool isScriptPath = taprootSpendType == TaprootSpendType.scriptPath;

      double estimateTaprootVirtualByte(int numberOfInputs) {
        return WalletUtility.estimateVirtualByte(
          addressType,
          numberOfInputs,
          numOutputs,
          isScriptPath: isScriptPath,
          requiredSignature: taprootConfig?.requiredSignature,
          leafCount: taprootConfig?.leafCount,
          tapScriptSize: taprootConfig?.tapScriptSize,
          totalOutputBytes: totalOutputBytes,
        );
      }

      baseVirtualByte = estimateTaprootVirtualByte(0);
      virtualByteWith1Input = estimateTaprootVirtualByte(1);
    } else {
      throw ArgumentError('Unsupported AddressType: $addressType');
    }

    final addedVBytePerInput = virtualByteWith1Input - baseVirtualByte;
    return VirtualByteInfo(baseVirtualByte: baseVirtualByte, addedVBytePerInput: addedVBytePerInput);
  }

  static int _computeTotalOutputBytes(Map<String, int> paymentMap, AddressType changeAddressType) {
    int total = paymentMap.keys.fold(0, (sum, address) {
      return sum + TransactionOutput.forPayment(0, address).length;
    });
    Logger.log('--> totalOutputBytes of PaymentMap: $total');
    total += _changeOutputNonWitnessBytes(changeAddressType);
    return total;
  }

  static int _changeOutputNonWitnessBytes(AddressType type) {
    if (type == AddressType.p2wpkh) return 31;
    if (type == AddressType.p2wsh || type == AddressType.p2tr) return 43;
    return 34;
  }
}

class VirtualByteInfo {
  final double baseVirtualByte;
  final double addedVBytePerInput;

  const VirtualByteInfo({required this.baseVirtualByte, required this.addedVBytePerInput});
}
