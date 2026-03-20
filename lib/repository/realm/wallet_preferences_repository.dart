import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

class WalletPreferencesRepository extends BaseRepository {
  WalletPreferencesRepository(super._realmManager);

  /// walletId 로 트랜잭션 목록 조회, rbf/cpfp 내역 미포함
  List<int> getWalletOrder() {
    final prefs = realm.query<RealmWalletPreferences>('TRUEPREDICATE').firstOrNull;
    return prefs?.walletOrder.toList() ?? [];
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
    return prefs?.favoriteWalletIds.toList() ?? [];
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
    return prefs?.excludedFromTotalBalanceWalletIds.toList() ?? [];
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

  @Deprecated('Manual UTXO Selection Mode는 지갑 별 설정이 아닌 앱 전체 설정으로 변경되었습니다. 이 메서드는 더 이상 사용되지 않습니다.')
  List<int> getManualUtxoSelectionWalletIds() {
    final prefs = realm.query<RealmWalletPreferences>('TRUEPREDICATE').firstOrNull;
    return prefs?.manualUtxoSelectionWalletIds.toList() ?? [];
  }

  @Deprecated('Manual UTXO Selection Mode는 지갑 별 설정이 아닌 앱 전체 설정으로 변경되었습니다. 이 메서드는 더 이상 사용되지 않습니다.')
  Future<void> setManualUtxoSelectionWalletIds(List<int> ids) async {
    final prefs = realm.query<RealmWalletPreferences>('TRUEPREDICATE').firstOrNull;
    if (prefs != null) {
      await realm.writeAsync(() {
        prefs.manualUtxoSelectionWalletIds.clear();
        prefs.manualUtxoSelectionWalletIds.addAll(ids);
      });
    } else {
      await realm.writeAsync(() {
        realm.add(RealmWalletPreferences(0)..manualUtxoSelectionWalletIds.addAll(ids));
      });
    }
  }

  @Deprecated('Manual UTXO Selection Mode는 지갑 별 설정이 아닌 앱 전체 설정으로 변경되었습니다. 이 메서드는 더 이상 사용되지 않습니다.')
  bool isManualUtxoSelection(int walletId) {
    return getManualUtxoSelectionWalletIds().contains(walletId);
  }

  /// walletId의 UTXO 선택 모드 토글
  @Deprecated('Manual UTXO Selection Mode는 지갑 별 설정이 아닌 앱 전체 설정으로 변경되었습니다. 이 메서드는 더 이상 사용되지 않습니다.')
  Future<void> toggleManualUtxoSelection(int walletId) async {
    final ids = getManualUtxoSelectionWalletIds();
    if (ids.contains(walletId)) {
      ids.remove(walletId);
    } else {
      ids.add(walletId);
    }
    await setManualUtxoSelectionWalletIds(ids);
  }
}
