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
import 'package:flutter/foundation.dart';
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
              width: 20,
              height: 20,
              FeatureUtxoIconPath.faucet,
              colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
            ),
          ),
        ListenableBuilder(
          listenable: _viewModel,
          builder:
              (context, _) => CoconutAppBarActionButton(
                onPressed: _viewModel.isRefreshing || _viewModel.isWalletSyncing ? null : _viewModel.refresh,
                icon: WalletRefreshIcon(isRefreshing: _viewModel.isRefreshing, size: 20),
              ),
        ),
        CoconutAppBarActionButton(
          onPressed: _openWalletInfo,
          icon: SvgPicture.asset(
            FeatureSettingsIconPath.settings,
            width: 20,
            height: 20,
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
        final isTargetExceeded = viewModel.isTargetExceeded;
        if (target == null && !viewModel.shouldShowTargetSuggestion) {
          return const SizedBox.shrink();
        }

        return ShrinkAnimationButton(
          key: ValueKey(target == null),
          onPressed: () => _openWalletInfo(showTargetSetting: target == null),
          defaultColor: context.coconutColors.surface,
          pressedOverlayColor: context.coconutColors.surfacePressOverlay,
          pressedOverlayOpacity: target == null ? context.coconutColors.surfacePressOverlayOpacity : 0,
          animationEndValue: target == null ? 0.97 : 1,
          isActive: target == null,
          borderRadius: 20,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            target == null
                                ? 'Stay humble, stack sats!'
                                : isTargetExceeded
                                ? t.wallet_info_screen.target_exceeded_title
                                : t.wallet_info_screen.target_progress_title,
                            style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
                          ),
                        ),
                        if (target != null && !isTargetExceeded)
                          Text(
                            '${viewModel.targetProgressPercent}%',
                            style: CoconutTypography.body1_16_NumberBold.setColor(context.coconutColors.iconPrimary),
                          ),
                      ],
                    ),
                    if (target == null) ...[
                      CoconutLayout.spacing_150h,
                      Text(
                        t.wallet_info_screen.target_not_set_secondary,
                        style: CoconutTypography.body2_14_NumberBold.setColor(context.coconutColors.secondaryText),
                      ),
                    ] else ...[
                      CoconutLayout.spacing_100h,
                      Text(
                        '${viewModel.currentUnit.displayBitcoinAmount(viewModel.balance, withUnit: true)} / ${t.wallet_info_screen.target} ${viewModel.currentUnit.displayBitcoinAmount(target, withUnit: true)}',
                        style: CoconutTypography.body3_12_Number.setColor(context.coconutColors.secondaryText),
                      ),
                      if (isTargetExceeded) ...[
                        CoconutLayout.spacing_100h,
                        Builder(
                          builder: (context) {
                            final amount = viewModel.currentUnit.displayBitcoinAmount(
                              viewModel.targetExcessSats,
                              withUnit: true,
                            );
                            final message = t.wallet_info_screen.target_exceeded_secondary(amount: amount);
                            final amountStart = message.indexOf(amount);
                            final baseStyle = CoconutTypography.body3_12_Number.setColor(
                              context.coconutColors.secondaryText,
                            );

                            return Text.rich(
                              TextSpan(
                                style: baseStyle,
                                children: [
                                  TextSpan(text: message.substring(0, amountStart)),
                                  TextSpan(text: amount, style: baseStyle.setColor(context.coconutColors.primary)),
                                  TextSpan(text: message.substring(amountStart + amount.length)),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                      CoconutLayout.spacing_300h,
                      _TargetProgressChart(
                        progress: viewModel.targetProgress,
                        history: viewModel.targetProgressHistory,
                        targetLabel:
                            '${t.wallet_info_screen.target} ${viewModel.currentUnit.displayBitcoinAmount(target, withUnit: true)}',
                      ),
                    ],
                  ],
                ),
              ),
              if (target == null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Semantics(
                    button: true,
                    label: t.close,
                    child: InkWell(
                      onTap: viewModel.dismissTargetSuggestion,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: SvgPicture.asset(
                          CommonActionIconPath.closeBold,
                          width: 12,
                          height: 12,
                          colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
                        ),
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

  Future<void> _openWalletInfo({bool showTargetSetting = false}) async {
    await Navigator.pushNamed(
      context,
      '/wallet-info',
      arguments: {
        'id': widget.id,
        'walletType': _viewModel.wallet.walletType,
        'entryPoint': widget.entryPoint,
        'showTargetSetting': showTargetSetting,
      },
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

class _TargetProgressChart extends StatelessWidget {
  static const _painterTop = 14.0;

  final double progress;
  final List<double> history;
  final String targetLabel;

  const _TargetProgressChart({required this.progress, required this.history, required this.targetLabel});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 108,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final goalLineY = _TargetProgressChartPainter.calculateGoalLineY(
            height: constraints.maxHeight - _painterTop,
            values: history,
            progress: progress,
          );
          const targetLabelHeight = 16.0;
          const targetLabelGap = 4.0;
          final targetLabelTop = (_painterTop + goalLineY - targetLabelHeight - targetLabelGap).clamp(
            0.0,
            double.infinity,
          );

          return Stack(
            children: [
              Positioned.fill(
                top: _painterTop,
                child: CustomPaint(
                  painter: _TargetProgressChartPainter(
                    values: history,
                    progress: progress,
                    guideColor: context.coconutColors.dividerStrong,
                    inactiveColor: context.coconutColors.dividerStrong,
                    gradientStartColor: context.coconutColors.targetProgressGradientStart,
                    gradientEndColor: context.coconutColors.targetProgressGradientEnd,
                  ),
                ),
              ),
              Positioned(
                top: targetLabelTop,
                left: 0,
                child: Text(
                  targetLabel,
                  style: CoconutTypography.body3_12_Number.setColor(context.coconutColors.secondaryText),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TargetProgressChartPainter extends CustomPainter {
  static const defaultGoalLineY = 16.0;
  static const _topInset = 2.0;
  static const _bottomInset = 4.0;

  final List<double> values;
  final double progress;
  final Color guideColor;
  final Color inactiveColor;
  final Color gradientStartColor;
  final Color gradientEndColor;

  const _TargetProgressChartPainter({
    required this.values,
    required this.progress,
    required this.guideColor,
    required this.inactiveColor,
    required this.gradientStartColor,
    required this.gradientEndColor,
  });

  static double calculateGoalLineY({required double height, required List<double> values, required double progress}) {
    final bottomY = height - _bottomInset;
    var maxValue = progress;
    for (final value in values) {
      if (value > maxValue) maxValue = value;
    }
    return maxValue <= 1 ? defaultGoalLineY : bottomY - (bottomY - _topInset) / (maxValue * 1.08);
  }

  @override
  void paint(Canvas canvas, Size size) {
    const horizontalInset = 2.0;
    final bottomY = size.height - _bottomInset;
    final safeValues = values.length < 2 ? <double>[0, progress] : values;
    final goalLineY = calculateGoalLineY(height: size.height, values: safeValues, progress: progress);
    final unitHeight = bottomY - goalLineY;

    final dashPaint =
        Paint()
          ..color = guideColor
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
    for (double x = horizontalInset; x < size.width; x += 9) {
      canvas.drawLine(Offset(x, goalLineY), Offset((x + 4).clamp(0, size.width), goalLineY), dashPaint);
    }

    final points = <Offset>[];
    for (var index = 0; index < safeValues.length; index++) {
      final x = horizontalInset + (size.width - horizontalInset * 2) * index / (safeValues.length - 1);
      final value = safeValues[index].clamp(0.0, double.infinity);
      final y = bottomY - value * unitHeight;
      points.add(Offset(x, y.clamp(_topInset, bottomY)));
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var index = 1; index < points.length; index++) {
      final previous = points[index - 1];
      final current = points[index];
      final controlX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(controlX, previous.dy, controlX, current.dy, current.dx, current.dy);
    }

    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [gradientStartColor, gradientEndColor],
    );
    final isNotStarted = progress <= 0;
    final shaderRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final fillPath =
        Path.from(linePath)
          ..lineTo(points.last.dx, size.height)
          ..lineTo(points.first.dx, size.height)
          ..close();
    if (!isNotStarted) {
      canvas.saveLayer(shaderRect, Paint());
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: gradient.colors.map((color) => color.withValues(alpha: 0.46)).toList(),
          ).createShader(shaderRect),
      );
      canvas.drawRect(
        shaderRect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xE6FFFFFF), Colors.transparent],
            stops: [0, 0.3, 1],
          ).createShader(shaderRect)
          ..blendMode = BlendMode.dstIn,
      );
      canvas.restore();
    }
    final linePaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    if (isNotStarted) {
      linePaint
        ..color = inactiveColor
        ..strokeWidth = 2;
    } else {
      linePaint.shader = gradient.createShader(shaderRect);
    }
    canvas.drawPath(linePath, linePaint);

    final end = points.last;
    if (isNotStarted) {
      return;
    }
    canvas.drawCircle(
      end,
      10,
      Paint()
        ..color = gradient.colors.last.withValues(alpha: 0.75)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawCircle(end, 3, Paint()..color = gradient.colors.last.withValues(alpha: 0.3));
    canvas.drawCircle(end, 2, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _TargetProgressChartPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.guideColor != guideColor ||
        oldDelegate.inactiveColor != inactiveColor ||
        oldDelegate.gradientStartColor != gradientStartColor ||
        oldDelegate.gradientEndColor != gradientEndColor ||
        !listEquals(oldDelegate.values, values);
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
