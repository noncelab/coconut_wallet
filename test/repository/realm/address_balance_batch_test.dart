import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/update_address_balance_dto.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/script_status_mock.dart';
import '../../mock/wallet_mock.dart';
import 'test_realm_manager.dart';

void main() {
  late TestRealmManager manager;
  late AddressRepository addresses;
  late WalletRepository wallets;
  late SinglesigWalletItem wallet;
  late NetworkType previousNetwork;

  SinglesigWalletItem addWallet(int id) {
    final item = WalletMock.createSingleSigWalletItem(id: id);
    manager.realm.write(() {
      manager.realm.add(
        RealmWalletBase(
          id,
          item.colorIndex,
          item.iconIndex,
          item.descriptor,
          item.name,
          WalletType.singleSignature.name,
        ),
      );
      for (final isChange in [false, true]) {
        final status = ScriptStatusMock.createMockScriptStatus(item, 0, isChange: isChange);
        manager.realm.add(
          RealmWalletAddress(
            getWalletAddressId(id, 0, status.address),
            id,
            status.address,
            0,
            isChange,
            status.derivationPath,
            false,
            0,
            0,
            0,
          ),
        );
      }
    });
    wallets.updateWalletBalance(id, Balance(0, 0));
    return item;
  }

  setUp(() async {
    previousNetwork = NetworkType.currentNetworkType;
    NetworkType.setNetworkType(NetworkType.regtest);
    manager = await setupTestRealmManager();
    addresses = AddressRepository(manager);
    wallets = WalletRepository(manager, TransactionDraftRepository(manager));
    wallet = addWallet(1);
  });

  tearDown(() {
    manager.reset();
    manager.dispose();
    NetworkType.setNetworkType(previousNetwork);
  });

  UpdateAddressBalanceDto update(int confirmed, int unconfirmed, {bool isChange = false, int index = 0}) {
    return UpdateAddressBalanceDto(
      scriptStatus: ScriptStatusMock.createMockScriptStatus(wallet, index, isChange: isChange),
      confirmed: confirmed,
      unconfirmed: unconfirmed,
    );
  }

  Future<Balance> apply(List<UpdateAddressBalanceDto> updates) async {
    return addresses.updateAddressBalanceBatch(wallet.id, updates, walletBalance: wallets.getWalletBalance(wallet.id));
  }

  void expectStoredBalances(int walletId, int confirmed, int unconfirmed) {
    final rows = manager.realm.query<RealmWalletAddress>(r'walletId == $0', [walletId]);
    final stored = wallets.getWalletBalance(walletId)!;
    expect(rows.fold<int>(0, (sum, row) => sum + row.confirmed), confirmed);
    expect(rows.fold<int>(0, (sum, row) => sum + row.unconfirmed), unconfirmed);
    expect((stored.confirmed, stored.unconfirmed, stored.total), (confirmed, unconfirmed, confirmed + unconfirmed));
    for (final row in rows) {
      expect(row.total, row.confirmed + row.unconfirmed);
    }
  }

  test('unique address update keeps wallet and address balances equal', () async {
    final delta = await apply([update(12345, 0)]);
    expect((delta.confirmed, delta.unconfirmed), (12345, 0));
    expectStoredBalances(wallet.id, 12345, 0);
  });

  for (final scenario in [
    (name: 'credit', before: Balance(0, 0), after: Balance(12345, 0)),
    (name: 'decrease', before: Balance(10000, 0), after: Balance(3000, 0)),
    (name: 'confirmation', before: Balance(0, 9000), after: Balance(9000, 0)),
    (name: 'pending debit', before: Balance(10000, 0), after: Balance(10000, -7000)),
    (name: 'confirmed debit', before: Balance(10000, -7000), after: Balance(3000, 0)),
  ]) {
    test('duplicate ${scenario.name} is reflected once in both balance components', () async {
      addresses.updateAddressBalance(walletId: wallet.id, index: 0, isChange: false, balance: scenario.before);
      wallets.updateWalletBalance(wallet.id, scenario.before);

      final delta = await apply([
        update(scenario.after.confirmed, scenario.after.unconfirmed),
        update(scenario.after.confirmed, scenario.after.unconfirmed),
      ]);

      expectStoredBalances(wallet.id, scenario.after.confirmed, scenario.after.unconfirmed);
      expect(
        (delta.confirmed, delta.unconfirmed),
        (
          scenario.after.confirmed - scenario.before.confirmed,
          scenario.after.unconfirmed - scenario.before.unconfirmed,
        ),
      );
    });
  }

  test('different duplicate values retain the last supplied address balance', () async {
    await apply([update(10000, 2000)]);
    final delta = await apply([update(15000, 500), update(3000, -1000), update(7000, 0)]);

    expectStoredBalances(wallet.id, 7000, 0);
    expect((delta.confirmed, delta.unconfirmed), (-3000, -2000));
  });

  test('repeating the same duplicate batch returns zero further change', () async {
    await apply([update(12345, 678), update(12345, 678)]);
    final delta = await apply([update(12345, 678), update(12345, 678)]);

    expectStoredBalances(wallet.id, 12345, 678);
    expect((delta.confirmed, delta.unconfirmed), (0, 0));
  });

  test('receive and change at the same index stay separate and other wallets stay unchanged', () async {
    final otherWallet = addWallet(2);
    addresses.updateAddressBalance(walletId: otherWallet.id, index: 0, isChange: false, balance: Balance(4000, 500));
    wallets.updateWalletBalance(otherWallet.id, Balance(4000, 500));

    await apply([update(1000, 100), update(2000, -200, isChange: true), update(1000, 100)]);

    expectStoredBalances(wallet.id, 3000, -100);
    expectStoredBalances(otherWallet.id, 4000, 500);
    final rows = manager.realm.query<RealmWalletAddress>(r'walletId == $0', [wallet.id]);
    expect(rows.singleWhere((row) => !row.isChange).confirmed, 1000);
    expect(rows.singleWhere((row) => row.isChange).confirmed, 2000);
  });

  test('empty batch preserves existing balances', () async {
    await apply([update(5000, -1000)]);
    final delta = await apply([]);

    expectStoredBalances(wallet.id, 5000, -1000);
    expect((delta.confirmed, delta.unconfirmed), (0, 0));
  });

  test('one satoshi changes remain exact at the Bitcoin supply limit', () async {
    const maxSats = 2100000000000000;
    await apply([update(maxSats, 0)]);
    await apply([update(maxSats - 1, 1), update(maxSats - 1, 1)]);
    expectStoredBalances(wallet.id, maxSats - 1, 1);
    await apply([update(maxSats - 1, 0)]);
    expectStoredBalances(wallet.id, maxSats - 1, 0);
  });

  test('another wallet aggregate is rejected before changing either wallet', () async {
    final other = addWallet(2);
    final wrongBalance = wallets.getWalletBalance(other.id)!;
    expect(
      () => addresses.updateAddressBalance(
        walletId: wallet.id,
        index: 0,
        isChange: false,
        balance: Balance(1000, 0),
        walletBalance: wrongBalance,
      ),
      throwsArgumentError,
    );
    await expectLater(
      addresses.updateAddressBalanceBatch(wallet.id, [update(1000, 0)], walletBalance: wrongBalance),
      throwsArgumentError,
    );
    expectStoredBalances(wallet.id, 0, 0);
    expectStoredBalances(other.id, 0, 0);
  });

  test('missing address rejects the whole batch without partially changing stored balances', () async {
    await apply([update(5000, 0)]);

    await expectLater(apply([update(8000, 0), update(8000, 0), update(9000, 0, index: 99)]), throwsStateError);

    expectStoredBalances(wallet.id, 5000, 0);
  });
}
