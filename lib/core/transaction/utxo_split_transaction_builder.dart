import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/base/async/cancelable_task.dart';
import 'dart:async';
import 'dart:isolate';
import 'package:coconut_wallet/core/exceptions/transaction_creation/transaction_creation_exception.dart';
import 'package:coconut_wallet/core/exceptions/utxo_split/utxo_split_exception.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:flutter/foundation.dart';

class UtxoSplitResult {
  final Transaction? transaction;
  final Map<int, int> splitAmountMap;
  final int estimatedFee;
  final double feeRatio;
  final Exception? exception;

  bool get isSuccess => transaction != null;
  bool get isFailure => transaction == null;

  const UtxoSplitResult({
    required this.transaction,
    required this.splitAmountMap,
    required this.estimatedFee,
    required this.feeRatio,
    this.exception,
  });

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln("┌──────────────── UTXO Split Result Info ────────────────┐");
    buffer.writeln("│ isSuccess = $isSuccess");
    buffer.writeln("│ splitAmountMap = $splitAmountMap");
    buffer.writeln("│ estimatedFee = $estimatedFee");
    buffer.writeln("│ feeRatio = $feeRatio%");
    buffer.writeln("│ exception = $exception");
    buffer.writeln("└───────────────────────────────────────────────────────┘");
    return buffer.toString();
  }
}

class SplitPreview {
  final double estimatedFee;
  final Map<int, int> amountCountMap;

  const SplitPreview({required this.estimatedFee, required this.amountCountMap});
}

class UtxoSplitTransactionBuilder {
  List<UtxoState> _utxos = [];
  final int dustThreshold;
  double _feeRate;
  final WalletItemBase walletListItemBase;
  final AddressRepository addressRepository;
  late final int _nextReceiveAddressIndex;
  final List<WalletAddress> _cachedReceiveAddresses = [];
  double? _outputVBytes;
  double? _oneOutputTxVBytes;
  double? _inputVBytes;
  double? _signedInputOverheadVBytes;
  List<int>? _cachedNiceSplitCounts;
  late final Policy? _scriptPathPolicy;

  static const int _varIntCountThreshold = 253;
  static const double _varIntExpansionVBytes = 2;

  /// Bitcoin Core 표준 정책 MAX_STANDARD_TX_WEIGHT(400,000 WU) / 4
  static const double maxStandardTxVBytes = 100000;
  static const List<int> niceAmounts = [
    10000,
    20000,
    50000,
    100000,
    200000,
    500000,
    1000000,
    2000000,
    5000000,
    10000000,
    20000000,
    50000000,
    100000000,
    200000000,
    500000000,
    1000000000,
    2000000000,
    5000000000,
  ];

  double get _outputCountVarIntFeeMargin => _varIntExpansionVBytes * feeRate;

  double get feeRate => _feeRate;
  set feeRate(double value) {
    if (value <= 0) {
      throw ArgumentError('feeRate must be greater than 0. Given: $value');
    }
    _feeRate = value;
    _cachedNiceSplitCounts = null;
  }

  List<UtxoState> get utxos => _utxos;

  UtxoSplitTransactionBuilder({
    List<UtxoState>? utxos,
    required this.dustThreshold,
    required double feeRate,
    required this.walletListItemBase,
    required this.addressRepository,
  }) : assert(dustThreshold > 0, 'dustThreshold must be greater than 0'),
       assert(feeRate > 0, 'feeRate must be greater than 0'),
       _feeRate = feeRate {
    _scriptPathPolicy =
        walletListItemBase is TaprootWalletItem
            ? ((walletListItemBase as TaprootWalletItem).defaultSpendType == TaprootSpendType.scriptPath
                ? (walletListItemBase as TaprootWalletItem).defaultPolicy
                : null)
            : null;
    /** output 개수가 253 이상일 때 tx 크기가 2 증가
     * Segwit tx에서 witness가 아닌 base 영역이 2bytes 증가하므로 수수료도 2 * feeRate 증가
     * output length: if (0 ~ 252) → 1 byte, if (253 ~ 65535) → 3 bytes, if (65536 ~ 4294967295) → 5 bytes
     * output이 65535개 초과인 경우는 커버 X
     */
    if (utxos != null && utxos.isNotEmpty) {
      _validateUtxos(utxos);
      _utxos = List.unmodifiable(utxos);
    }
    _nextReceiveAddressIndex =
        addressRepository.getReceiveAddress(walletListItemBase.id, wallet: walletListItemBase.walletBase).index;
  }

  void setUtxos(List<UtxoState>? utxos) {
    if (utxos != null && utxos.isNotEmpty) {
      _validateUtxos(utxos);
      _utxos = List.unmodifiable(utxos);
    } else {
      _utxos = [];
    }
    _cachedNiceSplitCounts = null;
  }

  int _sumOfAmounts(List<UtxoState> utxos) => utxos.fold<int>(0, (sum, utxo) => sum + utxo.amount);

  int get _totalUtxoAmount => _sumOfAmounts(_utxos);

  /// [inputCount]개의 input + output 1개인 tx의 vBytes
  double _oneOutputTxVBytesWithInputCount(int inputCount) =>
      _oneOutputTxVBytes! +
      _inputVBytes! * (inputCount - 1) +
      (inputCount >= _varIntCountThreshold ? _varIntExpansionVBytes : 0);

  /// 현재 설정된 모든 input + output 1개인 tx의 vBytes
  double get _oneOutputTxVBytesWithAllInputs => _oneOutputTxVBytesWithInputCount(_utxos.length);

  /// [inputCount]개의 input + [outputCount]개의 output인 tx의 vBytes
  double _txVBytes(int inputCount, int outputCount) =>
      _oneOutputTxVBytesWithInputCount(inputCount) +
      _outputVBytes! * (outputCount - 1) +
      (outputCount >= _varIntCountThreshold ? _varIntExpansionVBytes : 0);

  double _signedTxVBytesUpperBound(int inputCount, int outputCount) =>
      _txVBytes(inputCount, outputCount) + _signedInputOverheadVBytes! * inputCount;

  @visibleForTesting
  Future<double> signedTxVBytesUpperBound(int inputCount, int outputCount) async {
    await _initOutputVBytes();
    return _signedTxVBytesUpperBound(inputCount, outputCount);
  }

  void _throwIfTxTooLarge(int inputCount, int outputCount, double estimatedFee) {
    if (_signedTxVBytesUpperBound(inputCount, outputCount) > maxStandardTxVBytes) {
      throw SplitTxTooLargeException(estimatedFee: estimatedFee);
    }
  }

  List<UtxoState> get _requiredUtxos {
    if (_utxos.isEmpty) {
      throw StateError('utxos must be set before calling this operation');
    }
    return _utxos;
  }

  void _validateUtxos(List<UtxoState> utxos) {
    final totalAmount = utxos.fold<int>(0, (sum, utxo) => sum + utxo.amount);
    if (totalAmount < 20000) {
      throw ArgumentError('total utxo amount must be at least 20000');
    }

    final utxoIds = <String>{};
    for (final utxo in utxos) {
      if (!utxoIds.add(utxo.utxoId)) {
        throw ArgumentError('duplicate utxo: ${utxo.utxoId}');
      }
    }
  }

  Future<void> _initOutputVBytes() async {
    if (_outputVBytes != null) return;

    /// Transaction.forBatchSweep이 실제 사용하는 추정기와 동일하게 vBytes를 계산
    /// (input·output 크기가 개수에 선형이므로 1개씩 늘린 tx와의 차이로 구함)
    final addressType = walletListItemBase.walletType.addressType;
    final dummyAddress = walletListItemBase.walletBase.getAddress(0);
    double estimateVBytes(int inputCount, int outputCount) {
      final tx = Transaction.withInputsAndOutputs(
        List.generate(inputCount, (index) => TransactionInput.forPayment('00' * 32, index)),
        List.generate(outputCount, (_) => TransactionOutput.forPayment(0, dummyAddress)),
        addressType,
      );
      if (_scriptPathPolicy != null) {
        tx.setPolicy(_scriptPathPolicy);
      }
      return tx.estimateVirtualByte(
        addressType,
        requiredSignature: walletListItemBase.multisigConfig?.requiredSignature,
        totalSigner: walletListItemBase.multisigConfig?.totalSigner,
        leafCount:
            _scriptPathPolicy != null ? (walletListItemBase.walletBase as TaprootWallet).policyList.length : null,
      );
    }

    _oneOutputTxVBytes = estimateVBytes(1, 1);
    _inputVBytes = estimateVBytes(2, 1) - _oneOutputTxVBytes!;
    _outputVBytes = estimateVBytes(1, 2) - _oneOutputTxVBytes!;

    var overheadWitnessBytes = 0;
    final multisigConfig = walletListItemBase.multisigConfig;
    if (addressType == AddressType.p2wsh && multisigConfig != null) {
      final witnessScriptSize = 3 + multisigConfig.totalSigner * 34;
      overheadWitnessBytes = witnessScriptSize < _varIntCountThreshold ? 1 : 3;
    }
    _signedInputOverheadVBytes = overheadWitnessBytes / 4;
  }

  /// 최대 균등 분할 수를 계산하고 실제 빌드로 검증하여 조정
  Future<int> getMaxEqualSplitCount() async {
    await _initOutputVBytes();
    final totalAmount = _totalUtxoAmount;
    if (totalAmount == 0) {
      throw StateError('utxos must be set before calling this operation');
    }

    // fee = (_oneOutputTxVBytes + _outputVBytes * (n - 1)) * feeRate
    // 조건: (totalAmount - fee) >= (dustThreshold + 1) * n
    double feePerOutput = _outputVBytes! * feeRate;
    var left = totalAmount - (_oneOutputTxVBytesWithAllInputs * feeRate);
    /** left - feePerOutput * (n-1) >= (546 + 1) * n
        left + feePerOutput >= 547 * n + feePerOutput * n
        left + feePerOutput >= n * (547 + feePerOutput)
        n <= (left + feePerOutput) / (547 + feePerOutput) */
    var result = (left + feePerOutput) ~/ (dustThreshold + 1 + feePerOutput);
    if (result >= _varIntCountThreshold) {
      left = totalAmount - (_oneOutputTxVBytesWithAllInputs * feeRate) - _outputCountVarIntFeeMargin;
      result = (left + feePerOutput) ~/ (dustThreshold + 1 + feePerOutput);
    }

    final maxCountBySize =
        (maxStandardTxVBytes -
                _oneOutputTxVBytesWithAllInputs -
                _signedInputOverheadVBytes! * _utxos.length -
                _varIntExpansionVBytes) ~/
            _outputVBytes! +
        1;
    return result < maxCountBySize ? result : maxCountBySize;
  }

  /// 균등하게 나누기
  CancelableTask<UtxoSplitResult> buildEqualAmountSplit({required int splitCount}) {
    final completer = Completer<UtxoSplitResult>();
    CancelableTask<TransactionBuildResult>? txTask;
    var isBuildCancelled = false;

    () async {
      try {
        /// 빌드 도중 setUtxos로 _utxos가 교체돼도 이 빌드는 시작 시점의 UTXO들로 완결된다
        final utxos = _requiredUtxos;
        final splitPreview = await getEqualAmountSplitPreview(splitCount: splitCount, utxos: utxos);
        if (isBuildCancelled) {
          if (!completer.isCompleted) {
            completer.completeError(const TaskCancelledException());
          }
          return;
        }

        txTask = _buildTransactionWithDesiredAmounts(
          splitPreview.amountCountMap.entries.expand((entry) => List.filled(entry.value, entry.key)).toList(),
          utxos,
        );
        final txBuildResult = await txTask!.future;
        if (txBuildResult.isFailure) {
          _throwIfBuildFailed(txBuildResult);
        }

        if (!completer.isCompleted) {
          completer.complete(_buildSuccessResult(txBuildResult.transaction!, utxos));
        }
      } catch (e, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(e, stackTrace);
        }
      }
    }();
    return CancelableTask(
      future: completer.future,
      cancel: () async {
        isBuildCancelled = true;
        await txTask?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(const TaskCancelledException());
        }
      },
    );
  }

  /// 일정 금액으로 나누기
  CancelableTask<UtxoSplitResult> buildFixedAmountSplit({required int amountPerOutput}) {
    final completer = Completer<UtxoSplitResult>();
    CancelableTask<TransactionBuildResult>? txTask;
    var isBuildCancelled = false;

    () async {
      try {
        final utxos = _requiredUtxos;
        var splitPreview = await getFixedAmountSplitPreview(amountPerOutput: amountPerOutput, utxos: utxos);
        if (isBuildCancelled) {
          if (!completer.isCompleted) {
            completer.completeError(const TaskCancelledException());
          }
          return;
        }

        txTask = _buildTransactionWithDesiredAmounts(_flattenAmountCountMap(splitPreview.amountCountMap), utxos);
        var txBuildResult = await txTask!.future;
        if (txBuildResult.isFailure) {
          if (txBuildResult.exception is SendAmountTooLowException) {
            final exactAmounts = _getFixedSplitExactAmounts(amountPerOutput, utxos);
            if (exactAmounts.length > 2) {
              exactAmounts.removeLast();
              splitPreview = await _buildSplitPreview(
                exactAmounts,
                _fixedSplitFee(utxos.length, exactAmounts.length).toDouble(),
                utxos,
              );
              if (isBuildCancelled) {
                if (!completer.isCompleted) {
                  completer.completeError(const TaskCancelledException());
                }
                return;
              }
              txTask = _buildTransactionWithDesiredAmounts(_flattenAmountCountMap(splitPreview.amountCountMap), utxos);
              txBuildResult = await txTask!.future;
            }
            if (txBuildResult.isFailure) {
              _throwIfBuildFailed(txBuildResult);
            }
          } else {
            throw UtxoSplitException(
              estimatedFee: txBuildResult.estimatedFee.toDouble(),
              message: txBuildResult.exception!.toString(),
            );
          }
        }

        if (!completer.isCompleted) {
          completer.complete(_buildSuccessResult(txBuildResult.transaction!, utxos));
        }
      } catch (e, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(e, stackTrace);
        }
      }
    }();
    return CancelableTask(
      future: completer.future,
      cancel: () async {
        isBuildCancelled = true;
        await txTask?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(const TaskCancelledException());
        }
      },
    );
  }

  /// 직접 나누기
  CancelableTask<UtxoSplitResult> buildCustomAmountSplit({required Map<int, int> amountCountMap}) {
    final completer = Completer<UtxoSplitResult>();
    CancelableTask<TransactionBuildResult>? txTask;
    var isBuildCancelled = false;

    () async {
      try {
        final utxos = _requiredUtxos;
        final splitPreview = await getCustomAmountSplitPreview(amountCountMap: amountCountMap, utxos: utxos);
        if (isBuildCancelled) {
          if (!completer.isCompleted) {
            completer.completeError(const TaskCancelledException());
          }
          return;
        }

        txTask = _buildTransactionWithDesiredAmounts(_flattenAmountCountMap(splitPreview.amountCountMap), utxos);
        final txBuildResult = await txTask!.future;
        if (txBuildResult.isFailure) {
          _throwIfBuildFailed(txBuildResult);
        }

        if (!completer.isCompleted) {
          completer.complete(_buildSuccessResult(txBuildResult.transaction!, utxos));
        }
      } catch (e, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(e, stackTrace);
        }
      }
    }();

    return CancelableTask(
      future: completer.future,
      cancel: () async {
        isBuildCancelled = true;
        await txTask?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(const TaskCancelledException());
        }
      },
    );
  }

  Future<SplitPreview> getCustomAmountSplitPreview({
    required Map<int, int> amountCountMap,
    List<UtxoState>? utxos,
  }) async {
    await _initOutputVBytes();
    final effectiveUtxos = utxos ?? _requiredUtxos;
    final totalAmount = _sumOfAmounts(effectiveUtxos);
    for (final amount in amountCountMap.keys) {
      if (amount <= dustThreshold) {
        throw const SplitOutputDustException(); // 0.0000 0547부터 전송할 수 있어요 -> 이건 나누기 화면에서 미리 잡아야함
      }
    }

    final totalRequested = amountCountMap.entries.fold<int>(0, (sum, entry) => sum + entry.key * entry.value);
    final totalOutputCount = amountCountMap.values.fold<int>(0, (sum, count) => sum + count);

    final double estimatedFee =
        ((_oneOutputTxVBytesWithInputCount(effectiveUtxos.length) + _outputVBytes! * totalOutputCount) * feeRate +
                (totalOutputCount + 1 >= _varIntCountThreshold ? _outputCountVarIntFeeMargin : 0))
            .ceilToDouble();
    if (estimatedFee >= totalAmount) {
      throw FeeExceedsUtxoAmountException(estimatedFee: estimatedFee);
    }
    _throwIfTxTooLarge(effectiveUtxos.length, totalOutputCount + 1, estimatedFee);

    final left = totalAmount - totalRequested - estimatedFee;
    if (left < 0) {
      throw SplitInsufficientAmountException(estimatedFee: estimatedFee); // 금액이 부족해요
    }

    if (left <= dustThreshold) {
      throw const SplitOutputDustException(); // dust가 생성돼요
    }

    final flattenedAmounts = amountCountMap.entries.expand((entry) => List.filled(entry.value, entry.key)).toList();
    return _buildSplitPreview(flattenedAmounts, estimatedFee, effectiveUtxos);
  }

  Future<SplitPreview> getFixedAmountSplitPreview({required int amountPerOutput, List<UtxoState>? utxos}) async {
    assert(amountPerOutput > 0);
    await _initOutputVBytes();
    final effectiveUtxos = utxos ?? _requiredUtxos;
    if (amountPerOutput <= dustThreshold) {
      throw const SplitOutputDustException();
    }

    final exactAmounts = _getFixedSplitExactAmounts(amountPerOutput, effectiveUtxos);
    final estimatedFee = _fixedSplitFee(effectiveUtxos.length, exactAmounts.length).toDouble();
    _throwIfTxTooLarge(effectiveUtxos.length, exactAmounts.length + 1, estimatedFee);
    return _buildSplitPreview(exactAmounts, estimatedFee, effectiveUtxos);
  }

  Future<SplitPreview> getEqualAmountSplitPreview({required int splitCount, List<UtxoState>? utxos}) async {
    assert(splitCount >= 2);
    await _initOutputVBytes();
    final effectiveUtxos = utxos ?? _requiredUtxos;
    final totalAmount = _sumOfAmounts(effectiveUtxos);
    final int fee =
        ((_oneOutputTxVBytesWithInputCount(effectiveUtxos.length) + (_outputVBytes! * (splitCount - 1))) * feeRate +
                (splitCount >= _varIntCountThreshold ? _outputCountVarIntFeeMargin : 0))
            .ceil();

    if (fee >= totalAmount) {
      throw FeeExceedsUtxoAmountException(estimatedFee: fee.toDouble());
    }
    _throwIfTxTooLarge(effectiveUtxos.length, splitCount, fee.toDouble());

    final availableAmount = totalAmount - fee;
    final baseAmount = availableAmount ~/ splitCount;

    if (baseAmount <= dustThreshold) {
      throw SplitOutputDustException(estimatedFee: fee.toDouble());
    }

    final remainder = availableAmount % splitCount;
    final List<int> desiredAmounts = [];
    for (int i = 0; i < remainder; i++) {
      desiredAmounts.add(baseAmount + 1);
    }
    for (int i = 0; i < splitCount - remainder; i++) {
      desiredAmounts.add(baseAmount);
    }

    return _buildSplitPreview(desiredAmounts.sublist(0, desiredAmounts.length - 1), fee.toDouble(), effectiveUtxos);
  }

  /// UTXO를 niceAmounts로 나누어지게 하는 count 최대 5개를 반환
  Future<List<int>> getNiceSplitCounts() async {
    if (_cachedNiceSplitCounts != null) {
      return _cachedNiceSplitCounts!;
    }

    await _initOutputVBytes();
    _requiredUtxos;
    final totalAmount = _totalUtxoAmount;
    final Set<int> niceSplitCountsSet = {};

    for (final targetSats in niceAmounts.reversed) {
      final count = (totalAmount / targetSats).round();
      if (count >= 2) {
        try {
          await getEqualAmountSplitPreview(splitCount: count);
          niceSplitCountsSet.add(count);
        } catch (_) {
          continue;
        }
      }
      if (niceSplitCountsSet.length >= 5) break;
    }

    _cachedNiceSplitCounts = niceSplitCountsSet.toList()..sort();
    return _cachedNiceSplitCounts!;
  }

  // ----------- Internal methods -----------
  // ----------- Handle Result -----------
  UtxoSplitResult _buildSuccessResult(Transaction transaction, List<UtxoState> utxos) {
    final totalAmount = _sumOfAmounts(utxos);
    final realFee = _calculateRealFee(transaction, utxos);
    final actualSplitMap = _buildSplitAmountMapFromTx(transaction);

    return UtxoSplitResult(
      transaction: transaction,
      splitAmountMap: actualSplitMap,
      estimatedFee: realFee,
      feeRatio: calculateFeeRatio(realFee, totalAmount),
    );
  }

  double calculateFeeRatio(int fee, int denominator) {
    return ((fee / denominator * 100) * 100).roundToDouble() / 100;
  }

  Never _throwIfBuildFailed(TransactionBuildResult txBuildResult) {
    if (!txBuildResult.isFailure) {
      throw ArgumentError('txBuildResult must be failure');
    }

    if (txBuildResult.exception is SendAmountTooLowException) {
      throw SplitOutputDustException(estimatedFee: txBuildResult.estimatedFee.toDouble());
    }

    throw UtxoSplitException(
      estimatedFee: txBuildResult.estimatedFee.toDouble(),
      message: txBuildResult.exception!.toString(),
    );
  }

  int _calculateRealFee(Transaction transaction, List<UtxoState> utxos) {
    final inputSum = _sumOfAmounts(utxos);
    final outputSum = transaction.outputs.fold(0, (sum, output) => sum + output.amount);
    return inputSum - outputSum;
  }

  /// 실제 트랜잭션의 output 금액으로 splitAmountMap을 생성
  Map<int, int> _buildSplitAmountMapFromTx(Transaction transaction) {
    final Map<int, int> result = {};
    for (final output in transaction.outputs) {
      result[output.amount] = (result[output.amount] ?? 0) + 1;
    }
    return result;
  }

  /// sweep 방식의 recipients 생성
  /// [exactAmounts]: 확정된 금액의 output 리스트, last output은 미포함
  List<int> _getFixedSplitExactAmounts(int amountPerOutput, List<UtxoState> utxos) {
    final totalAmount = _sumOfAmounts(utxos);
    final oneOutputFee = _oneOutputTxVBytesWithInputCount(utxos.length) * feeRate;
    if (oneOutputFee >= totalAmount) {
      throw FeeExceedsUtxoAmountException(estimatedFee: oneOutputFee);
    }
    int sweepAmount(int exactCount) =>
        totalAmount - amountPerOutput * exactCount - _fixedSplitFee(utxos.length, exactCount);
    if (sweepAmount(1) <= dustThreshold) {
      throw SplitInsufficientAmountException(estimatedFee: oneOutputFee); // 수수료를 포함하면 나눌 수 없는 금액이에요
    }

    int count = 1;
    while (sweepAmount(count + 1) > dustThreshold) {
      count++;
    }

    return List.filled(count, amountPerOutput);
  }

  /// exact output [exactCount]개 + sweep output 1개인 tx의 수수료
  int _fixedSplitFee(int inputCount, int exactCount) =>
      ((_oneOutputTxVBytesWithInputCount(inputCount) + _outputVBytes! * exactCount) * feeRate +
              (exactCount + 1 >= _varIntCountThreshold ? _outputCountVarIntFeeMargin : 0))
          .ceil();

  Future<List<WalletAddress>> _getReceiveAddresses(int count, {bool Function()? isBuildCancelled}) async {
    if (_cachedReceiveAddresses.length >= count) {
      return _cachedReceiveAddresses.sublist(0, count);
    }

    final additionalCount = count - _cachedReceiveAddresses.length;
    final cursor = _nextReceiveAddressIndex + _cachedReceiveAddresses.length - 1;
    final addresses = await addressRepository.getWalletAddressList(
      walletListItemBase,
      cursor,
      additionalCount,
      false,
      true,
      shouldStopGenerating: isBuildCancelled,
    );

    if (addresses.length < additionalCount) {
      throw StateError(
        'Not enough unused addresses. Required: $count, Available: ${_cachedReceiveAddresses.length + addresses.length}',
      );
    }

    _cachedReceiveAddresses.addAll(addresses);
    return _cachedReceiveAddresses.sublist(0, count);
  }

  Future<Map<String, int>> _buildSweepRecipients(
    List<int> exactAmounts,
    List<UtxoState> utxos, {
    bool Function()? isBuildCancelled,
  }) async {
    final totalAmount = _sumOfAmounts(utxos);
    final totalOutputCount = exactAmounts.length + 1; // +1 for sweep output

    final addresses = await _getReceiveAddresses(totalOutputCount, isBuildCancelled: isBuildCancelled);

    if (addresses.length < totalOutputCount) {
      throw StateError('Not enough unused addresses. Required: $totalOutputCount, Available: ${addresses.length}');
    }

    final Map<String, int> recipients = {};

    int sumOfExact = 0;
    for (int i = 0; i < exactAmounts.length; i++) {
      recipients[addresses[i].address] = exactAmounts[i];
      sumOfExact += exactAmounts[i];
    }

    // sweep output: 나머지 전부 (fee 포함) → tx 생성 시 여기서 fee 차감
    recipients[addresses[totalOutputCount - 1].address] = totalAmount - sumOfExact;

    return recipients;
  }

  Future<SplitPreview> _buildSplitPreview(List<int> exactAmounts, double estimatedFee, List<UtxoState> utxos) async {
    return SplitPreview(
      estimatedFee: estimatedFee,
      amountCountMap: _buildAmountCountMap(exactAmounts, estimatedFee, utxos),
    );
  }

  Map<int, int> _buildAmountCountMap(List<int> exactAmounts, double estimatedFee, List<UtxoState> utxos) {
    final totalAmount = _sumOfAmounts(utxos);
    final Map<int, int> amountCountMap = {};
    int sumOfExact = 0;

    for (final amount in exactAmounts) {
      amountCountMap[amount] = (amountCountMap[amount] ?? 0) + 1;
      sumOfExact += amount;
    }

    final sweepAmount = totalAmount - sumOfExact - estimatedFee.ceil();
    amountCountMap[sweepAmount] = (amountCountMap[sweepAmount] ?? 0) + 1;
    return amountCountMap;
  }

  List<int> _flattenAmountCountMap(Map<int, int> amountCountMap) {
    final amounts = <int>[];
    for (final entry in amountCountMap.entries) {
      for (int i = 0; i < entry.value; i++) {
        amounts.add(entry.key);
      }
    }
    return amounts;
  }

  CancelableTask<TransactionBuildResult> _buildTransactionWithDesiredAmounts(
    List<int> desiredAmounts,
    List<UtxoState> utxos,
  ) {
    return _createTransactionBuildTask((isBuildCancelled) async {
      final exactAmounts = List<int>.from(desiredAmounts);
      if (exactAmounts.isEmpty) {
        throw StateError('desiredAmounts must contain at least one output');
      }
      exactAmounts.removeLast();
      return _buildSweepRecipients(exactAmounts, utxos, isBuildCancelled: isBuildCancelled);
    }, utxos);
  }

  CancelableTask<TransactionBuildResult> _buildTransactionWithRecipients(
    Map<String, int> recipients,
    List<UtxoState> utxos,
  ) {
    final changeAddress = addressRepository.getChangeAddress(
      walletListItemBase.id,
      wallet: walletListItemBase.walletBase,
    );
    return _spawnBuildTask(utxos: utxos, recipients: recipients, changeDerivationPath: changeAddress.derivationPath);
  }

  CancelableTask<TransactionBuildResult> _spawnBuildTask({
    required List<UtxoState> utxos,
    required Map<String, int> recipients,
    required String changeDerivationPath,
  }) {
    final receivePort = ReceivePort();
    final completer = Completer<TransactionBuildResult>();
    StreamSubscription? subscription;
    Isolate? isolate;
    var isBuildCancelled = false;

    () async {
      try {
        final spawned = await Isolate.spawn<_SplitBuildIsolateRequest>(
          _splitBuildIsolateEntry,
          _SplitBuildIsolateRequest(
            sendPort: receivePort.sendPort,
            utxos: utxos,
            recipients: recipients,
            feeRate: feeRate,
            changeDerivationPath: changeDerivationPath,
            walletItemBase: walletListItemBase,
            scriptPathPolicy: _scriptPathPolicy,
          ),
        );

        /// spawn 진행 중 취소됐으면 아무도 참조하지 않는 고아 isolate가 되기 전에 즉시 종료한다
        if (isBuildCancelled) {
          spawned.kill(priority: Isolate.immediate);
          return;
        }
        isolate = spawned;

        subscription = receivePort.listen((message) {
          if (completer.isCompleted) {
            return;
          }

          if (message is List && message.isNotEmpty) {
            final type = message[0];
            if (type == 'result' && message.length > 1 && message[1] is TransactionBuildResult) {
              completer.complete(message[1] as TransactionBuildResult);
            } else if (type == 'error' && message.length > 1 && message[1] is String) {
              completer.completeError(StateError(message[1] as String));
            } else {
              completer.completeError(StateError('Unexpected split build isolate message: $message'));
            }
          } else {
            completer.completeError(StateError('Unexpected split build isolate payload: $message'));
          }

          subscription?.cancel();
          receivePort.close();
          isolate?.kill(priority: Isolate.immediate);
          isolate = null;
        });
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
        await subscription?.cancel();
        receivePort.close();
        isolate?.kill(priority: Isolate.immediate);
        isolate = null;
      }
    }();
    return CancelableTask(
      future: completer.future,
      cancel: () async {
        isBuildCancelled = true;
        isolate?.kill(priority: Isolate.immediate);
        isolate = null;
        await subscription?.cancel();
        receivePort.close();
        if (!completer.isCompleted) {
          completer.completeError(const TaskCancelledException());
        }
      },
    );
  }

  static void _splitBuildIsolateEntry(_SplitBuildIsolateRequest request) {
    try {
      final result =
          TransactionBuilder(
            availableUtxos: request.utxos,
            recipients: request.recipients,
            feeRate: request.feeRate,
            changeDerivationPath: request.changeDerivationPath,
            walletItemBase: request.walletItemBase,
            isFeeSubtractedFromAmount: true,
            isUtxoFixed: true,
            scriptPathPolicy: request.scriptPathPolicy,
          ).build();
      request.sendPort.send(['result', result]);
    } catch (e) {
      request.sendPort.send(['error', e.toString()]);
    }
  }

  CancelableTask<TransactionBuildResult> _createTransactionBuildTask(
    Future<Map<String, int>> Function(bool Function() isBuildCancelled) prepareRecipients,
    List<UtxoState> utxos,
  ) {
    final completer = Completer<TransactionBuildResult>();
    CancelableTask<TransactionBuildResult>? innerTask;
    var isBuildCancelled = false;

    () async {
      try {
        final recipients = await prepareRecipients(() => isBuildCancelled);
        if (isBuildCancelled) {
          if (!completer.isCompleted) {
            completer.completeError(const TaskCancelledException());
          }
          return;
        }

        innerTask = _buildTransactionWithRecipients(recipients, utxos);
        final result = await innerTask!.future;
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      } catch (e, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(e, stackTrace);
        }
      }
    }();
    return CancelableTask(
      future: completer.future,
      cancel: () async {
        isBuildCancelled = true;
        await innerTask?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(const TaskCancelledException());
        }
      },
    );
  }
}

class _SplitBuildIsolateRequest {
  final SendPort sendPort;
  final List<UtxoState> utxos;
  final Map<String, int> recipients;
  final double feeRate;
  final String changeDerivationPath;
  final WalletItemBase walletItemBase;
  final Policy? scriptPathPolicy;

  const _SplitBuildIsolateRequest({
    required this.sendPort,
    required this.utxos,
    required this.recipients,
    required this.feeRate,
    required this.changeDerivationPath,
    required this.walletItemBase,
    required this.scriptPathPolicy,
  });
}
