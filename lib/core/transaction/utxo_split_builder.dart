import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/core/exceptions/transaction_creation/transaction_creation_exception.dart';
import 'package:coconut_wallet/core/exceptions/utxo_split/utxo_split_exception.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';

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

class UtxoSplitBuilder {
  final UtxoState utxo;
  double _feeRate;
  final WalletListItemBase walletListItemBase;
  final AddressRepository addressRepository;
  late final int _nextReceiveAddressIndex;
  late final double _outputCountVarIntFeeMargin;
  double? _outputVBytes;
  double? _oneOutputTxVBytes;

  static const int _outputCountVarIntThreshold = 253;
  static const List<double> niceAmounts = [
    0.0001,
    0.0002,
    0.0005,
    0.001,
    0.002,
    0.005,
    0.01,
    0.02,
    0.05,
    0.1,
    0.2,
    0.5,
    1,
    2,
    5,
    10,
    20,
    50,
  ];

  double get feeRate => _feeRate;
  set feeRate(double value) {
    if (value <= 0) {
      throw ArgumentError('feeRate must be greater than 0. Given: $value');
    }
    _feeRate = value;
  }

  UtxoSplitBuilder({
    required this.utxo,
    required double feeRate,
    required this.walletListItemBase,
    required this.addressRepository,
  }) : assert(feeRate > 0, 'feeRate must be greater than 0'),
       assert(utxo.amount >= 50000, 'utxo.amount must be at least 50000'),
       _feeRate = feeRate {
    /** output 개수가 253 이상일 때 tx 크기가 2 증가
     * Segwit tx에서 witness가 아닌 base 영역이 2bytes 증가하므로 수수료도 2 * feeRate 증가
     * output length: if (0 ~ 252) → 1 byte, if (253 ~ 65535) → 3 bytes, if (65536 ~ 4294967295) → 5 bytes
     * output이 65535개 초과인 경우는 커버 X
     */
    _outputCountVarIntFeeMargin = 2 * feeRate;
    _nextReceiveAddressIndex = addressRepository.getReceiveAddress(walletListItemBase.id).index;
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

    // fee = (_oneOutputTxVBytes + _outputVBytes * (n - 1)) * feeRate
    // 조건: (utxo.amount - fee) >= (dustLimit + 1) * n
    double feePerOutput = _outputVBytes! * feeRate;
    // INFO: _lastAmountMargin 필요한 이유: coconut_lib 트랜잭션 생성 시 예상 수수료가 여기서 예상한 것보다 큰 경우 마지막 Output Amount가 dustLimit 이하가 되는 경우를 방지
    var left = utxo.amount - (_oneOutputTxVBytes! * feeRate);
    /** left - feePerOutput * (n-1) >= (546 + 1) * n
        left + feePerOutput >= 547 * n + feePerOutput * n
        left + feePerOutput >= n * (547 + feePerOutput)
        n <= (left + feePerOutput) / (547 + feePerOutput) */
    var result = (left + feePerOutput) ~/ (dustLimit + 1 + feePerOutput);
    if (result < _outputCountVarIntThreshold) {
      return result;
    }

    left = utxo.amount - (_oneOutputTxVBytes! * feeRate) - _outputCountVarIntFeeMargin;
    result = (left + feePerOutput) ~/ (dustLimit + 1 + feePerOutput);
    return result;
  }

  /// 균등하게 나누기
  Future<UtxoSplitResult> buildEqualSplit({required int splitCount}) async {
    assert(splitCount >= 2);
    Logger.log("--> splitCount: $splitCount");
    await _initOutputVBytes();
    // INFO: _lastAmountMargin 필요한 이유: coconut_lib 트랜잭션 생성 시 예상 수수료가 여기서 예상한 것보다 큰 경우 마지막 Output Amount가 dustLimit 이하가 되는 경우를 방지
    var fee =
        (_oneOutputTxVBytes! + (_outputVBytes! * (splitCount - 1))) * feeRate +
        (splitCount >= _outputCountVarIntThreshold ? _outputCountVarIntFeeMargin : 0);
    Logger.log('--> UtxoSplitBuilder 균등분할 estimatedFee: $fee');
    if (fee >= utxo.amount) {
      throw SplitInsufficientAmountException(estimatedFee: fee); // 수수료가 UTXO 금액보다 커요
    }

    final availableAmount = utxo.amount - fee;
    final baseAmount = availableAmount ~/ splitCount;

    if (baseAmount <= dustLimit) {
      throw SplitOutputDustException(estimatedFee: fee); // 이 개수로 나누면 dust가 생성돼요
    }

    // 원하는 output 금액 리스트 생성
    final remainder = availableAmount % splitCount;
    List<int> desiredAmounts = [];
    for (int i = 0; i < splitCount - remainder; i++) {
      desiredAmounts.add(baseAmount);
    }
    for (int i = 0; i < remainder; i++) {
      desiredAmounts.add(baseAmount + 1);
    }

    // 트랜잭션 생성 (마지막 output에 fee 포함하여 sweep)
    var txBuildResult = await _buildTransaction(desiredAmounts.sublist(0, desiredAmounts.length - 1));
    if (txBuildResult.isFailure) {
      _throwIfBuildFailed(txBuildResult);
    }

    return _buildSuccessResult(txBuildResult.transaction!);
  }

  /// 일정 금액으로 나누기
  Future<UtxoSplitResult> buildFixedAmountSplit({required int amountPerOutput}) async {
    assert(amountPerOutput > 0);
    await _initOutputVBytes();
    if (amountPerOutput <= dustLimit) {
      throw const SplitOutputDustException(); // 0.0000 0547 BTC부터 전송할 수 있어요
    }

    double firstLeft = utxo.amount - (_oneOutputTxVBytes! * feeRate) - amountPerOutput;
    final feePerOutput = _outputVBytes! * feeRate;
    if (firstLeft <= dustLimit + feePerOutput) {
      throw const SplitInsufficientAmountException(); // 수수료를 포함하면 나눌 수 없는 금액이에요.
    }

    var neededSatsPerOneMore = amountPerOutput + feePerOutput;
    double left = firstLeft;

    // amountPerOutput을 최대한 많이 넣을 수 있는 개수를 구함
    // left에서 neededSatsPerOneMore를 차감한 후 마지막 sweep output이 dustLimit 이상인지 확인
    // exactAmounts: 정확한 금액의 output 리스트 (sweep output 제외)
    List<int> exactAmounts = [amountPerOutput];
    int count = 1;
    while (left - neededSatsPerOneMore > dustLimit + feePerOutput) {
      if (count + 1 == _outputCountVarIntThreshold) {
        if (left - _outputCountVarIntFeeMargin - neededSatsPerOneMore <= dustLimit + feePerOutput) {
          break;
        } else {
          left -= _outputCountVarIntFeeMargin;
        }
      }

      left -= neededSatsPerOneMore;
      exactAmounts.add(amountPerOutput);
      count++;
    }

    var txBuildResult = await _buildTransaction(exactAmounts);
    if (txBuildResult.isFailure) {
      if (txBuildResult.exception is SendAmountTooLowException) {
        if (exactAmounts.length > 2) {
          // 1개 줄여서 다시 시도
          exactAmounts.removeLast();
          txBuildResult = await _buildTransaction(exactAmounts);
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

    return _buildSuccessResult(txBuildResult.transaction!);
  }

  /// 직접 나누기
  Future<UtxoSplitResult> buildCustomSplit({required Map<int, int> amountCountMap}) async {
    await _initOutputVBytes();
    // dust 검증
    for (final amount in amountCountMap.keys) {
      if (amount <= dustLimit) {
        throw const SplitOutputDustException(); // 0.0000 0547부터 전송할 수 있어요 -> 이건 나누기 화면에서 미리 잡아야함
      }
    }

    final totalRequested = amountCountMap.entries.fold<int>(0, (sum, entry) => sum + entry.key * entry.value);
    final totalOutputCount = amountCountMap.values.fold<int>(0, (sum, count) => sum + count);

    final double estimatedFee =
        (_oneOutputTxVBytes! + _outputVBytes! * (totalOutputCount - 1)) * feeRate +
        (totalOutputCount >= _outputCountVarIntThreshold ? _outputCountVarIntFeeMargin : 0);
    final left = utxo.amount - totalRequested - estimatedFee;
    if (left < 0) {
      throw SplitInsufficientAmountException(estimatedFee: estimatedFee); // 금액이 부족해요
    }

    if (left <= dustLimit) {
      throw const SplitOutputDustException(); // dust가 생성돼요
    }

    final flattenedAmounts = amountCountMap.entries.expand((entry) => List.filled(entry.value, entry.key)).toList();
    var txBuildResult = await _buildTransaction(flattenedAmounts);
    if (txBuildResult.isFailure) {
      _throwIfBuildFailed(txBuildResult);
    }

    return _buildSuccessResult(txBuildResult.transaction!);
  }

  /// UTXO를 niceNumbers로 나눠지게 하는 count 최대 5개를 반환
  // List<int> getNiceSplitCounts(double value) {
  //   final raw = value / 10;

  //   const List<double> niceNumbers = [0.01, 0.05, 0.1, 0.5, 1, 2, 5, 10, 20, 50];

  //   const maxOutputs = 20;

  //   double best = niceNumbers.first;
  //   double minDiff = double.infinity;

  //   for (final n in niceNumbers) {
  //     final count = value / n;

  //     if (count > maxOutputs) continue;

  //     final diff = (raw - n).abs();

  //     if (diff < minDiff) {
  //       minDiff = diff;
  //       best = n;
  //     }
  //   }

  //   return best;
  // }

  // ----------- Internal methods -----------
  // ----------- Handle Result -----------
  UtxoSplitResult _buildSuccessResult(Transaction transaction) {
    final realFee = _calculateRealFee(transaction);
    final actualSplitMap = _buildSplitAmountMapFromTx(transaction);

    return UtxoSplitResult(
      transaction: transaction,
      splitAmountMap: actualSplitMap,
      estimatedFee: realFee,
      feeRatio: _calculateFeeRatio(realFee, utxo.amount),
    );
  }

  double _calculateFeeRatio(int fee, int denominator) {
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
  /// [exactAmounts]: 정확한 금액의 output 리스트 (sweep output 미포함)
  /// sweep output이 마지막에 자동으로 추가됨 (utxo.amount - sum(exactAmounts) - fee)
  /// TransactionBuilder가 isFeeSubtractedFromAmount: true로 마지막에서 fee 차감
  Future<Map<String, int>> _buildSweepRecipients(List<int> exactAmounts) async {
    final totalOutputCount = exactAmounts.length + 1; // +1 for sweep output

    final addresses = await addressRepository.getWalletAddressList(
      walletListItemBase,
      _nextReceiveAddressIndex,
      totalOutputCount,
      false,
      true,
    );

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

  Future<TransactionBuildResult> _buildTransaction(List<int> exactAmounts) async {
    final firstRecipients = await _buildSweepRecipients(exactAmounts);
    final changeAddress = addressRepository.getChangeAddress(walletListItemBase.id);

    return TransactionBuilder(
      availableUtxos: [utxo],
      recipients: firstRecipients,
      feeRate: feeRate,
      changeDerivationPath: changeAddress.derivationPath,
      walletListItemBase: walletListItemBase,
      isFeeSubtractedFromAmount: true,
      isUtxoFixed: true,
    ).build();
  }
}
