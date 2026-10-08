import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutAppBar, CoconutTypography;
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
import 'package:coconut_wallet/screens/home/home_item_configure_sheets.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_dialog.dart';
import 'package:coconut_wallet/screens/send/select_wallet_bottom_sheet.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/feature/feature_launcher.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/home/home_connection_status_indicator.dart';
import 'package:coconut_wallet/widgets/features/home/home_cube_pager.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:coconut_wallet/widgets/features/wallet/menu/long_pressed_menu_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _gridBadgeInset = 16.0;

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
    _widgetsViewModel.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _launch(BuildContext context, FeatureItem feature, {bool useShortcutWallet = true}) {
    if (_viewModel.shouldAddWalletBeforeLaunch(feature)) {
      WalletAddDialog.show(context, WalletAddDialogMode.walletType);
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
    WalletAddDialog.show(context, WalletAddDialogMode.walletType);
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
                child: HomeCubePager(swipeEnabled: !arranging, home: child!, allFeaturesBuilder: _buildAllFeatures),
              ),
          child: _buildHome(context),
        ),
      ),
    );
  }

  Widget _buildAllFeatures(VoidCallback showHome) => AllFeaturesScreen(
    registry: _viewModel.features,
    isAvailable: (feature) => feature.isAvailable?.call(context) ?? true,
    onLaunch: (context, feature) => _launch(context, feature, useShortcutWallet: false),
    recentIds: SharedPrefsRepository().getString(SharedPrefKeys.kAllFeaturesRecentIds).split(',')
      ..removeWhere((id) => id.isEmpty),
    saveRecentIds: (ids) => SharedPrefsRepository().setString(SharedPrefKeys.kAllFeaturesRecentIds, ids.join(',')),
  );

  Widget _buildHome(BuildContext context) {
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
    final iconColor = context.coconutColors.iconPrimary;
    final arranging = context.watch<HomeViewModel>().isArranging;
    return CoconutAppBar.buildHomeAppbar(
      context: context,
      leadingSvgAsset: Transform.translate(
        offset: const Offset(-8, 2),
        child: HomeConnectionStatusIndicator(
          networkStatus: status.networkStatus,
          showReconnected: status.showElectrumReconnected,
          isSyncing: status.isSyncing,
        ),
      ),
      appTitle: '',
      actionButtonList: [
        if (arranging)
          CupertinoButton(
            key: const Key('home-arrange-done'),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(40, 40),
            onPressed: _viewModel.finishArranging,
            child: Text(t.done, style: CoconutTypography.body2_14_Bold.copyWith(color: iconColor)),
          )
        else ...[
          CoconutAppBarActionButton(
            buttonKey: const Key('home-edit-button'),
            icon: SvgPicture.asset(
              CommonActionIconPath.editHome,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
            onPressed: () => _openHomeEdit(context),
            color: iconColor,
          ),
          CoconutAppBarActionButton(
            icon: SvgPicture.asset(
              FeatureWalletIconPath.walletAddDefault,
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
            onPressed: () => _openAddWallet(context),
            color: iconColor,
          ),
          CoconutAppBarActionButton(
            icon: SvgPicture.asset(
              FeatureSettingsIconPath.settings,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
            onPressed: () => _openAppSettings(context),
            color: iconColor,
          ),
        ],
      ],
    );
  }
}
