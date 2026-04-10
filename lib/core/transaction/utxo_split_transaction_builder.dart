import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/exceptions/transaction_creation/transaction_creation_exception.dart';
import 'package:coconut_wallet/core/exceptions/utxo_split/utxo_split_exception.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
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

class SplitPreview {
  final double estimatedFee;
  final Map<String, int> recipients;

  const SplitPreview({required this.estimatedFee, required this.recipients});
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
  Future<UtxoSplitResult> buildEqualAmountSplit({required int splitCount}) async {
    assert(splitCount >= 2);
    Logger.log("--> splitCount: $splitCount");
    final splitPreview = await getEqualAmountSplitPreview(splitCount: splitCount);

    var txBuildResult = await _buildTransactionWithRecipients(splitPreview.recipients);
    if (txBuildResult.isFailure) {
      _throwIfBuildFailed(txBuildResult);
    }

    return _buildSuccessResult(txBuildResult.transaction!);
  }

  Future<SplitPreview> getEqualAmountSplitPreview({required int splitCount}) async {
    assert(splitCount >= 2);
    await _initOutputVBytes();
    final utxo = _requiredUtxo;
    final fee =
        (_oneOutputTxVBytes! + (_outputVBytes! * (splitCount - 1))) * feeRate +
        (splitCount >= _outputCountVarIntThreshold ? _outputCountVarIntFeeMargin : 0);
    Logger.log('--> UtxoSplitBuilder 균등분할 estimatedFee: $fee');
    if (fee >= utxo.amount) {
      throw SplitInsufficientAmountException(estimatedFee: fee); // 수수료가 UTXO 금액보다 커요
    }

    final availableAmount = utxo.amount - fee;
    final baseAmount = availableAmount ~/ splitCount;

    if (baseAmount <= dustThreshold) {
      throw SplitOutputDustException(estimatedFee: fee); // 이 개수로 나누면 dust가 생성돼요
    }

    final remainder = availableAmount % splitCount;
    final List<int> desiredAmounts = [];
    for (int i = 0; i < splitCount - remainder; i++) {
      desiredAmounts.add(baseAmount);
    }
    for (int i = 0; i < remainder; i++) {
      desiredAmounts.add(baseAmount + 1);
    }

    return _buildSplitPreview(desiredAmounts.sublist(0, desiredAmounts.length - 1), fee);
  }

  /// 일정 금액으로 나누기
  Future<UtxoSplitResult> buildFixedAmountSplit({required int amountPerOutput}) async {
    var splitPreview = await getFixedAmountSplitPreview(amountPerOutput: amountPerOutput);
    var txBuildResult = await _buildTransactionWithRecipients(splitPreview.recipients);
    if (txBuildResult.isFailure) {
      if (txBuildResult.exception is SendAmountTooLowException) {
        final exactAmounts = _getFixedSplitExactAmounts(amountPerOutput);
        if (exactAmounts.length > 2) {
          // 1개 줄여서 다시 시도
          exactAmounts.removeLast();
          splitPreview = await _buildSplitPreview(
            exactAmounts,
            (_oneOutputTxVBytes! + _outputVBytes! * (exactAmounts.length - 1)) * feeRate,
          );
          txBuildResult = await _buildTransactionWithRecipients(splitPreview.recipients);
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

  Future<SplitPreview> getFixedAmountSplitPreview({required int amountPerOutput}) async {
    assert(amountPerOutput > 0);
    await _initOutputVBytes();
    if (amountPerOutput <= dustThreshold) {
      throw const SplitOutputDustException(); // 0.0000 0547 BTC부터 전송할 수 있어요
    }

    final exactAmounts = _getFixedSplitExactAmounts(amountPerOutput);
    final estimatedFee = (_oneOutputTxVBytes! + _outputVBytes! * (exactAmounts.length)) * feeRate;
    return _buildSplitPreview(exactAmounts, estimatedFee);
  }

  /// 직접 나누기
  Future<UtxoSplitResult> buildCustomAmountSplit({required Map<int, int> amountCountMap}) async {
    final splitPreview = await getCustomAmountSplitPreview(amountCountMap: amountCountMap);
    var txBuildResult = await _buildTransactionWithRecipients(splitPreview.recipients);
    if (txBuildResult.isFailure) {
      _throwIfBuildFailed(txBuildResult);
    }

    return _buildSuccessResult(txBuildResult.transaction!);
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

  /// UTXO를 niceAmounts로 나눠지게 하는 count 최대 5개를 반환
  Future<List<int>> getNiceSplitCounts() async {
    if (_cachedNiceSplitCounts != null) {
      return _cachedNiceSplitCounts!;
    }

    await _initOutputVBytes();
    final utxo = _requiredUtxo;
    final selectableNiceAmounts = niceAmounts.where((element) => element < utxo.amount).toList().reversed;
    final List<int> niceSplitCounts = [];

    for (final amount in selectableNiceAmounts) {
      try {
        final exactAmounts = _getFixedSplitExactAmounts(amount);
        niceSplitCounts.add(exactAmounts.length + 1);
        if (niceSplitCounts.length == 5) {
          break;
        }
      } on SplitOutputDustException {
        continue;
      } on SplitInsufficientAmountException {
        continue;
      }
    }

    _cachedNiceSplitCounts = niceSplitCounts;
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
    double firstLeft = utxo.amount - (_oneOutputTxVBytes! * feeRate) - amountPerOutput;
    final feePerOutput = _outputVBytes! * feeRate;
    if (firstLeft <= dustThreshold + feePerOutput) {
      throw const SplitInsufficientAmountException();
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
    final recipients = await _buildSweepRecipients(exactAmounts);
    return SplitPreview(estimatedFee: estimatedFee, recipients: recipients);
  }

  Future<TransactionBuildResult> _buildTransactionWithRecipients(Map<String, int> recipients) async {
    final utxo = _requiredUtxo;
    final changeAddress = addressRepository.getChangeAddress(walletListItemBase.id);

    return TransactionBuilder(
      availableUtxos: [utxo],
      recipients: recipients,
      feeRate: feeRate,
      changeDerivationPath: changeAddress.derivationPath,
      walletListItemBase: walletListItemBase,
      isFeeSubtractedFromAmount: true,
      isUtxoFixed: true,
    ).build();
  }
}
