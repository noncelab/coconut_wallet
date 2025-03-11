import 'package:coconut_wallet/model/wallet/transaction_address.dart';

class TransactionRecord {
  final String _transactionHash;
  final DateTime? _timestamp;
  final int? _blockHeight;
  String? _transactionType;
  String? _memo;
  int? _amount;
  int? _fee;
  List<TransactionAddress> _inputAddressList;
  List<TransactionAddress> _outputAddressList;
  DateTime? createdAt;
  int _vSize;

  /// Get the transaction hash of this transaction.
  String get transactionHash => _transactionHash;

  /// Get the timestamp of this transaction.
  DateTime? get timestamp => _timestamp;

  /// Get the block height of this transaction.
  int? get blockHeight => _blockHeight;

  /// Get the transaction type of this transaction. (RECEIVED, SEND, SELF, UNKNOWN)
  String? get transactionType => _transactionType;

  /// Get the memo of this transaction.
  String? get memo => _memo;

  /// Get the amount of this transaction.
  int? get amount => _amount;

  /// Get the fee of this transaction.
  int? get fee => _fee;

  /// Get the vSize of this transaction.
  int get vSize => _vSize;

  /// Get the fee rate of this transaction.
  double get feeRate => _fee != null ? (_fee! / _vSize * 100).floor() / 100 : 0;

  /// Get the input address list of this transaction.
  List<TransactionAddress> get inputAddressList => _inputAddressList;

  /// Get the output address list of this transaction.
  List<TransactionAddress> get outputAddressList => _outputAddressList;

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
      this.createdAt);

  factory TransactionRecord.fromTransactions({
    required String transactionHash,
    required DateTime timestamp,
    required int blockHeight,
    required String transactionType,
    required int amount,
    required int fee,
    required List<TransactionAddress> inputAddressList,
    required List<TransactionAddress> outputAddressList,
    required int vSize,
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
