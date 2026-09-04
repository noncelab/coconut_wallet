import 'package:collection/collection.dart';
import 'package:coconut_wallet/constants/dust_constants.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_bucket.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_list_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';

class RenewalUtxoListViewModel extends UtxoListViewModel {
  RenewalUtxoListViewModel(
    this._walletId,
    WalletProvider walletProvider,
    this._transactionProvider,
    UtxoTagProvider tagProvider,
    ConnectivityProvider connectivityProvider,
    PriceProvider priceProvider,
    PreferenceProvider preferenceProvider,
    Stream<WalletUpdateInfo> syncWalletStateStream,
  ) : super(
        _walletId,
        walletProvider,
        _transactionProvider,
        tagProvider,
        connectivityProvider,
        priceProvider,
        preferenceProvider,
        syncWalletStateStream,
      );

  final int _walletId;
  final TransactionProvider _transactionProvider;
  bool _isRefreshing = false;
  bool _isDisposed = false;

  bool isByAmount = true;
  bool isOverviewTab = true;
  int lockFilterIndex = 0;
  int viewModeIndex = 0;
  bool isSelectionMode = false;
  final Set<String> selectedUtxoIds = {};
  bool selectionBarExiting = false;
  int lastLockFilterForBar = 0;

  bool get isRefreshing => _isRefreshing;

  String get utxoDataKey => utxoList
      .map((utxo) => '${utxo.utxoId}:${utxo.status.name}:${utxo.amount}:${utxo.tags?.map((tag) => tag.id).join(',')}')
      .join('|');

  Future<void> refresh() async {
    if (_isRefreshing || isSyncing) return;

    _isRefreshing = true;
    notifyListeners();
    final stopwatch = Stopwatch()..start();
    try {
      _transactionProvider.initTxList(_walletId);
      refetchFromDB();
    } finally {
      const minimumIndicatorDuration = Duration(milliseconds: 500);
      final remaining = minimumIndicatorDuration - stopwatch.elapsed;
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      if (!_isDisposed) {
        _isRefreshing = false;
        notifyListeners();
      }
    }
  }

  List<UtxoBucket> buildBuckets() {
    return bucketize(utxoList, dustThreshold: walletType.addressType.dustThreshold);
  }

  List<UtxoBucket> filterBuckets(List<UtxoBucket> buckets, {required bool showLocked}) {
    return buckets
        .map(
          (bucket) => UtxoBucket(
            label: bucket.label,
            minSats: bucket.minSats,
            maxSats: bucket.maxSats,
            utxos: bucket.utxos.where((utxo) => showLocked ? utxo.isLocked : !utxo.isLocked).toList(),
          ),
        )
        .where((bucket) => bucket.utxos.isNotEmpty)
        .toList();
  }

  List<UtxoState> getUtxosByIds(Iterable<String> ids) {
    final idSet = ids is Set<String> ? ids : ids.toSet();
    return utxoList.where((utxo) => idSet.contains(utxo.utxoId)).toList();
  }

  int getUtxoAmountByIds(Iterable<String> ids) {
    return getUtxosByIds(ids).fold(0, (sum, utxo) => sum + utxo.amount);
  }

  List<String> getCurrentTagNames(String utxoId) {
    final utxo = utxoList.where((item) => item.utxoId == utxoId).firstOrNull;
    return utxo?.tags?.map((tag) => tag.name).toList() ?? [];
  }

  Set<String> get reusedAddresses {
    final addressCounts = <String, int>{};
    for (final utxo in utxoList) {
      addressCounts[utxo.to] = (addressCounts[utxo.to] ?? 0) + 1;
    }
    return addressCounts.entries.where((entry) => entry.value > 1).map((entry) => entry.key).toSet();
  }

  Set<String> get suspiciousUtxoIds {
    return utxoList.where(isUtxoSuspicious).map((utxo) => utxo.utxoId).toSet();
  }

  String buildLockToastMessage({required bool lock, required int selectedCount, required int changedCount}) {
    if (changedCount == 0) {
      if (selectedCount == 1) {
        return lock ? t.utxo_detail_screen.utxo_already_locked : t.utxo_detail_screen.utxo_already_unlocked;
      }
      return lock ? t.utxo_detail_screen.utxo_all_already_locked : t.utxo_detail_screen.utxo_all_already_unlocked;
    }
    if (changedCount == 1) {
      return lock ? t.utxo_detail_screen.utxo_locked_toast_msg : t.utxo_detail_screen.utxo_unlocked_toast_msg;
    }
    return lock
        ? t.utxo_detail_screen.utxo_locked_count_toast_msg(count: changedCount)
        : t.utxo_detail_screen.utxo_unlocked_count_toast_msg(count: changedCount);
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
