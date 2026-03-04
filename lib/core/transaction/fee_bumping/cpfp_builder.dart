import 'dart:math';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/core/exceptions/cpfp_creation/cpfp_creation_exception.dart';
import 'package:coconut_wallet/core/exceptions/transaction_creation/transaction_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/cpfp_preparer.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/extensions/transaction_extension.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/utils/bitcoin/transaction_util.dart';
import 'package:coconut_wallet/utils/fee_rate_util.dart';
import 'package:coconut_wallet/utils/logger.dart';

class CpfpBuildResult {
  final Transaction? transaction;

  /// 패키지(부모+자식)가 relay 가능한 최소 child tx 수수료율
  final double minimumFeeRate;

  /// 실제 달성되는 패키지 수수료율: (parentFee + childFee) / (parentVSize + childVSize)
  final double packageFeeRate;

  final double estimatedVSize;
  final Exception? exception;
  final List<UtxoState>? addedUtxo;
  final int? deficitAmount;

  /// 부모 tx의 수수료율이 이미 최소 네트워크 수수료율을 충족하는 경우 false
  final bool isCpfpNeeded;

  bool get isSuccess => transaction != null;
  bool get isFailure => transaction == null;

  int? get estimatedFee {
    if (transaction == null) return null;
    final totalOutput = transaction!.outputs.fold<int>(0, (s, o) => s + o.amount);
    return transaction!.totalInputAmount - totalOutput;
  }

  CpfpBuildResult({
    required this.minimumFeeRate,
    required this.packageFeeRate,
    required this.estimatedVSize,
    this.isCpfpNeeded = true,
    this.transaction,
    this.exception,
    this.addedUtxo,
    this.deficitAmount,
  });
}

class CpfpBuilder {
  final WalletListItemBase walletListItemBase;

  /// child tx의 단일 output 주소 (sweep 대상)
  final WalletAddress nextReceiveAddress;
  final double mininumFeeRate;

  late final TransactionRecord _pendingTx;
  late final List<UtxoState> _receivedUtxos;
  late final int _vSizeIncreasePerInput;
  late List<UtxoState> _additionalSpendable;

  int get parentFee => _pendingTx.fee;
  double get parentVSize => _pendingTx.vSize;

  int get totalReceivedAmount => _receivedUtxos.fold<int>(0, (s, u) => s + u.amount);

  CpfpBuildResult? _cachedBaseline;
  List<UtxoState> _baselineInputs = [];

  CpfpBuilder({
    required CpfpPreparer preparer,
    required this.walletListItemBase,
    required this.nextReceiveAddress,
    required this.mininumFeeRate,
    List<UtxoState> additionalSpendable = const [],
  }) {
    _pendingTx = preparer.pendingTx;
    _receivedUtxos = [...preparer.receivedUtxos]..sort((a, b) => b.amount.compareTo(a.amount));
    if (walletListItemBase.walletType == WalletType.singleSignature) {
      _vSizeIncreasePerInput = 68;
    } else {
      final wallet = walletListItemBase as MultisigWalletListItem;
      _vSizeIncreasePerInput = p2wshMultisigInputVSize(m: wallet.requiredSignatureCount, n: wallet.signers.length);
    }
    _additionalSpendable = [...additionalSpendable]..sort((a, b) => b.amount.compareTo(a.amount));
  }

  TransactionBuildResult _trySweep(List<UtxoState> inputs, double feeRate) {
    final inputSum = inputs.fold(0, (cur, utxo) => cur + utxo.amount);
    return TransactionBuilder(
      availableUtxos: inputs,
      recipients: {nextReceiveAddress.address: inputSum},
      feeRate: feeRate,
      changeDerivationPath: '',
      walletListItemBase: walletListItemBase,
      isFeeSubtractedFromAmount: true,
      isUtxoFixed: true,
    ).build();
  }

  double _estimateVSize(int inputCount) {
    return WalletUtility.estimateVirtualByte(
      walletListItemBase.walletType.addressType,
      inputCount,
      1, // sweep: 1 output (change 없음)
      requiredSignature: walletListItemBase.multisigConfig?.requiredSignature,
      totalSigner: walletListItemBase.multisigConfig?.totalSigner,
    );
  }

  double _calculateMinimumChildFeeRate(double childVSize) {
    return FeeRateUtils.ceilFeeRate(_calculateMinimumChildFee(childVSize) / childVSize);
  }

  /// 패키지(부모+자식)가 네트워크 최소 수수료율을 만족하기 위한 child tx 최소 수수료 (sats)
  /// 부모가 이미 충분히 또는 초과 납부한 경우, 자식 트랜잭션의 최소 수수료를 반환
  double _calculateMinimumChildFee(double childVSize) {
    final packageMinFee = (parentVSize + childVSize) * mininumFeeRate;
    // child가 부담해야 할 몫 (parent가 이미 낸 수수료 차감)
    final childShareOfPackageMin = packageMinFee - parentFee;
    final childOwnMin = childVSize * mininumFeeRate;
    Logger.log('childShareOfPackageMin: $childShareOfPackageMin / childOwnMin: $childOwnMin');
    // 두 조건 중 큰 값 (parent 초과 납부 시 childShareOfPackageMin < 0 가능 → childOwnMin 적용)
    return max(childShareOfPackageMin, childOwnMin);
  }

  /// 패키지가 최소 relay fee를 충족하는 baseline 트랜잭션을 계산
  ///
  /// receivedUtxos → additionalSpendable 순서로 UTXO를 점진적으로 추가하며
  /// minimumChildFeeRate로 sweep을 시도합니다.
  ///
  /// [isForce]: true면 캐시를 무시하고 재계산
  CpfpBuildResult getBaselineTransaction({bool isForce = false}) {
    if (!isForce && _cachedBaseline != null) return _cachedBaseline!;

    final List<UtxoState> inputs = [];
    final List<UtxoState> addedAdditionals = [];
    final allCandidates = [..._receivedUtxos, ..._additionalSpendable];

    TransactionBuildResult? txBuildResult;
    var minimumChildFeeRate = 0.0;
    double? actualChildVSize;

    for (final utxo in allCandidates) {
      inputs.add(utxo);
      if (!_receivedUtxos.contains(utxo)) {
        addedAdditionals.add(utxo);
      }

      final estimatedVSize =
          actualChildVSize != null ? actualChildVSize + _vSizeIncreasePerInput : _estimateVSize(inputs.length);
      minimumChildFeeRate = _calculateMinimumChildFeeRate(estimatedVSize);
      txBuildResult = _trySweep(inputs, minimumChildFeeRate);

      if (txBuildResult.isSuccess) {
        actualChildVSize = txBuildResult.transaction!.estimateVirtualByteForWallet(walletListItemBase);
        // actualVSize 기반으로 feeRate 보정 후 재시도
        final correctedFeeRate = _calculateMinimumChildFeeRate(actualChildVSize);
        if (correctedFeeRate > minimumChildFeeRate) {
          Logger.log('보정: $minimumChildFeeRate -> $correctedFeeRate');
          minimumChildFeeRate = correctedFeeRate;
          txBuildResult = _trySweep(inputs, minimumChildFeeRate);
          if (txBuildResult.isSuccess) break;
          // 보정 후 실패 시 다음 input 추가하여 계속 시도
        } else {
          break;
        }
      }
    }

    _baselineInputs = [...inputs];
    _cachedBaseline = _buildResult(txBuildResult!, minimumChildFeeRate, inputs, addedAdditionals);
    return _cachedBaseline!;
  }

  CpfpBuildResult changeAdditionalSpendable(List<UtxoState> utxos) {
    _additionalSpendable = [...utxos]..sort((a, b) => b.amount.compareTo(a.amount));
    _cachedBaseline = getBaselineTransaction(isForce: true);
    return _cachedBaseline!;
  }

  CpfpBuildResult _buildResult(
    TransactionBuildResult txBuildResult,
    double minimumChildFeeRate,
    List<UtxoState> inputs,
    List<UtxoState> addedAdditionals,
  ) {
    final addedUtxo = addedAdditionals.isEmpty ? null : addedAdditionals;
    final isCpfpNeeded = parentFee < parentVSize * mininumFeeRate;

    if (txBuildResult.isSuccess) {
      final tx = txBuildResult.transaction!;
      final actualChildFee = tx.totalInputAmount - tx.outputs.fold<int>(0, (s, o) => s + o.amount);
      final actualChildVSize = tx.estimateVirtualByteForWallet(walletListItemBase);
      final packageFeeRate = FeeRateUtils.ceilFeeRate((parentFee + actualChildFee) / (parentVSize + actualChildVSize));
      Logger.log(
        '[ Succeed ] actualChildFee: $actualChildFee, actualChildVSize: $actualChildVSize, packageFeeRate: $packageFeeRate',
      );

      return CpfpBuildResult(
        transaction: tx,
        addedUtxo: addedUtxo,
        isCpfpNeeded: isCpfpNeeded,
        minimumFeeRate: minimumChildFeeRate,
        packageFeeRate: packageFeeRate,
        estimatedVSize: actualChildVSize,
      );
    }

    final exception = txBuildResult.exception;
    if (exception is! SendAmountTooLowException && exception is! InsufficientBalanceException) {
      throw exception ?? Exception('Unexpected transaction build failure');
    }
    
    var estimatedVSize = _estimateVSize(inputs.length + 1);
    if (_cachedBaseline != null && _cachedBaseline!.isSuccess) {
      estimatedVSize = _cachedBaseline!.estimatedVSize + _vSizeIncreasePerInput;
    }
    final recalculatedFeeRate = _calculateMinimumChildFeeRate(estimatedVSize);
    final inputSum = inputs.fold<int>(0, (cur, utxo) => cur + utxo.amount);
    final deficitAmount = txBuildResult.estimatedFee - (inputSum - dustLimit);

    return CpfpBuildResult(
      addedUtxo: addedUtxo,
      isCpfpNeeded: isCpfpNeeded,
      minimumFeeRate: recalculatedFeeRate,
      packageFeeRate: mininumFeeRate,
      estimatedVSize: estimatedVSize,
      exception: const CpfpInsufficientFundsException(),
      deficitAmount: deficitAmount,
    );
  }

  /// 지정한 child tx 수수료율로 CPFP 트랜잭션 빌드
  ///
  /// [newFeeRate]: child tx 수수료율 (sat/vB). 패키지 수수료율이 아님.
  /// 지정한 child tx 수수료율로 CPFP 트랜잭션 빌드
  ///
  /// [newFeeRate]: child tx 수수료율 (sat/vB). 패키지 수수료율이 아님.
  CpfpBuildResult build({required double newFeeRate}) {
    _cachedBaseline ??= getBaselineTransaction();

    try {
      if (newFeeRate < _cachedBaseline!.minimumFeeRate) {
        throw const CpfpFeeRateTooLowException();
      }

      Logger.log('[ build ] newFeeRate: $newFeeRate / _cachedBaseline!.minimumFeeRate: ${_cachedBaseline!.minimumFeeRate}');
      if (newFeeRate == _cachedBaseline!.minimumFeeRate) {
        Logger.log('[ build ] return _cachedBaseline');
        return _cachedBaseline!;
      }

      // baseline과 동일한 inputs, addedAdditionals로 시작하여 나머지 candidates를 하나씩 추가하며 시도
      final inputs = [..._baselineInputs];
      final addedAdditionals = [...?_cachedBaseline!.addedUtxo];
      final remaining = [..._receivedUtxos, ..._additionalSpendable].where((utxo) => !inputs.contains(utxo));
      late TransactionBuildResult txBuildResult;
      for (final utxo in [null, ...remaining]) {
        if (utxo != null) {
          inputs.add(utxo);
          if (!_receivedUtxos.contains(utxo)) {
            addedAdditionals.add(utxo);
          }
        }
        txBuildResult = _trySweep(inputs, newFeeRate);
        if (txBuildResult.isSuccess) {
          final actualChildVSize = txBuildResult.transaction!.estimateVirtualByteForWallet(walletListItemBase);
          final correctedFeeRate = _calculateMinimumChildFeeRate(actualChildVSize);
          if (correctedFeeRate > newFeeRate) {
            // actualVSize 기반 최소 feeRate가 newFeeRate보다 높으면 보정하여 재시도
            txBuildResult = _trySweep(inputs, correctedFeeRate);
            if (txBuildResult.isSuccess) {
              return _buildResult(txBuildResult, _cachedBaseline!.minimumFeeRate, inputs, addedAdditionals);
            }
            // 보정 후 실패 시 다음 input 추가하여 계속 시도
          } else {
            return _buildResult(txBuildResult, _cachedBaseline!.minimumFeeRate, inputs, addedAdditionals);
          }
        }
      }

      // 모든 candidates 소진 — 실패 결과에 deficitAmount 포함
      return _buildResult(txBuildResult, _cachedBaseline!.minimumFeeRate, inputs, addedAdditionals);
    } on CpfpCreationException catch (e) {
      return CpfpBuildResult(
        exception: e,
        minimumFeeRate: _cachedBaseline!.minimumFeeRate,
        packageFeeRate: 0,
        estimatedVSize: _cachedBaseline!.estimatedVSize,
      );
    }
  }
}
