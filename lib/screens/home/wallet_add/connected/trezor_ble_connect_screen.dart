import 'package:coconut_design_system/coconut_design_system.dart';
import 'dart:io';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/connected/trezor_ble_connect_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/utils/wallet_sync_result_util.dart';
import 'package:coconut_wallet/widgets/button/key_button.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/trezor_digit_box.dart';
import 'package:coconut_wallet/widgets/trezor_connect_shared_widgets.dart';
import 'package:coconut_wallet/widgets/overlays/coconut_loading_overlay.dart';
import 'package:coconut_wallet/utils/app_settings_util.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/widgets/dialog.dart';
import 'package:coconut_wallet/widgets/wallet_connect_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class TrezorBleConnectScreen extends StatefulWidget {
  final String? psbtBase64;
  final String? walletName;
  final String? walletFingerprint;

  const TrezorBleConnectScreen({super.key, this.psbtBase64, this.walletName, this.walletFingerprint});

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
  static const List<String> _keypadKeys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '<'];
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
      barrierDismissible: false,
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
        return _buildPairingCard(vm, minHeight: inputMinHeight);
      case TrezorBleConnectStep.passphraseUseQuestion:
        return TrezorPassphraseUseQuestionCard(
          onUsePassphrase: vm.selectUsePassphrase,
          onNoPassphrase: vm.selectNoPassphrase,
        );
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
    return WalletConnectSuccessCard(
      title: t.wallet_connect_screen.guide_trezor.paired.title,
      child:
          hasXpub
              ? Column(
                children: [
                  TrezorWalletInfoCard(deviceLabel: vm.deviceLabel, fingerprint: vm.fingerprint, xpub: vm.xpub),
                  if (widget.psbtBase64 != null && _isWalletMismatch(vm)) ...[
                    CoconutLayout.spacing_400h,
                    _buildWalletMismatchWarning(vm),
                  ],
                ],
              )
              : hasSilentError
              ? _buildXPubRetryCard(vm)
              : const WalletConnectWalletInfoSkeleton(),
    );
  }

  Widget _buildWalletMismatchWarning(TrezorBleConnectViewModel vm) {
    final matchedName = vm.findMatchingTrezorWalletName(vm.xpub);
    final message =
        matchedName != null
            ? t.trezor_sign_screen.device_mismatch_other_wallet(wallet_name: matchedName)
            : t.trezor_sign_screen.device_mismatch;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: context.coconutColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
        border: Border.all(color: context.coconutColors.danger.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SvgPicture.asset(
              'assets/svg/triangle-warning.svg',
              colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
              width: 16,
              height: 16,
            ),
          ),
          CoconutLayout.spacing_200w,
          Expanded(child: Text(message, style: CoconutTypography.body3_12.setColor(context.coconutColors.danger))),
        ],
      ),
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

  Widget _buildPairingCard(TrezorBleConnectViewModel vm, {required double minHeight}) {
    final childAspectRatio = MediaQuery.sizeOf(context).width > 600 ? 2.5 : 1.4;
    final gridWidth = MediaQuery.sizeOf(context).width - 48;
    final keypadHeight = gridWidth / 3 / childAspectRatio * 4;

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: IntrinsicHeight(
        child: Column(
          children: [
            Text(
              t.wallet_connect_screen.guide_trezor.pairing_dialog.title,
              style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              t.wallet_connect_screen.guide_trezor.pairing_dialog.description,
              style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 84,
              child: Stack(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int index = 0; index < _codeLength; index++) ...[
                        if (index > 0) SizedBox(width: index == 3 ? 12 : 4),
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 40),
                            child: TrezorDigitBox(
                              digit: index < _pairingCode.length ? _pairingCode[index] : '',
                              hasError: vm.pairingErrorMessage != null,
                              isVerifying: _isVerifyingPairingCode,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (_isVerifyingPairingCode)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(color: context.coconutColors.primary, strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.wallet_connect_screen.guide_trezor.pairing_dialog.verifying,
                            style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                          ),
                        ],
                      ),
                    )
                  else if (vm.pairingErrorMessage != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Text(
                        vm.pairingErrorMessage!,
                        style: CoconutTypography.body3_12.setColor(context.coconutColors.danger),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: keypadHeight + 48),
                child: Center(
                  child: SizedBox(
                    height: keypadHeight,
                    child: GridView.count(
                      crossAxisCount: 3,
                      childAspectRatio: childAspectRatio,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children:
                          _keypadKeys.map((key) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: KeyButton(
                                keyValue: key,
                                onKeyTap: _isVerifyingPairingCode ? (_) {} : _onPairingKeyTap,
                              ),
                            );
                          }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isWalletMismatch(TrezorBleConnectViewModel vm) {
    if (widget.psbtBase64 == null) return false;
    if (vm.step != TrezorBleConnectStep.paired) return false;
    if (vm.xpub.isEmpty) return false;

    final matchedName = vm.findMatchingTrezorWalletName(vm.xpub);
    if (matchedName == null) return true;
    return matchedName != (widget.walletName ?? '');
  }

  Widget _buildPrimaryActionButton(TrezorBleConnectViewModel vm) {
    if (vm.step == TrezorBleConnectStep.pairing) return const SizedBox.shrink();

    final bool isRetry = vm.step == TrezorBleConnectStep.error;
    final bool hasXpub = vm.xpub.isNotEmpty;
    final bool isPaired = vm.step == TrezorBleConnectStep.paired;
    final bool isSignFlow = widget.psbtBase64 != null;
    final bool isMismatch = _isWalletMismatch(vm);

    String buttonText;
    VoidCallback onPressed;

    if (isSignFlow && isPaired && isMismatch) {
      buttonText = t.wallet_connect_screen.guide_trezor.btn.retry;
      onPressed = () {
        vm.reset();
        vm.connect();
      };
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
      onPressed = () => vm.connect();
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
