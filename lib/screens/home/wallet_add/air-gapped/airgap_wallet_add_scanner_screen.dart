import 'dart:async';
import 'dart:io';
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
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/constants/app_language.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/air-gapped/wallet_add_scanner_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_mfp_input_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/utils/descriptor_util.dart';
import 'package:coconut_wallet/utils/file_logger.dart';
import 'package:coconut_wallet/utils/wallet_sync_result_util.dart';
import 'package:coconut_wallet/widgets/features/qr/animated_qr/coconut_qr_scanner.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/card/expandable_info_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

const String className = 'WalletAddScannerScreen';

class WalletAddScannerScreen extends StatefulWidget {
  final WalletImportSource importSource;
  final Function(ResultOfSyncFromVault)? onNewWalletAdded;
  const WalletAddScannerScreen({super.key, required this.importSource, this.onNewWalletAdded});

  @override
  State<WalletAddScannerScreen> createState() => _WalletAddScannerScreenState();
}

class _WalletAddScannerScreenState extends State<WalletAddScannerScreen> with WidgetsBindingObserver {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  MobileScannerController? controller;
  bool _isProcessing = false;
  bool _clipboardContentAvailable = false;
  late WalletAddScannerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkClipboard();

    _viewModel = WalletAddScannerViewModel(
      widget.importSource,
      Provider.of<WalletProvider>(context, listen: false),
      Provider.of<PreferenceProvider>(context, listen: false),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
    }
  }

  Future<void> _checkClipboard() async {
    final isContentAvailable = await Clipboard.hasStrings();
    if (mounted && _clipboardContentAvailable != isContentAvailable) {
      setState(() {
        _clipboardContentAvailable = isContentAvailable;
      });
    }
  }

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller!.pause();
    } else if (Platform.isIOS) {
      controller!.start();
    }
  }

  List<TextSpan> _getGuideTextSpan() {
    final hasEnglishWordOrder =
        AppLanguage.fromCode(Provider.of<PreferenceProvider>(context, listen: false).language).hasEnglishWordOrder;

    switch (widget.importSource) {
      case WalletImportSource.coconutVault:
        {
          return [TextSpan(text: t.wallet_add_scanner_screen.guide_vault)];
        }
      case WalletImportSource.seedSigner:
        {
          if (!hasEnglishWordOrder) {
            return [
              TextSpan(text: t.wallet_add_scanner_screen.guide_seedsigner.step1),
              _em(t.wallet_add_scanner_screen.guide_seedsigner.step1_em),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_seedsigner.step2),
              _em(t.wallet_add_scanner_screen.guide_seedsigner.step2_em),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_seedsigner.step3),
              _em(t.wallet_add_scanner_screen.guide_seedsigner.step3_em),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_seedsigner.step4),
              _em(t.wallet_add_scanner_screen.guide_seedsigner.step4_em1),
              TextSpan(text: t.wallet_add_scanner_screen.guide_seedsigner.next),
              _em(t.wallet_add_scanner_screen.guide_seedsigner.step4_em2),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_seedsigner.step5),
              _em(t.wallet_add_scanner_screen.guide_seedsigner.step5_em),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_seedsigner.step6),
              _em(t.wallet_add_scanner_screen.guide_seedsigner.step6_em),
              _em(t.wallet_add_scanner_screen.guide_seedsigner.step6_end),
            ];
          } else {
            return [
              TextSpan(text: t.wallet_add_scanner_screen.guide_seedsigner.step1),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(t.wallet_add_scanner_screen.guide_seedsigner.step1_em),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_seedsigner.step2),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(t.wallet_add_scanner_screen.guide_seedsigner.step2_em),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_seedsigner.step3),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(t.wallet_add_scanner_screen.guide_seedsigner.step3_em),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_seedsigner.step4),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(t.wallet_add_scanner_screen.guide_seedsigner.step4_em1),
              TextSpan(text: t.wallet_add_scanner_screen.guide_seedsigner.next),
              _em(t.wallet_add_scanner_screen.guide_seedsigner.step4_em2),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_seedsigner.step5),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(t.wallet_add_scanner_screen.guide_seedsigner.step5_em),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_seedsigner.step6),
              _em(t.wallet_add_scanner_screen.guide_seedsigner.step6_em),
              _em(t.wallet_add_scanner_screen.guide_seedsigner.step6_end),
            ];
          }
        }
      case WalletImportSource.keystone:
        {
          if (!hasEnglishWordOrder) {
            return [
              // 키스톤 3 프로 외 에센셜, 이전 프로 기기 호환되지 않음에 따른 임시 조치
              TextSpan(text: t.wallet_add_scanner_screen.guide_keystone.step0),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_keystone.step1),
              _em(t.wallet_add_scanner_screen.guide_keystone.step1_em),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_keystone.step2),
              _em(t.wallet_add_scanner_screen.guide_keystone.step2_em),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_keystone.step3),
            ];
          } else {
            return [
              TextSpan(text: t.wallet_add_scanner_screen.guide_keystone.step0),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_keystone.step1),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(t.wallet_add_scanner_screen.guide_keystone.step1_em),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_keystone.step2),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(t.wallet_add_scanner_screen.guide_keystone.step2_em),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_keystone.step3),
            ];
          }
        }
      case WalletImportSource.jade:
        {
          if (!hasEnglishWordOrder) {
            return [
              _em(t.wallet_add_scanner_screen.guide_jade.step0_em),
              TextSpan(text: t.wallet_add_scanner_screen.guide_jade.step0),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_jade.step1),
              _em(t.wallet_add_scanner_screen.guide_jade.step1_em),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_jade.step2),
              _em(t.wallet_add_scanner_screen.guide_jade.step2_em),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_jade.step3),
              _em(t.wallet_add_scanner_screen.guide_jade.step3_em),
              TextSpan(text: t.wallet_add_scanner_screen.select),
            ];
          } else {
            return [
              TextSpan(text: t.wallet_add_scanner_screen.guide_jade.step0_preposition),
              _em(t.wallet_add_scanner_screen.guide_jade.step0_em),
              TextSpan(text: t.wallet_add_scanner_screen.guide_jade.step0),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_jade.step1),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(t.wallet_add_scanner_screen.guide_jade.step1_em),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_jade.step2),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(t.wallet_add_scanner_screen.guide_jade.step2_em),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_jade.step3),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(t.wallet_add_scanner_screen.guide_jade.step3_em),
            ];
          }
        }
      case WalletImportSource.coldCard:
        {
          if (!hasEnglishWordOrder) {
            return [
              TextSpan(text: t.wallet_add_scanner_screen.guide_coldcard.step1),
              _em(t.wallet_add_scanner_screen.guide_coldcard.step1_em),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_coldcard.step2),
              _em(t.wallet_add_scanner_screen.guide_coldcard.step2_em),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_coldcard.step3),
              _em(t.wallet_add_scanner_screen.guide_coldcard.step3_em),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_coldcard.step4),
              _em(t.wallet_add_scanner_screen.guide_coldcard.step4_em),
              TextSpan(text: t.wallet_add_scanner_screen.guide_coldcard.step4_end),
            ];
          } else {
            return [
              TextSpan(text: t.wallet_add_scanner_screen.guide_coldcard.step1),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(t.wallet_add_scanner_screen.guide_coldcard.step1_em),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_coldcard.step2),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(t.wallet_add_scanner_screen.guide_coldcard.step2_em),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_coldcard.step3),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(t.wallet_add_scanner_screen.guide_coldcard.step3_em),
              const TextSpan(text: '\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_coldcard.step4),
              TextSpan(text: t.wallet_add_scanner_screen.guide_coldcard.step4_preposition),
              _em(t.wallet_add_scanner_screen.guide_coldcard.step4_em),
              TextSpan(text: t.wallet_add_scanner_screen.guide_coldcard.step4_end),
            ];
          }
        }
      case WalletImportSource.krux:
        {
          if (!hasEnglishWordOrder) {
            return [
              TextSpan(text: '${t.wallet_add_scanner_screen.guide_krux.step0}\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_krux.step1),
              _em(t.wallet_add_scanner_screen.guide_krux.step1_em),
              TextSpan(text: '${t.wallet_add_scanner_screen.select}\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_krux.step2),
              _em(t.wallet_add_scanner_screen.guide_krux.step2_em),
              TextSpan(text: t.wallet_add_scanner_screen.select),
            ];
          } else {
            return [
              TextSpan(text: '${t.wallet_add_scanner_screen.guide_krux.step0}\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_krux.step1),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(' ${t.wallet_add_scanner_screen.guide_krux.step1_em}\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_krux.step2),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(' ${t.wallet_add_scanner_screen.guide_krux.step2_em}'),
            ];
          }
        }
      case WalletImportSource.passport:
        {
          if (!hasEnglishWordOrder) {
            return [
              TextSpan(text: '${t.wallet_add_scanner_screen.guide_passport.step0}\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_passport.step1),
              _em(t.wallet_add_scanner_screen.guide_passport.step1_em),
              TextSpan(text: '${t.wallet_add_scanner_screen.select}\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_passport.step2),
              _em(t.wallet_add_scanner_screen.guide_passport.step2_em),
              TextSpan(text: '${t.wallet_add_scanner_screen.select}\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_passport.step3),
              _em(t.wallet_add_scanner_screen.guide_passport.step3_em),
              TextSpan(text: '${t.wallet_add_scanner_screen.select}\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_passport.step4),
              _em(t.wallet_add_scanner_screen.guide_passport.step4_em),
              TextSpan(text: t.wallet_add_scanner_screen.select),
            ];
          } else {
            return [
              TextSpan(text: '${t.wallet_add_scanner_screen.guide_passport.step0}\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_passport.step1),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(' ${t.wallet_add_scanner_screen.guide_passport.step1_em}\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_passport.step2),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(' ${t.wallet_add_scanner_screen.guide_passport.step2_em}\n'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_passport.step3),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(' ${t.wallet_add_scanner_screen.guide_passport.step3_em}'),
              TextSpan(text: t.wallet_add_scanner_screen.guide_passport.step4),
              TextSpan(text: t.wallet_add_scanner_screen.select),
              _em(' ${t.wallet_add_scanner_screen.guide_passport.step4_em}'),
            ];
          }
        }
      default:
        return [];
    }
  }

  TextSpan _em(String text) => TextSpan(text: text, style: CoconutTypography.body2_14_Bold.copyWith(height: 1.3));

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CoconutAppBar.build(
        title: _getAppBarTitle(),
        context: context,
        isBottom: true,
        backgroundColor: context.coconutColors.background,
        actionButtonList: [
          IconButton(
            onPressed: () {
              if (controller != null) {
                controller!.switchCamera();
              }
            },
            icon: SvgPicture.asset(
              CommonActionIconPath.arrowReload,
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
            ),
            color: context.coconutColors.iconPrimary,
          ),
        ],
      ),
      body: Stack(
        children: [
          CoconutQrScanner(
            setMobileScannerController: (MobileScannerController qrViewcontroller) {
              controller = qrViewcontroller;
            },
            onComplete: _onCompletedScanning,
            onFailed: _onFailedScanning,
            qrDataHandler: _viewModel.qrDataHandler,
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: 20,
              left: CoconutLayout.defaultPadding,
              right: CoconutLayout.defaultPadding,
            ),
            child:
                widget.importSource == WalletImportSource.extendedPublicKey
                    ? ExpandableInfoCard(
                      descriptionText: t.wallet_add_scanner_screen.paste.wallet_description_text,
                      sections: [
                        ExpandableInfo(
                          titleText: t.wallet_add_scanner_screen.paste.blue_wallet_texts[0],
                          descriptionList: [...t.wallet_add_scanner_screen.paste.blue_wallet_texts.getRange(1, 3)],
                          addressText: t.wallet_add_scanner_screen.paste.blue_wallet_texts[3],
                        ),
                        ExpandableInfo(
                          titleText: t.wallet_add_scanner_screen.paste.nunchuck_wallet_texts[0],
                          descriptionList: [...t.wallet_add_scanner_screen.paste.nunchuck_wallet_texts.getRange(1, 2)],
                          addressText:
                              Platform.isAndroid
                                  ? t.wallet_add_scanner_screen.paste.nunchuck_wallet_texts[2]
                                  : t.wallet_add_scanner_screen.paste.nunchuck_wallet_texts[3],
                        ),
                      ],
                    )
                    : _buildDefaultToolTip(),
          ),
          if (widget.importSource == WalletImportSource.extendedPublicKey && _clipboardContentAvailable)
            FixedBottomButton(
              onButtonClicked: _handleClipboardImport,
              text: t.wallet_add_scanner_screen.paste.paste_button,
              showSurroundings: false,
            ),
        ],
      ),
    );
  }

  void _handleClipboardImport() async {
    if (_isProcessing) return;
    _isProcessing = true;

    await controller?.stop();
    if (!mounted) return;

    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text?.trim();

    if (text == null || text.isEmpty) {
      _showErrorDialog(t.alert.wallet_add.add_failed, t.alert.invalid_qr);
      _isProcessing = false;
      await controller?.start();
      return;
    }
    String? descriptor;
    String? extendedPublicKey;
    try {
      if (text.contains('[') && text.contains(']')) {
        descriptor = DescriptorUtil.normalizeDescriptor(text);
      } else {
        ExtendedPublicKey.parse(text);
        extendedPublicKey = text;
      }
    } catch (_) {}

    if (descriptor == null && extendedPublicKey == null) {
      if (mounted) {
        _showErrorDialog(
          t.alert.wallet_add.add_failed,
          "${t.wallet_add_scanner_screen.paste.format_error_text} ($text)",
        );
        _isProcessing = false;
        await controller?.start();
      }
      return;
    }

    try {
      if (!mounted) return;

      ResultOfSyncFromVault? addResult;
      if (descriptor != null && mounted) {
        context.loaderOverlay.show();
        addResult = await _viewModel.addWallet(descriptor);
      } else {
        String? mfp = await _showMfpInputBottomSheet();
        if (!mounted) return;
        context.loaderOverlay.show();
        addResult = await _viewModel.addWallet(extendedPublicKey!, isExtendedPublicKey: true, masterFingerPrint: mfp);
      }
      await _handleAddWalletResult(addResult);
    } catch (e, stackTrace) {
      _handleAddWalletError(e, stackTrace);
    } finally {
      _finalizeAddWallet();
    }
  }

  Future<String?> _showMfpInputBottomSheet() async {
    final result = await showModalBottomSheet(
      context: context,
      builder: (context) {
        return WalletAddMfpInputBottomSheet(
          onSkip: () {
            Navigator.pop(context, null);
          },
          onComplete: (text) {
            Navigator.pop(context, text);
          },
        );
      },
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
    );

    return result;

    // .then((_) {
    //   if (mounted) {
    //     _isProcessing = false;
    //     controller?.start();
    //   }
    // });
  }

  Widget _buildDefaultToolTip() {
    if (_getGuideTextSpan().isEmpty) return const SizedBox.shrink();

    return CoconutToolTip(
      backgroundColor: context.coconutColors.surface,
      borderColor: context.coconutColors.surface,
      icon: SvgPicture.asset(
        CommonStateIconPath.circleInfo,
        width: 20,
        colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
      ),
      tooltipType: CoconutTooltipType.fixed,
      richText: RichText(
        text: TextSpan(
          style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
          children: _getGuideTextSpan(),
        ),
      ),
    );
  }

  Future<void> _onCompletedScanning(dynamic additionInfo) async {
    const methodName = '_onCompletedScanning';
    FileLogger.log(className, methodName, 'additionInfo type: ${additionInfo.runtimeType}');

    if (_isProcessing) return;
    _isProcessing = true;

    try {
      String? mfp;
      if (_viewModel.isExtendedPublicKeyScanned) {
        await controller?.stop();
        mfp = await _showMfpInputBottomSheet();
      }

      ResultOfSyncFromVault addResult = await _viewModel.addWallet(
        additionInfo,
        isExtendedPublicKey: _viewModel.isExtendedPublicKeyScanned,
        masterFingerPrint: mfp,
      );
      await _handleAddWalletResult(addResult);
    } catch (e, stackTrace) {
      _handleAddWalletError(e, stackTrace);
    } finally {
      _finalizeAddWallet();
    }
  }

  Future<void> _handleAddWalletResult(ResultOfSyncFromVault addResult) async {
    FileLogger.log(className, '_handleAddWalletResult', 'result: ${addResult.result.name}');

    if (!mounted) return;

    switch (addResult.result) {
      case WalletSyncResult.newWalletAdded:
        {
          context.read<AnalyticsService>().logEvent(
            eventName: AnalyticsEventNames.walletAddCompleted,
            parameters: {AnalyticsParameterNames.walletAddImportSource: widget.importSource.name},
          );

          if (widget.onNewWalletAdded != null) {
            widget.onNewWalletAdded!(addResult);
          }
          if (mounted) {
            Navigator.pushReplacementNamed(
              context,
              '/wallet-detail',
              arguments: {'id': addResult.walletId, 'entryPoint': kEntryPointWalletHome},
            );
          }
          break;
        }
      case WalletSyncResult.existingWalletUpdated:
        {
          Navigator.pop(context, addResult);
          break;
        }
      case WalletSyncResult.existingWalletNoUpdate:
      case WalletSyncResult.existingName:
      case WalletSyncResult.existingWalletUpdateImpossible:
        {
          vibrateLightDouble();
          if (mounted) {
            final walletProvider = Provider.of<WalletProvider>(context, listen: false);
            final (title, description) = resolveWalletSyncResultDialog(addResult, walletProvider);
            _showErrorDialog(title, description);
          }
          break;
        }
    }
  }

  void _handleAddWalletError(Object e, StackTrace stackTrace) {
    FileLogger.error(className, '_handleAddWalletError', 'failed: $e', stackTrace);
    vibrateLightDouble();
    if (mounted) {
      String errorMessage = "${t.wallet_add_scanner_screen.paste.format_error_text}\n${e.toString()}";
      if (e.toString().contains("network type")) {
        errorMessage =
            NetworkType.currentNetworkType == NetworkType.mainnet
                ? t.wallet_add_scanner_screen.paste.mainnet_wallet_error_text
                : t.wallet_add_scanner_screen.paste.testnet_wallet_error_text;
      }
      _showErrorDialog(t.alert.wallet_add.add_failed, errorMessage);
    }
  }

  void _finalizeAddWallet() {
    FileLogger.log(className, '_finalizeAddWallet', 'finalize');
    vibrateMedium();
    if (mounted) {
      context.loaderOverlay.hide();
      controller?.start();
      _viewModel.qrDataHandler.reset(); // TODO: 추가됨. 다른 타입 지갑 추가 시 동작 확인 필요
    }
  }

  void _onFailedScanning(String message, String? scannedData) async {
    const methodName = '_onFailedScanning';
    FileLogger.error(
      className,
      methodName,
      '_onFailedScanning called with message: $message${scannedData != null ? " data: $scannedData" : null}',
    );

    if (_isProcessing) {
      return;
    }
    _isProcessing = true;

    String errorMessage;
    if (message == CoconutQrScanner.qrFormatErrorMessage) {
      errorMessage = '${t.alert.invalid_qr}${scannedData != null ? "\ndata: $scannedData" : null}';
      FileLogger.error(className, methodName, 'QR format error detected');
    } else {
      errorMessage = t.alert.scan_failed_description(error: message);
      FileLogger.error(className, methodName, 'Non-QR format error detected');
    }

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.alert.wallet_add.add_failed,
          description: errorMessage,
          rightButtonText: t.OK,
          onTapRight: () {
            FileLogger.log(className, methodName, 'Error dialog confirmed');
            _isProcessing = false;

            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _showErrorDialog(String title, String description) {
    const methodName = '_showErrorDialog';
    FileLogger.log(className, methodName, 'Error title: $title');
    FileLogger.log(className, methodName, 'Error description: $description');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: title,
          backgroundColor: context.coconutColors.popupBackground.withValues(alpha: 0.7),
          description: description,
          descriptionPadding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
          insetPadding: const EdgeInsets.symmetric(horizontal: 50),
          rightButtonText: t.confirm,
          rightButtonColor: context.coconutColors.primaryText,
          onTapRight: () {
            _isProcessing = false;
            Navigator.pop(context);
          },
        );
      },
    );
  }

  String _getAppBarTitle() => switch (widget.importSource) {
    WalletImportSource.coconutVault => t.wallet_add_scanner_screen.vault,
    WalletImportSource.keystone => t.wallet_add_scanner_screen.keystone,
    WalletImportSource.jade => t.wallet_add_scanner_screen.jade,
    WalletImportSource.seedSigner => t.wallet_add_scanner_screen.seed_signer,
    WalletImportSource.coldCard => t.wallet_add_scanner_screen.cold_card,
    WalletImportSource.krux => t.wallet_add_scanner_screen.krux,
    WalletImportSource.passport => t.wallet_add_scanner_screen.passport,
    WalletImportSource.extendedPublicKey => t.wallet_add_scanner_screen.self,
    _ => '',
  };
}
