import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/core/exceptions/rbf_creation/rbf_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/rbf_builder.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/transaction_record_mock.dart';
import '../../../mock/wallet_mock.dart';

void main() {
  // TODO: 아래 준비 변수, 함수들을 멀티시그용으로 수정

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

  group('멀티시그지갑 - InputSum enough', () {
    test('External 1 / InputSum enough', () async {
      final List<TransactionAddress> inputAddressList = [TransactionAddress(receiveAddressList[0], 100000)];
      final List<UtxoState> inputUtxos = [singleWalletInputUtxos[0]];
      final List<TransactionAddress> outputAddressList = [
        TransactionAddress(externalWalletAddressList[0], 1000),
        TransactionAddress(changeAddressList[0], 98859),
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

      final RbfBuildResult result = await rbfBuilder.buildRbfTransaction(newFeeRate: 2.0, additionalSpendable: []);

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.isChangeOutputUsed, isTrue);
      expect(result.isSelfOutputsUsed, isFalse);
      expect(result.addedUtxos, isNull);
      expect(result.deficitAmount, isNull);

      final tx = result.transaction!;
      final int totalInput = tx.totalInputAmount;
      final int totalOutput = tx.outputs.fold(0, (sum, out) => sum + out.amount);
      final int actualFee = totalInput - totalOutput;
      final double vByte = tx.estimateVirtualByte(AddressType.p2wpkh).ceil().toDouble();
      final double calculatedFeeRate = actualFee / vByte;
      final int changeAmount = totalInput - 1000 - actualFee;

      expect(calculatedFeeRate, 2.0);
      expect(changeAmount, equals(98718)); // 98859 - 141
    });

    test('External 3 / InputSum enough', () async {
      // TODO: 구현
    });
  });
}
