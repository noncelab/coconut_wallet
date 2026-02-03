import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/core/transaction/rbf_builder.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/packages/bc-ur-dart/lib/utils.dart';
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

  List<String> transactionHashes = [
    'd77dc64d3eb3454e9c65e5e36989af0eef349d824593dfe2a086fb9dadf7dfc4',
    '577a101d9bddd1ddee0d72a0853a8ca2d8b13d92c63f9a84277152ba791e426a',
  ];

  List<String> externalWalletAddressList = [
    'bcrt1qxa3vg30kvqsd73knsv0dj8z26jx223chv8fzcx',
    'bcrt1q390yhj79g5elvhazvp3kc8p5srnnfxjwhnltwh',
    'bcrt1q5uvpgutqd75vlzjd5scxxh0dd7xlannwql97f7',
    'bcrt1qtevwltqgx4k40gvkrgj2aevavzsnlrllxgp5gk',
    'bcrt1q02q4m5venfhucsvym5fadkftph0szumuuwdcf9',
  ];
  NetworkType.setNetworkType(NetworkType.regtest);

  RbfBuilder createRbfBuilder({
    required List<int> inputAmounts,
    required List<Tuple<bool, int>> recipients,
    required int changeAmount,
    required int fee,
    required double vSize,
    List<UtxoState>? additionalSpendable,
    required bool isMultiSig,
  }) {
    final List<TransactionAddress> inputAddressList = [];
    final List<UtxoState> inputUtxos = [];
    final derivationPathPrefix = isMultiSig ? "m/48'/1'/0'/2'" : "m/84'/1'/0'";
    for (int i = 0; i < inputAmounts.length; i++) {
      inputAddressList.add(TransactionAddress(receiveAddressList[i], inputAmounts[i]));
      inputUtxos.add(
        UtxoState(
          transactionHash: transactionHashes[i],
          index: i,
          amount: inputAmounts[i],
          blockHeight: 100 + i,
          to: receiveAddressList[i],
          derivationPath: "$derivationPathPrefix/0/$i",
          timestamp: DateTime.now(),
        ),
      );
    }

    final List<TransactionAddress> outputAddressList = [];
    for (int i = 0; i < recipients.length; i++) {
      if (recipients[i].item1) {
        outputAddressList.add(TransactionAddress(receiveAddressList[inputAmounts.length + i], recipients[i].item2));
      } else {
        outputAddressList.add(TransactionAddress(externalWalletAddressList[i], recipients[i].item2));
      }
    }

    if (changeAmount != 0) {
      outputAddressList.add(TransactionAddress(changeAddressList[0], changeAmount));
    }

    final TransactionRecord pendingTx = TransactionRecordMock.createMockTransactionRecord(
      inputAddressList: inputAddressList,
      outputAddressList: outputAddressList,
      amount: recipients.fold(0, (sum, recipient) => sum + recipient.item2),
      fee: fee,
      vSize: vSize,
    );

    return RbfBuilder(
      pendingTx: pendingTx,
      walletListItemBase: multiWallet,
      vSizeIncreasePerInput: isMultiSig ? 91 : 56,
      isMyAddress: isMyAddress,
      inputUtxos: inputUtxos,
      nextChangeAddress: WalletAddress(changeAddressList[1], "$derivationPathPrefix/1/1", 1, true, false, 0, 0, 0),
      getDerivationPath: getDerivationPath,
      dustLimit: dustLimit,
    );
  }

  group('멀티시그지갑 - InputSum enough', () {
    test('External 1 / InputSum enough', () async {
      final rbfBuilder = createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(false, 1000)],
        changeAmount: 98811,
        fee: 189,
        vSize: 189,
        isMultiSig: true,
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
      final rbfBuilder = createRbfBuilder(
        inputAmounts: [200000],
        recipients: [Tuple(false, 10000), Tuple(false, 20000), Tuple(false, 30000)],
        changeAmount: 139749,
        fee: 251,
        vSize: 251,
        isMultiSig: true,
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

  group('멀티시그지갑 - InputSum not enough / selfOutput 사용', () {
    test('selfOutput 1 / no change / selfOutput 1개의 amount를 차감하여 성공🟢', () async {
      final rbfBuilder = createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(true, 99000)],
        changeAmount: 0,
        fee: 1000,
        vSize: 1000,
        isMultiSig: true,
      );

      final RbfBuildResult result = await rbfBuilder.buildRbfTransaction(newFeeRate: 10.0, additionalSpendable: []);

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.isSelfOutputsUsed, isTrue);
      expect(result.isOnlyChangeOutputUsed, isFalse);
      expect(result.addedUtxos, isNull);
      expect(result.deficitAmount, isNull);

      final tx = result.transaction!;
      final int totalInput = tx.totalInputAmount; // 100,000
      final int totalOutput = tx.outputs.fold(0, (sum, out) => sum + out.amount);
      final int actualFee = totalInput - totalOutput;
      final double vByte =
          tx.estimateVirtualByte(AddressType.p2wsh, requiredSignature: 2, totalSigner: 3).ceil().toDouble();
      final double calculatedFeeRate = actualFee / vByte;

      expect(tx.outputs.length, 1);
      expect(actualFee, 1580);
      expect(calculatedFeeRate, 10.0);
    });
  });
}
