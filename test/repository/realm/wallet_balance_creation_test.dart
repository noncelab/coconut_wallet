import 'dart:io';

import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:realm/realm.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory directory;
  late Realm first;
  late Realm second;
  WalletRepository repository(Realm realm) {
    final manager = RealmManager.withRealm(realm);
    return WalletRepository(manager, TransactionDraftRepository(manager));
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsRepository().init();
    directory = await Directory.systemTemp.createTemp('wallet-balance-race-');
    final path = '${directory.path}/wallet.realm';
    first = Realm(Configuration.local(realmAllSchemas, path: path));
    first.write(() {
      for (final id in [1, 2]) {
        first.add(RealmWalletBase(id, 0, 0, 'descriptor', 'Wallet $id', 'singleSignature'));
      }
    });
    second = Realm(Configuration.local(realmAllSchemas, path: path));
  });

  tearDown(() async {
    second.close();
    first.close();
    await directory.delete(recursive: true);
  });

  test('counter creation rechecks a stale Realm snapshot inside the write transaction', () {
    const key = 'RealmWalletBalance';
    expect(first.find<RealmIntegerId>(key), isNull);
    expect(getLastId(second, key), 1);
    expect(getLastId(first, key), 1);
    expect(first.all<RealmIntegerId>().length, 1);
  });

  test('first balance reads across Realm instances preserve the balance and allocate unique IDs', () {
    expect(first.all<RealmWalletBalance>(), isEmpty);
    final writer = repository(second);
    final reader = repository(first);
    final created = writer.updateWalletBalance(1, Balance(1000, 200));
    final restored = reader.getWalletBalance(1)!;
    expect(restored.id, created.id);
    expect(restored.total, 1200);
    expect(first.all<RealmWalletBalance>().length, 1);
    final next = reader.getWalletBalance(2)!;
    expect(next.id, isNot(restored.id));
    expect(first.all<RealmWalletBalance>().length, 2);
    expect(first.find<RealmIntegerId>('RealmWalletBalance')!.value, next.id);
  });
}
