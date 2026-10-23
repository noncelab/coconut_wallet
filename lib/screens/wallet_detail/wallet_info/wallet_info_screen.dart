import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/model/feature/feature_navigation_target.dart';
import 'package:coconut_wallet/screens/common/feature_search_focus.dart';
import 'dart:async';
import 'package:coconut_wallet/constants/icon_path.dart';

import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/analytics/wallet_detail_analytics.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_view_model.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/providers/wallet_appearance_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/security/hot_wallet_unlock_service.dart';
import 'package:coconut_wallet/screens/common/flutter_hot_wallet_authenticator.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/screens/common/single_text_field_bottom_sheet.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_mfp_input_bottom_sheet.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart' show formatHomeRelativeTime;
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:coconut_wallet/widgets/common/overlays/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:coconut_wallet/screens/common/qr_with_copy_text_screen.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/numeric_input_formatters.dart';
import 'package:coconut_wallet/extensions/string_extensions.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/clipper/bubble_clipper.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/bitbox02_section.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/trezor_section.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/multisig_setup_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/taproot_setup_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/taproot_spend_type_bottom_sheet.dart';
import 'package:coconut_wallet/utils/mfp_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:provider/provider.dart';

const String kEntryPointWalletList = AppRouteNames.walletList;
const String kEntryPointWalletHome = '/wallet-home';

class WalletInfoScreen extends StatefulWidget {
  final int id;
  final WalletType walletType;
  final String entryPoint;
  final bool showMfpInput;
  final bool highlightMnemonicBackup;
  final bool showTargetSetting;
  final WalletInfoTarget? initialTarget;
  const WalletInfoScreen({
    super.key,
    required this.id,
    required this.walletType,
    required this.entryPoint,
    this.showMfpInput = false,
    this.highlightMnemonicBackup = false,
    this.showTargetSetting = false,
    this.initialTarget,
  });

  @override
  State<WalletInfoScreen> createState() => _WalletInfoScreenState();
}

class _MnemonicBackupButton extends StatefulWidget {
  const _MnemonicBackupButton({
    super.key,
    required this.onPressed,
    required this.showWarning,
    required this.isBackupVerified,
    this.backupVerifiedAt,
  });

  final VoidCallback onPressed;
  final bool showWarning;
  final bool isBackupVerified;
  final DateTime? backupVerifiedAt;

  @override
  State<_MnemonicBackupButton> createState() => _MnemonicBackupButtonState();
}

class _MnemonicBackupButtonState extends State<_MnemonicBackupButton> with SingleTickerProviderStateMixin {
  late final AnimationController _highlightController;

  String _formatBackupVerifiedAt(DateTime value) {
    final backupDate = value.toLocal();
    final formattedDate = t.wallet_info_screen.backup_date(
      year: backupDate.year,
      month: backupDate.month,
      day: backupDate.day,
    );
    return '${t.wallet_info_screen.backup_completed} · $formattedDate';
  }

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
  }

  Future<void> highlight() async {
    await _highlightController.forward(from: 0);
    await Future<void>.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    await _highlightController.reverse();
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _highlightController,
      builder: (context, child) {
        final progress = Curves.easeInOut.transform(_highlightController.value);
        final colors = context.coconutColors;
        final highlightedColor = colors.primaryText.withValues(alpha: 0.08);
        return ShrinkAnimationButton(
          onPressed: widget.onPressed,
          defaultColor: Color.lerp(Colors.transparent, highlightedColor, progress),
          pressedOverlayColor: colors.primaryText,
          pressedOverlayOpacity: 0.08,
          borderRadius: 12,
          child: Container(
            height: _WalletInfoScreenState._rowHeight,
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Row(
              children: [
                Text(
                  t.wallet_info_screen.mnemonic_backup,
                  style: CoconutTypography.body2_14.setColor(colors.primaryText),
                ),
                CoconutLayout.spacing_200w,
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.showWarning) ...[
                          SvgPicture.asset(
                            CommonStateIconPath.triangleWarning,
                            width: 16,
                            height: 16,
                            colorFilter: ColorFilter.mode(
                              context.coconutColors.appLockWarningBackground,
                              BlendMode.srcIn,
                            ),
                          ),
                          CoconutLayout.spacing_50w,
                          Text(
                            t.wallet_info_screen.backup_required,
                            style: CoconutTypography.body2_14_Bold.setColor(
                              context.coconutColors.appLockWarningBackground,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ] else if (widget.backupVerifiedAt != null) ...[
                          Text(
                            _formatBackupVerifiedAt(widget.backupVerifiedAt!),
                            style: CoconutTypography.body2_14.setColor(context.coconutColors.tertiaryText),
                            textAlign: TextAlign.end,
                          ),
                        ] else if (widget.isBackupVerified) ...[
                          Text(
                            t.wallet_info_screen.backup_completed,
                            style: CoconutTypography.body2_14.setColor(context.coconutColors.tertiaryText),
                            textAlign: TextAlign.end,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: _WalletInfoScreenState._trailingGap),
                const _RowArrow(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WalletInfoScreenState extends State<WalletInfoScreen> {
  Widget _focus(WalletInfoTarget target, Widget child, {double radius = 12}) =>
      widget.initialTarget == target
          ? FeatureSearchFocus(
            key: ValueKey('wallet-info-focus-${target.name}'),
            borderRadius: BorderRadius.circular(radius),
            child: child,
          )
          : child;
  final GlobalKey<_MnemonicBackupButtonState> _mnemonicBackupButtonKey = GlobalKey<_MnemonicBackupButtonState>();
  final GlobalKey _mfpTooltipIconKey = GlobalKey();
  static const Duration _tooltipDuration = Duration(seconds: 5);
  Timer? _tooltipTimer;
  Rect? _mfpTooltipAnchor;
  bool _hasScheduledTargetSetting = false;

  Widget _buildCardPreview(BuildContext context, WalletInfoViewModel viewModel) {
    final colors = context.coconutColors;
    final appearances = context.watchWalletAppearance();
    final wallet = viewModel.walletItemBase;
    final last = viewModel.lastTransactionTime;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 168,
              height: 168,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: WalletCard.elevationOf(context),
              ),
              child: WalletCard(
                key: const Key('wallet-info-card-preview'),
                wallet: wallet,
                appearance: appearances?.appearanceOf(wallet) ?? WalletAppearance.of(wallet),
                backgroundPhoto: appearances?.photoFileFor(wallet.id),
                size: WalletCardSize.small,
                secondaryText: last == null ? null : formatHomeRelativeTime(last, DateTime.now()),
              ),
            ),
            CoconutLayout.spacing_300h,
            _focus(
              WalletInfoTarget.appearance,
              radius: 20,
              ShrinkAnimationButton(
                key: const Key('wallet-info-appearance-edit'),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRouteNames.walletAppearance,
                    arguments: WalletAppearanceRouteArgs(id: widget.id),
                  );
                },
                defaultColor: colors.surfaceButton,
                pressedOverlayColor: colors.surfacePressOverlay,
                pressedOverlayOpacity: colors.surfacePressOverlayOpacity,
                borderRadius: 20,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    t.wallet_appearance_screen.edit_button,
                    style: CoconutTypography.body3_12_Bold.setColor(colors.surfaceButtonText),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<WalletInfoViewModel>(
      create:
          (_) => WalletInfoViewModel(
            widget.id,
            Provider.of<AuthProvider>(context, listen: false),
            Provider.of<WalletProvider>(context, listen: false),
            Provider.of<NodeProvider>(context, listen: false),
            widget.walletType,
          ),
      child: Consumer<WalletInfoViewModel>(
        builder: (innerContext, viewModel, child) {
          _scheduleTargetSettingBottomSheet(innerContext, viewModel);
          final wallet = viewModel.walletItemBase;
          final hotWalletMetadata = wallet.hotWalletMetadata;
          final needsPassphrase = hotWalletMetadata?.enterPassphraseWhenSigning ?? false;
          return Stack(
            children: [
              GestureDetector(
                onTapDown: (details) {
                  if (_mfpTooltipAnchor?.inflate(8).contains(details.globalPosition) ?? false) return;
                  _hideMfpTooltip();
                },
                child: NotificationListener<ScrollNotification>(
                  onNotification: (_) {
                    _hideMfpTooltip();
                    return false;
                  },
                  child: _buildScaffold(context, viewModel, wallet, hotWalletMetadata, needsPassphrase),
                ),
              ),
              if (_mfpTooltipAnchor case final anchor?)
                Positioned(
                  top: anchor.bottom - LeftTriangleBubbleClipper.arrowTip.dy + 2,
                  left: anchor.center.dx - LeftTriangleBubbleClipper.arrowTip.dx,
                  right: 16,
                  child: Align(alignment: Alignment.topLeft, child: _buildMfpTooltip(context, viewModel)),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    WalletInfoViewModel viewModel,
    WalletItemBase wallet,
    HotWalletMetadata? hotWalletMetadata,
    bool needsPassphrase,
  ) {
    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(title: '', context: context),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _buildCardPreview(context, viewModel),
            if (wallet.hasLocalKey || needsPassphrase)
              _section(t.wallet_info_screen.section_security, [
                if (wallet.hasLocalKey)
                  _MnemonicBackupButton(
                    key: _mnemonicBackupButtonKey,
                    isBackupVerified: hotWalletMetadata?.backupVerified ?? false,
                    showWarning: viewModel.walletBalance.total > 0 && !(hotWalletMetadata?.backupVerified ?? false),
                    backupVerifiedAt: hotWalletMetadata?.backupVerifiedAt,
                    onPressed: () => _showMnemonicBackup(viewModel),
                  ),
                if (needsPassphrase)
                  _focus(
                    WalletInfoTarget.passphrase,
                    _walletInfoMenu(
                      title: t.wallet_home_screen.hot_wallet_setup.passphrase_check_title,
                      onPressed: () => _showPassphraseCheck(viewModel),
                    ),
                  ),
              ]),
            _section(t.wallet_info_screen.section_details, _buildDetailRows(context, viewModel)),
            _section(t.wallet_info_screen.section_data, [
              _walletInfoMenu(
                title: t.wallet_info_screen.target_quantity,
                subWidget: Text(
                  viewModel.targetSats == null
                      ? t.wallet_info_screen.target_disabled
                      : context.read<PreferenceProvider>().currentUnit.displayBitcoinAmount(
                        viewModel.targetSats,
                        withUnit: true,
                      ),
                  style: _menuSubTextStyle,
                ),
                onPressed: () => _showTargetSettingBottomSheet(context, viewModel),
              ),
              _walletInfoMenu(
                title: t.wallet_info_screen.tag_management,
                subWidget: Text(
                  t.wallet_info_screen.tag_count(
                    count: context.watch<UtxoTagProvider>().getUtxoTagList(widget.id).length,
                  ),
                  style: _menuSubTextStyle,
                ),
                onPressed:
                    () => Navigator.pushNamed(
                      context,
                      AppRouteNames.utxoTag,
                      arguments: UtxoTagCrudRouteArgs(id: widget.id),
                    ),
              ),
              _walletInfoMenu(
                title: t.wallet_info_screen.memo_management,
                onPressed: () => _showLabelsManagementScreen(context, viewModel),
              ),
              _walletInfoMenu(
                title: t.wallet_info_screen.resync_label,
                onPressed:
                    () => Navigator.pushNamed(
                      context,
                      AppRouteNames.walletResync,
                      arguments: WalletResyncRouteArgs(id: widget.id),
                    ),
              ),
            ]),
            _section(t.wallet_info_screen.section_danger, [
              _focus(
                WalletInfoTarget.delete,
                _walletInfoMenu(
                  title: t.wallet_info_screen.delete_wallet,
                  trailing: SvgPicture.asset(
                    CommonActionIconPath.trash,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
                  ),
                  onPressed: () => _showDeleteWalletDialog(viewModel),
                ),
              ),
            ]),
            CoconutLayout.spacing_2500h,
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDetailRows(BuildContext context, WalletInfoViewModel viewModel) {
    final wallet = viewModel.walletItemBase;
    final mfp = walletMasterFingerprint(wallet);
    final bipLabel = viewModel.bipLabel;
    return [
      _walletInfoMenu(
        title: t.wallet_info_screen.wallet_type,
        subWidget: Text(
          [
            if (bipLabel != null) bipLabel,
            (wallet.hasLocalKey
                    ? t.wallet_home_screen.wallet_filter.hot
                    : t.wallet_home_screen.wallet_filter.watch_only)
                .toUpperCase(),
          ].join(' • '),
          style: _menuSubTextStyle,
        ),
        showArrowRight: false,
      ),
      if (widget.walletType == WalletType.singleSignature)
        _walletInfoMenu(
          title: t.wallet_info_screen.master_fingerprint,
          subWidget: Text(mfp == null ? t.wallet_info_screen.mfp_enter : formatMfp(mfp), style: _menuSubTextStyle),
          titleTrailing: GestureDetector(
            key: _mfpTooltipIconKey,
            behavior: HitTestBehavior.opaque,
            onTap: _toggleMfpTooltip,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.info_outline_rounded, color: context.coconutColors.iconSecondary, size: 18),
            ),
          ),
          showArrowRight: viewModel.canEditMfp,
          onPressed: viewModel.canEditMfp ? _showMfpInputBottomSheet : null,
        ),
      if (widget.walletType == WalletType.singleSignature)
        _focus(
          WalletInfoTarget.extendedPublicKey,
          _walletInfoMenu(
            title: t.wallet_info_screen.extended_public_key,
            onPressed:
                () => _handleAuthFlow(
                  onComplete:
                      () => _showQrBottomSheet(
                        title: t.extended_public_key,
                        data: viewModel.extendedPublicKey,
                        screenName: AnalyticsScreenNames.walletInfoXpubSheet,
                      ),
                ),
          ),
        ),
      if (viewModel.descriptor.isNotEmpty)
        _walletInfoMenu(
          title: t.wallet_info_screen.descriptor,
          onPressed:
              () => _handleAuthFlow(
                onComplete:
                    () => _showQrBottomSheet(
                      title: t.wallet_info_screen.descriptor,
                      data: viewModel.descriptor,
                      screenName: AnalyticsScreenNames.walletInfoDescriptorSheet,
                    ),
              ),
        ),
      _walletInfoMenu(
        title: t.wallet_info_screen.all_addresses,
        subWidget: Text(
          t.wallet_info_screen.watched_addresses_count(count: viewModel.watchedAddressCount),
          style: _menuSubTextStyle,
        ),
        onPressed:
            () =>
                Navigator.pushNamed(context, AppRouteNames.addressList, arguments: AddressListRouteArgs(id: widget.id)),
      ),
      if (widget.walletType == WalletType.multiSignature) ...[
        _walletInfoSubheader(t.wallet_info_screen.multisig_setup),
        _walletInfoMenu(
          title: t.wallet_info_screen.quorum,
          indent: true,
          subWidget: Text(
            '${viewModel.multisigRequiredSignerCount} / ${viewModel.multisigTotalSignerCount}',
            style: _menuSubTextStyle,
          ),
          onPressed: () => _showMultisigSetup(viewModel),
        ),
        _focus(
          WalletInfoTarget.backupData,
          _walletInfoMenu(
            title: t.wallet_info_screen.bsms,
            indent: true,
            onPressed:
                () => Navigator.pushNamed(
                  context,
                  AppRouteNames.walletBackupData,
                  arguments: WalletBackupDataRouteArgs(id: widget.id, walletName: viewModel.walletName),
                ),
          ),
        ),
      ],
      if (widget.walletType == WalletType.taproot) ...[
        _walletInfoSubheader(t.wallet_info_screen.inheritance_setup),
        _walletInfoMenu(
          title: t.wallet_signer_section.title,
          indent: true,
          subWidget: Text(
            viewModel.taprootSpendTypeIndex == 0
                ? t.wallet_signer_section.segmented_control.parent_key
                : t.wallet_signer_section.segmented_control.child_key,
            style: _menuSubTextStyle,
          ),
          showArrowRight: viewModel.canSpendBothPaths,
          onPressed: viewModel.canSpendBothPaths ? () => _showTaprootSpendTypeSheet(viewModel) : null,
        ),
        _walletInfoMenu(
          title: t.wallet_info_screen.taproot_participants,
          indent: true,
          subWidget: Text(
            t.wallet_info_screen.taproot_participant_count(
              parent: viewModel.taprootParticipantCount.parent,
              child: viewModel.taprootParticipantCount.child,
            ),
            style: _menuSubTextStyle,
          ),
          onPressed: () => _showTaprootSetup(viewModel),
        ),
        _focus(
          WalletInfoTarget.backupData,
          _walletInfoMenu(
            title: t.wallet_info_screen.backup_data,
            indent: true,
            onPressed:
                () => Navigator.pushNamed(
                  context,
                  AppRouteNames.taprootWalletBackupData,
                  arguments: TaprootWalletBackupDataRouteArgs(id: widget.id, walletName: viewModel.walletName),
                ),
          ),
        ),
      ],
      if (viewModel.isBitBox02Wallet)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: BitBox02Section(
            walletFingerprint: viewModel.walletFingerprint,
            onDisconnect: () async => viewModel.disconnectBitBox02(),
          ),
        ),
      if (viewModel.isTrezorWallet)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: TrezorSection(
            walletFingerprint: viewModel.walletFingerprint,
            onDisconnect: () async => viewModel.disconnectTrezor(),
          ),
        ),
    ];
  }

  static const double _tooltipPadding = 16;

  /// MFP 말풍선. 너비는 글자 폭 기준 기본 말풍선(좌우 18)의 110%, 본문 여백은 사방 14로 같다.
  Widget _buildMfpTooltip(BuildContext context, WalletInfoViewModel viewModel) {
    final style = CoconutTypography.body3_12
        .setColor(context.coconutColors.popoverText)
        .merge(const TextStyle(height: 1.3));
    final text = _mfpTooltipText(viewModel);
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = (painter.width + 36) * 1.1;
    painter.dispose();
    final arrowHeight = LeftTriangleBubbleClipper.arrowTip.dy + 10;
    return SizedBox(
      width: width,
      child: CoconutToolTip(
        width: width,
        isBubbleClipperSideLeft: true,
        tooltipType: CoconutTooltipType.placement,
        backgroundColor: context.coconutColors.popoverBackground,
        padding: EdgeInsets.fromLTRB(_tooltipPadding, arrowHeight + _tooltipPadding, _tooltipPadding, _tooltipPadding),
        richText: RichText(text: TextSpan(text: text, style: style)),
        onTapRemove: _hideMfpTooltip,
        isPlacementTooltipVisible: true,
      ),
    );
  }

  String _mfpTooltipText(WalletInfoViewModel viewModel) {
    var text = t.tooltip.mfp;
    if (viewModel.isMfpPlaceholder) text += '\n${t.wallet_info_screen.tooltip.mfp_placeholder_description}';
    return text;
  }

  void _toggleMfpTooltip() {
    if (_mfpTooltipAnchor != null) {
      _hideMfpTooltip();
      return;
    }
    final box = _mfpTooltipIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    setState(() => _mfpTooltipAnchor = box.localToGlobal(Offset.zero) & box.size);
    _tooltipTimer?.cancel();
    _tooltipTimer = Timer(_tooltipDuration, _hideMfpTooltip);
  }

  void _hideMfpTooltip() {
    _tooltipTimer?.cancel();
    if (_mfpTooltipAnchor == null || !mounted) return;
    setState(() => _mfpTooltipAnchor = null);
  }

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    super.dispose();
  }

  void _showMultisigSetup(WalletInfoViewModel viewModel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: MultisigSetupScreen.routeName),
        builder:
            (_) =>
                ChangeNotifierProvider<WalletInfoViewModel>.value(value: viewModel, child: const MultisigSetupScreen()),
      ),
    );
  }

  void _showTaprootSetup(WalletInfoViewModel viewModel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        settings: const RouteSettings(name: TaprootSetupScreen.routeName),
        builder:
            (_) =>
                ChangeNotifierProvider<WalletInfoViewModel>.value(value: viewModel, child: const TaprootSetupScreen()),
      ),
    );
  }

  void _showTaprootSpendTypeSheet(WalletInfoViewModel viewModel) {
    CommonBottomSheets.showBottomSheet<void>(
      context: context,
      title: t.wallet_signer_section.title,
      screenName: AnalyticsScreenNames.walletInfoTaprootSpendTypeSheet,
      showCloseButton: true,
      child: ChangeNotifierProvider<WalletInfoViewModel>.value(
        value: viewModel,
        child: const TaprootSpendTypeBottomSheet(),
      ),
    );
  }

  void _scheduleTargetSettingBottomSheet(BuildContext context, WalletInfoViewModel viewModel) {
    if (!widget.showTargetSetting || _hasScheduledTargetSetting) return;
    _hasScheduledTargetSetting = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted || !context.mounted) return;
      _showTargetSettingBottomSheet(context, viewModel);
    });
  }

  void _showLabelsManagementScreen(BuildContext context, WalletInfoViewModel viewModel) {
    Navigator.pushNamed(
      context,
      AppRouteNames.labelManagement,
      arguments: LabelManagementRouteArgs(id: viewModel.walletId),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _setOverlayLoading(false);
      if (widget.showMfpInput) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (!mounted) return;
        await _showMfpInputBottomSheet();
      }
      if (widget.highlightMnemonicBackup) {
        await _focusMnemonicBackupButton();
      }
    });
  }

  Future<void> _focusMnemonicBackupButton() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    final backupButtonContext = _mnemonicBackupButtonKey.currentContext;
    if (backupButtonContext == null || !backupButtonContext.mounted) return;

    await Scrollable.ensureVisible(
      backupButtonContext,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      alignment: 0.5,
    );
    if (!mounted) return;
    await _mnemonicBackupButtonKey.currentState?.highlight();
  }

  Future<String?> _showMfpInputBottomSheet() async {
    final result = await CommonBottomSheets.showBottomSheet_100<String>(
      context: context,
      screenName: AnalyticsScreenNames.walletInfoMfpSheet,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      child: WalletAddMfpInputBottomSheet(
        onComplete: (text) {
          Navigator.pop(context, text);
        },
      ),
    );

    if (result != null && result.isNotEmpty && mounted) {
      await context.read<WalletProvider>().updateWalletDescriptor(widget.id, result);
    }

    return result;
  }

  void _showTargetSettingBottomSheet(BuildContext context, WalletInfoViewModel viewModel) {
    if (viewModel.isUpdatingTarget) return;
    final btcString =
        viewModel.targetSats != null ? BalanceFormatUtil.formatSatoshiToBtcInputText(viewModel.targetSats!) : '';
    final parentContext = context;

    void showStorageError() {
      if (!parentContext.mounted) return;
      CoconutToast.showToast(
        context: parentContext,
        isVisibleIcon: true,
        iconPath: CommonStateIconPath.triangleWarning,
        text: t.errors.storage_write_error,
        level: CoconutToastLevel.warning,
      );
    }

    SingleTextFieldBottomSheet.show(
      context: context,
      screenName: AnalyticsScreenNames.walletInfoEditTargetAmountSheet,
      title: t.wallet_info_screen.target_set_title,
      originalText: btcString,
      completeButtonText: t.done,
      placeholder: t.wallet_info_screen.target_set_placeholder,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      visibleTextLimit: false,
      maxLength: 20,
      collapsedHeight: 300,
      textInputFormatters: [const BtcAmountInputFormatter()],
      completeEnabledWhen: (current, original) {
        final currentText = current.trim();
        return currentText.isNotEmpty && currentText != original.trim();
      },
      focusOnlyWhenOriginalNotEmpty: true,
      toggleLabel: t.wallet_info_screen.target_enabled,
      toggleDescription: t.wallet_info_screen.target_enabled_description,
      initiallyEnabled: !viewModel.isTargetDisabled,
      submitValidator: (text) {
        final btc = text.toDoubleSafe();
        return btc != null && btc <= 0 ? t.wallet_info_screen.target_set_zero_error : null;
      },
      suffix: Text(
        BitcoinUnit.btc.symbol,
        style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
      ),
      onComplete: (text) async {
        if (viewModel.isUpdatingTarget) return;
        if (text.isEmpty) {
          try {
            await viewModel.removeTargetSats();
          } catch (_) {
            showStorageError();
          }
          return;
        }

        final btc = text.toDoubleSafe();
        if (btc == null || btc <= 0) {
          if (text.isNotEmpty) {
            CoconutToast.showToast(
              context: parentContext,
              isVisibleIcon: true,
              iconPath: CommonStateIconPath.triangleWarning,
              text: t.wallet_info_screen.target_set_invalid,
              level: CoconutToastLevel.warning,
            );
          }
          return;
        }
        final sats = UnitUtil.convertBitcoinToSatoshi(btc);
        if (sats > 0) {
          final analytics = parentContext.read<AnalyticsService>();
          try {
            if (await viewModel.setTargetSats(sats)) {
              analytics.logTargetAmountSaved();
              if (btc == 21_000_000 && parentContext.mounted) {
                vibrateMedium();
                CoconutToast.showToast(
                  context: parentContext,
                  text: t.wallet_info_screen.target_set_21m,
                  isVisibleIcon: true,
                  iconPath: FeatureWalletIconPath.pie,
                  iconSize: 16,
                  iconRightPadding: 8,
                );
              }
            }
          } catch (_) {
            showStorageError();
          }
          return;
        }

        CoconutToast.showToast(
          context: parentContext,
          isVisibleIcon: true,
          iconPath: CommonStateIconPath.triangleWarning,
          text: t.wallet_info_screen.target_set_invalid,
          level: CoconutToastLevel.warning,
        );
      },
    );
  }

  Future<void> _deleteWalletAndGoToEntryPoint(WalletInfoViewModel viewModel) async {
    final navigator = Navigator.of(context);
    final languageCode = context.read<PreferenceProvider>().language;

    _setOverlayLoading(true);

    try {
      await viewModel.deleteWallet();

      _setOverlayLoading(false);

      if (mounted) {
        if (widget.entryPoint == kEntryPointWalletHome) {
          navigator.pushNamedAndRemoveUntil('/', (route) => false);
        } else {
          navigator.pushNamedAndRemoveUntil(kEntryPointWalletList, (route) => route.isFirst);
        }
      }
    } catch (e) {
      debugPrint('Delete wallet failed: $e');
      _setOverlayLoading(false);
      if (mounted) {
        await showInfoDialog(context, languageCode, t.wallet_info_screen.error.delete, e.toString());
      }
    }
  }

  Future<void> _showDeleteWalletDialog(WalletInfoViewModel viewModel) async {
    final shouldConfirmBackup = viewModel.walletItemBase.hasLocalKey && viewModel.walletBalance.total > 0;
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.alert.wallet_delete.confirm_delete,
          description: t.alert.wallet_delete.confirm_delete_description,
          onTapRight: () => Navigator.of(dialogContext).pop(true),
          onTapLeft: () => Navigator.of(dialogContext).pop(false),
          rightButtonText: t.delete,
          rightButtonColor: context.coconutColors.dangerText,
          leftButtonText: t.cancel,
        );
      },
    );
    if (shouldDelete != true || !mounted) return;

    if (shouldConfirmBackup) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      final backupConfirmed = await _showBackupBeforeDeleteDialog(viewModel);
      if (backupConfirmed != true || !mounted) return;
    }

    _handleAuthFlow(onComplete: () => _deleteWalletAndGoToEntryPoint(viewModel));
  }

  Future<bool?> _showBackupBeforeDeleteDialog(WalletInfoViewModel viewModel) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.alert.wallet_delete.confirm_backup,
          description: t.alert.wallet_delete.confirm_backup_description,
          onTapRight: () => Navigator.of(dialogContext).pop(true),
          onTapLeft: () {
            Navigator.of(dialogContext).pop(false);
            _showMnemonicBackup(viewModel);
          },
          rightButtonText: t.alert.wallet_delete.backup_and_delete,
          rightButtonColor: context.coconutColors.dangerText,
          leftButtonText: t.alert.wallet_delete.backup_now,
        );
      },
    );
  }

  void _setOverlayLoading(bool value) {
    if (!mounted) return;
    if (value) {
      context.loaderOverlay.show();
    } else {
      context.loaderOverlay.hide();
    }
  }

  Future<void> _handleAuthFlow({required VoidCallback onComplete}) async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthEnabled) {
      onComplete();
      return;
    }

    if (await authProvider.isBiometricsAuthValid()) {
      onComplete();
      return;
    }

    if (!mounted) return;
    await CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      screenName: AnalyticsScreenNames.walletInfoAuthSheet,
      heightRatio: 0.9,
      child: CustomLoadingOverlay(child: PinCheckScreen(onComplete: onComplete)),
    );
  }

  void _showQrBottomSheet({required String title, required String data, required String screenName}) {
    CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      screenName: screenName,
      heightRatio: 0.9,
      backgroundColor: context.coconutColors.background,
      child: QrWithCopyTextScreen(
        qrData: data,
        title: title,
        isBottom: true,
        showPulldownMenu: false,
        backgroundColor: context.coconutColors.background,
      ),
    );
  }

  Future<void> _showMnemonicBackup(WalletInfoViewModel viewModel) async {
    final metadata = viewModel.walletItemBase.hotWalletMetadata;
    if (metadata == null) return;

    await Navigator.pushNamed(
      context,
      AppRouteNames.hotWalletMnemonicBackupGuide,
      arguments: HotWalletMnemonicBackupGuideRouteArgs(
        walletId: widget.id,
        secureStorageKey: metadata.secureStorageKey,
        enterPassphraseWhenSigning: metadata.enterPassphraseWhenSigning,
        showWalletCreatedIntro: false,
        continueToAppLockGuide: false,
        returnToPreviousOnExit: true,
      ),
    );
  }

  Future<void> _showPassphraseCheck(WalletInfoViewModel viewModel) async {
    final metadata = viewModel.walletItemBase.hotWalletMetadata;
    if (metadata == null || !metadata.enterPassphraseWhenSigning) return;

    try {
      final plaintext = await AppGuard.runWithoutPrivacyScreen(
        () => HotWalletUnlockService(
          authenticator: FlutterHotWalletAuthenticator(context),
        ).unlock(metadata.secureStorageKey),
      );
      if (!mounted || plaintext == null) return;
      try {
        await Navigator.pushNamed(
          context,
          AppRouteNames.hotWalletPassphraseCheck,
          arguments: HotWalletPassphraseCheckRouteArgs(
            mnemonic: plaintext.mnemonic,
            descriptor: viewModel.walletItemBase.descriptor,
          ),
        );
      } finally {
        plaintext.wipe();
      }
    } catch (error) {
      if (!mounted) return;
      await showInfoDialog(
        context,
        context.read<PreferenceProvider>().language,
        t.alert.error_occurs,
        error.toString(),
      );
    }
  }

  Widget _section(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 12, color: context.coconutColors.divider),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(title, style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText)),
          ),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Column(children: children)),
        ],
      ),
    );
  }

  static const double _rowHeight = 52;
  static const double _trailingGap = 8;

  Widget _walletInfoSubheader(String title) {
    return SizedBox(
      height: _rowHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(title, style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText)),
        ),
      ),
    );
  }

  /// 지갑 정보의 한 줄. 높이가 같고, 화살표나 [trailing]이 없으면 값이 오른쪽 끝에 붙는다.
  Widget _walletInfoMenu({
    required String title,
    VoidCallback? onPressed,
    Widget? subWidget,
    Widget? rightWidget,
    Widget? trailing,
    Widget? titleTrailing,
    TextStyle? titleStyle,
    bool showArrowRight = true,
    bool indent = false,
  }) {
    final resolvedTitleStyle = titleStyle ?? CoconutTypography.body2_14.setColor(context.coconutColors.primaryText);
    final row = SizedBox(
      height: _rowHeight,
      child: Padding(
        padding: EdgeInsets.only(left: indent ? 28 : 12, right: 8),
        child: Row(
          children: [
            Text(title, style: resolvedTitleStyle),
            if (titleTrailing != null) ...[const SizedBox(width: 2), titleTrailing],
            CoconutLayout.spacing_200w,
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (subWidget != null)
                    Flexible(
                      child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: subWidget),
                    ),
                  if (rightWidget != null) ...[CoconutLayout.spacing_100w, rightWidget],
                ],
              ),
            ),
            if (trailing != null || showArrowRight) ...[
              const SizedBox(width: _trailingGap),
              trailing ?? const _RowArrow(),
            ],
          ],
        ),
      ),
    );
    if (onPressed == null) return row;
    return ShrinkAnimationButton(
      onPressed: onPressed,
      defaultColor: Colors.transparent,
      pressedOverlayColor: context.coconutColors.primaryText,
      pressedOverlayOpacity: 0.08,
      borderRadius: 12,
      child: row,
    );
  }

  TextStyle get _menuSubTextStyle => CoconutTypography.body2_14.setColor(context.coconutColors.tertiaryText);
}

/// 지갑 정보 행의 화살표. 여백 없는 화살표라 글자 행과 오른쪽 끝이 맞는다.
class _RowArrow extends StatelessWidget {
  const _RowArrow();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      CommonNavigationIconPath.arrowRight,
      width: 7,
      height: 12,
      colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
    );
  }
}
