import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutPopup,
        CoconutToast,
        CoconutToastLevel,
        CoconutToolTip,
        CoconutTooltipState,
        CoconutTooltipType;
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/renewal_wallet_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/app_settings/app_settings_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_faucet_request_bottom_sheet.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/amount/animated_balance.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:coconut_wallet/widgets/common/buttons/bottom_action_bar.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/home/card/home_alert_card.dart';
import 'package:coconut_wallet/widgets/features/transaction/card/transaction_item_card.dart';
import 'package:coconut_wallet/widgets/features/wallet/amount/wallet_balance_sync_shimmer.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_refresh_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class RenewalWalletDetailScreen extends StatefulWidget {
  final int id;
  final String entryPoint;

  const RenewalWalletDetailScreen({super.key, required this.id, required this.entryPoint});

  @override
  State<RenewalWalletDetailScreen> createState() => _RenewalWalletDetailScreenState();
}

class _RenewalWalletDetailScreenState extends State<RenewalWalletDetailScreen> {
  static const _nextWarningDelay = Duration(milliseconds: 400);
  late final RenewalWalletDetailViewModel _viewModel;
  final ValueNotifier<bool> _bottomActionButtonsExpandedNotifier = ValueNotifier<bool>(true);
  bool? _pendingBottomActionButtonsExpanded;
  bool _isBottomActionButtonsUpdateScheduled = false;

  @override
  void initState() {
    super.initState();
    _viewModel = RenewalWalletDetailViewModel(
      widget.id,
      context.read<WalletProvider>(),
      context.read<TransactionProvider>(),
      context.read<NodeProvider>(),
      initialUnit: context.read<PreferenceProvider>().currentUnit,
    );
  }

  @override
  void dispose() {
    _bottomActionButtonsExpandedNotifier.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: context.coconutColors.background,
        appBar: _buildAppBar(context),
        body: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollStartNotification || notification is ScrollUpdateNotification) {
                  _scheduleBottomActionButtonsExpanded(false);
                } else if (notification is ScrollEndNotification) {
                  _scheduleBottomActionButtonsExpanded(true);
                }
                return false;
              },
              child: CupertinoScrollbar(
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    Selector<RenewalWalletDetailViewModel, bool>(
                      selector: (_, viewModel) => viewModel.isWalletSyncing,
                      builder:
                          (_, isWalletSyncing, _) =>
                              isWalletSyncing
                                  ? const SliverToBoxAdapter(child: SizedBox.shrink())
                                  : CupertinoSliverRefreshControl(
                                    onRefresh: _viewModel.refresh,
                                    refreshTriggerPullDistance: 80,
                                  ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 150),
                      sliver: SliverList.list(
                        children: [
                          _buildBalanceHeader(),
                          CoconutLayout.spacing_500h,
                          _buildSecurityWarning(),
                          _buildTargetCard(),
                          CoconutLayout.spacing_500h,
                          _buildRecentTransactions(),
                          CoconutLayout.spacing_500h,
                          _buildUtxoSection(),
                          CoconutLayout.spacing_2500h,
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return CoconutAppBar.build(
      context: context,
      title: '',
      backgroundColor: context.coconutColors.background,
      actionButtonList: [
        if (NetworkType.currentNetworkType.isTestnet)
          CoconutAppBarActionButton(
            onPressed: _openFaucetRequest,
            icon: SvgPicture.asset(
              FeatureUtxoIconPath.faucet,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
            ),
          ),
        ListenableBuilder(
          listenable: _viewModel,
          builder:
              (context, _) => CoconutAppBarActionButton(
                onPressed: _viewModel.isRefreshing || _viewModel.isWalletSyncing ? null : _viewModel.refresh,
                icon: WalletRefreshIcon(isRefreshing: _viewModel.isRefreshing, size: 24),
              ),
        ),
        CoconutAppBarActionButton(
          onPressed: _openWalletInfo,
          icon: SvgPicture.asset(
            FeatureSettingsIconPath.settings,
            width: 24,
            height: 24,
            colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
          ),
        ),
      ],
    );
  }

  Widget _buildBalanceHeader() {
    return Consumer<RenewalWalletDetailViewModel>(
      builder: (context, viewModel, _) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: viewModel.toggleUnit,
          child: Column(
            children: [
              FiatPrice(satoshiAmount: viewModel.balance),
              CoconutLayout.spacing_100h,
              WalletBalanceSyncShimmer(
                isRefreshing: viewModel.isRefreshing || viewModel.isWalletSyncing,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: BitcoinAmountUnit(
                    currentUnit: viewModel.currentUnit,
                    unitStyle: CoconutTypography.heading4_18_Number.setColor(context.coconutColors.primaryText),
                    child: AnimatedBalance(
                      prevValue: viewModel.balance,
                      value: viewModel.balance,
                      currentUnit: viewModel.currentUnit,
                      textStyle: CoconutTypography.heading2_28_NumberBold.setColor(context.coconutColors.primaryText),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSecurityWarning() {
    final isAppLockEnabled = context.watch<AuthProvider>().isAuthEnabled;
    return Consumer<RenewalWalletDetailViewModel>(
      builder: (context, viewModel, _) {
        final warningType = viewModel.getSecurityWarningType(isAppLockEnabled: isAppLockEnabled);
        if (warningType == null) return const SizedBox.shrink();

        final isMnemonicWarning = warningType == RenewalWalletDetailSecurityWarningType.unbackedHotWallet;
        final iconColor =
            isMnemonicWarning ? context.coconutColors.iconOnDanger : context.coconutColors.appLockWarningForeground;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: HomeAlertCard.security(
            key: ValueKey(warningType),
            type: isMnemonicWarning ? HomeAlertCardType.mnemonicBackup : HomeAlertCardType.appLock,
            showDelay:
                viewModel.shouldUseShortWarningDelay(warningType) ? _nextWarningDelay : const Duration(seconds: 1),
            title:
                isMnemonicWarning
                    ? t.wallet_home_screen.unbacked_hot_wallet_warning.title
                    : t.wallet_home_screen.app_lock_warning.title,
            description:
                isMnemonicWarning
                    ? t.wallet_home_screen.unbacked_hot_wallet_warning.description
                    : t.wallet_home_screen.app_lock_warning.description,
            onTap: isMnemonicWarning ? _openMnemonicBackup : _openAppLockSettings,
            onClosed:
                () => viewModel.dismissSecurityWarning(
                  warningType,
                  showNextWarning:
                      isMnemonicWarning &&
                      !isAppLockEnabled &&
                      viewModel.canShowSecurityWarning(RenewalWalletDetailSecurityWarningType.appLock),
                ),
            icon: SvgPicture.asset(
              isMnemonicWarning ? CommonStateIconPath.triangleWarning : CommonStateIconPath.shieldWarning,
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTargetCard() {
    return Consumer<RenewalWalletDetailViewModel>(
      builder: (context, viewModel, _) {
        final target = viewModel.targetSats;
        final progress = viewModel.targetProgress;

        return ShrinkAnimationButton(
          onPressed: _openWalletInfo,
          defaultColor: context.coconutColors.surface,
          pressedOverlayColor: context.coconutColors.surfacePressOverlay,
          pressedOverlayOpacity: context.coconutColors.surfacePressOverlayOpacity,
          borderRadius: 20,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        target == null ? 'Stay humble, stack sats!' : t.wallet_info_screen.target_quantity,
                        style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.secondaryText),
                      ),
                    ),
                    if (target != null)
                      Text(
                        '${viewModel.targetProgressPercent}% / ${viewModel.currentUnit.displayBitcoinAmount(target, withUnit: true)}',
                        style: CoconutTypography.body3_12_Number.setColor(context.coconutColors.secondaryText),
                      ),
                  ],
                ),
                if (target == null) ...[
                  CoconutLayout.spacing_100h,
                  Text(
                    t.wallet_info_screen.target_not_set_secondary,
                    style: CoconutTypography.body3_12.setColor(context.coconutColors.tertiaryText),
                  ),
                ],
                CoconutLayout.spacing_300h,
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: context.coconutColors.pageIndicatorInactive,
                    valueColor: AlwaysStoppedAnimation(context.coconutColors.pageIndicatorActive),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentTransactions() {
    return Consumer<RenewalWalletDetailViewModel>(
      builder: (context, viewModel, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              title: t.wallet_detail_screen.recent_transactions,
              actionLabel: t.wallet_detail_screen.view_all,
              actionEnabled: viewModel.hasTransactions,
              onAction: _openTransactionList,
            ),
            CoconutLayout.spacing_200h,
            if (!viewModel.hasTransactions)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      CommonStateIconPath.leafFall,
                      colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
                    ),
                    CoconutLayout.spacing_200w,
                    Text(
                      t.wallet_detail_screen.never_used_wallet,
                      textAlign: TextAlign.center,
                      style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                    ),
                  ],
                ),
              )
            else
              ...viewModel.recentTransactions.indexed.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: entry.$1 == viewModel.recentTransactions.length - 1 ? 0 : 8),
                  child: TransactionItemCard(
                    tx: entry.$2,
                    currentUnit: viewModel.currentUnit,
                    id: widget.id,
                    onPressed: () => _openTransaction(entry.$2),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildUtxoSection() {
    return Consumer<RenewalWalletDetailViewModel>(
      builder: (context, viewModel, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.wallet_detail_screen.utxo_count(count: viewModel.utxoCount),
              style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
            ),
            CoconutLayout.spacing_200h,
            Container(
              decoration: BoxDecoration(color: context.coconutColors.surface, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  Expanded(
                    child: _UtxoAction(
                      iconPath: CommonMenuIconPath.grid,
                      label: t.wallet_detail_screen.utxo_overview,
                      description: t.wallet_detail_screen.utxo_overview_description,
                      onTap: () => Navigator.pushNamed(context, '/utxo-overview', arguments: {'id': widget.id}),
                    ),
                  ),
                  Expanded(
                    child: _UtxoAction(
                      iconPath: FeatureUtxoIconPath.splitUtxo,
                      label: t.wallet_detail_screen.utxo_organize,
                      description: t.wallet_detail_screen.utxo_organize_description,
                      onTap: () => Navigator.pushNamed(context, '/merge-utxos', arguments: {'id': widget.id}),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottomActionBar() {
    return ValueListenableBuilder<bool>(
      valueListenable: _bottomActionButtonsExpandedNotifier,
      builder: (context, isExpanded, _) {
        return Positioned.fill(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: BottomActionBar(
              child: AnimatedSlide(
                offset: isExpanded ? Offset.zero : const Offset(0, 0.35),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedScale(
                        scale: isExpanded ? 1 : 0.8,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: BottomActionButton(
                          iconPath: FeatureTransactionIconPath.receivePlane,
                          label: t.receive,
                          onTap: () => Navigator.pushNamed(context, '/receive-address', arguments: {'id': widget.id}),
                          buttonLayout: BottomActionButtonLayout.horizontal,
                          textStyle: CoconutTypography.body2_14_Bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: AnimatedScale(
                        scale: isExpanded ? 1 : 0.8,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        child: BottomActionButton(
                          iconPath: FeatureTransactionIconPath.sendPlane,
                          label: t.send,
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                '/send',
                                arguments: {
                                  'walletId': widget.id,
                                  'sendEntryPoint': SendEntryPoint.renewalWalletDetail,
                                },
                              ),
                          buttonLayout: BottomActionButtonLayout.horizontal,
                          textStyle: CoconutTypography.body2_14_Bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _scheduleBottomActionButtonsExpanded(bool isExpanded) {
    _pendingBottomActionButtonsExpanded = isExpanded;
    if (_isBottomActionButtonsUpdateScheduled) return;

    _isBottomActionButtonsUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _isBottomActionButtonsUpdateScheduled = false;
      if (!mounted) return;

      final pendingValue = _pendingBottomActionButtonsExpanded;
      _pendingBottomActionButtonsExpanded = null;
      if (pendingValue != null && _bottomActionButtonsExpandedNotifier.value != pendingValue) {
        _bottomActionButtonsExpandedNotifier.value = pendingValue;
      }
    });
  }

  void _openTransaction(TransactionRecord transaction) {
    Navigator.pushNamed(
      context,
      '/transaction-detail',
      arguments: {'id': widget.id, 'txHash': transaction.transactionHash},
    );
  }

  void _openTransactionList() {
    Navigator.pushNamed(context, '/wallet-detail', arguments: {'id': widget.id, 'entryPoint': widget.entryPoint});
  }

  Future<void> _openWalletInfo() async {
    await Navigator.pushNamed(
      context,
      '/wallet-info',
      arguments: {'id': widget.id, 'walletType': _viewModel.wallet.walletType, 'entryPoint': widget.entryPoint},
    );
    if (mounted) _viewModel.reloadWalletMetadata();
  }

  void _openMnemonicBackup() {
    Navigator.pushNamed(
      context,
      '/wallet-info',
      arguments: {
        'id': widget.id,
        'walletType': _viewModel.wallet.walletType,
        'entryPoint': widget.entryPoint,
        'highlightMnemonicBackup': true,
      },
    );
  }

  void _openAppLockSettings() {
    CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      child: const AppSettingsScreen(),
      heightRatio: 0.9,
    );
  }

  Future<void> _openFaucetRequest() async {
    await CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      heightRatio: 0.5,
      child: FaucetRequestBottomSheet(
        walletData: {
          'wallet_id': _viewModel.walletId,
          'wallet_address': _viewModel.receiveAddress,
          'wallet_name': _viewModel.wallet.name,
          'wallet_index': _viewModel.receiveAddressIndex,
        },
        isRequesting: _viewModel.isRequestingFaucet,
        onRequest: (address, requestAmount) {
          if (_viewModel.isRequestingFaucet) return;
          _viewModel.requestTestBitcoin(address, requestAmount, (success, message) {
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
        walletProvider: _viewModel.walletProvider,
        walletItem: _viewModel.wallet,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final bool actionEnabled;
  final VoidCallback onAction;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.actionEnabled,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText)),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: actionEnabled ? onAction : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Row(
              children: [
                Text(
                  actionLabel,
                  style: CoconutTypography.body3_12.setColor(
                    actionEnabled ? context.coconutColors.secondaryText : context.coconutColors.mutedText,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: actionEnabled ? context.coconutColors.iconSecondary : context.coconutColors.iconDisabled,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UtxoAction extends StatelessWidget {
  final String iconPath;
  final String label;
  final String description;
  final VoidCallback onTap;

  const _UtxoAction({required this.iconPath, required this.label, required this.description, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ShrinkAnimationButton(
      onPressed: onTap,
      pressedOverlayColor: context.coconutColors.surfacePressOverlay,
      pressedOverlayOpacity: context.coconutColors.surfacePressOverlayOpacity,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 22),
        child: Column(
          children: [
            SvgPicture.asset(
              iconPath,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
            ),
            CoconutLayout.spacing_100h,
            Text(label, style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText)),
            const SizedBox(height: 2),
            Text(description, style: CoconutTypography.body3_12.setColor(context.coconutColors.tertiaryText)),
          ],
        ),
      ),
    );
  }
}
