import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/core/transaction/rbf_builder.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/transaction_record_mock.dart';
import '../../../mock/wallet_mock.dart';

void main() {
  MultisigWalletListItem multiWallet = WalletMock.createMultiSigWalletItem();

  List<String> receiveAddressList = [];
  List<String> changeAddressList = [];
  for (int i = 0; i < 10; i++) {
    receiveAddressList.add(multiWallet.walletBase.getAddress(i));
    changeAddressList.add(multiWallet.walletBase.getAddress(i, isChange: true));
  }

  bool isMyAddress(String address, {bool isChange = false}) {
    if (isChange) {
      return changeAddressList.contains(address);
    }

    return receiveAddressList.contains(address);
  }

  String getDerivationPath(int walletId, String address) {
    String prefix = "m/48'/1'/0'/2'";
    if (walletId == multiWallet.id) {
      final index = receiveAddressList.indexOf(address);
      if (index != -1) {
        return "$prefix/0/$index";
      }

      final changeIndex = changeAddressList.indexOf(address);
      if (changeIndex != -1) {
        return "$prefix/1/$changeIndex";
      }
      return '';
    } else {
      throw UnimplementedError();
    }
  }

  /// utxo_selector에서 amount순으로 정렬됨
  late List<UtxoState> multiWalletInputUtxos = [
    UtxoState(
      transactionHash: 'd77dc64d3eb3454e9c65e5e36989af0eef349d824593dfe2a086fb9dadf7dfc4',
      index: 0,
      amount: 100000, // 0.001 BTC
      blockHeight: 100,
      to: receiveAddressList[0],
      derivationPath: "m/48'/1'/0'/2'/0/0",
      timestamp: DateTime.now(),
    ),
    UtxoState(
      transactionHash: '577a101d9bddd1ddee0d72a0853a8ca2d8b13d92c63f9a84277152ba791e426a',
      index: 1,
      amount: 200000, // 0.002 BTC
      blockHeight: 101,
      to: receiveAddressList[1],
      derivationPath: "m/48'/1'/0'/2'/0/1",
      timestamp: DateTime.now(),
    ),
  ];

  List<String> externalWalletAddressList = [
    'bcrt1qxa3vg30kvqsd73knsv0dj8z26jx223chv8fzcx',
    'bcrt1q390yhj79g5elvhazvp3kc8p5srnnfxjwhnltwh',
    'bcrt1q5uvpgutqd75vlzjd5scxxh0dd7xlannwql97f7',
    'bcrt1qtevwltqgx4k40gvkrgj2aevavzsnlrllxgp5gk',
    'bcrt1q02q4m5venfhucsvym5fadkftph0szumuuwdcf9',
  ];
  NetworkType.setNetworkType(NetworkType.regtest);

  group('멀티시그지갑 - InputSum enough', () {
    test('External 1 / InputSum enough', () async {
      final List<TransactionAddress> inputAddressList = [TransactionAddress(receiveAddressList[0], 100000)];
      final List<UtxoState> inputUtxos = [multiWalletInputUtxos[0]];
      final List<TransactionAddress> outputAddressList = [
        TransactionAddress(externalWalletAddressList[0], 1000),
        TransactionAddress(changeAddressList[0], 98000),
      ];
      final TransactionRecord pendingTx = TransactionRecordMock.createMockTransactionRecord(
        inputAddressList: inputAddressList,
        outputAddressList: outputAddressList,
        amount: 1000,
      );

      final rbfBuilder = RbfBuilder(
        pendingTx: pendingTx,
        walletListItemBase: multiWallet,
        vSizeIncreasePerInput: 91,
        isMyAddress: isMyAddress,
        inputUtxos: inputUtxos,
        nextChangeAddress: WalletAddress(changeAddressList[1], "m/48'/1'/0'/2'/1/1", 1, true, false, 0, 0, 0),
        getDerivationPath: getDerivationPath,
        dustLimit: dustLimit,
      );

      final RbfBuildResult result = await rbfBuilder.buildRbfTransaction(newFeeRate: 2.0, additionalSpendable: []);

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.isOnlyChangeOutputUsed, isTrue);
      expect(result.isSelfOutputsUsed, isFalse);

      final tx = result.transaction!;
      final int totalInput = tx.totalInputAmount;
      final int totalOutput = tx.outputs.fold(0, (sum, out) => sum + out.amount);
      final int actualFee = totalInput - totalOutput;
      final double vByte =
          tx.estimateVirtualByte(AddressType.p2wsh, requiredSignature: 2, totalSigner: 3).ceil().toDouble();
      final double calculatedFeeRate = actualFee / vByte;
      final int expectedChange = totalInput - 1000 - actualFee;

      expect(rbfBuilder.nonChangeOutputs.length, 1);
      expect(rbfBuilder.nonChangeOutputsSum, 1000);
      expect(calculatedFeeRate, 2.0);
      expect(expectedChange, equals(98622));
    });
    test('External 3 / InputSum enough', () async {
      final List<TransactionAddress> inputAddressList = [TransactionAddress(receiveAddressList[1], 200000)];
      final List<UtxoState> inputUtxos = [multiWalletInputUtxos[1]];
      final List<TransactionAddress> outputAddressList = [
        TransactionAddress(externalWalletAddressList[0], 10000),
        TransactionAddress(externalWalletAddressList[1], 20000),
        TransactionAddress(externalWalletAddressList[2], 30000),
        TransactionAddress(changeAddressList[0], 139000),
      ];

      final TransactionRecord pendingTx = TransactionRecordMock.createMockTransactionRecord(
        inputAddressList: inputAddressList,
        outputAddressList: outputAddressList,
        amount: 60000,
      );

      final rbfBuilder = RbfBuilder(
        pendingTx: pendingTx,
        walletListItemBase: multiWallet,
        vSizeIncreasePerInput: 91,
        isMyAddress: isMyAddress,
        inputUtxos: inputUtxos,
        nextChangeAddress: WalletAddress(changeAddressList[1], "m/48'/1'/0'/2'/1/1", 1, true, false, 0, 0, 0),
        getDerivationPath: getDerivationPath,
        dustLimit: dustLimit,
      );

      final RbfBuildResult result = await rbfBuilder.buildRbfTransaction(newFeeRate: 3.0, additionalSpendable: []);

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.isOnlyChangeOutputUsed, isTrue);

      final tx = result.transaction!;
      final int totalInput = tx.totalInputAmount;
      final int totalOutput = tx.outputs.fold(0, (sum, out) => sum + out.amount);
      final int actualFee = tx.totalInputAmount - totalOutput;
      final double vByte =
          tx.estimateVirtualByte(AddressType.p2wsh, requiredSignature: 2, totalSigner: 3).ceil().toDouble();
      final double calculatedFeeRate = actualFee / vByte;
      final int expectedChange = totalInput - 60000 - actualFee;

      expect(totalInput, 200000);
      expect(rbfBuilder.nonChangeOutputs.length, 3);
      expect(rbfBuilder.nonChangeOutputsSum, 60000);
      expect(calculatedFeeRate, 3.0);
      expect(expectedChange, equals(139247));
    });
  });
}
