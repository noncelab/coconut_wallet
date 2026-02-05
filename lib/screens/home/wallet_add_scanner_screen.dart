import 'dart:async';
import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_add_input_view_model.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_add_scanner_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add_mfp_input_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/utils/file_logger.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/animated_qr/coconut_qr_scanner.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/card/wallet_expandable_info_card.dart';
import 'package:flutter/cupertino.dart';
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
    final isEnglishOrSpanish =
        Provider.of<PreferenceProvider>(context, listen: false).isEnglish ||
        Provider.of<PreferenceProvider>(context, listen: false).isSpanish;

    switch (widget.importSource) {
      case WalletImportSource.coconutVault:
        {
          return [TextSpan(text: t.wallet_add_scanner_screen.guide_vault)];
        }
      case WalletImportSource.seedSigner:
        {
          if (!isEnglishOrSpanish) {
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
          if (!isEnglishOrSpanish) {
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
          if (!isEnglishOrSpanish) {
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
          if (!isEnglishOrSpanish) {
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
          if (!isEnglishOrSpanish) {
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
        backgroundColor: CoconutColors.black.withValues(alpha: 0.95),
        actionButtonList: [
          IconButton(
            onPressed: () {
              if (controller != null) {
                controller!.switchCamera();
              }
            },
            icon: SvgPicture.asset('assets/svg/arrow-reload.svg', width: 20, height: 20),
            color: CoconutColors.white,
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
                    ? const WalletExpandableInfoCard()
                    : _buildDefaultToolTip(),
          ),
          if (widget.importSource == WalletImportSource.extendedPublicKey && _clipboardContentAvailable)
            FixedBottomButton(
              onButtonClicked: _handleClipboardImport,
              text: t.wallet_add_scanner_screen.paste.paste_button,
              showGradient: false,
              backgroundColor: CoconutColors.white,
              textColor: CoconutColors.black,
            ),
        ],
      ),
    );
  }

  void _handleClipboardImport() async {
    await controller?.stop();
    if (!mounted) return;

    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    final text = clipboardData?.text?.trim();

    if (text == null || text.isEmpty) {
      _showErrorDialog(t.alert.wallet_add.add_failed, t.alert.invalid_qr);
      await controller?.start();
      return;
    }

    final inputViewModel = WalletAddInputViewModel(context.read<WalletProvider>(), context.read<PreferenceProvider>());

    final bool isDescriptor = text.contains('[');
    final bool isValid =
        isDescriptor ? inputViewModel.normalizeDescriptor(text) : inputViewModel.isExtendedPublicKey(text);

    if (!isValid) {
      if (mounted) {
        _showErrorDialog(
          t.alert.wallet_add.add_failed,
          inputViewModel.errorMessage ?? t.wallet_add_scanner_screen.paste.format_error_text,
        );
        await controller?.start();
      }
      return;
    }

    if (isDescriptor) {
      await _executeAddWallet(inputViewModel);
    } else {
      if (mounted) {
        _showMfpInputBottomSheet(inputViewModel);
      }
    }
  }

  Future<void> _executeAddWallet(WalletAddInputViewModel viewModel) async {
    if (_isProcessing) return;

    _isProcessing = true;
    context.loaderOverlay.show();

    await Future.delayed(const Duration(seconds: 2));

    try {
      if (!mounted) return;
      ResultOfSyncFromVault addResult = await viewModel.addWallet();

      if (!mounted) return;

      switch (addResult.result) {
        case WalletSyncResult.newWalletAdded:
          {
            context.read<AnalyticsService>().logEvent(
              eventName: AnalyticsEventNames.walletAddCompleted,
              parameters: {AnalyticsParameterNames.walletAddImportSource: WalletImportSource.extendedPublicKey.name},
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
        case WalletSyncResult.existingWalletUpdateImpossible:
          vibrateLightDouble();
          if (mounted) {
            _showErrorDialog(
              t.alert.wallet_add.already_exist,
              t.alert.wallet_add.already_exist_description(
                name: TextUtils.ellipsisIfLonger(viewModel.getWalletName(addResult.walletId!), maxLength: 15),
              ),
            );
          }
          break;
        default:
          throw 'No Support Result: ${addResult.result.name}';
      }
    } catch (e) {
      vibrateLightDouble();
      if (mounted) {
        _showErrorDialog(t.alert.wallet_add.add_failed, e.toString());
      }
    } finally {
      vibrateMedium();
      _isProcessing = false;
      if (mounted) {
        context.loaderOverlay.hide();
      }
    }
  }

  void _showMfpInputBottomSheet(WalletAddInputViewModel viewModel) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: WalletAddMfpInputBottomSheet(
            onSkip: () {
              viewModel.masterFingerPrint = null;
              _executeAddWallet(viewModel);
            },
            onComplete: (text) {
              viewModel.masterFingerPrint = text;
              _executeAddWallet(viewModel);
            },
          ),
        );
      },
      backgroundColor: CoconutColors.black,
      isScrollControlled: true,
      enableDrag: true,
      useSafeArea: true,
    ).then((_) {
      if (mounted && !_isProcessing) {
        controller?.start();
      }
    });
  }

  Widget _buildDefaultToolTip() {
    if (_getGuideTextSpan().isEmpty) return const SizedBox.shrink();

    return CoconutToolTip(
      backgroundColor: CoconutColors.gray900,
      borderColor: CoconutColors.gray900,
      icon: SvgPicture.asset(
        'assets/svg/circle-info.svg',
        width: 20,
        colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
      ),
      tooltipType: CoconutTooltipType.fixed,
      richText: RichText(text: TextSpan(style: CoconutTypography.body2_14, children: _getGuideTextSpan())),
    );
  }

  Future<void> _onCompletedScanning(dynamic additionInfo) async {
    const methodName = '_onCompletedScanning';

    FileLogger.log(className, methodName, 'additionInfo type: ${additionInfo.runtimeType}');

    if (_isProcessing) return;

    _isProcessing = true;

    if (widget.importSource == WalletImportSource.extendedPublicKey && additionInfo is String) {
      await controller?.stop();

      final inputViewModel = WalletAddInputViewModel(
        context.read<WalletProvider>(),
        context.read<PreferenceProvider>(),
      );

      final text = additionInfo;
      final bool isDescriptor = text.contains('[');

      final bool isValid =
          isDescriptor ? inputViewModel.normalizeDescriptor(text) : inputViewModel.isExtendedPublicKey(text);

      if (isValid) {
        _isProcessing = false;

        if (isDescriptor) {
          await _executeAddWallet(inputViewModel);
        } else {
          if (mounted) {
            _showMfpInputBottomSheet(inputViewModel);
          }
        }
        return;
      } else {
        _isProcessing = false;
        await controller?.start();
      }
    }

    try {
      ResultOfSyncFromVault addResult = await _viewModel.addWallet(additionInfo);
      FileLogger.log(className, methodName, 'addWallet completed: ${addResult.result.name}');

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
          {
            vibrateLightDouble();
            _showErrorDialog(
              t.alert.wallet_add.update_failed,
              t.alert.wallet_add.update_failed_description(
                name: TextUtils.ellipsisIfLonger(_viewModel.getWalletName(addResult.walletId!), maxLength: 15),
              ),
            );

            break;
          }
        case WalletSyncResult.existingName:
          vibrateLightDouble();
          if (mounted) {
            _showErrorDialog(t.alert.wallet_add.duplicate_name, t.alert.wallet_add.duplicate_name_description);
          }
        case WalletSyncResult.existingWalletUpdateImpossible:
          vibrateLightDouble();
          if (mounted) {
            _showErrorDialog(
              t.alert.wallet_add.already_exist,
              t.alert.wallet_add.already_exist_description(
                name: TextUtils.ellipsisIfLonger(_viewModel.getWalletName(addResult.walletId!), maxLength: 15),
              ),
            );
          }
      }
    } catch (e, stackTrace) {
      FileLogger.error(className, methodName, '_onCompletedScanning failed: $e', stackTrace);
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
    } finally {
      FileLogger.log(className, methodName, '_onCompletedScanning finally block');
      vibrateMedium();
      if (mounted) {
        context.loaderOverlay.hide();
      }
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
          onTapRight: () {
            FileLogger.log(className, methodName, 'Error dialog confirmed');
            _isProcessing = false;
            Navigator.pop(context);
          },
          rightButtonText: t.OK,
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
          backgroundColor: CoconutColors.black.withValues(alpha: 0.7),
          description: description,
          descriptionPadding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
          insetPadding: const EdgeInsets.symmetric(horizontal: 50),
          leftButtonText: t.cancel,
          leftButtonColor: CoconutColors.black.withValues(alpha: 0.7),
          rightButtonText: t.confirm,
          rightButtonColor: CoconutColors.white,
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
    WalletImportSource.extendedPublicKey => t.wallet_add_scanner_screen.self,
    _ => '',
  };
}
