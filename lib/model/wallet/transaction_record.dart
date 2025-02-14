import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';

class TransactionRecord {
  final String _transactionHash;
  final DateTime? _timestamp;
  final int? _blockHeight;
  final String? _transactionType;
  final String? _memo;
  final int? _amount;
  final int? _fee;
  final List<TransactionAddress> _inputAddressList;
  final List<TransactionAddress> _outputAddressList;

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
      this._outputAddressList);

  /// @nodoc
  factory TransactionRecord.fromTransactions(Transaction transaction) {
    dynamic addressBook;
    // TODO: timestamp
    var timestamp = DateTime.now();
    // var timestamp =
    //     DateTime.fromMillisecondsSinceEpoch(transaction.timestamp * 1000);
    var tx = Transaction.parse(transaction.serialize());

    int amount = 0;
    int fee = 0;
    List<TransactionAddress> inputAddressList = [];
    List<TransactionAddress> outputAddressList = [];
    int selfInputCount = 0;
    int selfOutputCount = 0;

    for (int i = 0; i < tx.inputs.length; ++i) {
      var input = tx.inputs[i];
      // TODO: perviousTransactionList
      throw UnimplementedError();
      // var inputTx = transaction.perviousTransactionList[i];
      // var inputTxOutput = inputTx.outputs[input.index];

      // String inputAddress = inputTxOutput.getAddress();
      // fee += inputTxOutput.amount;

      // String derivationPath = '';
      // if (addressBook.contains(inputAddress)) {
      //   derivationPath = addressBook.getDerivationPath(inputAddress);
      //   selfInputCount++;
      //   amount -= inputTxOutput.amount;
      // }

      // inputAddressList.add(Address(
      //     inputAddress, derivationPath, 0, false, inputTxOutput.amount));
    }

    for (var output in tx.outputs) {
      String outputAddress = output.getAddress();
      fee -= output.amount;

      String derivationPath = '';
      if (addressBook.contains(outputAddress)) {
        derivationPath = addressBook.getDerivationPath(outputAddress);
        selfOutputCount++;
        amount += output.amount;
      }

      outputAddressList.add(TransactionAddress(outputAddress, output.amount));
    }

    TransactionTypeEnum txType;
    if (selfInputCount > 0 &&
        selfOutputCount == tx.outputs.length &&
        selfInputCount == tx.inputs.length) {
      txType = TransactionTypeEnum.self;
    } else if (selfInputCount > 0 && selfOutputCount < tx.outputs.length) {
      txType = TransactionTypeEnum.sent;
    } else {
      txType = TransactionTypeEnum.received;
    }

    // TODO: transaction.height, memo
    return TransactionRecord(
      transaction.transactionHash,
      timestamp,
      0,
      txType.name,
      'memo',
      amount,
      fee,
      inputAddressList,
      outputAddressList,
    );
  }
}
