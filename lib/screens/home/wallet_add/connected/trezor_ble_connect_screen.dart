import 'package:coconut_design_system/coconut_design_system.dart';
import 'dart:io';
import 'package:coconut_wallet/analytics/wallet_add_analytics.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/connected/trezor_ble_connect_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/utils/wallet_sync_result_util.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/trezor_connect_shared_widgets.dart';
import 'package:coconut_wallet/widgets/overlays/coconut_loading_overlay.dart';
import 'package:coconut_wallet/utils/app_settings_util.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/widgets/dialog.dart';
import 'package:coconut_wallet/widgets/wallet_connect_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TrezorBleConnectScreen extends StatefulWidget {
  final String? psbtBase64;
  final String? walletName;
  final String? walletFingerprint;
  final bool resumeFromExistingSession;

  const TrezorBleConnectScreen({
    super.key,
    this.psbtBase64,
    this.walletName,
    this.walletFingerprint,
    this.resumeFromExistingSession = false,
  });

  @override
  State<TrezorBleConnectScreen> createState() => _TrezorBleConnectScreenState();
}

class _TrezorBleConnectScreenState extends State<TrezorBleConnectScreen> {
  late TrezorBleConnectViewModel _viewModel;
  bool _isAddingWallet = false;
  bool _isVerifyingPairingCode = false;
  TrezorBleConnectStep? _lastStep;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _passphraseFocusNode = FocusNode();

  static const int _codeLength = 6;
  String _pairingCode = '';
  final TextEditingController _passphraseController = TextEditingController();
  late final Future<TrezorPassphraseResponse> Function(bool) _passphraseHandler;

  @override
  void initState() {
    super.initState();
    _viewModel = TrezorBleConnectViewModel(Provider.of<WalletProvider>(context, listen: false));
    _passphraseHandler = _viewModel.requestPassphrase;
    TrezorDevice.onPassphraseRequested = _passphraseHandler;
    _viewModel.onPairingFailed = () {};
    if (widget.resumeFromExistingSession) {
      _viewModel.resumeFromExistingSession();
    }
    _viewModel.addListener(_onViewModelChanged);
  }

  void _onPairingKeyTap(String value) {
    if (value == '<') {
      if (_pairingCode.isNotEmpty) {
        setState(() => _pairingCode = _pairingCode.substring(0, _pairingCode.length - 1));
      }
      return;
    }
    if (value.isEmpty) return;
    if (_pairingCode.length >= _codeLength) return;

    setState(() => _pairingCode += value);
    vibrateExtraLight();

    if (_pairingCode.length == _codeLength) {
      final code = _pairingCode;
      setState(() => _isVerifyingPairingCode = true);
      _viewModel.submitPairingCode(code);
    }
  }

  void _onViewModelChanged() {
    final step = _viewModel.step;
    if (_lastStep != step) {
      _lastStep = step;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      if (_isVerifyingPairingCode) {
        _isVerifyingPairingCode = false;
        _pairingCode = '';
      }
      if (mounted) setState(() {});
    }
    if (_viewModel.isPairingCodeWrong && mounted) {
      _viewModel.consumePairingCodeWrong();
      _showPairingCodeWrongDialog();
    }
    if (_viewModel.isPermissionDenied && mounted) {
      _viewModel.consumePermissionDenied();
      _showPermissionDeniedDialog();
    }
  }

  void _showPairingCodeWrongDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => CoconutPopup(
            languageCode: context.read<PreferenceProvider>().language,
            title: t.wallet_connect_screen.guide_trezor.pairing_dialog.error_wrong_code,
            description: t.wallet_connect_screen.guide_trezor.pairing_dialog.error_wrong_code_dialog,
            onTapRight: () {
              _viewModel.reset();
              Navigator.pop(context);
            },
            rightButtonText: t.OK,
          ),
    );
  }

  void _showPermissionDeniedDialog() {
    final isIOS = Platform.isIOS;
    final title = isIOS ? t.alert.ios_ble_permission_denied.title : t.alert.aos_ble_permission_denied.title;
    final description =
        isIOS ? t.alert.ios_ble_permission_denied.description : t.alert.aos_ble_permission_denied.description;
    showConfirmDialog(
      context,
      context.read<PreferenceProvider>().language,
      title,
      description,
      rightButtonText: t.go_to_settings,
      onTapRight: () {
        _viewModel.reset();
        openAppSettings();
      },
      onTapLeft: () {
        _viewModel.reset();
        Navigator.pop(context);
      },
    );
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    if (TrezorDevice.onPassphraseRequested == _passphraseHandler) {
      TrezorDevice.onPassphraseRequested = null;
    }
    _passphraseController.dispose();
    _passphraseFocusNode.dispose();
    _scrollController.dispose();
    _loadingOverlayEntry?.remove();
    _loadingOverlayEntry = null;
    _viewModel.dispose();
    super.dispose();
  }

  OverlayEntry? _loadingOverlayEntry;

  void _showFullScreenLoading() {
    _loadingOverlayEntry = OverlayEntry(builder: (_) => const CoconutLoadingOverlay(applyFullScreen: true));
    Overlay.of(context).insert(_loadingOverlayEntry!);
    setState(() => _isAddingWallet = true);
  }

  void _hideFullScreenLoading() {
    _loadingOverlayEntry?.remove();
    _loadingOverlayEntry = null;
    if (mounted) setState(() => _isAddingWallet = false);
  }

  Future<void> _onAddWalletPressed(TrezorBleConnectViewModel vm) async {
    if (_isAddingWallet) return;
    _showFullScreenLoading();

    final stopwatch = Stopwatch()..start();
    ResultOfSyncFromVault result;
    try {
      result = await vm.addToWalletList();
    } catch (e) {
      if (!mounted) return;
      _hideFullScreenLoading();
      showDialog(
        context: context,
        builder:
            (context) => CoconutPopup(
              languageCode: context.read<PreferenceProvider>().language,
              title: t.alert.wallet_add.add_failed,
              description: e.toString(),
              onTapRight: () => Navigator.pop(context),
              rightButtonText: t.OK,
            ),
      );
      return;
    }
    final remaining = const Duration(seconds: 3) - stopwatch.elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;

    if (result.result == WalletSyncResult.newWalletAdded && result.walletId != null) {
      context.read<AnalyticsService>().logWalletAddCompleted(WalletImportSource.trezor);
      _hideFullScreenLoading();
      Navigator.pushReplacementNamed(
        context,
        '/wallet-detail',
        arguments: {'id': result.walletId, 'entryPoint': kEntryPointWalletHome},
      );
      return;
    }

    _hideFullScreenLoading();

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    showWalletSyncResultErrorDialog(context, result, walletProvider);
  }

  Future<void> _handleClose() async {
    if (_viewModel.step == TrezorBleConnectStep.pairing) {
      _viewModel.cancelPairing();
      Navigator.pop(context);
      return;
    }
    if (_viewModel.step == TrezorBleConnectStep.passphraseUseQuestion ||
        _viewModel.step == TrezorBleConnectStep.passphraseSourceSelection ||
        _viewModel.step == TrezorBleConnectStep.passphraseInput) {
      Navigator.pop(context);
      return;
    }
    if (!_viewModel.isPaired) {
      Navigator.pop(context);
      return;
    }

    bool? keepConnection;
    await showConfirmDialog(
      context,
      context.read<PreferenceProvider>().language,
      t.wallet_connect_screen.guide_trezor.keep_connection_title,
      t.wallet_connect_screen.guide_trezor.keep_connection_description,
      leftButtonText: t.no,
      rightButtonText: t.yes,
      barrierDismissible: true,
      onTapLeft: () {
        keepConnection = false;
        Navigator.pop(context);
      },
      onTapRight: () {
        keepConnection = true;
        Navigator.pop(context);
      },
    );
    if (!mounted || keepConnection == null) return;
    if (keepConnection == false) {
      await _viewModel.disconnect();
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleClose();
        }
      },
      child: ChangeNotifierProvider.value(
        value: _viewModel,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: context.coconutColors.background,
          appBar: CoconutAppBar.build(
            title: WalletImportSource.trezor.displayName,
            context: context,
            isBottom: true,
            onBackPressed: _handleClose,
          ),
          body: Consumer<TrezorBleConnectViewModel>(
            builder: (context, vm, _) {
              return SafeArea(
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isPairingVisible = vm.step == TrezorBleConnectStep.pairing;
                            final bottomPadding = isPairingVisible ? 24.0 : 120.0;
                            final minContentHeight =
                                (constraints.maxHeight - 24 - bottomPadding).clamp(0.0, double.infinity).toDouble();
                            return SingleChildScrollView(
                              controller: _scrollController,
                              padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
                              child: _buildStatusSection(vm, inputMinHeight: minContentHeight),
                            );
                          },
                        ),
                      ),
                      if (vm.step == TrezorBleConnectStep.idle ||
                          vm.step == TrezorBleConnectStep.error ||
                          (vm.step == TrezorBleConnectStep.paired && vm.xpub.isNotEmpty))
                        Stack(alignment: Alignment.center, children: [_buildPrimaryActionButton(vm)]),
                      if (vm.step == TrezorBleConnectStep.passphraseInput)
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            TrezorPassphraseInputActionButton(
                              onSubmit: () => vm.submitPassphraseValue(_passphraseController.text),
                              passphraseController: _passphraseController,
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection(TrezorBleConnectViewModel vm, {required double inputMinHeight}) {
    switch (vm.step) {
      case TrezorBleConnectStep.idle:
        return _buildInstructionToolTip([
          t.wallet_connect_screen.guide_trezor.init.ble_step1,
          t.wallet_connect_screen.guide_trezor.init.ble_step2,
          _buildPairAndConnectStep(),
          t.wallet_connect_screen.guide_trezor.init.ble_step4(
            btn: t.wallet_connect_screen.guide_trezor.btn.connect_via_ble,
          ),
        ], notice: t.wallet_connect_screen.guide_trezor.init.notice);
      case TrezorBleConnectStep.connecting:
        return _buildProgressCard(t.wallet_connect_screen.guide_trezor.connecting.title, [
          t.wallet_connect_screen.guide_trezor.init.ble_step2,
          _buildPairAndConnectStep(),
          t.wallet_connect_screen.guide_trezor.connecting.step3,
          t.wallet_connect_screen.guide_trezor.connecting.step4,
        ]);
      case TrezorBleConnectStep.pairing:
        return TrezorPairingCard(
          pairingCode: _pairingCode,
          isVerifying: _isVerifyingPairingCode,
          hasError: vm.pairingErrorMessage != null,
          errorMessage: vm.pairingErrorMessage,
          onKeyTap: _onPairingKeyTap,
          minHeight: inputMinHeight,
        );
      case TrezorBleConnectStep.passphraseUseQuestion:
        return TrezorPassphraseUseQuestionCard(
          onUsePassphrase: vm.selectUsePassphrase,
          onNoPassphrase: vm.selectNoPassphrase,
        );
      case TrezorBleConnectStep.passphraseEnabling:
        return TrezorLoadingCard(title: t.wallet_connect_screen.guide_trezor.usb.passphrase_enabling);
      case TrezorBleConnectStep.passphraseSourceSelection:
        return TrezorPassphraseSourceSelectionCard(onAppEntry: vm.selectAppEntry, onDeviceEntry: vm.selectDeviceEntry);
      case TrezorBleConnectStep.passphraseInput:
        return TrezorPassphraseInputCard(
          passphraseController: _passphraseController,
          passphraseFocusNode: _passphraseFocusNode,
          onChanged: (_) => setState(() {}),
        );
      case TrezorBleConnectStep.passphraseOnDevice:
        return const TrezorPassphraseOnDeviceCard();
      case TrezorBleConnectStep.passphraseConfirm:
        return const TrezorPassphraseConfirmCard();
      case TrezorBleConnectStep.passphraseProcessing:
        return const TrezorPassphraseProcessingCard();
      case TrezorBleConnectStep.paired:
        return _buildSuccessCard(vm);
      case TrezorBleConnectStep.error:
        return _buildErrorCard(vm, steps: vm.peerRemovedPairingSteps);
    }
  }

  List<TextSpan> _buildPairAndConnectStep() {
    return [
      TextSpan(
        text: t.wallet_connect_screen.guide_trezor.init.ble_step3_prefix,
        style: TextStyle(color: context.coconutColors.primaryText),
      ),
      TextSpan(
        text: t.wallet_connect_screen.guide_trezor.init.ble_step3_bold,
        style: TextStyle(color: context.coconutColors.primaryText, fontWeight: FontWeight.bold),
      ),
      TextSpan(
        text: t.wallet_connect_screen.guide_trezor.init.ble_step3_suffix,
        style: TextStyle(color: context.coconutColors.primaryText),
      ),
    ];
  }

  Widget _buildInstructionToolTip(List<Object> steps, {String? notice}) {
    return WalletConnectInstructionToolTip(steps: steps, notice: notice);
  }

  Widget _buildProgressCard(String title, List<Object> steps) {
    return WalletConnectProgressCard(title: title, steps: steps);
  }

  Widget _buildSuccessCard(TrezorBleConnectViewModel vm) {
    final hasXpub = vm.xpub.isNotEmpty;
    final hasSilentError = !hasXpub && vm.errorMessage != null;
    final isMismatch = widget.psbtBase64 != null && hasXpub && _isWalletMismatch(vm);

    if (isMismatch) {
      final matchedWalletName = context.read<WalletProvider>().findWalletNameByXpub(vm.xpub);
      return WalletConnectMismatchCard(
        title: t.trezor_sign_screen.wrong_wallet_title,
        description: t.trezor_sign_screen.device_mismatch,
        footerText:
            matchedWalletName != null
                ? t.trezor_sign_screen.device_mismatch_other_wallet(wallet_name: matchedWalletName)
                : null,
        child: Column(
          children: [
            WalletConnectSectionLabel(label: t.wallet_connect_screen.guide_trezor.paired.master_fingerprint),
            FingerprintCompareCard(
              expectedFingerprint: widget.walletFingerprint ?? '',
              connectedFingerprint: vm.fingerprint,
            ),
            CoconutLayout.spacing_400h,
            WalletConnectSectionLabel(label: t.trezor_sign_screen.connected_wallet_label),
            HardwareWalletInfoCard(deviceName: vm.deviceLabel, fingerprint: vm.fingerprint, xpub: vm.xpub),
          ],
        ),
      );
    }

    return WalletConnectSuccessCard(
      title: t.wallet_connect_screen.guide_trezor.paired.title,
      child:
          hasXpub
              ? HardwareWalletInfoCard(deviceName: vm.deviceLabel, fingerprint: vm.fingerprint, xpub: vm.xpub)
              : hasSilentError
              ? _buildXPubRetryCard(vm)
              : const WalletConnectWalletInfoSkeleton(),
    );
  }

  Widget _buildXPubRetryCard(TrezorBleConnectViewModel vm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: context.coconutColors.surface,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Column(
        children: [
          Text(
            vm.errorMessage ?? '',
            style: CoconutTypography.body3_12_Number.setColor(context.coconutColors.secondaryText),
            textAlign: TextAlign.center,
          ),
          CoconutLayout.spacing_200h,
          GestureDetector(
            onTap: () => vm.retrieveXPub(),
            child: Text(
              t.wallet_connect_screen.guide_trezor.btn.retry,
              style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(TrezorBleConnectViewModel vm, {List<String>? steps}) {
    return WalletConnectErrorCard(
      title: t.wallet_connect_screen.guide_trezor.error.title,
      description: vm.errorDescription ?? t.wallet_connect_screen.guide_trezor.error.ble_description,
      errorMessage: vm.errorMessage,
      steps: steps,
    );
  }

  bool _isWalletMismatch(TrezorBleConnectViewModel vm) {
    final isSignFlow = widget.psbtBase64 != null;
    final isPaired = vm.step == TrezorBleConnectStep.paired;
    final hasXpub = vm.xpub.isNotEmpty;
    if (!isSignFlow || !isPaired || !hasXpub) {
      debugPrint(
        'TREZOR_BLE_CONNECT mismatch check skipped: signFlow=$isSignFlow '
        'step=${vm.step.name} hasXpub=$hasXpub targetWallet="${widget.walletName}"',
      );
      return false;
    }

    final wp = context.read<WalletProvider>();
    final matchedName = wp.findWalletNameByXpub(vm.xpub);
    final isMismatch = matchedName == null || matchedName != (widget.walletName ?? '');
    debugPrint(
      'TREZOR_BLE_CONNECT mismatch check: targetWallet="${widget.walletName}" '
      'isMismatch=$isMismatch',
    );
    return isMismatch;
  }

  Widget _buildPrimaryActionButton(TrezorBleConnectViewModel vm) {
    if (vm.step == TrezorBleConnectStep.pairing) return const SizedBox.shrink();

    final bool isRetry = vm.step == TrezorBleConnectStep.error;
    final bool hasXpub = vm.xpub.isNotEmpty;
    final bool isPaired = vm.step == TrezorBleConnectStep.paired;
    final bool isSignFlow = widget.psbtBase64 != null;
    final bool isMismatch = _isWalletMismatch(vm);
    debugPrint(
      'TREZOR_BLE_CONNECT button build: step=${vm.step.name} signFlow=$isSignFlow '
      'isPaired=$isPaired hasXpub=$hasXpub isMismatch=$isMismatch',
    );

    String buttonText;
    VoidCallback onPressed;

    if (isSignFlow && isPaired && isMismatch) {
      return TrezorWalletMismatchActionButton(
        onButtonClicked: () {
          debugPrint('TREZOR_BLE_CONNECT mismatch alternate-device clicked: resetting and reconnecting BLE device');
          vm.reset();
          vm.connect();
        },
        isActive: !_isAddingWallet && !vm.isConnecting,
      );
    } else if (isSignFlow && isPaired) {
      buttonText = t.wallet_connect_screen.guide_trezor.btn.start_signing;
      onPressed = () {
        Navigator.pop(context);
        Navigator.pushNamed(
          context,
          '/trezor-sign',
          arguments: {
            'psbtBase64': widget.psbtBase64,
            'walletName': widget.walletName ?? '',
            'walletFingerprint': widget.walletFingerprint ?? '',
            'isFromSendFlow': true,
            'transport': 'ble',
          },
        );
      };
    } else if (!isSignFlow && isPaired && hasXpub) {
      buttonText = t.wallet_connect_screen.guide_trezor.btn.add_wallet;
      onPressed = () => _onAddWalletPressed(vm);
    } else if (isRetry) {
      buttonText = t.wallet_connect_screen.guide_trezor.btn.retry;
      onPressed = () {
        _passphraseController.clear();
        vm.reset();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          vm.connect();
        });
      };
    } else {
      buttonText = t.wallet_connect_screen.guide_trezor.btn.connect_via_ble;
      onPressed = () => vm.connect();
    }

    return FixedBottomButton(
      onButtonClicked: onPressed,
      text: buttonText,
      isActive: !_isAddingWallet && !vm.isConnecting,
    );
  }
}
