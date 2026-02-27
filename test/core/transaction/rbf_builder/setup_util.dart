import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_builder.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_preparer.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/output_analysis.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/packages/bc-ur-dart/lib/utils.dart';

import '../../../mock/transaction_record_mock.dart';

class RbfBuilderCreator {
  List<String> transactionHashes = [
    'd77dc64d3eb3454e9c65e5e36989af0eef349d824593dfe2a086fb9dadf7dfc4',
    '577a101d9bddd1ddee0d72a0853a8ca2d8b13d92c63f9a84277152ba791e426a',
    '00000000000000000000df7f314b2c650ceeea5fa862cc52b97ceae636955a38',
    '00000000000000000000cd1c9f4938ab95f28f5b4140c958aa526fe7b275f3bf',
    '00000000000000000000acf4baf6370a4d94c93b5fb067e945d32b3cc6fbcbdf',
    '00000000000000000001210c8dbcd22fcb3998e7adc1c5dcfa2b74352a844f18',
    '00000000000000000000a261a1e3cfd12d241b4d074205ea7cda9e8a042e1456',
    '00000000000000000000a261a1e3cfd12d241b4d074205ea7cda9e8a042e1456',
    '00000000000000000000a261a1e3cfd12d241b4d074205ea7cda9e8a042e1456',
    '00000000000000000000a261a1e3cfd12d241b4d074205ea7cda9e8a042e1456',
  ];

  List<String> externalWalletAddressList = [
    'bcrt1qxa3vg30kvqsd73knsv0dj8z26jx223chv8fzcx',
    'bcrt1q390yhj79g5elvhazvp3kc8p5srnnfxjwhnltwh',
    'bcrt1q5uvpgutqd75vlzjd5scxxh0dd7xlannwql97f7',
    'bcrt1qtevwltqgx4k40gvkrgj2aevavzsnlrllxgp5gk',
    'bcrt1q02q4m5venfhucsvym5fadkftph0szumuuwdcf9',
  ];

  final WalletListItemBase _walletListItemBase;
  late final List<String> receiveAddressList = [];
  late final List<String> changeAddressList = [];
  late final String derivationPathPrefix;

  RbfBuilderCreator(this._walletListItemBase) {
    NetworkType.setNetworkType(NetworkType.regtest);

    for (int i = 0; i < 10; i++) {
      receiveAddressList.add(_walletListItemBase.walletBase.getAddress(i));
      changeAddressList.add(_walletListItemBase.walletBase.getAddress(i, isChange: true));
    }

    derivationPathPrefix =
        _walletListItemBase.walletType == WalletType.singleSignature ? "m/84'/1'/0'" : "m/48'/1'/0'/2'";
  }

  bool isMyAddress(String address, {bool isChange = false}) {
    if (isChange) {
      return changeAddressList.contains(address);
    }

    return receiveAddressList.contains(address);
  }

  String getDerivationPath(int walletId, String address) {
    if (walletId == _walletListItemBase.id) {
      final index = receiveAddressList.indexOf(address);
      if (index != -1) {
        return "$derivationPathPrefix/0/$index";
      }

      final changeIndex = changeAddressList.indexOf(address);
      if (changeIndex != -1) {
        return "$derivationPathPrefix/1/$changeIndex";
      }
      return '';
    } else {
      throw UnimplementedError();
    }
  }

  (TransactionRecord, RbfBuilder) createRbfBuilder({
    required List<int> inputAmounts,
    required List<Tuple<bool, int>> recipients,
    required int changeAmount,
    required int fee,
    required double vSize,
    List<int> additionalSpendable = const [],
  }) {
    final List<TransactionAddress> inputAddressList = [];
    final List<UtxoState> inputUtxos = [];
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

    final List<UtxoState> additionalUtxos = [];
    for (int i = 0; i < additionalSpendable.length; i++) {
      additionalUtxos.add(
        UtxoState(
          transactionHash: transactionHashes[inputAmounts.length + i],
          index: i,
          amount: additionalSpendable[i],
          blockHeight: 100 + inputAmounts.length + i,
          to: receiveAddressList[inputAmounts.length + i],
          derivationPath: "$derivationPathPrefix/0/${inputAmounts.length + i}",
          timestamp: DateTime.now(),
        ),
      );
    }

    final List<TransactionAddress> outputAddressList = [];
    int internalAddressIndex = inputAmounts.length;
    for (int i = 0; i < recipients.length; i++) {
      if (recipients[i].item1) {
        outputAddressList.add(TransactionAddress(receiveAddressList[internalAddressIndex++], recipients[i].item2));
      } else {
        outputAddressList.add(TransactionAddress(externalWalletAddressList[i], recipients[i].item2));
      }
    }

    if (changeAmount != 0) {
      outputAddressList.add(TransactionAddress(changeAddressList[0], changeAmount));
    }

    final pendingTx = TransactionRecordMock.createMockTransactionRecord(
      inputAddressList: inputAddressList,
      outputAddressList: outputAddressList,
      amount: recipients.fold(0, (sum, recipient) => sum + recipient.item2),
      fee: fee,
      vSize: vSize,
    );

    // Create RbfPreparer directly
    final preparer = RbfPreparer(
      pendingTx: pendingTx,
      inputUtxos: inputUtxos,
      outputAnalysis: OutputAnalysis.fromPendingTx(
        pendingTx: pendingTx,
        isMyAddress: isMyAddress,
        getDerivationPath: (address) => getDerivationPath(_walletListItemBase.id, address),
      ),
    );

    return (
      pendingTx,
      RbfBuilder(
        preparer: preparer,
        walletListItemBase: _walletListItemBase,
        nextChangeAddress: WalletAddress(changeAddressList[1], "$derivationPathPrefix/1/1", 1, true, false, 0, 0, 0),
        additionalSpendable: additionalUtxos,
      ),
    );
  }
}
