import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_info_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_mfp_input_bottom_sheet.dart';
import 'package:coconut_wallet/screens/settings/tools/bip329/label_management_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_signer_section.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_stats_section.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/button/button_group.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';
import 'package:coconut_wallet/widgets/card/wallet_info_item_card.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/dialog.dart';
import 'package:coconut_wallet/screens/common/qr_with_copy_text_screen.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/numeric_input_formatters.dart';
import 'package:coconut_wallet/extensions/string_extensions.dart';
import 'package:coconut_wallet/screens/common/single_text_field_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/bitbox02_section.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/trezor_section.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

const String kEntryPointWalletList = '/wallet-list';
const String kEntryPointWalletHome = '/wallet-home';

class WalletInfoScreen extends StatefulWidget {
  final int id;
  final WalletType walletType;
  final String entryPoint;
  final bool showMfpInput;
  const WalletInfoScreen({
    super.key,
    required this.id,
    required this.walletType,
    required this.entryPoint,
    this.showMfpInput = false,
  });

  @override
  State<WalletInfoScreen> createState() => _WalletInfoScreenState();
}

class _WalletInfoScreenState extends State<WalletInfoScreen> {
  final GlobalKey _walletTooltipKey = GlobalKey();
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
                        WalletInfoStatsSection(
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
                                  showNotificationDot: viewModel.hasUnacknowledgedOlderToAfterBackupUpdate,
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
                              SingleButton(
                                enableShrinkAnim: true,
                                title: t.label_management_screen.title,
                                onPressed: () => _showLabelsManagementScreen(context, viewModel),
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
                            title: t.wallet_info_screen.resync_label,
                            rightElement: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: context.coconutColors.primaryText.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: SvgPicture.asset(
                                'assets/svg/arrow-reload.svg',
                                width: 16,
                                colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
                              ),
                            ),
                            onPressed: () {
                              _removeTooltip();
                              Navigator.pushNamed(context, '/wallet-resync', arguments: {'id': widget.id});
                            },
                          ),
                        ),
                        CoconutLayout.spacing_200h,
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
                                'assets/svg/trash.svg',
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

      if (!mounted || widget.walletType != WalletType.taproot) return;
      final hasUnacknowledgedBackupUpdate = context
          .read<WalletProvider>()
          .walletIdsWithUnacknowledgedOlderToAfterBackupUpdate
          .contains(widget.id);
      if (hasUnacknowledgedBackupUpdate) {
        await _showTaprootBackupUpdateDialog();
      }
    });
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
      backgroundColor: context.coconutColors.background,
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
      fieldBackgroundColor: context.coconutColors.inputSurface,
      errorColor: context.coconutColors.danger,
      placeholderColor: context.coconutColors.inputPlaceholder,
      inputBorderColor: context.coconutColors.inputBorder,
      activeColor: context.coconutColors.primaryText,
      cursorColor: context.coconutColors.primaryText,
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
              iconPath: 'assets/svg/triangle-warning.svg',
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
            iconPath: 'assets/svg/pie.svg',
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
          iconPath: 'assets/svg/triangle-warning.svg',
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

  Future<void> _showTaprootBackupUpdateDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colors = dialogContext.coconutColors;
        final bodyStyle = CoconutTypography.body2_14.setColor(colors.primaryText).copyWith(height: 1.4);
        final emphasisStyle = CoconutTypography.body2_14_Bold.setColor(colors.primaryText).copyWith(height: 1.4);

        return PopScope(
          canPop: false,
          child: Dialog(
            backgroundColor: colors.popupBackground,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        t.wallet_info_screen.backup_update_dialog.title,
                        textAlign: TextAlign.center,
                        style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText),
                      ),
                    ),
                    const SizedBox(height: 16),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: '${t.wallet_info_screen.backup_update_dialog.step1_title}\n',
                            style: emphasisStyle,
                          ),
                          TextSpan(
                            text: "${t.wallet_info_screen.backup_update_dialog.step1_description}\n\n",
                            style: bodyStyle,
                          ),
                          TextSpan(
                            text: '${t.wallet_info_screen.backup_update_dialog.step2_title}\n',
                            style: emphasisStyle,
                          ),
                          TextSpan(
                            text: "${t.wallet_info_screen.backup_update_dialog.step2_description}\n\n",
                            style: bodyStyle,
                          ),
                          TextSpan(
                            text: '${t.wallet_info_screen.backup_update_dialog.why_title}\n',
                            style: emphasisStyle,
                          ),
                          TextSpan(text: t.wallet_info_screen.backup_update_dialog.why_description, style: bodyStyle),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: CoconutButton(
                        height: 52,
                        backgroundColor: colors.surfaceButton,
                        foregroundColor: colors.surfaceButtonText,
                        text: t.wallet_info_screen.backup_update_dialog.confirm,
                        onPressed: () => Navigator.pop(dialogContext),
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

  void _showDeleteWalletDialog(BuildContext context, WalletInfoViewModel viewModel) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.alert.wallet_delete.confirm_delete,
          description: t.alert.wallet_delete.confirm_delete_description,
          onTapRight: () {
            _handleAuthFlow(
              onComplete: () async {
                Navigator.of(dialogContext).pop();
                await _deleteWalletAndGoToEntryPoint(viewModel);
              },
            );
          },
          onTapLeft: () => Navigator.of(dialogContext).pop(),
          rightButtonText: t.delete,
          rightButtonColor: context.coconutColors.danger,
          leftButtonText: t.cancel,
        );
      },
    );
  }

  void _showLabelsManagementScreen(BuildContext context, WalletInfoViewModel viewModel) {
    Navigator.of(
      context,
    ).push(CupertinoPageRoute(builder: (context) => LabelManagementScreen(walletId: viewModel.walletId)));
  }
}
