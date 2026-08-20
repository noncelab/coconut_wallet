import 'dart:async';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/constants/lottie_path.dart';

import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup;
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/security/hot_wallet_unlock_service.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/screens/common/single_text_field_bottom_sheet.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_mfp_input_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_signer_section.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/button_group.dart';
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
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
import 'package:lottie/lottie.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

const String kEntryPointWalletList = '/wallet-list';
const String kEntryPointWalletHome = '/wallet-home';

class WalletInfoScreen extends StatefulWidget {
  final int id;
  final WalletType walletType;
  final String entryPoint;
  final bool showMfpInput;
  final bool highlightMnemonicBackup;
  const WalletInfoScreen({
    super.key,
    required this.id,
    required this.walletType,
    required this.entryPoint,
    this.showMfpInput = false,
    this.highlightMnemonicBackup = false,
  });

  @override
  State<WalletInfoScreen> createState() => _WalletInfoScreenState();
}

class _MnemonicBackupButton extends StatefulWidget {
  const _MnemonicBackupButton({super.key, required this.onPressed, required this.showWarning});

  final VoidCallback onPressed;
  final bool showWarning;

  @override
  State<_MnemonicBackupButton> createState() => _MnemonicBackupButtonState();
}

class _MnemonicBackupButtonState extends State<_MnemonicBackupButton> with SingleTickerProviderStateMixin {
  late final AnimationController _highlightController;

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
        final pressedColor = Color.alphaBlend(
          colors.surfacePressOverlay.withValues(alpha: colors.surfacePressOverlayOpacity),
          colors.surface,
        );
        return SingleButton(
          enableShrinkAnim: true,
          backgroundColor: Color.lerp(colors.surface, pressedColor, progress),
          title: t.wallet_home_screen.hot_wallet_setup.backup_title,
          rightElement:
              widget.showWarning
                  ? SvgPicture.asset(
                    CommonStateIconPath.triangleWarning,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(context.coconutColors.appLockWarningBackground, BlendMode.srcIn),
                  )
                  : null,
          showRightArrowWithRightElement: widget.showWarning,
          onPressed: widget.onPressed,
        );
      },
    );
  }
}

class _WalletInfoScreenState extends State<WalletInfoScreen> {
  final GlobalKey _walletTooltipKey = GlobalKey();
  final GlobalKey<_MnemonicBackupButtonState> _mnemonicBackupButtonKey = GlobalKey<_MnemonicBackupButtonState>();
  static const int kTooltipDuration = 5;
  RenderBox? _walletTooltipIconRenderBox;
  Offset _walletTooltipIconPosition = Offset.zero;
  double _tooltipTopPadding = 0;
  Timer? _tooltipTimer;
  int _tooltipRemainingTime = 0;

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
          return Stack(
            children: [
              GestureDetector(
                onTapDown: (details) => _removeTooltip(),
                child: Scaffold(
                  backgroundColor: context.coconutColors.background,
                  appBar: CoconutAppBar.build(title: '', context: context),
                  body: SingleChildScrollView(
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
                        _WalletInfoStatsSection(
                          walletId: widget.id,
                          transactionCount: viewModel.transactionCount,
                          utxoCount: viewModel.utxoCount,
                          balanceSats: viewModel.walletBalance.total,
                          currentUnit: context.read<PreferenceProvider>().currentUnit,
                          targetSats: viewModel.targetSats,
                          onEditTargetTap: () => _showTargetSettingBottomSheet(context, viewModel),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: ButtonGroup(
                            buttons: [
                              SingleButton(
                                enableShrinkAnim: true,
                                title: t.view_all_addresses,
                                onPressed: () {
                                  _removeTooltip();
                                  Navigator.pushNamed(context, '/address-list', arguments: {'id': widget.id});
                                },
                              ),
                              if (widget.walletType == WalletType.singleSignature) ...[
                                SingleButton(
                                  enableShrinkAnim: true,
                                  title: t.wallet_info_screen.view_xpub,
                                  onPressed: () async {
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
                                SingleButton(
                                  enableShrinkAnim: true,
                                  title: t.wallet_info_screen.view_wallet_backup_data,
                                  onPressed: () {
                                    _removeTooltip();

                                    Navigator.pushNamed(
                                      context,
                                      '/taproot-wallet-backup-data',
                                      arguments: {'id': widget.id, 'walletName': viewModel.walletName},
                                    );
                                  },
                                ),
                              ],
                              if (widget.walletType == WalletType.multiSignature) ...[
                                SingleButton(
                                  enableShrinkAnim: true,
                                  title: t.wallet_info_screen.view_wallet_backup_data,
                                  onPressed: () {
                                    _removeTooltip();

                                    Navigator.pushNamed(
                                      context,
                                      '/wallet-backup-data',
                                      arguments: {'id': widget.id, 'walletName': viewModel.walletName},
                                    );
                                  },
                                ),
                              ],
                              SingleButton(
                                enableShrinkAnim: true,
                                title: t.tag_manage_label,
                                onPressed: () {
                                  _removeTooltip();
                                  Navigator.pushNamed(context, '/utxo-tag', arguments: {'id': widget.id});
                                },
                              ),
                              if (viewModel.walletItemBase.hasLocalKey)
                                _MnemonicBackupButton(
                                  key: _mnemonicBackupButtonKey,
                                  showWarning:
                                      viewModel.walletBalance.total > 0 &&
                                      !(viewModel.walletItemBase.hotWalletMetadata?.backupVerified ?? false),
                                  onPressed: () {
                                    _removeTooltip();
                                    _showMnemonicBackup(viewModel);
                                  },
                                ),
                              if (viewModel.walletItemBase.hotWalletMetadata?.enterPassphraseWhenSigning ?? false)
                                SingleButton(
                                  enableShrinkAnim: true,
                                  title: t.wallet_home_screen.hot_wallet_setup.passphrase_check_title,
                                  onPressed: () {
                                    _removeTooltip();
                                    _showPassphraseCheck(viewModel);
                                  },
                                ),
                            ],
                          ),
                        ),
                        Center(
                          child: Container(
                            width: 65,
                            height: 1,
                            margin: const EdgeInsets.symmetric(vertical: 20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1),
                              color: context.coconutColors.divider,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: SingleButton(
                            enableShrinkAnim: true,
                            title: t.delete_label,
                            rightElement: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: context.coconutColors.primaryText.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: SvgPicture.asset(
                                CommonActionIconPath.trash,
                                width: 16,
                                colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
                              ),
                            ),
                            onPressed: () {
                              _removeTooltip();
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return CoconutPopup(
                                    languageCode: context.read<PreferenceProvider>().language,
                                    title: t.alert.wallet_delete.confirm_delete,
                                    description: t.alert.wallet_delete.confirm_delete_description,
                                    onTapRight: () {
                                      final dialogContext = context;
                                      _handleAuthFlow(
                                        onComplete: () async {
                                          Navigator.of(dialogContext).pop();
                                          await _deleteWalletAndGoToEntryPoint(viewModel);
                                        },
                                      );
                                    },
                                    onTapLeft: () {
                                      Navigator.of(context).pop();
                                    },
                                    rightButtonText: t.delete,
                                    rightButtonColor: context.coconutColors.danger,
                                    leftButtonText: t.cancel,
                                  );
                                },
                              );
                            },
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
      suffix: Text(
        BitcoinUnit.btc.symbol,
        style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
      ),
      onComplete: (text) {
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
      heightRatio: 0.9,
      child: CustomLoadingOverlay(child: PinCheckScreen(onComplete: onComplete)),
    );
  }

  void _showExtendedBottomSheet(String extendedPublicKey) {
    CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
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
      '/hot-wallet-mnemonic-backup-guide',
      arguments: {
        'walletName': viewModel.walletItemBase.name,
        'walletId': widget.id,
        'secureStorageKey': metadata.secureStorageKey,
        'enterPassphraseWhenSigning': metadata.enterPassphraseWhenSigning,
        'showWalletCreatedIntro': false,
        'continueToAppLockGuide': false,
        'returnToPreviousOnExit': true,
      },
    );
  }

  Future<void> _showPassphraseCheck(WalletInfoViewModel viewModel) async {
    final metadata = viewModel.walletItemBase.hotWalletMetadata;
    if (metadata == null || !metadata.enterPassphraseWhenSigning) return;

    try {
      final plaintext = await HotWalletUnlockService().unlockPreferBiometrics(
        context: context,
        storageKey: metadata.secureStorageKey,
      );
      if (!mounted || plaintext == null) return;
      await Navigator.pushNamed(
        context,
        '/hot-wallet-passphrase-check',
        arguments: {'mnemonic': plaintext.mnemonic, 'descriptor': viewModel.walletItemBase.descriptor},
      );
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
}

/// 트랜잭션 수, UTXO 수, 목표 수량 통계 카드
class _WalletInfoStatsSection extends StatelessWidget {
  final int walletId;
  final int transactionCount;
  final int utxoCount;
  final int balanceSats;
  final BitcoinUnit currentUnit;
  final int? targetSats;
  final VoidCallback onEditTargetTap;

  const _WalletInfoStatsSection({
    required this.walletId,
    required this.transactionCount,
    required this.utxoCount,
    required this.balanceSats,
    required this.currentUnit,
    this.targetSats,
    required this.onEditTargetTap,
  });

  static const int _maxBtcSats = 2100000000000000; // 21M BTC

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _StatCard(label: t.wallet_info_screen.transaction, value: '$transactionCount')),
              const SizedBox(width: 12),
              Expanded(
                child: ShrinkAnimationButton(
                  defaultColor: colors.surface,
                  pressedOverlayColor: colors.surfacePressOverlay,
                  pressedOverlayOpacity: colors.surfacePressOverlayOpacity,
                  borderRadius: 24,
                  onPressed: () {
                    Navigator.pushNamed(context, '/utxo-overview', arguments: {'id': walletId});
                  },
                  child: _StatCard(label: t.wallet_info_screen.utxo, value: '$utxoCount', transparentBackground: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ShrinkAnimationButton(
            defaultColor: colors.surface,
            pressedOverlayColor: colors.surfacePressOverlay,
            pressedOverlayOpacity: colors.surfacePressOverlayOpacity,
            borderRadius: 24,
            onPressed: onEditTargetTap,
            child: _TargetQuantityCard(
              balanceSats: balanceSats,
              currentUnit: currentUnit,
              targetSats: targetSats,
              maxSats: _maxBtcSats,
              transparentBackground: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final bool transparentBackground;

  const _StatCard({required this.label, required this.value, this.transparentBackground = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      decoration: BoxDecoration(
        color: transparentBackground ? Colors.transparent : context.coconutColors.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.secondaryText)),
              const SizedBox(width: 4),
              transparentBackground
                  ? Icon(Icons.keyboard_arrow_right_rounded, size: 20, color: context.coconutColors.iconSecondary)
                  : const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              value,
              style: CoconutTypography.heading3_21_NumberBold.setColor(context.coconutColors.primaryText),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetQuantityCard extends StatelessWidget {
  final int balanceSats;
  final BitcoinUnit currentUnit;
  final int? targetSats;
  final int maxSats;
  final bool transparentBackground;

  const _TargetQuantityCard({
    required this.balanceSats,
    required this.currentUnit,
    this.targetSats,
    required this.maxSats,
    this.transparentBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTarget = targetSats ?? maxSats;
    final progress = effectiveTarget > 0 ? (balanceSats / effectiveTarget).clamp(0.0, 1.0) : 0.0;
    final percent = _formatProgressPercent(progress);
    final isTargetReached = targetSats != null && progress >= 1.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: transparentBackground ? Colors.transparent : context.coconutColors.surfaceInfoChip,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    t.wallet_info_screen.target_quantity,
                    style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.secondaryText),
                  ),
                  const SizedBox(width: 4),
                  SvgPicture.asset(
                    CommonActionIconPath.editOutlined,
                    width: 12,
                    height: 12,
                    colorFilter: ColorFilter.mode(context.coconutColors.secondaryText, BlendMode.srcIn),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              targetSats == null
                  ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Stay humble, stack sats!',
                        style: CoconutTypography.heading4_18_NumberBold.setColor(context.coconutColors.secondaryText),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.wallet_info_screen.target_not_set_secondary,
                        style: CoconutTypography.body3_12.setColor(context.coconutColors.tertiaryText),
                      ),
                    ],
                  )
                  : _buildTargetProgressText(
                    context: context,
                    percent: percent,
                    amountText: currentUnit.displayBitcoinAmount(effectiveTarget, withUnit: false),
                    unitSymbol: currentUnit.symbol,
                    isPrefixUnit: currentUnit.isPrefixSymbol,
                  ),
              if (targetSats != null) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: context.coconutColors.pageIndicatorActive,
                      inactiveTrackColor: context.coconutColors.pageIndicatorInactive,
                      overlayShape: SliderComponentShape.noOverlay,
                      trackHeight: 6,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                    ),
                    child: IgnorePointer(child: Slider(value: progress, onChanged: (_) {})),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
        if (isTargetReached)
          Positioned(
            top: -10,
            right: 10,
            child: IgnorePointer(
              child: ClipRRect(
                borderRadius: const BorderRadius.only(topRight: Radius.circular(24)),
                // 목표 수량 달성 축하 효과는 의도된 디자인이라 테마 색상을 적용하지 않음
                child: Lottie.asset(
                  CommonLottiePath.fireworks,
                  width: 140,
                  height: 120,
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTargetProgressText({
    required BuildContext context,
    required String percent,
    required String amountText,
    required String unitSymbol,
    required bool isPrefixUnit,
  }) {
    final whiteStyle = CoconutTypography.heading3_21_Number.setColor(context.coconutColors.primaryText);
    final grayStyle = CoconutTypography.body1_16_Number.setColor(context.coconutColors.secondaryText);

    return RichText(
      text: TextSpan(
        style: whiteStyle,
        children: [
          TextSpan(text: percent, style: whiteStyle),
          TextSpan(text: '%', style: grayStyle),
          TextSpan(text: ' / ', style: whiteStyle),
          if (isPrefixUnit) ...[
            TextSpan(text: '$unitSymbol ', style: grayStyle),
            TextSpan(text: amountText, style: whiteStyle),
          ] else ...[
            TextSpan(text: amountText, style: whiteStyle),
            TextSpan(text: ' $unitSymbol', style: grayStyle),
          ],
        ],
      ),
    );
  }

  String _formatProgressPercent(double progress) {
    final percentValue = progress * 100;
    if (percentValue == percentValue.truncateToDouble()) {
      return percentValue.toStringAsFixed(0);
    }

    var decimalPlaces = 1;
    var formatted = percentValue.toStringAsFixed(decimalPlaces);

    while (decimalPlaces < 16 && _countNonZeroFractionDigits(formatted) < 2) {
      decimalPlaces++;
      formatted = percentValue.toStringAsFixed(decimalPlaces);
    }

    return formatted;
  }

  int _countNonZeroFractionDigits(String value) {
    final dotIndex = value.indexOf('.');
    if (dotIndex < 0 || dotIndex == value.length - 1) {
      return 0;
    }

    var count = 0;
    for (final char in value.substring(dotIndex + 1).split('')) {
      if (char != '0') {
        count++;
      }
    }

    return count;
  }
}
