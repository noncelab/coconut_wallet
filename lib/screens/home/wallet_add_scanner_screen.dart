import 'dart:async';
import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_add_scanner_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/utils/file_logger.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/animated_qr/coconut_qr_scanner.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:provider/provider.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

const String className = 'WalletAddScannerScreen';

class WalletAddScannerScreen extends StatefulWidget {
  final WalletImportSource importSource;
  final Function(ResultOfSyncFromVault)? onNewWalletAdded;
  const WalletAddScannerScreen({
    super.key,
    required this.importSource,
    this.onNewWalletAdded,
  });

  @override
  State<WalletAddScannerScreen> createState() => _WalletAddScannerScreenState();
}

class _WalletAddScannerScreenState extends State<WalletAddScannerScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  bool _isProcessing = false;
  late WalletAddScannerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = WalletAddScannerViewModel(
      widget.importSource,
      Provider.of<WalletProvider>(context, listen: false),
      Provider.of<PreferenceProvider>(context, listen: false),
    );
  }

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller!.pauseCamera();
    } else if (Platform.isIOS) {
      controller!.resumeCamera();
    }
  }

  List<TextSpan> _getGuideTextSpan() {
    final isKorean = Provider.of<PreferenceProvider>(context, listen: false).isKorean;

    switch (widget.importSource) {
      case WalletImportSource.coconutVault:
        {
          return [
            TextSpan(
              text: t.wallet_add_scanner_screen.guide_vault,
            ),
          ];
        }
      case WalletImportSource.seedSigner:
        {
          if (isKorean) {
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
          if (isKorean) {
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
          if (isKorean) {
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
          if (isKorean) {
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
          const prefix = 't.wallet_add_scanner_screen.guide_krux';
          if (isKorean) {
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

  TextSpan _em(String text) => TextSpan(
        text: text,
        style: CoconutTypography.body3_12_Bold,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CoconutAppBar.build(
        title: _getAppBarTitle(),
        context: context,
        isBottom: true,
        backgroundColor: CoconutColors.black.withOpacity(0.95),
        actionButtonList: [
          IconButton(
            onPressed: () {
              if (controller != null) {
                controller!.flipCamera();
              }
            },
            icon: const Icon(CupertinoIcons.camera_rotate, size: 22),
            color: CoconutColors.white,
          ),
        ],
      ),
      body: Stack(
        children: [
          CoconutQrScanner(
            setQrViewController: (QRViewController qrViewcontroller) {
              controller = qrViewcontroller;
            },
            onComplete: _onCompletedScanning,
            onFailed: _onFailedScanning,
            qrDataHandler: _viewModel.qrDataHandler,
          ),
          Padding(
            padding: const EdgeInsets.only(
                top: 20, left: CoconutLayout.defaultPadding, right: CoconutLayout.defaultPadding),
            child: CoconutToolTip(
              backgroundColor: CoconutColors.gray900,
              borderColor: CoconutColors.gray900,
              icon: SvgPicture.asset(
                'assets/svg/circle-info.svg',
                colorFilter: const ColorFilter.mode(
                  CoconutColors.white,
                  BlendMode.srcIn,
                ),
              ),
              tooltipType: CoconutTooltipType.fixed,
              richText: RichText(
                text: TextSpan(
                  style: CoconutTypography.body3_12,
                  children: _getGuideTextSpan(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCompletedScanning(dynamic additionInfo) async {
    const methodName = '_onCompletedScanning';

    FileLogger.log(className, methodName, 'additionInfo type: ${additionInfo.runtimeType}');

    if (_isProcessing) return;

    _isProcessing = true;
    try {
      ResultOfSyncFromVault addResult = await _viewModel.addWallet(additionInfo);
      FileLogger.log(className, methodName, 'addWallet completed: ${addResult.result.name}');

      if (!mounted) return;

      switch (addResult.result) {
        case WalletSyncResult.newWalletAdded:
          {
            context.read<AnalyticsService>().logEvent(
                eventName: AnalyticsEventNames.walletAddCompleted,
                parameters: {
                  AnalyticsParameterNames.walletAddImportSource: widget.importSource.name
                });

            if (widget.onNewWalletAdded != null) {
              widget.onNewWalletAdded!(addResult);
            }
            if (mounted) {
              Navigator.pushReplacementNamed(
                context,
                '/wallet-detail',
                arguments: {
                  'id': addResult.walletId,
                  'entryPoint': kEntryPointWalletHome,
                },
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
                    name: TextUtils.ellipsisIfLonger(
                  _viewModel.getWalletName(addResult.walletId!),
                  maxLength: 15,
                )));

            break;
          }
        case WalletSyncResult.existingName:
          vibrateLightDouble();
          if (mounted) {
            _showErrorDialog(
              t.alert.wallet_add.duplicate_name,
              t.alert.wallet_add.duplicate_name_description,
            );
          }
        case WalletSyncResult.existingWalletUpdateImpossible:
          vibrateLightDouble();
          if (mounted) {
            _showErrorDialog(
              t.alert.wallet_add.already_exist,
              t.alert.wallet_add.already_exist_description(
                  name: TextUtils.ellipsisIfLonger(_viewModel.getWalletName(addResult.walletId!),
                      maxLength: 15)),
            );
          }
      }
    } catch (e, stackTrace) {
      FileLogger.error(className, methodName, '_onCompletedScanning failed: $e', stackTrace);
      vibrateLightDouble();
      if (mounted) {
        String errorMessage = "${t.wallet_add_input_screen.format_error_text}\n${e.toString()}";
        if (e.toString().contains("network type")) {
          errorMessage = NetworkType.currentNetworkType == NetworkType.mainnet
              ? t.wallet_add_input_screen.mainnet_wallet_error_text
              : t.wallet_add_input_screen.testnet_wallet_error_text;
        }
        _showErrorDialog(
          t.alert.wallet_add.add_failed,
          errorMessage,
        );
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
    FileLogger.error(className, methodName,
        '_onFailedScanning called with message: $message${scannedData != null ? " data: $scannedData" : null}');

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

    await CustomDialogs.showCustomAlertDialog(context,
        title: t.alert.scan_failed, message: errorMessage, onConfirm: () {
      FileLogger.log(className, methodName, 'Error dialog confirmed');
      _isProcessing = false;
      Navigator.pop(context);
    });
  }

  void _showErrorDialog(String title, String description) {
    const methodName = '_showErrorDialog';
    FileLogger.log(className, methodName, 'Error title: $title');
    FileLogger.log(className, methodName, 'Error description: $description');

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CoconutPopup(
          title: title,
          backgroundColor: CoconutColors.black.withOpacity(0.7),
          description: description,
          descriptionPadding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 12),
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 50,
          ),
          rightButtonColor: CoconutColors.white,
          rightButtonTextStyle: CoconutTypography.body2_14,
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
        _ => '',
      };

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
