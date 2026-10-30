import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/node_provider/balance_sync_service.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:realm/realm.dart';

import '../../mock/script_sync_service_mock.dart';
import '../../mock/script_status_mock.dart';
import '../../mock/wallet_mock.dart';
import '../../repository/realm/test_realm_manager.dart';

class _FailingAggregateRepository extends WalletRepository {
  final RealmWalletBalance foreignRow;
  bool failWrite = true;
  _FailingAggregateRepository(RealmManager manager, this.foreignRow)
    : super(manager, TransactionDraftRepository(manager));
  @override
  RealmWalletBalance? getWalletBalance(int walletId) => failWrite ? foreignRow : super.getWalletBalance(walletId);
}

void main() {
  for (final batch in [false, true]) {
    test('aggregate write failure rolls back address updates and retry stays exact (batch: $batch)', () async {
      final previousNetwork = NetworkType.currentNetworkType;
      ScriptSyncServiceMock.init();
      final manager = ScriptSyncServiceMock.realmManager!;
      final foreign = TestRealmManager();
      addTearDown(() {
        foreign.dispose();
        manager.dispose();
        ScriptSyncServiceMock.realmManager = null;
        NetworkType.setNetworkType(previousNetwork);
      });
      final wallet = WalletMock.createSingleSigWalletItem(id: 903);
      manager.realm.write(
        () => manager.realm.add(
          RealmWalletBase(
            wallet.id,
            wallet.colorIndex,
            wallet.iconIndex,
            wallet.descriptor,
            wallet.name,
            WalletType.singleSignature.name,
          ),
        ),
      );
      final addresses = ScriptSyncServiceMock.addressRepository;
      await addresses.ensureAddressesInit(walletItemBase: wallet);
      addresses.updateAddressBalance(walletId: wallet.id, index: 0, isChange: false, balance: Balance(10000, 0));
      ScriptSyncServiceMock.walletRepository.updateWalletBalance(wallet.id, Balance(10000, 0));
      final foreignRow = foreign.realm.write(
        () => foreign.realm.add(RealmWalletBalance(1, wallet.id, 10000, 10000, 0)),
      );
      // A managed row in a different Realm throws when the aggregate setter is reached.
      final wallets = _FailingAggregateRepository(manager, foreignRow);
      final service = BalanceSyncService(
        ScriptSyncServiceMock.electrumService,
        ScriptSyncServiceMock.stateManager,
        addresses,
        wallets,
      );
      final status = ScriptStatusMock.createMockScriptStatus(wallet, 0);
      when(
        ScriptSyncServiceMock.electrumService.getBalance(any, status.address),
      ).thenAnswer((_) async => GetBalanceRes(confirmed: 5000, unconfirmed: -1000));
      Future<void> fetch() =>
          batch
              ? service.fetchScriptBalanceBatch(wallet, [status, status])
              : service.fetchScriptBalance(wallet, status);
      await expectLater(fetch(), throwsA(isA<RealmException>()));
      final row =
          manager.realm.query<RealmWalletAddress>(r'walletId == $0 AND index == 0 AND isChange == false', [
            wallet.id,
          ]).single;
      expect((row.confirmed, row.unconfirmed, row.total), (10000, 0, 10000));
      expect(ScriptSyncServiceMock.walletRepository.getWalletBalance(wallet.id)!.total, 10000);
      expect(foreignRow.total, 10000);
      expect(service.hasBalanceFetchFailures(wallet.id), isTrue);
      wallets.failWrite = false;
      await fetch();
      await fetch();
      expect((row.confirmed, row.unconfirmed, row.total), (5000, -1000, 4000));
      final total = wallets.getWalletBalance(wallet.id)!;
      expect((total.confirmed, total.unconfirmed, total.total), (5000, -1000, 4000));
      expect(service.hasBalanceFetchFailures(wallet.id), isFalse);
    });
  }
}
