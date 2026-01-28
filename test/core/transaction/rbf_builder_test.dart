import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/core/exceptions/transaction_creation/transaction_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/rbf_builder.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/transaction_record_mock.dart';
import '../../mock/wallet_mock.dart';

void main() {
  SinglesigWalletListItem singleWallet = WalletMock.createSingleSigWalletItem();

  List<String> receiveAddressList = [];
  List<String> changeAddressList = [];
  for (int i = 0; i < 10; i++) {
    receiveAddressList.add(singleWallet.walletBase.getAddress(i));
    changeAddressList.add(singleWallet.walletBase.getAddress(i, isChange: true));
  }

  bool isMyAddress(String address, {bool isChange = false}) {
    if (isChange) {
      return changeAddressList.contains(address);
    }

    return receiveAddressList.contains(address);
  }

  String getDerivationPath(int walletId, String address) {
    String prefix = "m/84'/1'/0'";
    if (walletId == singleWallet.id) {
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
  late List<UtxoState> singleWalletInputUtxos = [
    UtxoState(
      transactionHash: 'd77dc64d3eb3454e9c65e5e36989af0eef349d824593dfe2a086fb9dadf7dfc4',
      index: 0,
      amount: 100000, // 0.001 BTC
      blockHeight: 100,
      to: receiveAddressList[0],
      derivationPath: "m/84'/1'/0'/0/0",
      timestamp: DateTime.now(),
    ),
    UtxoState(
      transactionHash: '577a101d9bddd1ddee0d72a0853a8ca2d8b13d92c63f9a84277152ba791e426a',
      index: 1,
      amount: 200000, // 0.002 BTC
      blockHeight: 101,
      to: receiveAddressList[1],
      derivationPath: "m/84'/1'/0'/0/1",
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

  group('변수 생성 테스트', () {
    test('External 1 / 모든 getter들 정합성 확인', () {
      final List<TransactionAddress> inputAddressList = [TransactionAddress(receiveAddressList[0], 100000)];
      final List<UtxoState> inputUtxos = [singleWalletInputUtxos[0]];
      final List<TransactionAddress> outputAddressList = [
        TransactionAddress(externalWalletAddressList[0], 1000),
        TransactionAddress(changeAddressList[0], 99000),
      ];
      final TransactionRecord pendingTx = TransactionRecordMock.createMockTransactionRecord(
        inputAddressList: inputAddressList,
        outputAddressList: outputAddressList,
        amount: 1000,
      );

      final rbfBuilder = RbfBuilder(
        pendingTx: pendingTx,
        walletListItemBase: singleWallet,
        vSizeIncreasePerInput: 56,
        isMyAddress: isMyAddress,
        inputUtxos: inputUtxos,
        nextChangeAddress: WalletAddress(changeAddressList[1], "m/84'/1'/0'/0/1", 1, true, false, 0, 0, 0),
        getDerivationPath: getDerivationPath,
        dustLimit: dustLimit,
      );

      expect(rbfBuilder.nonChangeOutputs.length, 1);
      expect(rbfBuilder.nonChangeOutputsSum, 1000);
      expect(rbfBuilder.recipientMap.length, 1);
      expect(rbfBuilder.recipientMap[externalWalletAddressList[0]], 1000);
      expect(rbfBuilder.changeOutput, isNotNull);
      expect(rbfBuilder.changeOutput!.address, changeAddressList[0]);
      expect(rbfBuilder.changeOutput!.amount, 99000);
      expect(rbfBuilder.changeOutputDerivationPath, isNotNull);
      expect(rbfBuilder.changeOutputDerivationPath, "m/84'/1'/0'/1/0");
      expect(rbfBuilder.selfOutputs, isNull);
      expect(rbfBuilder.selfOutputs, isNull);
      expect(rbfBuilder.externalOutputs, isNotNull);
      expect(rbfBuilder.externalOutputs!.length, 1);
      expect(rbfBuilder.externalOutputs![0].address, externalWalletAddressList[0]);
      expect(rbfBuilder.externalOutputs![0].amount, 1000);
      expect(rbfBuilder.sendAmount, 1000);
      expect(rbfBuilder.inputSum, 100000);
    });

    test('External 1 / 그 중 1개가 selfOutputs / 모든 getter들 정합성 확인', () {
      // TODO:
    });

    test('External 3 / 그 중 2개가 selfOutputs / 모든 getter들 정합성 확인', () {
      // TODO:
    });

    test('Invalid getDerivationPath 함수 전달 시 InvalidChangeOutputException 발생', () {
      // TODO:
    });
  });

  group('싱글시그지갑 - InputSum enough', () {
    test('External 1 / InputSum enough', () async {
      final List<TransactionAddress> inputAddressList = [TransactionAddress(receiveAddressList[0], 100000)];
      final List<UtxoState> inputUtxos = [singleWalletInputUtxos[0]];
      final List<TransactionAddress> outputAddressList = [
        TransactionAddress(externalWalletAddressList[0], 1000),
        TransactionAddress(changeAddressList[0], 99000),
      ];
      final TransactionRecord pendingTx = TransactionRecordMock.createMockTransactionRecord(
        inputAddressList: inputAddressList,
        outputAddressList: outputAddressList,
        amount: 1000,
      );

      final rbfBuilder = RbfBuilder(
        pendingTx: pendingTx,
        walletListItemBase: singleWallet,
        vSizeIncreasePerInput: 56,
        isMyAddress: isMyAddress,
        inputUtxos: inputUtxos,
        nextChangeAddress: WalletAddress(changeAddressList[1], "m/84'/1'/0'/0/1", 1, true, false, 0, 0, 0),
        getDerivationPath: getDerivationPath,
        dustLimit: dustLimit,
      );

      final RbfBuildResult result = await rbfBuilder.buildRbfTransaction(
        newFeeRate: 2.0,
        additionalSpendable: [],
        getChangeAddress: () => changeAddressList[1],
      );

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.isChangeOutputUsed, isTrue);
      expect(result.isSelfOutputsUsed, isFalse);
      expect(result.addedUtxos, isNull);
      expect(result.deficitAmount, isNull);
    });

    test('External 2 / InputSum enough', () async {});

    test('External 2 / InputSum enough', () async {});
  });

  group('예외 상황', () async {
    test('newFeeRate가 pendingTx.feeRate보다 작으면 FeeRateTooLowException 발생', () async {
      // TODO:
    });
  });
}
