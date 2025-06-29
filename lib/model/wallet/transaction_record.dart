import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/cpfp_history.dart';
import 'package:coconut_wallet/model/node/rbf_history.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';

class TransactionRecord {
  final String _transactionHash;
  final DateTime _timestamp;
  final int _blockHeight;
  TransactionType _transactionType;
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
  TransactionType get transactionType => _transactionType;

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
    required TransactionType transactionType,
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

  @override
  bool operator ==(Object other) {
    if (other is TransactionRecord) {
      return transactionHash == other.transactionHash && blockHeight == other.blockHeight;
    }
    return false;
  }

  @override
  int get hashCode => transactionHash.hashCode ^ blockHeight.hashCode;

  /// 트랜잭션 내용이 변경되었는지 감지하기 위한 컨텐트 해시
  /// UI 업데이트 감지용으로 사용됩니다.
  int get contentHashCode {
    // TransactionAddress의 hashCode를 활용하여 더 깔끔하게 처리
    final inputHash = Object.hashAll(inputAddressList);
    final outputHash = Object.hashAll(outputAddressList);

    return Object.hash(
      transactionHash,
      blockHeight,
      amount,
      fee,
      feeRate,
      memo,
      transactionType,
      inputHash,
      outputHash,
    );
  }

  /// 트랜잭션 내용 변경 감지를 위한 고유한 키 생성
  /// Flutter 위젯의 Key로 사용하여 내용이 변경될 때 위젯을 재생성합니다.
  String get contentKey => contentHashCode.toString();
}
