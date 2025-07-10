import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

class WalletPreferencesRepository extends BaseRepository {
  WalletPreferencesRepository(super._realmManager);

  /// walletId 로 트랜잭션 목록 조회, rbf/cpfp 내역 미포함
  List<int> getWalletOrder() {
    final prefs = realm.query<RealmWalletPreferences>('TRUEPREDICATE').firstOrNull;
    return prefs?.walletOrder ?? [];
  }

  Future<void> setWalletOrder(List<int> walletOrder) async {
    final copiedOrder = List<int>.from(walletOrder);
    final prefs = realm.query<RealmWalletPreferences>('TRUEPREDICATE').firstOrNull;
    if (prefs != null) {
      await realm.writeAsync(() {
        prefs.walletOrder.clear();
        prefs.walletOrder.addAll(copiedOrder);
      });
    } else {
      await realm.writeAsync(() {
        realm.add(RealmWalletPreferences(0)..walletOrder.addAll(walletOrder));
      });
    }
  }

  List<int> getFavoriteWalletIds() {
    final prefs = realm.query<RealmWalletPreferences>('TRUEPREDICATE').firstOrNull;
    return prefs?.favoriteWalletIds ?? [];
  }

  Future<void> setFavoriteWalletIds(List<int> ids) async {
    final prefs = realm.query<RealmWalletPreferences>('TRUEPREDICATE').firstOrNull;
    if (prefs != null) {
      await realm.writeAsync(() {
        prefs.favoriteWalletIds.clear();
        prefs.favoriteWalletIds.addAll(ids);
      });
    } else {
      await realm.writeAsync(() {
        realm.add(RealmWalletPreferences(0)..favoriteWalletIds.addAll(ids));
      });
    }
  }

  List<int> getExcludedWalletIds() {
    final prefs = realm.query<RealmWalletPreferences>('TRUEPREDICATE').firstOrNull;
    return prefs?.excludedFromTotalBalanceWalletIds ?? [];
  }

  Future<void> setExcludedWalletIds(List<int> ids) async {
    final prefs = realm.query<RealmWalletPreferences>('TRUEPREDICATE').firstOrNull;
    if (prefs != null) {
      await realm.writeAsync(() {
        prefs.excludedFromTotalBalanceWalletIds.clear();
        prefs.excludedFromTotalBalanceWalletIds.addAll(ids);
      });
    } else {
      await realm.writeAsync(() {
        realm.add(RealmWalletPreferences(0)..excludedFromTotalBalanceWalletIds.addAll(ids));
      });
    }
  }
}
