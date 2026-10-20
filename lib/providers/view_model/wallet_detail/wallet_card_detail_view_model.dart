import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/home/wallet_widget_definitions.dart';
import 'package:flutter/foundation.dart';

/// 지갑 상세(카드) 화면. 위쪽 카드 휠로 지갑을 넘기고, 가운데 카드의 지갑 하나를 보여 준다.
///
/// - 동기화·새로고침·잔액 단위·목표·보안 경고는 가운데 지갑의 [WalletDetailViewModel]을 그대로 쓴다.
/// - 최근 거래·UTXO 현황·저축 목표는 홈 위젯 데이터를 이 지갑 하나로 좁혀 쓴다(가짜 잔액 없음).
class WalletCardDetailViewModel extends ChangeNotifier {
  final WalletProvider _walletProvider;
  final TransactionProvider _transactionProvider;
  final NodeProvider _nodeProvider;
  final PreferenceProvider _preferenceProvider;
  final WalletAppearanceProvider? _appearanceProvider;
  final List<int>? _walletIds;
  final HomeWidgetsViewModel widgets;

  late int _focusedWalletId;
  late WalletDetailViewModel _detail;
  late BitcoinUnit _unit;
  bool _disposed = false;

  WalletCardDetailViewModel({
    required int initialWalletId,
    required WalletProvider walletProvider,
    required TransactionProvider transactionProvider,
    required NodeProvider nodeProvider,
    required PreferenceProvider preferenceProvider,
    required PriceProvider priceProvider,
    WalletAppearanceProvider? appearanceProvider,
    List<int>? walletIds,
  }) : _walletProvider = walletProvider,
       _transactionProvider = transactionProvider,
       _nodeProvider = nodeProvider,
       _preferenceProvider = preferenceProvider,
       _appearanceProvider = appearanceProvider,
       _walletIds = walletIds,
       widgets = HomeWidgetsViewModel(
         walletProvider: walletProvider,
         preferenceProvider: preferenceProvider,
         priceProvider: priceProvider,
         targetSatsOf: SharedPrefsRepository().getWalletTargetSats,
         walletUpdates: Listenable.merge([nodeProvider, nodeProvider.currentBlockNotifier]),
         usesFakeBalance: false,
       ) {
    _unit = preferenceProvider.currentUnit;
    _focusedWalletId = initialWalletId;
    _detail = _createDetail(initialWalletId);
    _walletProvider.addListener(_onWalletsChanged);
    _appearanceProvider?.addListener(notifyListeners);
    widgets.addListener(notifyListeners);
  }

  /// 카드 휠에 놓이는 지갑. 진입한 목록(예: 핫월렛 휠)이 있으면 그 순서, 없으면 전체 지갑 순서.
  List<WalletItemBase> get wallets {
    final all = orderStackWallets(
      _walletProvider.walletItemList,
      _preferenceProvider.walletOrder,
      kind: WalletStackKind.all,
    );
    final ids = _walletIds;
    if (ids == null) return all;
    final byId = {for (final wallet in all) wallet.id: wallet};
    return [
      for (final id in ids)
        if (byId[id] case final wallet?) wallet,
    ];
  }

  int get focusedIndex {
    final index = wallets.indexWhere((wallet) => wallet.id == _focusedWalletId);
    return index < 0 ? 0 : index;
  }

  WalletItemBase get focusedWallet => _detail.wallet;
  WalletDetailViewModel get detail => _detail;
  BitcoinUnit get unit => _unit;

  WalletAppearance appearanceOf(WalletItemBase wallet) =>
      _appearanceProvider?.appearanceOf(wallet) ?? WalletAppearance.of(wallet);

  int balanceOf(WalletItemBase wallet) => _walletProvider.getWalletBalance(wallet.id).total;

  String balanceText(WalletItemBase wallet) => _unit.displayBitcoinAmount(balanceOf(wallet));

  int get utxoCount => _walletProvider.getUtxoList(_focusedWalletId).length;

  List<HomeRecentTransaction> get recentTransactions => widgets.recentTransactions(walletIds: [_focusedWalletId]);

  HomeUtxoBuckets get utxoBuckets => widgets.utxoBuckets(walletIds: [_focusedWalletId]);

  String amountText(int sats) => _unit.displayBitcoinAmount(sats, withUnit: true);

  void focusWallet(int walletId) {
    if (walletId == _focusedWalletId) return;
    _focusedWalletId = walletId;
    _detail.removeListener(notifyListeners);
    _detail.dispose();
    _detail = _createDetail(walletId);
    notifyListeners();
  }

  void toggleUnit() {
    _unit = _unit.next;
    notifyListeners();
  }

  Future<void> refresh() => _detail.refresh();

  void reloadWalletMetadata() {
    _detail.reloadWalletMetadata();
    widgets.refresh();
  }

  WalletDetailViewModel _createDetail(int walletId) {
    final detail = WalletDetailViewModel(
      walletId,
      _walletProvider,
      _transactionProvider,
      _nodeProvider,
      initialUnit: _preferenceProvider.currentUnit,
    );
    detail.addListener(notifyListeners);
    return detail;
  }

  void _onWalletsChanged() {
    final current = wallets;
    if (current.isNotEmpty && current.every((wallet) => wallet.id != _focusedWalletId)) {
      focusWallet(current.first.id);
      return;
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _walletProvider.removeListener(_onWalletsChanged);
    _appearanceProvider?.removeListener(notifyListeners);
    widgets.removeListener(notifyListeners);
    widgets.dispose();
    _detail.removeListener(notifyListeners);
    _detail.dispose();
    super.dispose();
  }
}
