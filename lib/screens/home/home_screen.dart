import 'dart:async';
import 'dart:math' as math;

import 'package:coconut_wallet/widgets/features/home/all_features_hint.dart';
import 'package:coconut_wallet/widgets/features/home/add_wallet_hint.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_screen.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/analytics/wallet_add_analytics.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_preset.dart';
import 'package:coconut_wallet/analytics/home_edit_analytics.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_connection_status_view_model.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/home/all_features_screen.dart';
import 'package:coconut_wallet/screens/home/home_edit_screen.dart';
import 'package:coconut_wallet/screens/home/home_fake_balance_search.dart';
import 'package:coconut_wallet/screens/home/home_item_configure_sheets.dart';
import 'package:coconut_wallet/screens/send/select_wallet_bottom_sheet.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/feature/feature_launcher.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/home/home_app_bar.dart';
import 'package:coconut_wallet/widgets/features/home/home_cube_pager.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:coconut_wallet/widgets/features/wallet/menu/long_pressed_menu_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _gridBadgeInset = 16.0;

  /// 말풍선 오른쪽 끝이 지갑 추가 버튼 오른쪽 끝보다 더 나가는 거리
  static const _addWalletHintRightOverhang = 52.0;

  final LayerLink _addWalletButtonLink = LayerLink();
  final GlobalKey<HomeCubePagerState> _pagerKey = GlobalKey();

  /// All Features 말풍선이 보이는 동안 홈을 살짝 밀어 보인다. 처음엔 곧바로, 그다음엔 [_peekInterval]마다,
  /// 앱을 켤 때마다 최대 [_peekLimit]번. 사용자가 홈을 만지고 있으면 그 차례는 건너뛴다.
  static const _peekDelay = Duration(milliseconds: 900);
  static const _peekInterval = Duration(seconds: 7);
  static const _peekLimit = 3;
  Timer? _peekTimer;
  int _peeks = 0;
  DateTime _lastTouch = DateTime.fromMillisecondsSinceEpoch(0);

  void _startPeeking() {
    if (_peekTimer != null || _peeks >= _peekLimit) return;
    _peekTimer = Timer(_peeks == 0 ? _peekDelay : _peekInterval, () async {
      _peekTimer = null;
      if (!mounted || !_viewModel.showsAllFeaturesHint) return;
      final idle = DateTime.now().difference(_lastTouch) > const Duration(seconds: 2);
      if (!_viewModel.isArranging && idle) {
        _peeks++;
        await _pagerKey.currentState?.peek();
      }
      if (mounted) _startPeeking();
    });
  }

  late final HomeViewModel _viewModel;
  late final HomeWidgetsViewModel _widgetsViewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = HomeViewModel(
      repository: HomeConfigurationRepository(SharedPrefsRepository()),
      wallets: () => context.read<WalletProvider>().walletItemList,
      onShortcutTap: _launch,
      isFeatureAvailable: (feature) => feature.isAvailable?.call(context) ?? true,
      legacyFakeBalanceActive: context.read<PreferenceProvider>().isFakeBalanceActive,
      legacyBalanceHidden: context.read<PreferenceProvider>().isBalanceHidden,
      walletListChanges: context.read<WalletProvider>().walletItemListNotifier,
      addWalletHintDismissed: SharedPrefsRepository().getBool(SharedPrefKeys.kAddWalletHintDismissed),
      onAddWalletHintDismissed: () => SharedPrefsRepository().setBool(SharedPrefKeys.kAddWalletHintDismissed, true),
      allFeaturesHintDismissed: SharedPrefsRepository().getBool(SharedPrefKeys.kAllFeaturesHintDismissed),
      onAllFeaturesHintDismissed: () => SharedPrefsRepository().setBool(SharedPrefKeys.kAllFeaturesHintDismissed, true),
    );
    _widgetsViewModel = HomeWidgetsViewModel(
      walletProvider: context.read<WalletProvider>(),
      preferenceProvider: context.read<PreferenceProvider>(),
      priceProvider: context.read<PriceProvider>(),
      targetSatsOf: SharedPrefsRepository().getWalletTargetSats,
      walletUpdates: Listenable.merge([
        context.read<NodeProvider>(),
        context.read<NodeProvider>().currentBlockNotifier,
      ]),
    );
  }

  @override
  void dispose() {
    _peekTimer?.cancel();
    _widgetsViewModel.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _launch(BuildContext context, FeatureItem feature, {bool useShortcutWallet = true}) {
    if (_viewModel.shouldAddWalletBeforeLaunch(feature)) {
      if (useShortcutWallet) {
        _viewModel.remindAddWallet();
      } else {
        CoconutToast.showToast(context: context, text: t.add_wallet_hint.needs_wallet);
      }
      return;
    }
    FeatureLauncher(
      wallets: () => _viewModel.wallets,
      pickWallet: _pickWallet,
    ).launch(context, feature, walletContext: useShortcutWallet ? _viewModel.shortcutWalletContext : null);
  }

  Future<int?> _pickWallet(BuildContext context, List<int> candidateWalletIds) {
    return CommonBottomSheets.showDraggableBottomSheet<int>(
      context: context,
      screenName: AnalyticsScreenNames.homeShortcutSelectWalletSheet,
      childBuilder:
          (scrollController) => SelectWalletBottomSheet(
            showOnlyMfpWallets: false,
            scrollController: scrollController,
            currentUnit: context.read<PreferenceProvider>().currentUnit,
            walletId: -1,
            candidateWalletIds: candidateWalletIds,
            onWalletChanged: (id) => Navigator.pop(context, id),
          ),
    );
  }

  void _openAddWallet(BuildContext context) {
    context.read<AnalyticsService>().logWalletAddButtonClicked(entrySource: WalletAddEntrySource.appBar);
    _viewModel.dismissAddWalletHint();
    WalletAddScreen.openByWalletCount(context);
  }

  Future<void> _openHomeEdit(BuildContext context) async {
    final analytics = context.read<AnalyticsService>();
    final before = _viewModel.configuration;
    final presetApplied = await Navigator.of(context).push<HomePresetApplied>(
      CupertinoPageRoute(
        settings: const RouteSettings(name: '/home-edit'),
        builder:
            (_) => MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: _viewModel),
                ChangeNotifierProvider.value(value: _widgetsViewModel),
              ],
              child: const HomeEditScreen(),
            ),
      ),
    );
    analytics.logHomeEditCompleted(changed: _viewModel.configuration != before, presetApplied: presetApplied != null);
    if (presetApplied != null && mounted) _showPresetApplied(presetApplied);
  }

  void _showPresetApplied(HomePresetApplied applied) {
    CoconutToast.showToast(
      context: context,
      text: t.home_presets.applied(name: applied.preset.name()),
      seconds: 5,
      actionText: t.home_presets.undo,
      onAction: () => _viewModel.restore(applied.previous),
    );
  }

  List<LongPressedMenuItem> _menuItemsOf(BuildContext context, HomeItem item) {
    final definition = _viewModel.registry.byId(item.definitionId);
    final isShortcut = item.kind == HomeItemKind.shortcut;
    return [
      if (definition != null && _viewModel.canConfigure(definition))
        LongPressedMenuItem(
          title: isShortcut ? t.home_menu.configure_shortcut : t.home_menu.configure_widget,
          iconPath: CommonActionIconPath.command,
          onSelected: () => HomeItemConfigureSheets.configure(context, _viewModel, definition, item),
        ),
      LongPressedMenuItem(
        title: t.home_menu.edit_home_screen,
        iconPath: CommonActionIconPath.editHome,
        onSelected: _viewModel.startArranging,
      ),
      LongPressedMenuItem(
        title: isShortcut ? t.home_menu.remove_shortcut : t.home_menu.remove_widget,
        iconPath: CommonFormIconPath.circleMinus,
        isDanger: true,
        onSelected: () => _remove(item),
      ),
    ];
  }

  void _remove(HomeItem item) {
    final previous = _viewModel.configuration;
    _viewModel.removeItem(item.id);
    CoconutToast.showToast(
      context: context,
      text: t.home_menu.removed,
      seconds: 5,
      actionText: t.home_presets.undo,
      onAction: () => _viewModel.restore(previous),
    );
  }

  void _openAppSettings(BuildContext context) {
    final feature = _viewModel.features.byId(FeatureIds.appSettings);
    if (feature != null) _launch(context, feature);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _viewModel),
        ChangeNotifierProvider.value(value: _widgetsViewModel),
        ChangeNotifierProvider(
          create:
              (context) =>
                  HomeConnectionStatusViewModel(context.read<ConnectivityProvider>(), context.read<NodeProvider>()),
        ),
      ],
      child: CupertinoPageScaffold(
        backgroundColor: context.coconutColors.homeBackground,
        child: Selector<HomeViewModel, bool>(
          selector: (_, viewModel) => viewModel.isArranging,
          builder:
              (context, arranging, child) => PopScope(
                canPop: !arranging,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) _viewModel.finishArranging();
                },
                child: HomeCubePager(
                  key: _pagerKey,
                  swipeEnabled: !arranging,
                  home: child!,
                  allFeaturesBuilder: _buildAllFeatures,
                  onPageChanged: (page) {
                    if (page == 1) _viewModel.dismissAllFeaturesHint();
                  },
                ),
              ),
          child: _buildHome(context),
        ),
      ),
    );
  }

  Widget _buildAllFeatures(VoidCallback showHome) => ValueListenableBuilder<bool>(
    valueListenable: _viewModel.noWallets,
    builder: (context, noWallets, _) => _buildAllFeaturesScreen(noWallets),
  );

  Widget _buildAllFeaturesScreen(bool noWallets) => AllFeaturesScreen(
    registry: _viewModel.features,
    isAvailable: (feature) => feature.isAvailable?.call(context) ?? true,
    isDimmed: (feature) => noWallets && feature.context == FeatureContext.wallet,
    onLaunch: (context, feature) => _launch(context, feature, useShortcutWallet: false),
    onFakeBalanceTap: (context) => openFakeBalanceFromSearch(context, _viewModel),
    recentIds: SharedPrefsRepository().getString(SharedPrefKeys.kAllFeaturesRecentIds).split(',')
      ..removeWhere((id) => id.isEmpty),
    saveRecentIds: (ids) => SharedPrefsRepository().setString(SharedPrefKeys.kAllFeaturesRecentIds, ids.join(',')),
  );

  Widget _buildHome(BuildContext context) {
    return Listener(onPointerDown: (_) => _lastTouch = DateTime.now(), child: _buildHomeLayers(context));
  }

  Widget _buildHomeLayers(BuildContext context) {
    return Stack(
      children: [
        _buildHomeScroll(context),
        Consumer<HomeViewModel>(
          builder: (context, viewModel, _) {
            if (!viewModel.showsAllFeaturesHint || viewModel.isArranging) return const SizedBox.shrink();
            _startPeeking();
            return Positioned(
              right: 8,
              top: MediaQuery.sizeOf(context).height * 0.42,
              child: AllFeaturesHint(
                onOpen: () {
                  viewModel.dismissAllFeaturesHint();
                  _pagerKey.currentState?.showAllFeatures();
                },
                onClose: viewModel.dismissAllFeaturesHint,
              ),
            );
          },
        ),
        Consumer<HomeViewModel>(
          builder:
              (context, viewModel, _) =>
                  !viewModel.showsAddWalletHint || viewModel.isArranging
                      ? const SizedBox.shrink()
                      : CompositedTransformFollower(
                        link: _addWalletButtonLink,
                        showWhenUnlinked: false,
                        targetAnchor: Alignment.bottomRight,
                        followerAnchor: Alignment.topRight,
                        offset: const Offset(_addWalletHintRightOverhang, 0),
                        child: Align(
                          alignment: Alignment.topRight,
                          child: AddWalletHint(
                            tailFromRight: _addWalletHintRightOverhang + HomeAppBar.addWalletButtonSize / 2,
                            nudges: viewModel.addWalletHintNudges,
                            onClose: viewModel.dismissAddWalletHint,
                          ),
                        ),
                      ),
        ),
      ],
    );
  }

  Widget _buildHomeScroll(BuildContext context) {
    return CustomScrollView(
      slivers: [
        Builder(builder: _buildAppBar),
        SliverPadding(
          padding: const EdgeInsets.all(16 - _gridBadgeInset),
          sliver: SliverLayoutBuilder(
            builder:
                (context, constraints) => SliverToBoxAdapter(
                  child: Consumer<HomeViewModel>(
                    builder:
                        (context, viewModel, _) => HomeItemsView(
                          configuration: viewModel.configuration,
                          registry: viewModel.registry,
                          onMoveToCell: viewModel.moveToCell,
                          onInsertBefore: viewModel.insertBefore,
                          menuItemsOf: (item) => _menuItemsOf(context, item),
                          isArranging: viewModel.isArranging,
                          onRemove: _remove,
                          onArrangeDone: viewModel.finishArranging,
                          onResize: (item, span) => viewModel.resizeItem(item.id, span),
                          badgeInset: _gridBadgeInset,
                          minHeight: math.max(
                            0,
                            constraints.viewportMainAxisExtent -
                                constraints.precedingScrollExtent -
                                16 -
                                _gridBadgeInset,
                          ),
                        ),
                  ),
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final status = context.watch<HomeConnectionStatusViewModel>();
    final arranging = context.watch<HomeViewModel>().isArranging;
    return HomeAppBar(
      networkStatus: status.networkStatus,
      showReconnected: status.showElectrumReconnected,
      isSyncing: status.isSyncing,
      isArranging: arranging,
      addWalletButtonLink: _addWalletButtonLink,
      onArrangeDone: _viewModel.finishArranging,
      onEdit: () => _openHomeEdit(context),
      onAddWallet: () => _openAddWallet(context),
      onSettings: () => _openAppSettings(context),
    );
  }
}
