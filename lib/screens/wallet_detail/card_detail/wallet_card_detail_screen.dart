import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart'
    hide CoconutAppBar, CoconutToast, CoconutToastLevel, CoconutPopup;
import 'package:coconut_lib/coconut_lib.dart' show NetworkType;
import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/analytics/backup_analytics.dart';
import 'package:coconut_wallet/analytics/wallet_detail_analytics.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/feature_entry_routes.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/model/wallet/wallet_background.dart';
import 'package:coconut_wallet/constants/wallet_skins.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_card_detail_view_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/app_settings/app_settings_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/card_detail/wallet_detail_card_carousel.dart';
import 'package:coconut_wallet/screens/wallet_detail/move_to_vault_bottom_sheets.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_faucet_request_bottom_sheet.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/home/card/home_alert_card.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/activity_widget_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/utxo_summary_view.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card_background.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_refresh_icon.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/widgets/common/amount/animated_balance.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:coconut_wallet/widgets/features/wallet/amount/wallet_balance_sync_shimmer.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// 지갑 상세 화면. 위쪽 카드 휠로 지갑을 넘기고, 가운데 카드의 배경이 화면 전체에 펼쳐진다.
class WalletCardDetailScreen extends StatefulWidget {
  final int id;
  final String entryPoint;

  /// 카드 휠에 놓을 지갑과 순서(예: 핫월렛 휠에서 들어온 경우). 없으면 전체 지갑.
  final List<int>? walletIds;

  /// 가운데 카드가 바뀔 때 알린다(돌아갈 화면이 같은 카드를 보여 주도록).
  final void Function(int walletId)? onFocusChanged;

  /// 지갑 목록 휠 ↔ 지갑 상세 전환 시간.
  static const Duration transitionDuration = Duration(milliseconds: 480);

  const WalletCardDetailScreen({
    super.key,
    required this.id,
    required this.entryPoint,
    this.walletIds,
    this.onFocusChanged,
  });

  @override
  State<WalletCardDetailScreen> createState() => _WalletCardDetailScreenState();
}

class _WalletCardDetailScreenState extends State<WalletCardDetailScreen> {
  static const _nextWarningDelay = Duration(milliseconds: 400);
  static const _horizontalPadding = 16.0;

  late final WalletCardDetailViewModel _viewModel;
  late final AnalyticsService _analyticsService;
  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _collapseProgress = ValueNotifier(0);
  final ValueNotifier<double> _pagePosition = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    _analyticsService = context.read<AnalyticsService>();
    _viewModel = WalletCardDetailViewModel(
      initialWalletId: widget.id,
      walletIds: widget.walletIds,
      walletProvider: context.read<WalletProvider>(),
      transactionProvider: context.read<TransactionProvider>(),
      nodeProvider: context.read<NodeProvider>(),
      preferenceProvider: context.read<PreferenceProvider>(),
      priceProvider: context.read<PriceProvider>(),
      appearanceProvider: context.readWalletAppearance(),
    );
    _pagePosition.value = _viewModel.focusedIndex.toDouble();
    _scrollController.addListener(_updateCollapseProgress);
  }

  /// 카드의 잔액이 앱바 아래로 사라지는 구간에서 앱바에 잔액이 나타난다.
  void _updateCollapseProgress() {
    final cardHeight = WalletDetailCardCarousel.heightFor(MediaQuery.sizeOf(context).width);
    final start = cardHeight * 0.3;
    final end = cardHeight * 0.55;
    final progress = ((_scrollController.offset - start) / (end - start)).clamp(0.0, 1.0);
    _collapseProgress.value = Curves.easeInOutCubic.transform(progress);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _collapseProgress.dispose();
    _pagePosition.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  WalletDetailViewModel get _detail => _viewModel.detail;
  int get _walletId => _viewModel.focusedWallet.id;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WalletCardDetailViewModel>.value(
      value: _viewModel,
      child: Consumer<WalletCardDetailViewModel>(
        builder: (context, viewModel, _) {
          return Stack(
            children: [
              Positioned.fill(
                child: ValueListenableBuilder<double>(
                  valueListenable: _pagePosition,
                  builder: (context, position, _) => _buildBlendedBackground(viewModel.wallets, position),
                ),
              ),
              Scaffold(
                backgroundColor: Colors.transparent,
                extendBodyBehindAppBar: true,
                appBar: PreferredSize(
                  preferredSize: const Size.fromHeight(kToolbarHeight),
                  child: _onBackground(Builder(builder: (context) => _buildAppBar(context, viewModel))),
                ),
                body: _buildBody(context, viewModel),
              ),
            ],
          );
        },
      ),
    );
  }

  /// 카드를 넘기는 만큼 지금 카드와 다음 카드의 배경을 겹쳐 섞는다.
  Widget _buildBlendedBackground(List<WalletItemBase> wallets, double position) {
    if (wallets.isEmpty) return const SizedBox.shrink();
    final clamped = position.clamp(0.0, wallets.length - 1.0);
    final lower = clamped.floor();
    final upper = math.min(lower + 1, wallets.length - 1);
    final blend = clamped - lower;
    return Stack(
      fit: StackFit.expand,
      children: [
        KeyedSubtree(
          key: ValueKey(('wallet-detail-background', wallets[lower].id)),
          child: _ScreenBackground(wallet: wallets[lower]),
        ),
        if (upper != lower && blend > 0)
          Opacity(
            key: ValueKey(('wallet-detail-background', wallets[upper].id)),
            opacity: blend,
            child: _ScreenBackground(wallet: wallets[upper]),
          ),
      ],
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, WalletCardDetailViewModel viewModel) {
    return CoconutAppBar.build(
      context: context,
      backgroundColor: Colors.transparent,
      customTitle: ValueListenableBuilder<double>(
        valueListenable: _collapseProgress,
        builder:
            (context, progress, child) =>
                progress == 0
                    ? const SizedBox.shrink()
                    : Opacity(
                      opacity: progress,
                      child: Transform.translate(offset: Offset(0, 8 * (1 - progress)), child: child),
                    ),
        child: _CollapsedBalance(
          key: const Key('wallet-detail-appbar-balance'),
          balance: viewModel.balanceOf(viewModel.focusedWallet),
          unit: viewModel.unit,
          isSyncing: viewModel.detail.isWalletSyncing,
          onTap: viewModel.toggleUnit,
        ),
      ),
      actionButtonList: [
        WalletRefreshIndicator(isRefreshing: viewModel.detail.isRefreshing),
        if (NetworkType.currentNetworkType.isTestnet)
          CoconutAppBarActionButton(
            key: const Key('wallet-detail-faucet'),
            onPressed: _openFaucetRequest,
            icon: SvgPicture.asset(
              FeatureUtxoIconPath.faucet,
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
            ),
          ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, WalletCardDetailViewModel viewModel) {
    final topInset = MediaQuery.paddingOf(context).top + kToolbarHeight;
    final wallets = viewModel.wallets;
    return Stack(
      children: [
        Padding(
          padding: EdgeInsets.only(top: topInset),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              if (!viewModel.detail.isWalletSyncing)
                _onBackground(CupertinoSliverRefreshControl(onRefresh: viewModel.refresh)),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: WalletDetailCardCarousel(
                  wallets: wallets,
                  initialIndex: viewModel.focusedIndex,
                  onFocusChanged: (wallet) {
                    vibrateExtraLight();
                    viewModel.focusWallet(wallet.id);
                    widget.onFocusChanged?.call(wallet.id);
                    _pagePosition.value = viewModel.wallets.indexOf(wallet).toDouble();
                  },
                  onPageScrolled: (page) => _pagePosition.value = page,
                  cardBuilder: (context, wallet, isFocused) => _buildCard(viewModel, wallet, isFocused),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
                sliver: SliverList.list(
                  children: [
                    if (viewModel.focusedWallet.hasLocalKey && viewModel.balanceOf(viewModel.focusedWallet) > 0)
                      _buildMoveToVault(context),
                    const SizedBox(height: 20),
                    _buildSecurityWarning(viewModel.detail),
                    _sectionHeader(
                      context,
                      key: const Key('wallet-detail-utxo-header'),
                      title: 'UTXO • ${viewModel.utxoCount}',
                      onMore: _openUtxoOverview,
                      moreEnabled: viewModel.utxoCount > 0,
                    ),
                    _lifted(
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.coconutColors.homeSurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: UtxoSummaryView(
                            keyPrefix: 'wallet-detail',
                            buckets: viewModel.utxoBuckets,
                            bucketColors: viewModel.widgets.utxoBucketColors,
                            amountText: viewModel.amountText,
                          ),
                        ),
                      ),
                      radius: 20,
                    ),
                    const SizedBox(height: 28),
                    _sectionHeader(
                      context,
                      key: const Key('wallet-detail-transactions-header'),
                      title: t.wallet_detail_screen.recent_transactions,
                      onMore: _openTransactionList,
                      moreEnabled: viewModel.recentTransactions.isNotEmpty,
                    ),
                    SizedBox(
                      height: 216,
                      child: _lifted(
                        RecentTransactionsView(
                          transactions: viewModel.recentTransactions,
                          amountText: viewModel.amountText,
                          now: DateTime.now(),
                          onTransactionSelected: _openTransaction,
                        ),
                        radius: 20,
                      ),
                    ),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom + 40),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: topInset,
          child: IgnorePointer(
            child: ValueListenableBuilder<double>(
              valueListenable: _collapseProgress,
              builder:
                  (context, progress, child) =>
                      progress == 0 ? const SizedBox.shrink() : Opacity(opacity: progress, child: child),
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  maxHeight: MediaQuery.sizeOf(context).height,
                  child: _ScreenBackground(wallet: viewModel.focusedWallet),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(WalletCardDetailViewModel viewModel, WalletItemBase wallet, bool isFocused) {
    final card = _buildDetailCard(viewModel, wallet, isFocused);
    return _lifted(card, radius: 28);
  }

  Widget _buildDetailCard(WalletCardDetailViewModel viewModel, WalletItemBase wallet, bool isFocused) {
    final detail = viewModel.detail;
    final isCurrent = isFocused && detail.walletId == wallet.id;
    return WalletDetailCard(
      key: ValueKey('wallet-detail-card-${wallet.id}'),
      wallet: wallet,
      appearance: viewModel.appearanceOf(wallet),
      balance: viewModel.balanceOf(wallet),
      unit: viewModel.unit,
      isSyncing: isCurrent && (detail.isRefreshing || detail.isWalletSyncing),
      onBalanceTap: viewModel.toggleUnit,
      actions: WalletDetailCardAction.standard(
        onReceive: _openReceive,
        onSend: _openSend,
        onOrganize: _openOrganizer,
        onDetails: _openWalletInfo,
        hasBalance: viewModel.balanceOf(wallet) > 0,
      ),
    );
  }

  WalletBackground? get _focusedBackground => _viewModel.appearanceOf(_viewModel.focusedWallet).background;

  /// 배경을 대표하는 색. 사진은 테마 색 막을 덮어 그리므로 따로 맞추지 않는다.
  static Color? _backdropColorOf(WalletBackground? background) => switch (background) {
    WalletSkinBackground(:final skinId) => WalletSkin.byId(skinId)?.base,
    WalletColorBackground(:final color) => color,
    _ => null,
  };

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// 배경 위에 바로 놓이는 글자·아이콘. 테마 색이 배경에 묻힐 때만 배경 밝기에 맞춘 색으로 바꾼다.
  Widget _onBackground(Widget child) => Builder(
    builder: (context) {
      final backdrop = _backdropColorOf(_focusedBackground);
      if (backdrop == null || _contrast(context.coconutColors.primaryText, backdrop) >= 3) return child;
      return WalletContentTheme(background: _focusedBackground, child: child);
    },
  );

  /// 카드. 테마 색이 배경과 거의 같아 경계가 사라질 때만 그림자로 띄운다.
  Widget _lifted(Widget child, {required double radius}) => Builder(
    builder: (context) {
      final colors = context.coconutColors;
      final backdrop = _backdropColorOf(_focusedBackground);
      if (backdrop == null || _contrast(colors.homeSurface, backdrop) >= 1.15) return child;
      return DecoratedBox(
        key: const Key('wallet-detail-lifted-surface'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [BoxShadow(color: colors.shadowSubtle, blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: child,
      );
    },
  );

  /// 구역 제목. [onMore]가 있으면 오른쪽에 "더보기"를 두고, [moreEnabled]가 false면 흐리게 두고 누를 수 없게 한다.

  Widget _sectionHeader(
    BuildContext context, {
    Key? key,
    required String title,
    VoidCallback? onMore,
    bool moreEnabled = true,
  }) => _onBackground(
    Builder(
      builder:
          (context) => _buildSectionHeader(context, key: key, title: title, onMore: onMore, moreEnabled: moreEnabled),
    ),
  );

  Widget _buildSectionHeader(
    BuildContext context, {
    Key? key,
    required String title,
    VoidCallback? onMore,
    required bool moreEnabled,
  }) {
    final colors = context.coconutColors;
    final moreColor = moreEnabled ? colors.secondaryText : colors.mutedText;
    return Padding(
      key: key,
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
      child: Row(
        children: [
          Expanded(child: Text(title, style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText))),
          if (onMore != null)
            Semantics(
              button: true,
              enabled: moreEnabled,
              child: GestureDetector(
                key: key == null ? null : ValueKey(('more', key)),
                behavior: HitTestBehavior.opaque,
                onTap: moreEnabled ? onMore : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(t.view_more, style: CoconutTypography.body2_14.setColor(moreColor)),
                      const SizedBox(width: 6),
                      SvgPicture.asset(
                        CommonNavigationIconPath.arrowRight,
                        width: 7,
                        height: 12,
                        colorFilter: ColorFilter.mode(moreColor, BlendMode.srcIn),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMoveToVault(BuildContext context) {
    final colors = context.coconutColors;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Center(
        child: _lifted(
          radius: 100,
          ShrinkAnimationButton(
            key: const Key('wallet-detail-move-to-vault'),
            onPressed: _onMoveToVaultPressed,
            defaultColor: colors.homeSurface,
            pressedOverlayColor: colors.homeSurfacePressOverlay,
            pressedOverlayOpacity: colors.homeSurfacePressOverlayOpacity,
            borderRadius: 100,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    FeatureWalletIconPath.vault,
                    width: 18,
                    height: 18,
                    colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    t.wallet_detail_screen.move_to_vault,
                    style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText),
                  ),
                  const SizedBox(width: 8),
                  SvgPicture.asset(
                    CommonNavigationIconPath.arrowRight,
                    width: 6,
                    height: 10,
                    colorFilter: ColorFilter.mode(colors.secondaryText, BlendMode.srcIn),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityWarning(WalletDetailViewModel detail) {
    final isAppLockEnabled = context.watch<AuthProvider>().isAuthEnabled;
    final warningType = detail.getSecurityWarningType(isAppLockEnabled: isAppLockEnabled);
    if (warningType == null) return const SizedBox.shrink();
    final isMnemonicWarning = warningType == WalletDetailSecurityWarningType.unbackedHotWallet;
    final iconColor =
        isMnemonicWarning ? context.coconutColors.iconOnDanger : context.coconutColors.appLockWarningForeground;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: HomeAlertCard.security(
        topSpacing: 8,
        key: ValueKey(('wallet-detail-warning', detail.walletId, warningType)),
        type: isMnemonicWarning ? HomeAlertCardType.mnemonicBackup : HomeAlertCardType.appLock,
        showDelay: detail.shouldUseShortWarningDelay(warningType) ? _nextWarningDelay : const Duration(seconds: 1),
        title:
            isMnemonicWarning
                ? t.wallet_home_screen.unbacked_hot_wallet_warning.title
                : t.wallet_home_screen.app_lock_warning.title,
        description:
            isMnemonicWarning
                ? t.wallet_home_screen.unbacked_hot_wallet_warning.description
                : t.wallet_home_screen.app_lock_warning.description,
        onTap: isMnemonicWarning ? _onBackupBannerTapped : _openAppLockSettings,
        onClosed:
            () => detail.dismissSecurityWarning(
              warningType,
              showNextWarning:
                  isMnemonicWarning &&
                  !isAppLockEnabled &&
                  detail.canShowSecurityWarning(WalletDetailSecurityWarningType.appLock),
            ),
        icon: SvgPicture.asset(
          isMnemonicWarning ? CommonStateIconPath.triangleWarning : CommonStateIconPath.shieldWarning,
          width: 20,
          height: 20,
          colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        ),
      ),
    );
  }

  void _logAction(WalletDetailAction action) => _analyticsService.logWalletDetailAction(action);

  void _openReceive() {
    _logAction(WalletDetailAction.receive);
    Navigator.pushNamed(context, AppRouteNames.receiveAddress, arguments: ReceiveAddressRouteArgs(id: _walletId));
  }

  void _openSend() {
    _logAction(WalletDetailAction.send);
    Navigator.pushNamed(
      context,
      AppRouteNames.send,
      arguments: SendRouteArgs(id: _walletId, sendEntryPoint: SendEntryPoint.walletDetail),
    );
  }

  void _openOrganizer() {
    _logAction(WalletDetailAction.utxoOrganize);
    _pushAsFeatureEntry(AppRouteNames.utxoOrganizer, UtxoOrganizerRouteArgs(id: _walletId));
  }

  void _openUtxoOverview() {
    _logAction(WalletDetailAction.utxoOverview);
    Navigator.pushNamed(context, AppRouteNames.utxoOverview, arguments: UtxoOverviewRouteArgs(id: _walletId));
  }

  void _openTransaction(HomeRecentTransaction tx) {
    final txHash = tx.txHash;
    if (txHash == null) return;
    _logAction(WalletDetailAction.txDetail);
    Navigator.pushNamed(
      context,
      AppRouteNames.transactionDetail,
      arguments: TransactionDetailRouteArgs(id: _walletId, txHash: txHash),
    );
  }

  void _openTransactionList() {
    _logAction(WalletDetailAction.txMore);
    Navigator.pushNamed(
      context,
      AppRouteNames.transactionList,
      arguments: WalletDetailRouteArgs(id: _walletId, entryPoint: widget.entryPoint),
    );
  }

  Future<void> _openWalletInfo({bool showTargetSetting = false, bool highlightMnemonicBackup = false}) async {
    _logAction(WalletDetailAction.walletInfo);
    await _pushAsFeatureEntry(
      AppRouteNames.walletInfo,
      WalletInfoRouteArgs(
        id: _walletId,
        walletType: _viewModel.focusedWallet.walletType,
        entryPoint: widget.entryPoint,
        showTargetSetting: showTargetSetting,
        highlightMnemonicBackup: highlightMnemonicBackup,
      ),
    );
    if (mounted) _viewModel.reloadWalletMetadata();
  }

  /// 카드 버튼으로 여는 화면은 기능 진입 화면처럼 왼쪽 위에 닫기(X)를 보인다.
  Future<void> _pushAsFeatureEntry(String routeName, Object arguments) async {
    Future<Object?>? closed;
    await FeatureEntryRoutes.instance.launching(() async {
      closed = Navigator.pushNamed(context, routeName, arguments: arguments);
    });
    await closed;
  }

  void _onBackupBannerTapped() {
    _analyticsService.logBackupPromptTapped(BackupPromptLocation.detailBanner);
    _logAction(WalletDetailAction.backupBanner);
    _openWalletInfo(highlightMnemonicBackup: true);
  }

  void _openAppLockSettings() {
    CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      screenName: AnalyticsScreenNames.walletDetailAppSettingsSheet,
      child: const AppSettingsScreen(),
      heightRatio: 0.9,
    );
  }

  Future<void> _onMoveToVaultPressed() async {
    final walletId = _walletId;
    final watchOnlyWallets =
        context.read<WalletProvider>().walletItemList.where((wallet) => !wallet.hasLocalKey).toList();
    final destination = resolveMoveToVaultDestination(_detail.balance, watchOnlyWallets.length);
    if (destination == MoveToVaultDestination.selectWatchOnlyWallet) {
      final receivingVaultWalletId = await CommonBottomSheets.showCustomHeightBottomSheet<int>(
        context: context,
        screenName: AnalyticsScreenNames.walletDetailMoveToVaultSelectWalletSheet,
        heightRatio: 0.5,
        childBuilder:
            (scrollController) => ShowVaultSelectWalletBottomSheet(
              walletId: walletId,
              watchOnlyWallets: watchOnlyWallets,
              scrollController: scrollController,
            ),
      );
      if (!mounted || receivingVaultWalletId == null) return;
      _logAction(WalletDetailAction.send);
      Navigator.pushNamed(
        context,
        AppRouteNames.send,
        arguments: SendRouteArgs(
          id: walletId,
          sendEntryPoint: SendEntryPoint.walletDetail,
          isMoveToVault: true,
          receivingVaultWalletId: receivingVaultWalletId,
        ),
      );
      return;
    }

    final content = switch (destination) {
      MoveToVaultDestination.noBalance => ShowVaultNoBalanceBottomSheet(walletId: walletId),
      _ => ShowVaultNoWatchOnlyWalletBottomSheet(walletId: walletId),
    };
    CommonBottomSheets.showBottomSheet<int>(
      context: context,
      title: t.wallet_detail_screen.move_to_vault,
      screenName:
          destination == MoveToVaultDestination.noBalance
              ? AnalyticsScreenNames.walletDetailMoveToVaultNoBalanceSheet
              : AnalyticsScreenNames.walletDetailMoveToVaultNoWatchOnlyWalletSheet,
      showCloseButton: true,
      showDragHandle: true,
      keyboardBottomPadding: 16,
      backgroundColor: context.coconutColors.surfaceBottomSheet,
      child: SafeArea(top: false, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: content)),
    );
  }

  Future<void> _openFaucetRequest() async {
    final detail = _detail;
    await CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      screenName: AnalyticsScreenNames.walletDetailFaucetSheet,
      heightRatio: 0.5,
      child: FaucetRequestBottomSheet(
        walletData: {
          'wallet_id': detail.walletId,
          'wallet_address': detail.receiveAddress,
          'wallet_name': detail.wallet.name,
          'wallet_index': detail.receiveAddressIndex,
        },
        isRequesting: detail.isRequestingFaucet,
        onRequest: (address, requestAmount) {
          if (detail.isRequestingFaucet) return;
          detail.requestTestBitcoin(address, requestAmount, (success, message) {
            if (!mounted) return;
            if (success) {
              Navigator.pop(context);
              vibrateLight();
              CoconutToast.showToast(context: context, text: message, isVisibleIcon: true);
              return;
            }
            vibrateMedium();
            CoconutToast.showToast(
              context: context,
              text: message,
              isVisibleIcon: true,
              iconPath: CommonStateIconPath.triangleWarning,
              level: CoconutToastLevel.warning,
            );
          });
        },
        walletProvider: detail.walletProvider,
        walletItem: detail.wallet,
      ),
    );
  }
}

/// 화면 전체 배경. 가운데 카드의 배경을 화면 전체에 펼친다. 기본이면 지갑 목록 휠 화면과 같은 홈 배경색.
/// 스크롤로 카드가 앱바 아래로 사라졌을 때 앱바 가운데에 보이는 잔액과 법정화폐 금액.
class _CollapsedBalance extends StatelessWidget {
  final int balance;
  final BitcoinUnit unit;
  final bool isSyncing;
  final VoidCallback onTap;

  const _CollapsedBalance({
    super.key,
    required this.balance,
    required this.unit,
    required this.isSyncing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          WalletBalanceSyncShimmer(
            isRefreshing: isSyncing,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: BitcoinAmountUnit(
                currentUnit: unit,
                unitStyle: CoconutTypography.body2_14_NumberBold.setColor(colors.primaryText),
                child: AnimatedBalance(
                  prevValue: balance,
                  value: balance,
                  currentUnit: unit,
                  textStyle: CoconutTypography.body1_16_NumberBold
                      .merge(const TextStyle(fontSize: 18))
                      .setColor(colors.primaryText),
                ),
              ),
            ),
          ),
          FiatPrice(satoshiAmount: balance, textStyle: CoconutTypography.body3_12.setColor(colors.secondaryText)),
        ],
      ),
    );
  }
}

class _ScreenBackground extends StatelessWidget {
  final WalletItemBase wallet;

  const _ScreenBackground({required this.wallet});

  @override
  Widget build(BuildContext context) {
    final viewModel = context.read<WalletCardDetailViewModel>();
    final background = viewModel.appearanceOf(wallet).background;
    if (background == null) return ColoredBox(color: context.coconutColors.homeBackground);
    return WalletCardBackground(
      background: background,
      photoFile: context.watchWalletAppearance()?.photoFileFor(wallet.id),
    );
  }
}
