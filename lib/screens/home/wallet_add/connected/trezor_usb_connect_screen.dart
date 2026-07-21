import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/connected/trezor_usb_connect_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/utils/wallet_sync_result_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_tween_button.dart';
import 'package:coconut_wallet/widgets/dialog.dart';
import 'package:coconut_wallet/widgets/trezor_usb_prompt.dart';
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

  static const List<String> _pinKeys = ['7', '8', '9', '4', '5', '6', '1', '2', '3', '', '', '<'];

  @override
  void initState() {
    super.initState();
    _viewModel = TrezorUsbConnectViewModel(context.read<WalletProvider>());
    _pinHandler = _viewModel.requestPin;
    _passphraseHandler = (onDevice) => TrezorUsbPrompt.requestPassphrase(context, onDevice);
    TrezorDevice.onPinRequested = _pinHandler;
    TrezorDevice.onPassphraseRequested = _passphraseHandler;
  }

  @override
  void dispose() {
    if (TrezorDevice.onPinRequested == _pinHandler) {
      TrezorDevice.onPinRequested = null;
    }
    if (TrezorDevice.onPassphraseRequested == _passphraseHandler) {
      TrezorDevice.onPassphraseRequested = null;
    }
    _viewModel.dispose();
    super.dispose();
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
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
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
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                          child: _buildStatusSection(vm),
                        ),
                      ),
                      if (vm.step == TrezorUsbConnectStep.idle ||
                          vm.step == TrezorUsbConnectStep.error ||
                          (vm.step == TrezorUsbConnectStep.connected && vm.xpub.isNotEmpty))
                        Stack(alignment: Alignment.center, children: [_buildMainButton(vm)]),
                      if (vm.step == TrezorUsbConnectStep.pinEntry)
                        Stack(alignment: Alignment.center, children: [_buildPinButtons(vm)]),
                    ],
                  ),
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildStatusSection(TrezorUsbConnectViewModel vm) {
    switch (vm.step) {
      case TrezorUsbConnectStep.idle:
        return WalletConnectInstructionToolTip(steps: [t.wallet_connect_screen.guide_trezor.usb.description]);
      case TrezorUsbConnectStep.connecting:
        return WalletConnectProgressCard(
          title: t.wallet_connect_screen.guide_trezor.usb.connecting,
          steps: [t.wallet_connect_screen.guide_trezor.usb.connecting_description],
        );
      case TrezorUsbConnectStep.pinEntry:
        return _buildPinCard(vm);
      case TrezorUsbConnectStep.connected:
        return _buildSuccessCard(vm);
      case TrezorUsbConnectStep.error:
        return WalletConnectErrorCard(
          title: t.wallet_connect_screen.guide_trezor.error.title,
          description: t.wallet_connect_screen.guide_trezor.usb.error,
          errorMessage: vm.errorMessage,
        );
    }
  }

  Widget _buildSuccessCard(TrezorUsbConnectViewModel vm) {
    final hasXpub = vm.xpub.isNotEmpty;
    return WalletConnectSuccessCard(
      title: t.wallet_connect_screen.guide_trezor.paired.title,
      child: hasXpub ? _buildWalletInfoCard(vm) : const WalletConnectWalletInfoSkeleton(),
    );
  }

  Widget _buildWalletInfoCard(TrezorUsbConnectViewModel vm) {
    return WalletConnectWalletInfoCard(
      children: [
        if (vm.deviceLabel.isNotEmpty) ...[
          WalletConnectInfoRow(label: t.wallet_connect_screen.guide_trezor.paired.device_name, value: vm.deviceLabel),
          CoconutLayout.spacing_300h,
        ],
        WalletConnectInfoRow(
          label: t.wallet_connect_screen.guide_trezor.paired.master_fingerprint,
          value: vm.fingerprint.toUpperCase(),
        ),
        CoconutLayout.spacing_300h,
        WalletConnectInfoRow(
          label: t.wallet_connect_screen.guide_trezor.paired.derivation_path,
          value: NetworkType.currentNetworkType.isTestnet ? "m/84'/1'/0'" : "m/84'/0'/0'",
        ),
        CoconutLayout.spacing_300h,
        WalletConnectInfoRow(
          label: t.wallet_connect_screen.guide_trezor.paired.xpub,
          value: vm.xpub,
          direction: Axis.vertical,
        ),
      ],
    );
  }

  Widget _buildMainButton(TrezorUsbConnectViewModel vm) {
    final bool isRetry = vm.step == TrezorUsbConnectStep.error;
    final bool isPaired = vm.step == TrezorUsbConnectStep.connected;
    final bool hasXpub = vm.xpub.isNotEmpty;
    final bool isSignFlow = widget.psbtBase64 != null;

    String buttonText;
    VoidCallback onPressed;

    if (isSignFlow && isPaired) {
      buttonText = t.wallet_connect_screen.guide_trezor.btn.start_signing;
      onPressed = _startSigning;
    } else if (!isSignFlow && isPaired && hasXpub) {
      buttonText = t.wallet_connect_screen.guide_trezor.btn.add_wallet;
      onPressed = _addWallet;
    } else if (isRetry) {
      buttonText = t.wallet_connect_screen.guide_trezor.btn.retry;
      onPressed = () {
        vm.reset();
        vm.connect();
      };
    } else {
      buttonText = t.wallet_connect_screen.guide_trezor.usb.connect;
      onPressed = vm.connect;
    }

    return FixedBottomButton(
      onButtonClicked: onPressed,
      text: buttonText,
      isActive:
          vm.step != TrezorUsbConnectStep.connecting && vm.step != TrezorUsbConnectStep.pinEntry && !_isAddingWallet,
    );
  }

  void _onPinKeyTap(String value) {
    vibrateExtraLight();
    _viewModel.onPinKeyTap(value);
  }

  Widget _buildPinCard(TrezorUsbConnectViewModel vm) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
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
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 3,
            childAspectRatio: MediaQuery.of(context).size.width > 600 ? 2.5 : 1.6,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children:
                _pinKeys.map((key) {
                  return Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildPinKeyButton(key));
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPinButtons(TrezorUsbConnectViewModel vm) {
    return FixedBottomTweenButton(
      leftButtonClicked: vm.cancelPin,
      rightButtonClicked: vm.submitPin,
      leftButtonRatio: 0.35,
      leftText: t.cancel,
      rightText: t.OK,
      isRightButtonActive: vm.pin.length >= 4,
    );
  }

  Widget _buildPinKeyButton(String key) {
    if (key.isEmpty) return const SizedBox.shrink();
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
