import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/cpfp_builder.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/cpfp_preparer.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';

import '../../../mock/transaction_record_mock.dart';

class CpfpBuilderCreator {
  List<String> additionalSpendableTxHashes = [
    '577a101d9bddd1ddee0d72a0853a8ca2d8b13d92c63f9a84277152ba791e426a',
    '00000000000000000000df7f314b2c650ceeea5fa862cc52b97ceae636955a38',
    '00000000000000000000cd1c9f4938ab95f28f5b4140c958aa526fe7b275f3bf',
    '00000000000000000000acf4baf6370a4d94c93b5fb067e945d32b3cc6fbcbdf',
    '00000000000000000001210c8dbcd22fcb3998e7adc1c5dcfa2b74352a844f18',
    '00000000000000000000a261a1e3cfd12d241b4d074205ea7cda9e8a042e1456',
  ];

  /// 부모 tx의 input (외부 → 나에게 보내는 sender 주소)
  List<String> externalWalletAddressList = [
    'bcrt1qxa3vg30kvqsd73knsv0dj8z26jx223chv8fzcx',
    'bcrt1q390yhj79g5elvhazvp3kc8p5srnnfxjwhnltwh',
    'bcrt1q5uvpgutqd75vlzjd5scxxh0dd7xlannwql97f7',
  ];

  /// 부모 tx의 hash (고정값 사용)
  static const String pendingTxHash = 'd77dc64d3eb3454e9c65e5e36989af0eef349d824593dfe2a086fb9dadf7dfc4';

  final WalletListItemBase _walletListItemBase;
  late final List<String> receiveAddressList = [];
  late final List<String> changeAddressList = [];
  late final String derivationPathPrefix;

  CpfpBuilderCreator(this._walletListItemBase) {
    NetworkType.setNetworkType(NetworkType.regtest);

    for (int i = 0; i < 10; i++) {
      receiveAddressList.add(_walletListItemBase.walletBase.getAddress(i));
      changeAddressList.add(_walletListItemBase.walletBase.getAddress(i, isChange: true));
    }

    derivationPathPrefix =
        _walletListItemBase.walletType == WalletType.singleSignature ? "m/84'/1'/0'" : "m/48'/1'/0'/2'";
  }

  bool isMyAddress(String address, {bool isChange = false}) {
    if (isChange) return changeAddressList.contains(address);
    return receiveAddressList.contains(address);
  }

  /// 테스트용 CPFP 빌더 생성
  ///
  /// [receivedAmounts]: 부모 tx에서 내가 받은 output 금액 목록
  ///   (각 output은 receiveAddressList[i]로 수신됨)
  /// [parentFee]: 부모 tx 수수료 (sats)
  /// [parentVSize]: 부모 tx vSize
  (TransactionRecord, CpfpBuilder) createCpfpBuilder({
    required List<int> receivedAmounts,
    required int parentFee,
    required double parentVSize,
    required double minimumNetworkFeeRate,
    List<int> additionalSpendables = const [],
  }) {
    // 부모 tx의 outputAddressList: 내 receive 주소들 (index 0~n-1)
    final List<TransactionAddress> outputAddressList = [];
    for (int i = 0; i < receivedAmounts.length; i++) {
      outputAddressList.add(TransactionAddress(receiveAddressList[i], receivedAmounts[i]));
    }

    // 부모 tx의 inputAddressList: 외부 주소들 (송금자)
    final List<TransactionAddress> inputAddressList = [
      TransactionAddress(externalWalletAddressList[0], receivedAmounts.fold(0, (s, a) => s + a) + parentFee),
    ];

    final pendingTx = TransactionRecordMock.createMockTransactionRecord(
      transactionHash: pendingTxHash,
      inputAddressList: inputAddressList,
      outputAddressList: outputAddressList,
      amount: receivedAmounts.fold(0, (s, a) => s + a),
      fee: parentFee,
      vSize: parentVSize,
      transactionType: TransactionType.received,
    );

    // 수신 UTXO 생성 (isCpfpable: incoming, blockHeight=0)
    final List<UtxoState> receivedUtxos = [];
    for (int i = 0; i < receivedAmounts.length; i++) {
      receivedUtxos.add(
        UtxoState(
          transactionHash: pendingTxHash,
          index: i,
          amount: receivedAmounts[i],
          blockHeight: 0,
          to: receiveAddressList[i],
          derivationPath: "$derivationPathPrefix/0/$i",
          timestamp: DateTime.now(),
          status: UtxoStatus.incoming,
        ),
      );
    }

    final preparer = CpfpPreparer(pendingTx: pendingTx, receivedUtxos: receivedUtxos);

    // child tx의 sweep 대상: 다음 receive 주소 (receivedAmounts.length 번째)
    final nextReceiveIndex = receivedAmounts.length;
    final nextReceiveAddress = WalletAddress(
      receiveAddressList[nextReceiveIndex],
      "$derivationPathPrefix/0/$nextReceiveIndex",
      nextReceiveIndex,
      false,
      false,
      0,
      0,
      0,
    );

    final additionalUtxos = createAdditionalUtxos(
      amounts: additionalSpendables,
      startAddressIndex: nextReceiveIndex + 1,
    );

    return (
      pendingTx,
      CpfpBuilder(
        preparer: preparer,
        walletListItemBase: _walletListItemBase,
        nextReceiveAddress: nextReceiveAddress,
        minimumFeeRate: minimumNetworkFeeRate,
        additionalSpendable: additionalUtxos,
      ),
    );
  }

  List<UtxoState> createAdditionalUtxos({required List<int> amounts, int startAddressIndex = 3}) {
    final List<UtxoState> utxos = [];
    for (int i = 0; i < amounts.length; i++) {
      final addressIndex = startAddressIndex + i;
      utxos.add(
        UtxoState(
          transactionHash: additionalSpendableTxHashes[i],
          index: i,
          amount: amounts[i],
          blockHeight: 1,
          to: receiveAddressList[addressIndex],
          derivationPath: "$derivationPathPrefix/0/$addressIndex",
          timestamp: DateTime.now(),
          status: UtxoStatus.unspent,
        ),
      );
    }
    return utxos;
  }
}
