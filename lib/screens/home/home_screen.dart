import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutAppBar, CoconutTypography;
import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/analytics/wallet_add_analytics.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_connection_status_view_model.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/home/all_features_screen.dart';
import 'package:coconut_wallet/screens/home/home_edit_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_dialog.dart';
import 'package:coconut_wallet/screens/send/select_wallet_bottom_sheet.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/feature/feature_launcher.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/home/home_connection_status_indicator.dart';
import 'package:coconut_wallet/widgets/features/home/home_cube_pager.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = HomeViewModel(
      repository: HomeConfigurationRepository(SharedPrefsRepository()),
      wallets: () => context.read<WalletProvider>().walletItemList,
      onShortcutTap: _launch,
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  void _launch(BuildContext context, FeatureItem feature) {
    if (_viewModel.shouldAddWalletBeforeLaunch(feature)) {
      WalletAddDialog.show(context, WalletAddDialogMode.walletType);
      return;
    }
    FeatureLauncher(
      wallets: () => _viewModel.wallets,
      pickWallet: _pickWallet,
    ).launch(context, feature, walletContext: _viewModel.shortcutWalletContext);
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

  void _openHomeEdit(BuildContext context) {
    Navigator.of(context).push(
      CupertinoPageRoute(
        settings: const RouteSettings(name: '/home-edit'),
        builder: (_) => ChangeNotifierProvider.value(value: _viewModel, child: const HomeEditScreen()),
      ),
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
        ChangeNotifierProvider(
          create:
              (context) =>
                  HomeConnectionStatusViewModel(context.read<ConnectivityProvider>(), context.read<NodeProvider>()),
        ),
      ],
      child: CupertinoPageScaffold(
        child: HomeCubePager(
          allFeaturesBuilder: (showHome) => AllFeaturesScreen(onBack: showHome),
          home: CustomScrollView(
            slivers: [
              Builder(builder: _buildAppBar),
              SliverPadding(
                padding: const EdgeInsets.all(16),
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
                                minHeight: math.max(
                                  0,
                                  constraints.viewportMainAxisExtent - constraints.precedingScrollExtent - 16,
                                ),
                              ),
                        ),
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
    final iconColor = context.coconutColors.iconPrimary;
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
        CupertinoButton(
          key: const Key('home-edit-button'),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(40, 40),
          onPressed: () => _openHomeEdit(context),
          child: Text(t.edit, style: CoconutTypography.body2_14_Bold.copyWith(color: iconColor)),
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
    );
  }
}
