import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';

class TransactionRecord {
  final String _transactionHash;
  final DateTime _timestamp;
  final int _blockHeight;
  String _transactionType;
  String? _memo;
  int _amount;
  int _fee;
  List<TransactionAddress> _inputAddressList;
  List<TransactionAddress> _outputAddressList;
  DateTime createdAt;
  double _vSize;
  List<RbfHistory>? _rbfHistoryList;
  CpfpHistory? _cpfpHistory;

  /// Get the transaction hash of this transaction.
  String get transactionHash => _transactionHash;

  /// Get the timestamp of this transaction.
  DateTime get timestamp => _timestamp;

  /// Get the block height of this transaction.
  int get blockHeight => _blockHeight;

  /// Get the transaction type of this transaction. (RECEIVED, SEND, SELF, UNKNOWN)
  /// [TransactionType]
  String get transactionType => _transactionType;

  /// Get the memo of this transaction.
  String? get memo => _memo;

  /// Get the amount of this transaction.
  int get amount => _amount;

  /// Get the fee of this transaction.
  int get fee => _fee;

  /// Get the vSize of this transaction.
  double get vSize => _vSize;

  /// Get the fee rate of this transaction.
  double get feeRate => (_fee / _vSize * 100).ceil() / 100;

  /// Get the input address list of this transaction.
  List<TransactionAddress> get inputAddressList => _inputAddressList;

  /// Get the output address list of this transaction.
  List<TransactionAddress> get outputAddressList => _outputAddressList;

  /// Get the rbf history list of this transaction.
  List<RbfHistory>? get rbfHistoryList => _rbfHistoryList;

  /// Get the cpfp history of this transaction.
  CpfpHistory? get cpfpHistory => _cpfpHistory;

  /// @nodoc
  TransactionRecord(
      this._transactionHash,
      this._timestamp,
      this._blockHeight,
      this._transactionType,
      this._memo,
      this._amount,
      this._fee,
      this._inputAddressList,
      this._outputAddressList,
      this._vSize,
      this.createdAt,
      {List<RbfHistory>? rbfHistoryList,
      CpfpHistory? cpfpHistory})
      : _rbfHistoryList = rbfHistoryList,
        _cpfpHistory = cpfpHistory;

  factory TransactionRecord.fromTransactions({
    required String transactionHash,
    required DateTime timestamp,
    required int blockHeight,
    required String transactionType,
    required int amount,
    required int fee,
    required List<TransactionAddress> inputAddressList,
    required List<TransactionAddress> outputAddressList,
    required double vSize,
    String? memo,
  }) {
    return TransactionRecord(
      transactionHash,
      timestamp,
      blockHeight,
      transactionType,
      memo,
      amount,
      fee,
      inputAddressList,
      outputAddressList,
      vSize,
      DateTime.now(), // createdAt
    );
  }

  DateTime? getDateTimeToDisplay() {
    return timestamp;
  }
}

class RbfHistory {
  final double feeRate;
  final DateTime timestamp;
  final String transactionHash;

  RbfHistory({
    required this.feeRate,
    required this.timestamp,
    required this.transactionHash,
  });
}

class CpfpHistory {
  final double originalFee;
  final double newFee;
  final DateTime timestamp;
  final String parentTransactionHash;
  final String childTransactionHash;

  CpfpHistory({
    required this.originalFee,
    required this.newFee,
    required this.timestamp,
    required this.parentTransactionHash,
    required this.childTransactionHash,
  });
}
