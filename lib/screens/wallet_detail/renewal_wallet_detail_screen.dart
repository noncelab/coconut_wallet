import 'package:coconut_design_system/coconut_design_system.dart'
    hide CoconutAppBar, CoconutPopup, CoconutToast, CoconutToolTip, CoconutTooltipState, CoconutTooltipType;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/constants/security_warning_constants.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/renewal_wallet_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/settings/app_settings/app_settings_screen.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/amount/animated_balance.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:coconut_wallet/widgets/common/buttons/bottom_action_bar.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/home/card/home_alert_card.dart';
import 'package:coconut_wallet/widgets/features/transaction/card/transaction_item_card.dart';
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
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();
  final Set<_WalletDetailSecurityWarningType> _dismissedWarningsThisSession = {};
  _WalletDetailSecurityWarningType? _nextWarningAfterDismissal;
  late final RenewalWalletDetailViewModel _viewModel;
  late BitcoinUnit _currentUnit;

  @override
  void initState() {
    super.initState();
    _currentUnit = context.read<PreferenceProvider>().currentUnit;
    _viewModel = RenewalWalletDetailViewModel(
      widget.id,
      context.read<WalletProvider>(),
      context.read<TransactionProvider>(),
      context.read<NodeProvider>(),
    );
  }

  @override
  void dispose() {
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
            CupertinoScrollbar(
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  CupertinoSliverRefreshControl(onRefresh: _viewModel.refresh),
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
                      ],
                    ),
                  ),
                ],
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
        CoconutAppBarActionButton(
          onPressed: _viewModel.refresh,
          icon: SvgPicture.asset(
            CommonActionIconPath.arrowReload,
            width: 18,
            height: 18,
            colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
          ),
        ),
        CoconutAppBarActionButton(
          onPressed: _openWalletInfo,
          icon: SvgPicture.asset(
            FeatureWalletIconPath.walletOutlined,
            width: 18,
            height: 18,
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
          onTap: () => setState(() => _currentUnit = _currentUnit.next),
          child: Column(
            children: [
              FiatPrice(satoshiAmount: viewModel.balance),
              CoconutLayout.spacing_100h,
              FittedBox(
                fit: BoxFit.scaleDown,
                child: BitcoinAmountUnit(
                  currentUnit: _currentUnit,
                  unitStyle: CoconutTypography.heading4_18_Number.setColor(context.coconutColors.primaryText),
                  child: AnimatedBalance(
                    prevValue: viewModel.balance,
                    value: viewModel.balance,
                    currentUnit: _currentUnit,
                    textStyle: CoconutTypography.heading2_28_NumberBold.setColor(context.coconutColors.primaryText),
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
        final wallet = viewModel.wallet;
        if (!wallet.hasLocalKey || viewModel.balance <= 0) {
          return const SizedBox.shrink();
        }

        final warningType =
            !(wallet.hotWalletMetadata?.backupVerified ?? false) &&
                    _canShowSecurityWarning(_WalletDetailSecurityWarningType.unbackedHotWallet)
                ? _WalletDetailSecurityWarningType.unbackedHotWallet
                : !isAppLockEnabled && _canShowSecurityWarning(_WalletDetailSecurityWarningType.appLock)
                ? _WalletDetailSecurityWarningType.appLock
                : null;
        if (warningType == null) return const SizedBox.shrink();

        final isMnemonicWarning = warningType == _WalletDetailSecurityWarningType.unbackedHotWallet;
        final iconColor =
            isMnemonicWarning ? context.coconutColors.iconOnDanger : context.coconutColors.appLockWarningForeground;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: HomeAlertCard.security(
            key: ValueKey(warningType),
            type: isMnemonicWarning ? HomeAlertCardType.mnemonicBackup : HomeAlertCardType.appLock,
            showDelay: _nextWarningAfterDismissal == warningType ? _nextWarningDelay : const Duration(seconds: 1),
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
                () => _dismissSecurityWarning(
                  warningType,
                  showNextWarning:
                      isMnemonicWarning &&
                      !isAppLockEnabled &&
                      _canShowSecurityWarning(_WalletDetailSecurityWarningType.appLock),
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
        final progress = target == null || target == 0 ? 0.0 : (viewModel.balance / target).clamp(0.0, 1.0);

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
                        '${_formatPercent(progress)}% / ${_currentUnit.displayBitcoinAmount(target, withUnit: true)}',
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
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                decoration: BoxDecoration(
                  color: context.coconutColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  t.wallet_detail_screen.never_used_wallet,
                  textAlign: TextAlign.center,
                  style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                ),
              )
            else
              ...viewModel.recentTransactions.indexed.map(
                (entry) => Padding(
                  padding: EdgeInsets.only(bottom: entry.$1 == viewModel.recentTransactions.length - 1 ? 0 : 8),
                  child: TransactionItemCard(
                    tx: entry.$2,
                    currentUnit: _currentUnit,
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
              padding: const EdgeInsets.symmetric(vertical: 14),
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
    return Positioned.fill(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: BottomActionBar(
          child: Row(
            children: [
              Expanded(
                child: BottomActionButton(
                  iconPath: FeatureTransactionIconPath.receivePlane,
                  label: t.receive,
                  onTap: () => Navigator.pushNamed(context, '/receive-address', arguments: {'id': widget.id}),
                  buttonLayout: BottomActionButtonLayout.horizontal,
                  textStyle: CoconutTypography.body2_14_Bold,
                ),
              ),
              Expanded(
                child: BottomActionButton(
                  iconPath: FeatureTransactionIconPath.sendPlane,
                  label: t.send,
                  onTap:
                      () => Navigator.pushNamed(
                        context,
                        '/send',
                        arguments: {'walletId': widget.id, 'sendEntryPoint': SendEntryPoint.renewalWalletDetail},
                      ),
                  buttonLayout: BottomActionButtonLayout.horizontal,
                  textStyle: CoconutTypography.body2_14_Bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPercent(double progress) {
    final percent = progress * 100;
    return percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent.toStringAsFixed(1);
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

  bool _canShowSecurityWarning(_WalletDetailSecurityWarningType type) {
    if (_dismissedWarningsThisSession.contains(type)) return false;
    final dismissedAt = _sharedPrefs.getInt(type.dismissedAtKey);
    return dismissedAt == 0 ||
        DateTime.now().millisecondsSinceEpoch - dismissedAt >= kSecurityWarningDismissDuration.inMilliseconds;
  }

  Future<void> _dismissSecurityWarning(_WalletDetailSecurityWarningType type, {required bool showNextWarning}) async {
    _dismissedWarningsThisSession.add(type);
    await _sharedPrefs.setInt(type.dismissedAtKey, DateTime.now().millisecondsSinceEpoch);
    if (!mounted) return;
    setState(() => _nextWarningAfterDismissal = showNextWarning ? _WalletDetailSecurityWarningType.appLock : null);
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
      defaultColor: Colors.transparent,
      pressedOverlayColor: context.coconutColors.surfacePressOverlay,
      pressedOverlayOpacity: context.coconutColors.surfacePressOverlayOpacity,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
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

enum _WalletDetailSecurityWarningType { unbackedHotWallet, appLock }

extension on _WalletDetailSecurityWarningType {
  String get dismissedAtKey => switch (this) {
    _WalletDetailSecurityWarningType.unbackedHotWallet => SharedPrefKeys.kUnbackedHotWalletWarningDismissedAt,
    _WalletDetailSecurityWarningType.appLock => SharedPrefKeys.kAppLockWarningDismissedAt,
  };
}
