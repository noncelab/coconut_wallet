import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/dust_constants.dart';
import 'package:coconut_wallet/core/transaction/utxo_split_transaction_builder.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/wallet_mock.dart';
import '../../providers/node_provider/transaction/rbf_service_test.mocks.dart';
import '../../repository/realm/test_realm_manager.dart';

void main() {
  for (final count in [50, 201]) {
    test('$count split outputs are owned before any subscription notification arrives', () async {
      final network = NetworkType.currentNetworkType;
      NetworkType.setNetworkType(NetworkType.regtest);
      final manager = TestRealmManager();
      addTearDown(() {
        manager.dispose();
        NetworkType.setNetworkType(network);
      });
      final wallet = WalletMock.createSingleSigWalletItem();
      manager.realm.write(() {
        manager.realm.add(
          RealmWalletBase(
            wallet.id,
            wallet.colorIndex,
            wallet.iconIndex,
            wallet.descriptor,
            wallet.name,
            WalletType.singleSignature.name,
          ),
        );
      });
      final addresses = AddressRepository(manager);
      await addresses.ensureAddressesInit(walletItemBase: wallet);
      await addresses.updateWalletUsedIndex(wallet, 0, isChange: false);
      final funding = Transaction.withInputsAndOutputs(
        [TransactionInput.forPayment(List.filled(64, 'a').join(), 0)],
        [TransactionOutput.forPayment(1000000, wallet.walletBase.getAddress(0))],
        AddressType.p2wpkh,
      );
      final utxo = UtxoState(
        transactionHash: funding.transactionHash,
        index: 0,
        amount: 1000000,
        blockHeight: 100,
        to: wallet.walletBase.getAddress(0),
        derivationPath: '${wallet.walletBase.derivationPath}/0/0',
        timestamp: DateTime.now(),
      );
      expect(addresses.containsAddress(wallet.id, wallet.walletBase.getAddress(count)), isFalse);
      final builder = UtxoSplitTransactionBuilder(
        utxos: [utxo],
        dustThreshold: DustThresholds.p2wpkh,
        feeRate: 1,
        walletListItemBase: wallet,
        addressRepository: addresses,
      );
      final result = await builder.buildEqualAmountSplit(splitCount: count).future;
      expect(result.isSuccess, isTrue);
      final tx = result.transaction!;
      expect(tx.outputs, hasLength(count));
      for (final output in tx.outputs) {
        expect(addresses.containsAddress(wallet.id, output.scriptPubKey.getAddress()), isTrue);
      }
      expect(addresses.getUsedIndexes(wallet.id).$1, 0);
      // The old input's notification can classify the transaction before any output notification.
      final details = TransactionRecordService(
        MockElectrumService(),
        addresses,
      ).processTransactionDetails(tx, [funding], wallet.id);
      expect(details.txType, TransactionType.self);
      expect(details.amount, -details.fee);
      expect(tx.outputs.fold<int>(0, (sum, output) => sum + output.amount) + details.fee, utxo.amount);
    });
  }
}
