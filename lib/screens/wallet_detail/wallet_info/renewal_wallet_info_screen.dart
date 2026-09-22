import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
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
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/security/hot_wallet_unlock_service.dart';
import 'package:coconut_wallet/screens/common/flutter_hot_wallet_authenticator.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/screens/common/single_text_field_bottom_sheet.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_mfp_input_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_signer_section.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_info_item_card.dart';
import 'package:coconut_wallet/widgets/common/overlays/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:coconut_wallet/screens/common/qr_with_copy_text_screen.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/numeric_input_formatters.dart';
import 'package:coconut_wallet/extensions/string_extensions.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/bitbox02_section.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/trezor_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

const String kEntryPointWalletList = AppRouteNames.walletList;
const String kEntryPointWalletHome = '/wallet-home';

class RenewalWalletInfoScreen extends StatefulWidget {
  final int id;
  final WalletType walletType;
  final String entryPoint;
  final bool showMfpInput;
  final bool highlightMnemonicBackup;
  final bool showTargetSetting;
  const RenewalWalletInfoScreen({
    super.key,
    required this.id,
    required this.walletType,
    required this.entryPoint,
    this.showMfpInput = false,
    this.highlightMnemonicBackup = false,
    this.showTargetSetting = false,
  });

  @override
  State<RenewalWalletInfoScreen> createState() => _RenewalWalletInfoScreenState();
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.wallet_info_screen.mnemonic_backup,
                  style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText),
                ),
                CoconutLayout.spacing_200w,
                Flexible(
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
                            colorFilter: ColorFilter.mode(colors.appLockWarningBackground, BlendMode.srcIn),
                          ),
                          CoconutLayout.spacing_50w,
                          Text(
                            t.wallet_info_screen.backup_required,
                            style: CoconutTypography.body2_14.setColor(colors.appLockWarningBackground),
                            textAlign: TextAlign.end,
                          ),
                          CoconutLayout.spacing_100w,
                        ] else if (widget.backupVerifiedAt != null) ...[
                          Text(
                            _formatBackupVerifiedAt(widget.backupVerifiedAt!),
                            style: CoconutTypography.body2_14.setColor(context.coconutColors.tertiaryText),
                            textAlign: TextAlign.end,
                          ),
                          CoconutLayout.spacing_100w,
                        ] else if (widget.isBackupVerified) ...[
                          Text(
                            t.wallet_info_screen.backup_completed,
                            style: CoconutTypography.body2_14.setColor(context.coconutColors.tertiaryText),
                            textAlign: TextAlign.end,
                          ),
                          CoconutLayout.spacing_100w,
                        ],
                        Icon(Icons.keyboard_arrow_right_rounded, color: colors.iconSecondary),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RenewalWalletInfoScreenState extends State<RenewalWalletInfoScreen> {
  final GlobalKey _walletTooltipKey = GlobalKey();
  final GlobalKey<_MnemonicBackupButtonState> _mnemonicBackupButtonKey = GlobalKey<_MnemonicBackupButtonState>();
  static const int kTooltipDuration = 5;
  RenderBox? _walletTooltipIconRenderBox;
  Offset _walletTooltipIconPosition = Offset.zero;
  double _tooltipTopPadding = 0;
  Timer? _tooltipTimer;
  int _tooltipRemainingTime = 0;
  bool _hasScheduledTargetSetting = false;

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
          return Stack(
            children: [
              GestureDetector(
                onTapDown: (details) => _removeTooltip(),
                child: Scaffold(
                  backgroundColor: context.coconutColors.background,
                  appBar: CoconutAppBar.build(title: '', context: context),
                  body: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 12, left: 16, right: 16),
                          child: WalletInfoItemCard(
                            id: widget.id,
                            walletItem: viewModel.walletItemBase,
                            taprootKeyPathSelected: viewModel.taprootSpendTypeIndex == 0,
                            onTooltipClicked: () {
                              if (_tooltipRemainingTime > 0) {
                                _removeTooltip();
                                return;
                              }

                              Future.delayed(const Duration(milliseconds: 50), () {
                                setState(() {
                                  _tooltipRemainingTime = kTooltipDuration;
                                });

                                _tooltipTimer?.cancel();
                                _tooltipTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                                  setState(() {
                                    if (_tooltipRemainingTime > 0) {
                                      _tooltipRemainingTime--;
                                    } else {
                                      _removeTooltip();
                                      timer.cancel();
                                    }
                                  });
                                });
                              });
                            },
                            onShowMfpInputBottomSheet: () {
                              _showMfpInputBottomSheet();
                            },
                            tooltipKey: _walletTooltipKey,
                            onNameChanged: (updatedName) => viewModel.updateWalletName(updatedName),
                          ),
                        ),
                        WalletSignerSection(walletType: widget.walletType),
                        if (viewModel.isBitBox02Wallet)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: BitBox02Section(
                              walletFingerprint: viewModel.walletFingerprint,
                              onDisconnect: () async {
                                await viewModel.disconnectBitBox02();
                              },
                            ),
                          ),
                        if (viewModel.isTrezorWallet)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            child: TrezorSection(
                              walletFingerprint: viewModel.walletFingerprint,
                              onDisconnect: () async {
                                await viewModel.disconnectTrezor();
                              },
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              if (viewModel.walletItemBase.hasLocalKey)
                                _MnemonicBackupButton(
                                  key: _mnemonicBackupButtonKey,
                                  isBackupVerified: viewModel.walletItemBase.hotWalletMetadata?.backupVerified ?? false,
                                  showWarning:
                                      viewModel.walletBalance.total > 0 &&
                                      !(viewModel.walletItemBase.hotWalletMetadata?.backupVerified ?? false),
                                  backupVerifiedAt: viewModel.walletItemBase.hotWalletMetadata?.backupVerifiedAt,
                                  onPressed: () {
                                    _removeTooltip();
                                    _showMnemonicBackup(viewModel);
                                  },
                                ),
                              _walletInfoMenu(
                                title: t.wallet_info_screen.all_addresses,
                                subWidget: Text(
                                  t.wallet_info_screen.watched_addresses_count(count: viewModel.watchedAddressCount),
                                  style: _menuSubTextStyle,
                                ),
                                onPressed: () {
                                  _removeTooltip();
                                  Navigator.pushNamed(
                                    context,
                                    AppRouteNames.addressList,
                                    arguments: AddressListRouteArgs(id: widget.id),
                                  );
                                },
                              ),
                              if (widget.walletType == WalletType.singleSignature) ...[
                                _walletInfoMenu(
                                  title: t.wallet_info_screen.extended_public_key,
                                  onPressed: () {
                                    _removeTooltip();
                                    _handleAuthFlow(
                                      onComplete: () {
                                        _showExtendedBottomSheet(viewModel.extendedPublicKey);
                                      },
                                    );
                                  },
                                ),
                              ],
                              if (widget.walletType == WalletType.taproot) ...[
                                _walletInfoMenu(
                                  title: t.wallet_info_screen.view_wallet_backup_data,
                                  onPressed: () {
                                    _removeTooltip();

                                    Navigator.pushNamed(
                                      context,
                                      AppRouteNames.taprootWalletBackupData,
                                      arguments: TaprootWalletBackupDataRouteArgs(
                                        id: widget.id,
                                        walletName: viewModel.walletName,
                                      ),
                                    );
                                  },
                                ),
                              ],
                              if (widget.walletType == WalletType.multiSignature) ...[
                                _walletInfoMenu(
                                  title: t.wallet_info_screen.view_wallet_backup_data,
                                  onPressed: () {
                                    _removeTooltip();

                                    Navigator.pushNamed(
                                      context,
                                      AppRouteNames.walletBackupData,
                                      arguments: WalletBackupDataRouteArgs(
                                        id: widget.id,
                                        walletName: viewModel.walletName,
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                        _sectionDivider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              _walletInfoMenu(
                                title: t.wallet_info_screen.target_quantity,
                                subWidget:
                                    viewModel.targetSats == null
                                        ? Text(t.wallet_info_screen.target_disabled, style: _menuSubTextStyle)
                                        : Text(
                                          context.read<PreferenceProvider>().currentUnit.displayBitcoinAmount(
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
                                onPressed: () {
                                  _removeTooltip();
                                  Navigator.pushNamed(
                                    context,
                                    AppRouteNames.utxoTag,
                                    arguments: UtxoTagCrudRouteArgs(id: widget.id),
                                  );
                                },
                              ),
                              _walletInfoMenu(
                                title: t.wallet_info_screen.memo_management,
                                onPressed: () {
                                  _showLabelsManagementScreen(context, viewModel);
                                },
                              ),
                              if (viewModel.walletItemBase.hotWalletMetadata?.enterPassphraseWhenSigning ?? false)
                                _walletInfoMenu(
                                  title: t.wallet_home_screen.hot_wallet_setup.passphrase_check_title,
                                  onPressed: () {
                                    _removeTooltip();
                                    _showPassphraseCheck(viewModel);
                                  },
                                ),
                            ],
                          ),
                        ),
                        _sectionDivider(),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Column(
                            children: [
                              _walletInfoMenu(
                                title: t.wallet_info_screen.resync_label,
                                onPressed: () {
                                  _removeTooltip();
                                  Navigator.pushNamed(
                                    context,
                                    AppRouteNames.walletResync,
                                    arguments: WalletResyncRouteArgs(id: widget.id),
                                  );
                                },
                              ),
                              _walletInfoMenu(
                                title: t.wallet_info_screen.delete_wallet,
                                titleStyle: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.danger),
                                showArrowRight: false,
                                subWidget: Container(
                                  width: 24,
                                  height: 24,
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: context.coconutColors.danger.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SvgPicture.asset(
                                    CommonActionIconPath.trash,
                                    width: 16,
                                    height: 16,
                                    colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
                                  ),
                                ),
                                onPressed: () {
                                  _removeTooltip();
                                  _showDeleteWalletDialog(viewModel);
                                },
                              ),
                            ],
                          ),
                        ),
                        CoconutLayout.spacing_2500h,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: _tooltipTopPadding,
                right:
                    MediaQuery.of(context).size.width -
                    _walletTooltipIconPosition.dx -
                    (_walletTooltipIconRenderBox == null ? 0 : _walletTooltipIconRenderBox!.size.width) -
                    10,
                child: CoconutToolTip(
                  width: MediaQuery.sizeOf(context).width,
                  isBubbleClipperSideLeft: false,
                  tooltipType: CoconutTooltipType.placement,
                  backgroundColor: context.coconutColors.popoverBackground,
                  richText: RichText(
                    text: TextSpan(
                      text: _getTooltipText(viewModel),
                      style: CoconutTypography.body3_12
                          .setColor(context.coconutColors.popoverText)
                          .merge(const TextStyle(height: 1.3)),
                    ),
                  ),
                  onTapRemove: _removeTooltip,
                  isPlacementTooltipVisible: _tooltipRemainingTime > 0,
                ),
              ),
            ],
          );
        },
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
    _removeTooltip();
    Navigator.pushNamed(
      context,
      AppRouteNames.labelManagement,
      arguments: LabelManagementRouteArgs(id: viewModel.walletId),
    );
  }

  String _getTooltipText(WalletInfoViewModel viewModel) {
    switch (widget.walletType) {
      case WalletType.multiSignature:
        return t.tooltip.multisig_wallet(
          total: viewModel.multisigTotalSignerCount,
          count: viewModel.multisigRequiredSignerCount,
        );
      case WalletType.singleSignature:
        var tooltipText = t.tooltip.mfp;
        if (viewModel.isMfpPlaceholder) {
          tooltipText += '\n${t.wallet_info_screen.tooltip.mfp_placeholder_description}';
        }
        return tooltipText;
      case WalletType.taproot:
        return t.wallet_info_screen.tooltip.taproot_created_at;
    }
  }

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _initializeTooltipPosition();
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
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: WalletAddMfpInputBottomSheet(
            onComplete: (text) {
              Navigator.pop(context, text);
            },
          ),
        );
      },
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
    );

    if (result != null && result.isNotEmpty && mounted) {
      await context.read<WalletProvider>().updateWalletDescriptor(widget.id, result);
    }

    return result;
  }

  void _initializeTooltipPosition() {
    try {
      _walletTooltipIconRenderBox = _walletTooltipKey.currentContext?.findRenderObject() as RenderBox?;
      if (_walletTooltipIconRenderBox != null) {
        _walletTooltipIconPosition = _walletTooltipIconRenderBox!.localToGlobal(Offset.zero);
        _tooltipTopPadding = _walletTooltipIconPosition.dy + _walletTooltipIconRenderBox!.size.height;

        // debugPrint('MediaQuery.paddingOf(context).top = ${MediaQuery.paddingOf(context).top}');
        // debugPrint('kToolbarHeight = $kToolbarHeight');
        // debugPrint(
        //     '_walletTooltipIconRenderBox!.size.height: ${_walletTooltipIconRenderBox!.size.height}');
        // debugPrint('_tooltipTopPadding: $_tooltipTopPadding');
      }
    } catch (e) {
      // debugPrint('Tooltip position initialization failed: $e');
      _walletTooltipIconPosition = Offset.zero;
    }
  }

  _removeTooltip() {
    if (_tooltipRemainingTime == 0) return;
    setState(() {
      _tooltipRemainingTime = 0;
    });
    _tooltipTimer?.cancel();
  }

  void _showTargetSettingBottomSheet(BuildContext context, WalletInfoViewModel viewModel) {
    final btcString =
        viewModel.targetSats != null ? BalanceFormatUtil.formatSatoshiToBtcInputText(viewModel.targetSats!) : '';
    final parentContext = context;

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
      onComplete: (text) {
        if (text.isEmpty) {
          viewModel.removeTargetSats();
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
        if (btc == 21_000_000) {
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

        final sats = UnitUtil.convertBitcoinToSatoshi(btc);
        if (sats > 0) {
          viewModel.setTargetSats(sats);
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
          rightButtonColor: context.coconutColors.danger,
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
          rightButtonColor: context.coconutColors.danger,
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

  void _showExtendedBottomSheet(String extendedPublicKey) {
    CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      screenName: AnalyticsScreenNames.walletInfoXpubSheet,
      heightRatio: 0.9,
      backgroundColor: context.coconutColors.background,
      child: QrWithCopyTextScreen(
        qrData: extendedPublicKey,
        title: t.extended_public_key,
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

  Widget _walletInfoMenu({
    required VoidCallback onPressed,
    required String title,
    Widget? subWidget,
    Widget? rightWidget,
    TextStyle? titleStyle,
    bool showArrowRight = true,
  }) {
    final resolvedTitleStyle =
        titleStyle ?? CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText);

    return ShrinkAnimationButton(
      onPressed: onPressed,
      defaultColor: Colors.transparent,
      pressedOverlayColor: context.coconutColors.primaryText,
      pressedOverlayOpacity: 0.08,
      borderRadius: 12,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(child: Text(title, style: resolvedTitleStyle)),
            CoconutLayout.spacing_200w,
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (subWidget != null) ...[Flexible(child: subWidget), CoconutLayout.spacing_100w],
                  if (rightWidget != null) rightWidget,
                  if (showArrowRight)
                    Icon(Icons.keyboard_arrow_right_rounded, color: context.coconutColors.iconSecondary),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle get _menuSubTextStyle => CoconutTypography.body2_14.setColor(context.coconutColors.tertiaryText);

  Widget _sectionDivider() => Container(height: 16, color: context.coconutColors.divider);
}
