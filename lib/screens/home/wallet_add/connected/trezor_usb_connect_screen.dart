import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/connected/trezor_usb_connect_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/wallet_sync_result_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/trezor_connect_shared_widgets.dart';
import 'package:coconut_wallet/widgets/dialog.dart';
import 'package:coconut_wallet/widgets/card/expandable_info_card.dart';
import 'package:coconut_wallet/widgets/wallet_connect_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TrezorUsbConnectScreen extends StatefulWidget {
  final String? psbtBase64;
  final String? walletName;
  final String? walletFingerprint;

  const TrezorUsbConnectScreen({super.key, this.psbtBase64, this.walletName, this.walletFingerprint});

  @override
  State<TrezorUsbConnectScreen> createState() => _TrezorUsbConnectScreenState();
}

class _TrezorUsbConnectScreenState extends State<TrezorUsbConnectScreen> {
  late final TrezorUsbConnectViewModel _viewModel;
  late final Future<String?> Function() _pinHandler;
  late final Future<TrezorPassphraseResponse> Function(bool) _passphraseHandler;
  bool _isAddingWallet = false;
  bool _isVerifyingPairingCode = false;
  TrezorUsbConnectStep? _lastStep;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _passphraseFocusNode = FocusNode();

  static const int _codeLength = 6;
  String _pairingCode = '';
  final TextEditingController _passphraseController = TextEditingController();

  static const List<String> _modelOnePinKeys = ['7', '8', '9', '4', '5', '6', '1', '2', '3', '', 'OK', '<'];

  @override
  void initState() {
    super.initState();
    _viewModel = TrezorUsbConnectViewModel(context.read<WalletProvider>());
    _pinHandler = _viewModel.requestPin;
    _passphraseHandler = _viewModel.requestPassphrase;
    TrezorDevice.onPinRequested = _pinHandler;
    TrezorDevice.onPassphraseRequested = _passphraseHandler;
    _viewModel.addListener(_onViewModelChanged);
  }

  @override
  void dispose() {
    if (TrezorDevice.onPinRequested == _pinHandler) {
      TrezorDevice.onPinRequested = null;
    }
    if (TrezorDevice.onPassphraseRequested == _passphraseHandler) {
      TrezorDevice.onPassphraseRequested = null;
    }
    _passphraseController.dispose();
    _passphraseFocusNode.dispose();
    _scrollController.dispose();
    _viewModel.dispose();
    super.dispose();
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
    debugPrint('TREZOR_USB_SCREEN state=${step.name} mounted=$mounted');
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

  Future<void> _addWallet() async {
    if (_isAddingWallet) return;
    setState(() => _isAddingWallet = true);
    try {
      final result = await _viewModel.addToWalletList();
      if (!mounted) return;
      if (result.result == WalletSyncResult.newWalletAdded && result.walletId != null) {
        Navigator.pushReplacementNamed(
          context,
          '/wallet-detail',
          arguments: {'id': result.walletId, 'entryPoint': kEntryPointWalletHome},
        );
        return;
      }
      showWalletSyncResultErrorDialog(context, result, context.read<WalletProvider>());
    } catch (error) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder:
            (dialogContext) => CoconutPopup(
              languageCode: context.read<PreferenceProvider>().language,
              title: t.alert.wallet_add.add_failed,
              description: error.toString(),
              onTapRight: () => Navigator.pop(dialogContext),
              rightButtonText: t.OK,
            ),
      );
    } finally {
      if (mounted) setState(() => _isAddingWallet = false);
    }
  }

  Future<void> _handleClose() async {
    if (_viewModel.step == TrezorUsbConnectStep.pinEntry) {
      _viewModel.cancelPin();
      Navigator.pop(context);
      return;
    }
    if (_viewModel.step == TrezorUsbConnectStep.pairing) {
      _viewModel.cancelPairing();
      Navigator.pop(context);
      return;
    }
    if (_viewModel.step == TrezorUsbConnectStep.passphraseUseQuestion ||
        _viewModel.step == TrezorUsbConnectStep.passphraseSourceSelection ||
        _viewModel.step == TrezorUsbConnectStep.passphraseInput) {
      Navigator.pop(context);
      return;
    }
    if (!_viewModel.isConnected) {
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

  void _startSigning() {
    Navigator.pop(context);
    Navigator.pushNamed(
      context,
      '/trezor-sign',
      arguments: {
        'psbtBase64': widget.psbtBase64,
        'walletName': widget.walletName ?? '',
        'walletFingerprint': widget.walletFingerprint ?? '',
        'isFromSendFlow': true,
        'transport': TrezorTransport.usb.name,
      },
    );
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
          body: Consumer<TrezorUsbConnectViewModel>(
            builder:
                (context, vm, _) => SafeArea(
                  child: SizedBox(
                    height: MediaQuery.sizeOf(context).height,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final isFullHeight =
                                  vm.step == TrezorUsbConnectStep.pinEntry || vm.step == TrezorUsbConnectStep.pairing;
                              final bottomPadding = isFullHeight ? 24.0 : 120.0;
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
                        if (vm.step == TrezorUsbConnectStep.idle ||
                            vm.step == TrezorUsbConnectStep.error ||
                            (vm.step == TrezorUsbConnectStep.connected && vm.xpub.isNotEmpty))
                          Stack(alignment: Alignment.center, children: [_buildPrimaryActionButton(vm)]),
                        if (vm.step == TrezorUsbConnectStep.passphraseInput)
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
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSection(TrezorUsbConnectViewModel vm, {required double inputMinHeight}) {
    Logger.log('TREZOR_USB_SCREEN _buildStatusSection step=${vm.step}');
    switch (vm.step) {
      case TrezorUsbConnectStep.idle:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WalletConnectInstructionToolTip(
              steps: [
                t.wallet_connect_screen.guide_trezor.usb.idle_step1,
                t.wallet_connect_screen.guide_trezor.usb.idle_step2,
                t.wallet_connect_screen.guide_trezor.usb.idle_step3,
              ],
            ),
            CoconutLayout.spacing_400h,
            _buildInfoCardForTrezorSuite(),
          ],
        );
      case TrezorUsbConnectStep.connecting:
        return WalletConnectProgressCard(
          title: t.wallet_connect_screen.guide_trezor.usb.connecting,
          steps: [t.wallet_connect_screen.guide_trezor.usb.connecting_step1],
        );
      case TrezorUsbConnectStep.pinEntry:
        return _buildPinCard(vm, minHeight: inputMinHeight);
      case TrezorUsbConnectStep.passphraseUseQuestion:
        return TrezorPassphraseUseQuestionCard(
          onUsePassphrase: vm.selectUsePassphrase,
          onNoPassphrase: vm.selectNoPassphrase,
        );
      case TrezorUsbConnectStep.passphraseEnabling:
        return TrezorLoadingCard(title: t.wallet_connect_screen.guide_trezor.usb.passphrase_enabling);
      case TrezorUsbConnectStep.passphraseSourceSelection:
        return TrezorPassphraseSourceSelectionCard(onAppEntry: vm.selectAppEntry, onDeviceEntry: vm.selectDeviceEntry);
      case TrezorUsbConnectStep.passphraseInput:
        return TrezorPassphraseInputCard(
          passphraseController: _passphraseController,
          passphraseFocusNode: _passphraseFocusNode,
          onChanged: (_) => setState(() {}),
        );
      case TrezorUsbConnectStep.passphraseOnDevice:
        return const TrezorPassphraseOnDeviceCard();
      case TrezorUsbConnectStep.passphraseConfirm:
        return const TrezorPassphraseConfirmCard();
      case TrezorUsbConnectStep.passphraseProcessing:
        return TrezorPassphraseProcessingCard(usesThp: vm.usesThp, usePassphrase: vm.passphraseProtection);
      case TrezorUsbConnectStep.pairing:
        return TrezorPairingCard(
          pairingCode: _pairingCode,
          isVerifying: _isVerifyingPairingCode,
          hasError: vm.isPairingCodeWrong,
          errorMessage:
              vm.isPairingCodeWrong ? t.wallet_connect_screen.guide_trezor.pairing_dialog.error_wrong_code : null,
          onKeyTap: _onPairingKeyTap,
          minHeight: inputMinHeight,
        );
      case TrezorUsbConnectStep.connected:
        return _buildSuccessCard(vm);
      case TrezorUsbConnectStep.error:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WalletConnectErrorCard(
              title: t.wallet_connect_screen.guide_trezor.error.title,
              description: t.wallet_connect_screen.guide_trezor.error.usb_description,
              errorMessage: vm.errorMessage,
            ),
            CoconutLayout.spacing_400h,
            _buildInfoCardForTrezorSuite(),
          ],
        );
    }
  }

  Widget _buildInfoCardForTrezorSuite() {
    return ExpandableInfoCard(
      descriptionText: t.wallet_connect_screen.guide_trezor.usb.suite_app_notice,
      sections: [
        ExpandableInfo(
          titleText: t.wallet_connect_screen.guide_trezor.usb.suite_app_setting_guide.title,
          descriptionList: t.wallet_connect_screen.guide_trezor.usb.suite_app_setting_guide.descriptions,
        ),
      ],
    );
  }

  Widget _buildSuccessCard(TrezorUsbConnectViewModel vm) {
    final hasXpub = vm.xpub.isNotEmpty;
    final isMismatch = widget.psbtBase64 != null && hasXpub && _isWalletMismatch(vm);

    if (isMismatch) {
      final matchedWalletName = context.read<WalletProvider>().findWalletNameByXpub(vm.xpub);
      final mismatchMessage =
          matchedWalletName != null
              ? t.trezor_sign_screen.device_mismatch_other_wallet(wallet_name: matchedWalletName)
              : t.trezor_sign_screen.device_mismatch;
      return WalletConnectMismatchCard(
        title: mismatchMessage,
        child: TrezorWalletInfoCard(deviceLabel: vm.deviceLabel, fingerprint: vm.fingerprint, xpub: vm.xpub),
      );
    }

    return WalletConnectSuccessCard(
      title: t.wallet_connect_screen.guide_trezor.paired.title,
      child:
          hasXpub
              ? TrezorWalletInfoCard(deviceLabel: vm.deviceLabel, fingerprint: vm.fingerprint, xpub: vm.xpub)
              : const WalletConnectWalletInfoSkeleton(),
    );
  }

  bool _isWalletMismatch(TrezorUsbConnectViewModel vm) {
    final isSignFlow = widget.psbtBase64 != null;
    final isPaired = vm.step == TrezorUsbConnectStep.connected;
    final hasXpub = vm.xpub.isNotEmpty;
    if (!isSignFlow || !isPaired || !hasXpub) return false;

    final wp = context.read<WalletProvider>();
    final matchedName = wp.findWalletNameByXpub(vm.xpub);
    return matchedName == null || matchedName != (widget.walletName ?? '');
  }

  Widget _buildPrimaryActionButton(TrezorUsbConnectViewModel vm) {
    if (vm.step == TrezorUsbConnectStep.pairing) return const SizedBox.shrink();

    final bool isRetry = vm.step == TrezorUsbConnectStep.error;
    final bool isPaired = vm.step == TrezorUsbConnectStep.connected;
    final bool hasXpub = vm.xpub.isNotEmpty;
    final bool isSignFlow = widget.psbtBase64 != null;
    final bool isMismatch = _isWalletMismatch(vm);

    String buttonText;
    VoidCallback onPressed;

    if (isSignFlow && isPaired && isMismatch) {
      return TrezorWalletMismatchActionButton(
        onButtonClicked: () {
          debugPrint('TREZOR_USB_CONNECT mismatch alternate-device clicked: resetting and reconnecting USB device');
          vm.reset();
          vm.connect();
        },
        isActive:
            vm.step != TrezorUsbConnectStep.connecting &&
            vm.step != TrezorUsbConnectStep.pinEntry &&
            vm.step != TrezorUsbConnectStep.passphraseUseQuestion &&
            vm.step != TrezorUsbConnectStep.passphraseSourceSelection &&
            vm.step != TrezorUsbConnectStep.passphraseOnDevice &&
            vm.step != TrezorUsbConnectStep.passphraseConfirm &&
            vm.step != TrezorUsbConnectStep.passphraseProcessing &&
            vm.step != TrezorUsbConnectStep.pairing &&
            !_isAddingWallet,
      );
    } else if (isSignFlow && isPaired) {
      buttonText = t.wallet_connect_screen.guide_trezor.btn.start_signing;
      onPressed = _startSigning;
    } else if (!isSignFlow && isPaired && hasXpub) {
      buttonText = t.wallet_connect_screen.guide_trezor.btn.add_wallet;
      onPressed = _addWallet;
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
      buttonText = t.wallet_connect_screen.guide_trezor.usb.connect;
      onPressed = vm.connect;
    }

    return FixedBottomButton(
      onButtonClicked: onPressed,
      text: buttonText,
      isActive:
          vm.step != TrezorUsbConnectStep.connecting &&
          vm.step != TrezorUsbConnectStep.pinEntry &&
          vm.step != TrezorUsbConnectStep.passphraseUseQuestion &&
          vm.step != TrezorUsbConnectStep.passphraseSourceSelection &&
          vm.step != TrezorUsbConnectStep.passphraseOnDevice &&
          vm.step != TrezorUsbConnectStep.passphraseConfirm &&
          vm.step != TrezorUsbConnectStep.passphraseProcessing &&
          vm.step != TrezorUsbConnectStep.pairing &&
          !_isAddingWallet,
    );
  }

  void _onPinKeyTap(String value) {
    vibrateExtraLight();
    _viewModel.onPinKeyTap(value);
  }

  Widget _buildPinCard(TrezorUsbConnectViewModel vm, {required double minHeight}) {
    final childAspectRatio = MediaQuery.sizeOf(context).width > 600 ? 2.5 : 1.6;
    final gridWidth = MediaQuery.sizeOf(context).width - 48;
    final keypadHeight = (gridWidth / 3 / childAspectRatio * 4) + 24;

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: IntrinsicHeight(
        child: Column(
          children: [
            Text(
              t.wallet_connect_screen.guide_trezor.usb.pin_title,
              style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              t.wallet_connect_screen.guide_trezor.usb.pin_description,
              style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 84,
              child: Wrap(
                alignment: WrapAlignment.center,
                children: List.generate(
                  vm.pin.length,
                  (_) => const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: Text('●', style: TextStyle(fontSize: 18)),
                  ),
                ),
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
                      mainAxisSpacing: 8,
                      childAspectRatio: childAspectRatio,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children:
                          _modelOnePinKeys.map((key) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: _buildPinKeyButton(key, vm),
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

  Widget _buildPinKeyButton(String key, TrezorUsbConnectViewModel vm) {
    if (key.isEmpty) return const SizedBox.shrink();
    if (key == 'OK') {
      final isEnabled = vm.pin.length >= 4;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isEnabled ? vm.submitPin : null,
        child: SizedBox.expand(
          child: Center(
            child: Text(
              t.OK,
              style: CoconutTypography.body1_16_Bold.setColor(
                isEnabled ? context.coconutColors.primaryText : context.coconutColors.mutedText,
              ),
            ),
          ),
        ),
      );
    }
    if (key == '<') {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onPinKeyTap('<'),
        child: SizedBox.expand(
          child: Center(child: Icon(Icons.backspace, color: context.coconutColors.primaryText, size: 20)),
        ),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onPinKeyTap(key),
      child: SizedBox.expand(
        child: Center(
          child: Text('●', style: CoconutTypography.heading3_21_Number.setColor(context.coconutColors.primaryText)),
        ),
      ),
    );
  }
}
