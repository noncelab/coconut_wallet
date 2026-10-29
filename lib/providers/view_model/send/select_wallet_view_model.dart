import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_stack_list_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/home/wallet_widget_definitions.dart';
import 'package:coconut_wallet/utils/wallet_util.dart';
import 'package:flutter/foundation.dart';

enum BalanceMode { includingPending, onlyUnspent }

typedef _SelectionLayout = ({bool grid, int selected, int last});

/// 지갑 선택 시트의 후보·선택·보기 방식과 실시간 지갑 정보를 관리한다.
class SelectWalletViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;
  final SharedPrefsRepository _preferences;
  final BalanceMode balanceMode;
  late final List<WalletItemBase> wallets;
  late final WalletStackListViewModel facts;
  late final Listenable _updates;
  late bool _isGrid;
  late int _selectedWalletId;
  late int _lastCarouselWalletId;
  bool _disposed = false;
  bool _layoutSaveFailed = false;
  bool get layoutSaveFailed => _layoutSaveFailed;
  Future<void> _layoutWrite = Future<void>.value();
  late _SelectionLayout _savedLayout;
  int _layoutRevision = 0;
  int _pendingLayoutWrites = 0;
  _SelectionLayout get _layout => (grid: _isGrid, selected: _selectedWalletId, last: _lastCarouselWalletId);

  SelectWalletViewModel({
    required WalletProvider walletProvider,
    required PreferenceProvider preferenceProvider,
    required int walletId,
    required this.balanceMode,
    bool showOnlyMfpWallets = false,
    List<int>? candidateWalletIds,
    NodeProvider? nodeProvider,
    SharedPrefsRepository? preferences,
  }) : _walletProvider = walletProvider,
       _preferences = preferences ?? SharedPrefsRepository() {
    final source = walletProvider.walletItemList;
    final byId = {for (final wallet in source) wallet.id: wallet};
    final ordered = preferenceProvider.walletOrder.map((id) => byId[id]).whereType<WalletItemBase>().toList();
    final orderedIds = ordered.map((wallet) => wallet.id).toSet();
    wallets = List.unmodifiable(
      [...ordered, ...source.where((wallet) => !orderedIds.contains(wallet.id))].where(
        (wallet) =>
            (!showOnlyMfpWallets || !isWalletWithoutMfp(wallet)) &&
            (candidateWalletIds == null || candidateWalletIds.contains(wallet.id)),
      ),
    );
    _isGrid = _preferences.getBool(SharedPrefKeys.kSelectWalletGridView);
    _lastCarouselWalletId =
        wallets.isEmpty ? -1 : (wallets.any((wallet) => wallet.id == walletId) ? walletId : wallets.first.id);
    _selectedWalletId = _isGrid ? -1 : _lastCarouselWalletId;
    _savedLayout = _layout;
    facts = WalletStackListViewModel(WalletStackKind.all, walletProvider, preferenceProvider);
    _updates = Listenable.merge([facts, nodeProvider, nodeProvider?.currentBlockNotifier]);
    _updates.addListener(notifyListeners);
  }

  bool get isGrid => _isGrid;
  int get selectedWalletId => _selectedWalletId;
  int get carouselIndex => wallets.indexWhere((wallet) => wallet.id == _lastCarouselWalletId).clamp(0, wallets.length);

  void selectWallet(int id) {
    if (!wallets.any((wallet) => wallet.id == id)) return;
    _selectedWalletId = _isGrid && _selectedWalletId == id ? -1 : id;
    if (!_isGrid) _lastCarouselWalletId = id;
    if (_pendingLayoutWrites == 0) _savedLayout = _layout;
    notifyListeners();
  }

  void focusCarouselWallet(int id) {
    if (_isGrid || _selectedWalletId == id) return;
    selectWallet(id);
  }

  Future<bool> toggleLayout() async {
    if (_disposed) return false;
    final previous = _layout;
    final revision = ++_layoutRevision;
    _pendingLayoutWrites++;
    _isGrid = !_isGrid;
    if (_isGrid) {
      _lastCarouselWalletId = _selectedWalletId;
      _selectedWalletId = -1;
    } else {
      if (_selectedWalletId == -1) _selectedWalletId = _lastCarouselWalletId;
      _lastCarouselWalletId = _selectedWalletId;
    }
    _layoutSaveFailed = false;
    final requested = _layout;
    // 저장 결과와 롤백도 같은 큐에서 처리해 이전 실패가 최신 전환을 되돌리지 않도록 한다.
    final write = _layoutWrite.then((_) async {
      try {
        await _preferences.setSelectWalletGridView(requested.grid);
        _savedLayout = revision == _layoutRevision ? _layout : requested;
        if (revision == _layoutRevision) _layoutSaveFailed = false;
        return true;
      } catch (_) {
        if (revision == _layoutRevision) {
          final restore = _savedLayout.grid == previous.grid ? previous : _savedLayout;
          _isGrid = restore.grid;
          _selectedWalletId = restore.selected;
          _lastCarouselWalletId = restore.last;
          _savedLayout = restore;
          _layoutSaveFailed = true;
        }
        return false;
      } finally {
        _pendingLayoutWrites--;
        if (!_disposed) notifyListeners();
      }
    });
    _layoutWrite = write.then<void>((_) {});
    notifyListeners();
    return write;
  }

  Map<int, int> get balances {
    if (balanceMode == BalanceMode.includingPending) {
      return _walletProvider.fetchWalletBalanceMap().map((id, balance) => MapEntry(id, balance.total));
    }
    return {
      for (final wallet in wallets)
        wallet.id: _walletProvider
            .getUtxoList(wallet.id)
            .where((utxo) => utxo.status == UtxoStatus.unspent)
            .fold<int>(0, (sum, utxo) => sum + utxo.amount),
    };
  }

  @override
  void dispose() {
    _disposed = true;
    _updates.removeListener(notifyListeners);
    facts.dispose();
    super.dispose();
  }
}
