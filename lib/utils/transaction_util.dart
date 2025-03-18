import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';

class TransactionUtil {
  static TransactionStatus? getStatus(TransactionRecord tx) {
    if (tx.transactionType == TransactionType.received.name) {
      if (tx.blockHeight == 0 || tx.blockHeight == null) {
        return TransactionStatus.receiving;
      }
      return TransactionStatus.received;
    }
    if (tx.transactionType == TransactionType.sent.name) {
      if (tx.blockHeight == 0 || tx.blockHeight == null) {
        return TransactionStatus.sending;
      }
      return TransactionStatus.sent;
    }
    if (tx.transactionType == TransactionType.self.name) {
      if (tx.blockHeight == 0 || tx.blockHeight == null) {
        return TransactionStatus.selfsending;
      }
      return TransactionStatus.self;
    }

    return null;
  }

  static String getInputAddress(TransactionRecord? transaction, index) =>
      _getTransactionField<String>(transaction, index,
          (tx) => transaction!.inputAddressList, (item) => item.address,
          defaultValue: '');

  static String getOutputAddress(TransactionRecord? transaction, int index) =>
      _getTransactionField<String>(transaction, index,
          (tx) => transaction!.outputAddressList, (item) => item.address,
          defaultValue: '');

  static int getInputAmount(TransactionRecord? transaction, int index) =>
      _getTransactionField<int>(transaction, index,
          (tx) => transaction!.inputAddressList, (item) => item.amount,
          defaultValue: 0);

  static int getOutputAmount(TransactionRecord? transaction, int index) =>
      _getTransactionField<int>(transaction, index,
          (tx) => transaction!.outputAddressList, (item) => item.amount,
          defaultValue: 0);

  static T _getTransactionField<T>(
    TransactionRecord? transaction,
    int index,
    List<dynamic> Function(TransactionRecord) listSelector,
    T Function(dynamic) valueSelector, {
    required T defaultValue,
  }) {
    if (transaction == null) return defaultValue;

    final list = listSelector(transaction);
    if (index < 0 || index >= list.length) return defaultValue;

    return valueSelector(list[index]);
  }

  /// confirmed uxto만 사용 가능
  static List<UtxoState> selectOptimalUtxos(List<UtxoState> utxoList,
      int amount, int feeRate, AddressType addressType) {
    int baseVbyte = 72; // 0 input, 2 output
    int vBytePerInput = 0;
    int dust = _getDustThreshold(addressType);
    if (addressType.isSegwit) {
      vBytePerInput = 68; //segwit discount
    } else {
      vBytePerInput = 148;
    }
    List<UtxoState> selectedUtxos = [];
    List<UtxoState> unspentUtxos = utxoList
        .where((u) => u.status == UtxoStatus.unspent)
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    // List<UtxoState> incomingUtxos = utxoList
    //     .where((u) => u.status == UtxoStatus.incoming)
    //     .toList()
    //   ..sort((a, b) => b.amount.compareTo(a.amount));

    int totalAmount = 0;
    int totalVbyte = baseVbyte;
    int finalFee = 0;

    void selectFrom(List<UtxoState> source) {
      for (UtxoState utxo in source) {
        totalAmount += utxo.amount;
        selectedUtxos.add(utxo);
        totalVbyte += vBytePerInput;
        finalFee = totalVbyte * feeRate;
        if (totalAmount >= amount + finalFee + dust) {
          return;
        }
      }
    }

    // 우선 unspent UTXO 사용
    selectFrom(unspentUtxos);

    // 부족하면 incoming UTXO 추가
    // if (totalAmount < amount + finalFee + dust) {
    //   selectFrom(incomingUtxos);
    // }

    if (totalAmount < amount + finalFee + dust) {
      throw Exception('Not enough amount for sending. (Fee : $finalFee)');
    }

    return selectedUtxos;
  }

  static int _getDustThreshold(AddressType addressType) {
    if (addressType == AddressType.p2wpkh) {
      return 294;
    } else if (addressType == AddressType.p2wsh || addressType.isTaproot) {
      return 330;
    } else if (addressType == AddressType.p2pkh) {
      return 546;
    } else if (addressType == AddressType.p2sh) {
      return 888;
    } else if (addressType == AddressType.p2wpkhInP2sh) {
      return 273;
    } else {
      throw Exception('Unsupported Address Type');
    }
  }

  /// 코인베이스 트랜잭션 여부를 확인합니다.
  static bool isCoinbaseTransaction(Transaction tx) {
    if (tx.inputs.length != 1) {
      return false;
    }

    if (tx.inputs[0].transactionHash !=
        '0000000000000000000000000000000000000000000000000000000000000000') {
      return false;
    }

    return tx.inputs[0].index == 4294967295; // 0xffffffff
  }
}
