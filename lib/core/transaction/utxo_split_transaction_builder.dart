import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/base/async/cancelable_task.dart';
import 'dart:async';
import 'dart:isolate';
import 'package:coconut_wallet/core/exceptions/transaction_creation/transaction_creation_exception.dart';
import 'package:coconut_wallet/core/exceptions/utxo_split/utxo_split_exception.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';

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
  UtxoState? _utxo;
  final int dustThreshold;
  double _feeRate;
  final WalletListItemBase walletListItemBase;
  final AddressRepository addressRepository;
  late final int _nextReceiveAddressIndex;
  final List<WalletAddress> _cachedReceiveAddresses = [];
  double? _outputVBytes;
  double? _oneOutputTxVBytes;
  List<int>? _cachedNiceSplitCounts;

  static const int _outputCountVarIntThreshold = 253;
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

  double get _outputCountVarIntFeeMargin => 2 * feeRate;

  double get feeRate => _feeRate;
  set feeRate(double value) {
    if (value <= 0) {
      throw ArgumentError('feeRate must be greater than 0. Given: $value');
    }
    _feeRate = value;
    _cachedNiceSplitCounts = null;
  }

  UtxoState? get utxo => _utxo;

  UtxoSplitTransactionBuilder({
    UtxoState? utxo,
    required this.dustThreshold,
    required double feeRate,
    required this.walletListItemBase,
    required this.addressRepository,
  }) : assert(dustThreshold > 0, 'dustThreshold must be greater than 0'),
       assert(feeRate > 0, 'feeRate must be greater than 0'),
       _utxo = utxo,
       _feeRate = feeRate {
    /** output 개수가 253 이상일 때 tx 크기가 2 증가
     * Segwit tx에서 witness가 아닌 base 영역이 2bytes 증가하므로 수수료도 2 * feeRate 증가
     * output length: if (0 ~ 252) → 1 byte, if (253 ~ 65535) → 3 bytes, if (65536 ~ 4294967295) → 5 bytes
     * output이 65535개 초과인 경우는 커버 X
     */
    if (utxo != null) {
      _validateUtxo(utxo);
    }
    _nextReceiveAddressIndex = addressRepository.getReceiveAddress(walletListItemBase.id).index;
  }

  void setUtxo(UtxoState? utxo) {
    if (utxo != null) {
      _validateUtxo(utxo);
    }
    _utxo = utxo;
    _cachedNiceSplitCounts = null;
  }

  UtxoState get _requiredUtxo {
    final utxo = _utxo;
    if (utxo == null) {
      throw StateError('utxo must be set before calling this operation');
    }
    return utxo;
  }

  void _validateUtxo(UtxoState utxo) {
    if (utxo.amount < 20000) {
      throw ArgumentError('utxo.amount must be at least 20000');
    }
  }

  Future<void> _initOutputVBytes() async {
    if (_outputVBytes != null) return;

    if (walletListItemBase.walletType == WalletType.singleSignature) {
      _oneOutputTxVBytes = 110;
      _outputVBytes = 31;
    } else {
      final wallet = walletListItemBase as MultisigWalletListItem;
      _oneOutputTxVBytes = 132 + (wallet.signers.length - 2) * 8 + (wallet.requiredSignatureCount - 1) * 18;
      _outputVBytes = 43;
    }
    assert(_outputVBytes != null && _oneOutputTxVBytes != null);
  }

  /// 최대 균등 분할 수를 계산하고 실제 빌드로 검증하여 조정
  Future<int> getMaxEqualSplitCount() async {
    await _initOutputVBytes();
    final utxo = _requiredUtxo;

    // fee = (_oneOutputTxVBytes + _outputVBytes * (n - 1)) * feeRate
    // 조건: (utxo.amount - fee) >= (dustThreshold + 1) * n
    double feePerOutput = _outputVBytes! * feeRate;
    var left = utxo.amount - (_oneOutputTxVBytes! * feeRate);
    /** left - feePerOutput * (n-1) >= (546 + 1) * n
        left + feePerOutput >= 547 * n + feePerOutput * n
        left + feePerOutput >= n * (547 + feePerOutput)
        n <= (left + feePerOutput) / (547 + feePerOutput) */
    var result = (left + feePerOutput) ~/ (dustThreshold + 1 + feePerOutput);
    if (result < _outputCountVarIntThreshold) {
      return result;
    }

    left = utxo.amount - (_oneOutputTxVBytes! * feeRate) - _outputCountVarIntFeeMargin;
    result = (left + feePerOutput) ~/ (dustThreshold + 1 + feePerOutput);
    return result;
  }

  /// 균등하게 나누기
  CancelableTask<UtxoSplitResult> buildEqualAmountSplit({required int splitCount}) {
    final completer = Completer<UtxoSplitResult>();
    CancelableTask<TransactionBuildResult>? txTask;
    var isCancelled = false;

    () async {
      try {
        final splitPreview = await getEqualAmountSplitPreview(splitCount: splitCount);
        if (isCancelled) {
          if (!completer.isCompleted) {
            completer.completeError(const TaskCancelledException());
          }
          return;
        }

        txTask = _buildTransactionWithDesiredAmounts(
          splitPreview.amountCountMap.entries.expand((entry) => List.filled(entry.value, entry.key)).toList(),
        );
        final txBuildResult = await txTask!.future;
        if (txBuildResult.isFailure) {
          _throwIfBuildFailed(txBuildResult);
        }

        if (!completer.isCompleted) {
          completer.complete(_buildSuccessResult(txBuildResult.transaction!));
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
        isCancelled = true;
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
    var isCancelled = false;

    () async {
      try {
        var splitPreview = await getFixedAmountSplitPreview(amountPerOutput: amountPerOutput);
        if (isCancelled) {
          if (!completer.isCompleted) {
            completer.completeError(const TaskCancelledException());
          }
          return;
        }

        txTask = _buildTransactionWithDesiredAmounts(_flattenAmountCountMap(splitPreview.amountCountMap));
        var txBuildResult = await txTask!.future;
        if (txBuildResult.isFailure) {
          if (txBuildResult.exception is SendAmountTooLowException) {
            final exactAmounts = _getFixedSplitExactAmounts(amountPerOutput);
            if (exactAmounts.length > 2) {
              exactAmounts.removeLast();
              splitPreview = await _buildSplitPreview(
                exactAmounts,
                (_oneOutputTxVBytes! + _outputVBytes! * (exactAmounts.length - 1)) * feeRate,
              );
              if (isCancelled) {
                if (!completer.isCompleted) {
                  completer.completeError(const TaskCancelledException());
                }
                return;
              }
              txTask = _buildTransactionWithDesiredAmounts(_flattenAmountCountMap(splitPreview.amountCountMap));
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
          completer.complete(_buildSuccessResult(txBuildResult.transaction!));
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
        isCancelled = true;
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
    var isCancelled = false;

    () async {
      try {
        final splitPreview = await getCustomAmountSplitPreview(amountCountMap: amountCountMap);
        if (isCancelled) {
          if (!completer.isCompleted) {
            completer.completeError(const TaskCancelledException());
          }
          return;
        }

        txTask = _buildTransactionWithDesiredAmounts(_flattenAmountCountMap(splitPreview.amountCountMap));
        final txBuildResult = await txTask!.future;
        if (txBuildResult.isFailure) {
          _throwIfBuildFailed(txBuildResult);
        }

        if (!completer.isCompleted) {
          completer.complete(_buildSuccessResult(txBuildResult.transaction!));
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
        isCancelled = true;
        await txTask?.cancel();
        if (!completer.isCompleted) {
          completer.completeError(const TaskCancelledException());
        }
      },
    );
  }

  Future<SplitPreview> getCustomAmountSplitPreview({required Map<int, int> amountCountMap}) async {
    await _initOutputVBytes();
    final utxo = _requiredUtxo;
    for (final amount in amountCountMap.keys) {
      if (amount <= dustThreshold) {
        throw const SplitOutputDustException(); // 0.0000 0547부터 전송할 수 있어요 -> 이건 나누기 화면에서 미리 잡아야함
      }
    }

    final totalRequested = amountCountMap.entries.fold<int>(0, (sum, entry) => sum + entry.key * entry.value);
    final totalOutputCount = amountCountMap.values.fold<int>(0, (sum, count) => sum + count);

    final double estimatedFee =
        (_oneOutputTxVBytes! + _outputVBytes! * totalOutputCount) * feeRate +
        (totalOutputCount >= _outputCountVarIntThreshold ? _outputCountVarIntFeeMargin : 0);
    if (estimatedFee >= utxo.amount) {
      throw FeeExceedsUtxoAmountException(estimatedFee: estimatedFee);
    }

    final left = utxo.amount - totalRequested - estimatedFee;
    if (left < 0) {
      throw SplitInsufficientAmountException(estimatedFee: estimatedFee); // 금액이 부족해요
    }

    if (left <= dustThreshold) {
      throw const SplitOutputDustException(); // dust가 생성돼요
    }

    final flattenedAmounts = amountCountMap.entries.expand((entry) => List.filled(entry.value, entry.key)).toList();
    return _buildSplitPreview(flattenedAmounts, estimatedFee);
  }

  Future<SplitPreview> getFixedAmountSplitPreview({required int amountPerOutput}) async {
    assert(amountPerOutput > 0);
    await _initOutputVBytes();
    if (amountPerOutput <= dustThreshold) {
      throw const SplitOutputDustException();
    }

    final exactAmounts = _getFixedSplitExactAmounts(amountPerOutput);
    final estimatedFee = (_oneOutputTxVBytes! + _outputVBytes! * (exactAmounts.length)) * feeRate;
    return _buildSplitPreview(exactAmounts, estimatedFee);
  }

  Future<SplitPreview> getEqualAmountSplitPreview({required int splitCount}) async {
    assert(splitCount >= 2);
    await _initOutputVBytes();
    final utxo = _requiredUtxo;
    final int fee =
        ((_oneOutputTxVBytes! + (_outputVBytes! * (splitCount - 1))) * feeRate +
                (splitCount >= _outputCountVarIntThreshold ? _outputCountVarIntFeeMargin : 0))
            .ceil();

    if (fee >= utxo.amount) {
      throw FeeExceedsUtxoAmountException(estimatedFee: fee.toDouble());
    }

    final availableAmount = utxo.amount - fee;
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

    return _buildSplitPreview(desiredAmounts.sublist(0, desiredAmounts.length - 1), fee.toDouble());
  }

  /// UTXO를 niceAmounts로 나누어지게 하는 count 최대 5개를 반환
  Future<List<int>> getNiceSplitCounts() async {
    if (_cachedNiceSplitCounts != null) {
      return _cachedNiceSplitCounts!;
    }

    await _initOutputVBytes();
    final utxo = _requiredUtxo;
    final Set<int> niceSplitCountsSet = {};

    for (final targetSats in niceAmounts.reversed) {
      final count = (utxo.amount / targetSats).round();
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
  UtxoSplitResult _buildSuccessResult(Transaction transaction) {
    final utxo = _requiredUtxo;
    final realFee = _calculateRealFee(transaction);
    final actualSplitMap = _buildSplitAmountMapFromTx(transaction);

    return UtxoSplitResult(
      transaction: transaction,
      splitAmountMap: actualSplitMap,
      estimatedFee: realFee,
      feeRatio: calculateFeeRatio(realFee, utxo.amount),
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

  int _calculateRealFee(Transaction transaction) {
    final utxo = _requiredUtxo;
    final outputSum = transaction.outputs.fold(0, (sum, output) => sum + output.amount);
    return utxo.amount - outputSum;
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
  List<int> _getFixedSplitExactAmounts(int amountPerOutput) {
    final utxo = _requiredUtxo;
    final oneOutputFee = _oneOutputTxVBytes! * feeRate;
    if (oneOutputFee >= utxo.amount) {
      throw FeeExceedsUtxoAmountException(estimatedFee: oneOutputFee);
    }
    double firstLeft = utxo.amount - oneOutputFee - amountPerOutput;
    final feePerOutput = _outputVBytes! * feeRate;
    if (firstLeft <= dustThreshold + feePerOutput) {
      throw SplitInsufficientAmountException(estimatedFee: oneOutputFee); // 수수료를 포함하면 나눌 수 없는 금액이에요
    }

    var neededSatsPerOneMore = amountPerOutput + feePerOutput;
    double left = firstLeft;
    List<int> exactAmounts = [amountPerOutput];
    int count = 1;

    while (left - neededSatsPerOneMore > dustThreshold + feePerOutput) {
      if (count + 1 == _outputCountVarIntThreshold) {
        if (left - _outputCountVarIntFeeMargin - neededSatsPerOneMore <= dustThreshold + feePerOutput) {
          break;
        } else {
          left -= _outputCountVarIntFeeMargin;
        }
      }

      left -= neededSatsPerOneMore;
      exactAmounts.add(amountPerOutput);
      count++;
    }

    return exactAmounts;
  }

  Future<List<WalletAddress>> _getReceiveAddresses(int count) async {
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
    );

    if (addresses.length < additionalCount) {
      throw StateError(
        'Not enough unused addresses. Required: $count, Available: ${_cachedReceiveAddresses.length + addresses.length}',
      );
    }

    _cachedReceiveAddresses.addAll(addresses);
    return _cachedReceiveAddresses.sublist(0, count);
  }

  Future<Map<String, int>> _buildSweepRecipients(List<int> exactAmounts) async {
    final utxo = _requiredUtxo;
    final totalOutputCount = exactAmounts.length + 1; // +1 for sweep output

    final addresses = await _getReceiveAddresses(totalOutputCount);

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
    recipients[addresses[totalOutputCount - 1].address] = utxo.amount - sumOfExact;

    return recipients;
  }

  Future<SplitPreview> _buildSplitPreview(List<int> exactAmounts, double estimatedFee) async {
    return SplitPreview(estimatedFee: estimatedFee, amountCountMap: _buildAmountCountMap(exactAmounts, estimatedFee));
  }

  Map<int, int> _buildAmountCountMap(List<int> exactAmounts, double estimatedFee) {
    final utxo = _requiredUtxo;
    final Map<int, int> amountCountMap = {};
    int sumOfExact = 0;

    for (final amount in exactAmounts) {
      amountCountMap[amount] = (amountCountMap[amount] ?? 0) + 1;
      sumOfExact += amount;
    }

    final sweepAmount = utxo.amount - sumOfExact - estimatedFee.ceil();
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

  CancelableTask<TransactionBuildResult> _buildTransactionWithDesiredAmounts(List<int> desiredAmounts) {
    return _createTransactionBuildTask(() async {
      final exactAmounts = List<int>.from(desiredAmounts);
      if (exactAmounts.isEmpty) {
        throw StateError('desiredAmounts must contain at least one output');
      }
      exactAmounts.removeLast();
      return _buildSweepRecipients(exactAmounts);
    });
  }

  CancelableTask<TransactionBuildResult> _buildTransactionWithRecipients(Map<String, int> recipients) {
    final utxo = _requiredUtxo;
    final changeAddress = addressRepository.getChangeAddress(walletListItemBase.id);
    return _spawnBuildTask(utxo: utxo, recipients: recipients, changeDerivationPath: changeAddress.derivationPath);
  }

  CancelableTask<TransactionBuildResult> _spawnBuildTask({
    required UtxoState utxo,
    required Map<String, int> recipients,
    required String changeDerivationPath,
  }) {
    final receivePort = ReceivePort();
    final completer = Completer<TransactionBuildResult>();
    StreamSubscription? subscription;
    Isolate? isolate;

    () async {
      try {
        isolate = await Isolate.spawn<_SplitBuildIsolateRequest>(
          _splitBuildIsolateEntry,
          _SplitBuildIsolateRequest(
            sendPort: receivePort.sendPort,
            utxo: utxo,
            recipients: recipients,
            feeRate: feeRate,
            changeDerivationPath: changeDerivationPath,
            walletListItemBase: walletListItemBase,
          ),
        );

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
            availableUtxos: [request.utxo],
            recipients: request.recipients,
            feeRate: request.feeRate,
            changeDerivationPath: request.changeDerivationPath,
            walletListItemBase: request.walletListItemBase,
            isFeeSubtractedFromAmount: true,
            isUtxoFixed: true,
          ).build();
      request.sendPort.send(['result', result]);
    } catch (e) {
      request.sendPort.send(['error', e.toString()]);
    }
  }

  CancelableTask<TransactionBuildResult> _createTransactionBuildTask(
    Future<Map<String, int>> Function() prepareRecipients,
  ) {
    final completer = Completer<TransactionBuildResult>();
    CancelableTask<TransactionBuildResult>? innerTask;
    var isCancelled = false;

    () async {
      try {
        final recipients = await prepareRecipients();
        if (isCancelled) {
          if (!completer.isCompleted) {
            completer.completeError(const TaskCancelledException());
          }
          return;
        }

        innerTask = _buildTransactionWithRecipients(recipients);
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
        isCancelled = true;
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
  final UtxoState utxo;
  final Map<String, int> recipients;
  final double feeRate;
  final String changeDerivationPath;
  final WalletListItemBase walletListItemBase;

  const _SplitBuildIsolateRequest({
    required this.sendPort,
    required this.utxo,
    required this.recipients,
    required this.feeRate,
    required this.changeDerivationPath,
    required this.walletListItemBase,
  });
}
