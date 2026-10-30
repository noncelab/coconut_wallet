import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/dust_constants.dart';
import 'package:coconut_wallet/core/transaction/utxo_split_transaction_builder.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utxo_split_test_helper.dart';
import '../../mock/wallet_mock.dart';
import '../../repository/realm/test_realm_manager.dart';

void main() {
  NetworkType.setNetworkType(NetworkType.regtest);

  late TestRealmManager realmManager;
  late AddressRepository addressRepository;
  final TaprootWalletItem keyPathWallet = WalletMock.createTaprootWalletItem(hasScriptPathSeedInfo: false);
  final TaprootWalletItem scriptPathWallet = WalletMock.createTaprootWalletItem(hasKeyPathSeedInfo: false);
  final TaprootWalletItem wallet = keyPathWallet;
  const int walletId = 1;

  UtxoState createUtxo(int amount, {int index = 0, String? txHash}) => UtxoState(
    transactionHash: txHash ?? 'd77dc64d3eb3454e9c65e5e36989af0eef349d824593dfe2a086fb9dadf7dfc4',
    index: index,
    amount: amount,
    blockHeight: 100,
    to: 'bcrt1qh22yl57ys0vaaln9nfp4zczj2fshjnl6gnsh66',
    derivationPath: "m/86'/1'/0'/0/0",
    timestamp: DateTime.now(),
  );

  UtxoSplitTransactionBuilder createBuilder(TaprootWalletItem taprootWallet, List<UtxoState> utxos, double feeRate) =>
      UtxoSplitTransactionBuilder(
        utxos: utxos,
        dustThreshold: DustThresholds.p2wsh,
        feeRate: feeRate,
        walletListItemBase: taprootWallet,
        addressRepository: addressRepository,
      );

  setUpAll(() async {
    realmManager = await setupTestRealmManager();
    final realmWalletBase = RealmWalletBase(
      wallet.id,
      wallet.colorIndex,
      wallet.iconIndex,
      wallet.descriptor,
      wallet.name,
      WalletType.taproot.name,
    );
    addressRepository = AddressRepository(realmManager);

    realmManager.realm.write(() {
      realmManager.realm.add(realmWalletBase);
    });

    // generatedReceiveIndex, generatedChangeIndex 업데이트
    realmManager.realm.write(() {
      final savedWallet = realmManager.realm.find<RealmWalletBase>(wallet.id)!;
      savedWallet.generatedReceiveIndex = 399;
      savedWallet.generatedChangeIndex = 19;
    });

    // receive 주소 400개, change 주소 20개 생성
    final List<WalletAddress> addresses = [];
    for (int i = 0; i < 400; i++) {
      final address = wallet.walletBase.getAddress(i, isChange: false);
      final derivationPath = "${wallet.walletBase.derivationPath}/0/$i";
      addresses.add(WalletAddress(address, derivationPath, i, false, false, 0, 0, 0));
    }
    for (int i = 0; i < 20; i++) {
      final address = wallet.walletBase.getAddress(i, isChange: true);
      final derivationPath = "${wallet.walletBase.derivationPath}/1/$i";
      addresses.add(WalletAddress(address, derivationPath, i, true, false, 0, 0, 0));
    }

    realmManager.realm.write(() {
      realmManager.realm.addAll<RealmWalletAddress>([
        ...addresses.map(
          (addr) => RealmWalletAddress(
            getWalletAddressId(walletId, addr.index, addr.address),
            walletId,
            addr.address,
            addr.index,
            addr.isChange,
            addr.derivationPath,
            false,
            0,
            0,
            0,
          ),
        ),
      ]);
    });
  });

  tearDownAll(() {
    realmManager.dispose();
  });

  for (final (label, taprootWallet) in [('key-path', keyPathWallet), ('script-path', scriptPathWallet)]) {
    group('taproot $label', () {
      for (final feeRate in [1.0, 10.0]) {
        for (final inputCount in [2, 10, 253]) {
          test('input $inputCount개, $feeRate sat/vB 균등 분할 시 preview 수수료가 실제와 같고 출력 간 차이가 1 sat 이내', () async {
            final utxos = List.generate(inputCount, (i) => createUtxo(50000, index: i));
            final builder = createBuilder(taprootWallet, utxos, feeRate);

            final preview = await builder.getEqualAmountSplitPreview(splitCount: 2);
            final result = await builder.buildEqualAmountSplit(splitCount: 2).future;

            expectSuccessfulTransaction(result, expectedInputCount: inputCount, expectedOutputCount: 2);
            expect(preview.estimatedFee, result.estimatedFee);
            final amounts = result.transaction!.outputs.map((output) => output.amount).toList();
            expect((amounts[0] - amounts[1]).abs(), lessThanOrEqualTo(1));
          });
        }
      }
    });
  }
}
