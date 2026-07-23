import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/core/bip/329/label_jsonl_manager.dart';
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
import 'package:coconut_wallet/screens/common/single_text_field_bottom_sheet.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_mfp_input_bottom_sheet.dart';
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
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/bitbox02_section.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/bottom_sheet/manage_labels_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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
                              onDisconnect: () async {
                                await viewModel.disconnectBitBox02();
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
                        _buildActionButtons(innerContext, viewModel),
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

  Widget _buildActionButtons(BuildContext context, WalletInfoViewModel viewModel) {
    return Column(
      children: [
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
              if (widget.walletType == WalletType.singleSignature)
                SingleButton(
                  enableShrinkAnim: true,
                  title: t.wallet_info_screen.view_xpub,
                  onPressed: () {
                    _removeTooltip();
                    _handleAuthFlow(onComplete: () => _showExtendedBottomSheet(viewModel.extendedPublicKey));
                  },
                ),
              if (widget.walletType == WalletType.taproot)
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
              if (widget.walletType == WalletType.multiSignature)
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
                title: t.manage_labels_bottom_sheet.title,
                onPressed: () => _showManageLabelsBottomSheet(context, viewModel),
              ),
            ],
          ),
        ),
        Center(
          child: Container(
            width: 65,
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(1), color: context.coconutColors.divider),
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
                'assets/svg/trash.svg',
                width: 16,
                colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
              ),
            ),
            onPressed: () {
              _removeTooltip();
              _showDeleteWalletDialog(context, viewModel);
            },
          ),
        ),
      ],
    );
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

  void _showExportLabelsDialog(BuildContext context, WalletInfoViewModel viewModel) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.wallet_info_screen.export_labels,
          description: t.wallet_info_screen.export_labels_description,
          onTapRight: () async {
            Navigator.of(dialogContext).pop();
            _setOverlayLoading(true);
            final startTime = DateTime.now();

            final file = await viewModel.createLabelsJsonLFile();

            final duration = DateTime.now().difference(startTime);
            if (duration < const Duration(seconds: 1)) {
              await Future.delayed(const Duration(seconds: 1) - duration);
            }
            _setOverlayLoading(false);

            if (!mounted) return;

            if (file != null) {
              await viewModel.shareLabelsFile(file);
            } else {
              CoconutToast.showToast(
                context: context,
                text: t.wallet_info_screen.error.no_memos,
                level: CoconutToastLevel.info,
                isVisibleIcon: true,
                iconPath: 'assets/svg/circle-info.svg',
              );
            }
          },
          rightButtonText: t.next,
          onTapLeft: () => Navigator.of(dialogContext).pop(),
          leftButtonText: t.cancel,
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

  void _showManageLabelsBottomSheet(BuildContext context, WalletInfoViewModel viewModel) {
    ManageLabelsBottomSheet.show(
      context: context,
      onImportPressed: () => _showImportLabelsDialog(context, viewModel),
      onExportPressed: () => _showExportLabelsDialog(context, viewModel),
    );
  }

  void _showImportLabelsDialog(BuildContext context, WalletInfoViewModel viewModel) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.wallet_info_screen.import_labels,
          titleTextStyle: CoconutTypography.heading4_18_Bold,
          description: t.wallet_info_screen.import_labels_description,
          descriptionTextStyle: CoconutTypography.body1_16,
          onTapRight: () {
            Navigator.of(dialogContext).pop();
            _importLabels(viewModel);
          },
          rightButtonText: t.next,
          onTapLeft: () => Navigator.of(dialogContext).pop(),
          leftButtonText: t.cancel,
        );
      },
    );
  }

  Future<void> _importLabels(WalletInfoViewModel viewModel) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result != null) {
      final file = result.files.single;
      if (file.extension?.toLowerCase() != 'jsonl') {
        if (mounted) {
          CoconutToast.showToast(
            context: context,
            text: t.wallet_info_screen.error.invalid_file_type,
            level: CoconutToastLevel.warning,
            isVisibleIcon: true,
            iconPath: 'assets/svg/triangle-warning.svg',
          );
        }
        return;
      }

      final filePath = file.path;
      if (filePath == null) return;

      _setOverlayLoading(true);
      try {
        final labelManager = LabelJsonLManager();
        await labelManager.importLabelsFromJsonLFile(widget.id, context.read<WalletProvider>(), filePath);

        _setOverlayLoading(false);
        if (mounted) {
          CoconutToast.showToast(
            context: context,
            text: t.wallet_info_screen.import_labels_success,
            level: CoconutToastLevel.success,
          );
        }
      } catch (e) {
        _setOverlayLoading(false);
        if (mounted) {
          await showInfoDialog(
            context,
            context.read<PreferenceProvider>().language,
            t.wallet_info_screen.import_labels_fail,
            e.toString(),
          );
        }
      }
    }
  }
}
