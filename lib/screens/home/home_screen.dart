import 'dart:async';
import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/screens/safety/safety_alerts_screen.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_screen.dart';
import 'package:coconut_wallet/services/safety/home_safety_status_resolver.dart';
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
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/safety/home_safety_banner.dart';
import 'package:coconut_wallet/widgets/features/wallet/menu/long_pressed_menu_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  final ValueChanged<int>? onPageChanged;

  const HomeScreen({super.key, this.onPageChanged});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _gridBadgeInset = 16.0;

  /// 말풍선 오른쪽 끝이 지갑 추가 버튼 오른쪽 끝보다 더 나가는 거리: 오른쪽 버튼(🔔·설정, 🔔가 없으면 설정만) + 4.
  /// 🔔는 앱바와 같은 조건(SafetyProvider가 있을 때)으로 그린다.
  static double _addWalletHintRightOverhang(BuildContext context) =>
      HomeAppBar.addWalletButtonSize * (context.watch<SafetyProvider?>() == null ? 1 : 2) + 4;

  /// 그리드 아래 홈 편집 버튼 높이와 위아래 여백
  static const _homeEditEntryHeight = 56.0;
  static const _homeEditEntryTop = 12.0;
  static const _homeEditEntryBottom = 16.0;

  final LayerLink _addWalletButtonLink = LayerLink();
  final LayerLink _statusChipLink = LayerLink();
  final GlobalKey<HomeCubePagerState> _pagerKey = GlobalKey();
  final GlobalKey<HomeItemsViewState> _itemsKey = GlobalKey();

  /// All Features 말풍선이 보이는 동안 홈을 살짝 밀어 보인다. 처음엔 곧바로, 그다음엔 [_peekInterval]마다,
  /// 앱을 켤 때마다 최대 [_peekLimit]번. 사용자가 홈을 만지고 있으면 그 차례는 건너뛴다.
  static const _peekDelay = Duration(milliseconds: 900);
  static const _peekInterval = Duration(seconds: 7);
  static const _peekLimit = 3;
  Timer? _peekTimer;
  int _peeks = 0;
  bool _reduceMotion = false;
  DateTime _lastTouch = DateTime.fromMillisecondsSinceEpoch(0);

  void _startPeeking() {
    if (_reduceMotion ||
        !_viewModel.showsAllFeaturesHint ||
        _viewModel.isArranging ||
        _peekTimer != null ||
        _peeks >= _peekLimit) {
      return;
    }
    _peekTimer = Timer(_peeks == 0 ? _peekDelay : _peekInterval, () async {
      _peekTimer = null;
      if (!mounted || _reduceMotion || !_viewModel.showsAllFeaturesHint) return;
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

  void _cancelPeeking() {
    _peekTimer?.cancel();
    _peekTimer = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pagerKey.currentState?.cancelPeek();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context);
    if (_reduceMotion) _cancelPeeking();
  }

  @override
  void dispose() {
    _peekTimer?.cancel();
    _widgetsViewModel.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _launch(BuildContext context, FeatureItem feature, {bool useShortcutWallet = true}) async {
    if (_viewModel.shouldAddWalletBeforeLaunch(feature)) {
      if (useShortcutWallet) {
        _viewModel.remindAddWallet();
      } else {
        CoconutToast.showToast(context: context, text: t.add_wallet_hint.needs_wallet);
      }
      return;
    }
    await FeatureLauncher(
      wallets: () => _viewModel.wallets,
      pickWallet: _pickWallet,
    ).launch(context, feature, walletContext: useShortcutWallet ? _viewModel.shortcutWalletContext : null);
    if (mounted) setState(() {});
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

  void _finishArranging() {
    _itemsKey.currentState?.cancelActiveDrag();
    _viewModel.finishArranging();
  }

  void _undoArrangement() {
    _itemsKey.currentState?.cancelActiveDrag();
    _viewModel.undoArrangement();
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
                  if (!didPop && _itemsKey.currentState?.cancelActiveDrag() != true) {
                    _viewModel.finishArranging();
                  }
                },
                child: HomeCubePager(
                  key: _pagerKey,
                  swipeEnabled: !arranging,
                  home: child!,
                  allFeaturesBuilder: _buildAllFeatures,
                  onPageChanged: (page) {
                    widget.onPageChanged?.call(page);
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
    isAvailable:
        (feature) =>
            (feature.isAvailable?.call(context) ?? true) &&
            (feature.parentId == null ||
                feature.context != FeatureContext.wallet ||
                _viewModel.wallets.isEmpty ||
                _viewModel.wallets.any(feature.supportsWallet)),
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
            if (!viewModel.showsAllFeaturesHint || viewModel.isArranging) {
              _cancelPeeking();
              return const SizedBox.shrink();
            }
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
                        offset: Offset(_addWalletHintRightOverhang(context), 0),
                        child: Align(
                          alignment: Alignment.topRight,
                          child: AddWalletHint(
                            tailFromRight: _addWalletHintRightOverhang(context) + HomeAppBar.addWalletButtonSize / 2,
                            nudges: viewModel.addWalletHintNudges,
                            onClose: viewModel.dismissAddWalletHint,
                          ),
                        ),
                      ),
        ),
        Consumer<HomeViewModel>(builder: _buildSafetyHint),
      ],
    );
  }

  /// 업데이트 뒤 처음 한 번 상태칩 아래 말풍선. 지갑 추가 말풍선이 먼저다.
  Widget _buildSafetyHint(BuildContext context, HomeViewModel viewModel, Widget? _) {
    final safety = context.watch<SafetyProvider?>();
    if (safety == null || !safety.showsHomeHint || viewModel.isArranging || viewModel.showsAddWalletHint) {
      return const SizedBox.shrink();
    }
    final hint = GestureDetector(
      key: const Key('wallet-health-hint'),
      onTap: () {
        safety.dismissHomeHint();
        WalletHealthScreen.open(context);
      },
      child: AddWalletHint(
        title: t.wallet_health.first_hint.title,
        description: t.wallet_health.first_hint.description,
        closeLabel: t.wallet_health.first_hint.close_a11y,
        tailFromRight: AddWalletHint.width - 16,
        nudges: 0,
        onClose: safety.dismissHomeHint,
      ),
    );
    return CompositedTransformFollower(
      link: _statusChipLink,
      showWhenUnlinked: false,
      targetAnchor: Alignment.bottomLeft,
      followerAnchor: Alignment.topLeft,
      offset: const Offset(0, 4),
      child: Align(alignment: Alignment.topLeft, child: _reduceMotion ? hint : hint.fadeInAnimation()),
    );
  }

  Widget _buildHomeScroll(BuildContext context) {
    return CustomScrollView(
      slivers: [
        Builder(builder: _buildAppBar),
        SliverToBoxAdapter(
          child: Selector<HomeViewModel, bool>(
            selector: (_, viewModel) => viewModel.isArranging,
            builder:
                (context, arranging, _) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: HomeSafetyBanner(isArranging: arranging),
                ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16 - _gridBadgeInset),
          sliver: SliverLayoutBuilder(
            builder:
                (context, constraints) => SliverToBoxAdapter(
                  child: Consumer<HomeViewModel>(
                    builder:
                        (context, viewModel, _) => HomeItemsView(
                          key: _itemsKey,
                          configuration: viewModel.configuration,
                          registry: viewModel.registry,
                          onMoveToCell: viewModel.moveToCell,
                          onInsertBefore: viewModel.insertBefore,
                          menuItemsOf: (item) => _menuItemsOf(context, item),
                          isArranging: viewModel.isArranging,
                          onRemove: _remove,
                          onArrangeStart: viewModel.startArranging,
                          onArrangeDone: _finishArranging,
                          onResize: (item, span) => viewModel.resizeItem(item.id, span),
                          badgeInset: _gridBadgeInset,
                          minHeight: math.max(
                            0,
                            constraints.viewportMainAxisExtent -
                                constraints.precedingScrollExtent -
                                16 -
                                _gridBadgeInset -
                                (viewModel.isArranging ? 0 : _homeEditEntryExtent(context)),
                          ),
                        ),
                  ),
                ),
          ),
        ),
        SliverToBoxAdapter(
          child: Selector<HomeViewModel, bool>(
            selector: (_, viewModel) => viewModel.isArranging,
            builder: (context, arranging, _) => arranging ? const SizedBox.shrink() : _buildHomeEditEntry(context),
          ),
        ),
      ],
    );
  }

  double _homeEditEntryExtent(BuildContext context) =>
      _homeEditEntryTop + _homeEditEntryHeight + _homeEditEntryBottom + MediaQuery.paddingOf(context).bottom;

  /// 프리셋·위젯·바로가기 카탈로그로 가는 주 진입. 항목이 없어도 화면 맨 아래에 보인다.
  Widget _buildHomeEditEntry(BuildContext context) {
    final colors = context.coconutColors;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        _homeEditEntryTop,
        16,
        _homeEditEntryBottom + MediaQuery.paddingOf(context).bottom,
      ),
      child: HomeWidgetPressable(
        key: const Key('home-edit-entry'),
        borderRadius: 16,
        onTap: () => _openHomeEdit(context),
        child: Container(
          height: _homeEditEntryHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(16)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                CommonActionIconPath.editHome,
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
              ),
              CoconutLayout.spacing_200w,
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    t.home_edit.title,
                    maxLines: 1,
                    style: CoconutTypography.body2_14_Bold.copyWith(color: colors.primaryText),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    final status = context.watch<HomeConnectionStatusViewModel>();
    final arranging = context.watch<HomeViewModel>().isArranging;
    final safety = context.watch<SafetyProvider?>();
    return HomeAppBar(
      networkStatus: status.networkStatus,
      showReconnected: status.showElectrumReconnected,
      isSyncing: status.isSyncing,
      isArranging: arranging,
      addWalletButtonLink: _addWalletButtonLink,
      onArrangeDone: _finishArranging,
      onUndoArrangement: _viewModel.canUndoArrangement ? _undoArrangement : null,
      onAddWallet: () => _openAddWallet(context),
      onSettings: () => _openAppSettings(context),
      safetyStatus:
          safety == null
              ? null
              : resolveHomeSafetyStatus(
                report: safety.report,
                networkStatus: status.networkStatus,
                showReconnected: status.showElectrumReconnected,
                isSyncing: status.isSyncing,
              ),
      statusChipLink: _statusChipLink,
      onStatusTap: () {
        safety?.dismissHomeHint();
        WalletHealthScreen.open(context);
      },
      onAlerts: safety == null ? null : () => SafetyAlertsScreen.open(context),
      // 점은 읽지 않은 위급·조치 필요(hasUnreadAlerts)만, 건수는 의미 라벨에 쓴다
      unreadAlerts: safety?.hasUnreadAlerts ?? false ? safety!.alertItems.where((item) => item.unread).length : 0,
    );
  }
}
