import 'dart:io' show Platform;

import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup;
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/connected/bitbox02_connect_viewmodel.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_transport.dart';
import 'package:coconut_wallet/utils/wallet_sync_result_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:coconut_wallet/widgets/common/overlays/coconut_loading_overlay.dart';
import 'package:coconut_wallet/widgets/features/wallet/connect/wallet_connect_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BitBox02ConnectScreen extends StatefulWidget {
  final WalletImportSource importSource;

  /// When non-null, the screen is in "sign flow" mode:
  /// after pairing, the button navigates to /bitbox02-sign instead of adding the wallet.
  final String? psbtBase64;
  final String? walletName;
  final String? walletFingerprint;
  final bool resumeFromExistingSession;

  const BitBox02ConnectScreen({
    super.key,
    required this.importSource,
    this.psbtBase64,
    this.walletName,
    this.walletFingerprint,
    this.resumeFromExistingSession = false,
  });

  @override
  State<BitBox02ConnectScreen> createState() => _BitBox02ConnectScreenState();
}

class _BitBox02ConnectScreenState extends State<BitBox02ConnectScreen> {
  late BitBox02ConnectViewModel _viewModel;
  bool _isAddingWallet = false;

  @override
  void initState() {
    super.initState();
    _viewModel = BitBox02ConnectViewModel(Provider.of<WalletProvider>(context, listen: false));
    if (widget.resumeFromExistingSession) {
      _viewModel.resumeFromExistingSession();
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  Future<void> _onAddWalletPressed(BitBox02ConnectViewModel vm) async {
    if (_isAddingWallet) return;
    setState(() => _isAddingWallet = true);

    final stopwatch = Stopwatch()..start();
    final result = await vm.addToWalletList();
    final remaining = const Duration(seconds: 3) - stopwatch.elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }

    if (!mounted) return;

    if (result.result == WalletSyncResult.newWalletAdded && result.walletId != null) {
      Navigator.pushReplacementNamed(
        context,
        '/renewal-wallet-detail',
        arguments: {'id': result.walletId, 'entryPoint': kEntryPointWalletHome},
      );
      return;
    }

    setState(() => _isAddingWallet = false);

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    showWalletSyncResultErrorDialog(context, result, walletProvider);
  }

  Future<void> _handleClose() async {
    if (_viewModel.step == BitBox02ConnectStep.pairing) {
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
      t.wallet_connect_screen.guide_bitbox02.keep_connection_title,
      t.wallet_connect_screen.guide_bitbox02.keep_connection_description,
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
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: context.coconutColors.background,
        appBar: CoconutAppBar.build(
          title: widget.importSource.displayName,
          context: context,
          isBottom: true,
          onBackPressed: _handleClose,
        ),
        body: Consumer<BitBox02ConnectViewModel>(
          builder: (context, vm, _) {
            return SafeArea(
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
                    if (vm.step == BitBox02ConnectStep.idle ||
                        vm.step == BitBox02ConnectStep.error ||
                        (vm.step == BitBox02ConnectStep.paired && !vm.isConnecting))
                      Stack(alignment: Alignment.center, children: [_buildPrimaryActionButton(vm)]),
                    if (_isAddingWallet) const CoconutLoadingOverlay(applyFullScreen: true),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusSection(BitBox02ConnectViewModel vm) {
    switch (vm.step) {
      case BitBox02ConnectStep.idle:
        if (Platform.isIOS) {
          return _buildInstructionToolTip([
            t.wallet_connect_screen.guide_bitbox02.init.ble_step1,
            t.wallet_connect_screen.guide_bitbox02.init.ble_step2,
            t.wallet_connect_screen.guide_bitbox02.init.ble_step3(
              btn: t.wallet_connect_screen.guide_bitbox02.btn.connect_via_ble,
            ),
          ]);
        }
        return _buildInstructionToolTip([
          t.wallet_connect_screen.guide_bitbox02.init.step1,
          t.wallet_connect_screen.guide_bitbox02.init.step2,
          t.wallet_connect_screen.guide_bitbox02.init.step3(
            btn: t.wallet_connect_screen.guide_bitbox02.btn.connect_via_usb,
          ),
        ]);
      case BitBox02ConnectStep.pairing:
        return _buildProgressCard(t.wallet_connect_screen.guide_bitbox02.connecting.title, [
          t.wallet_connect_screen.guide_bitbox02.connecting.step1,
          t.wallet_connect_screen.guide_bitbox02.connecting.step2,
        ]);
      case BitBox02ConnectStep.paired:
        return _buildSuccessCard(vm);
      case BitBox02ConnectStep.error:
        return _buildErrorCard(vm);
    }
  }

  Widget _buildInstructionToolTip(List<String> steps) {
    return WalletConnectInstructionToolTip(steps: steps);
  }

  Widget _buildProgressCard(String title, List<String> steps) {
    return WalletConnectProgressCard(title: title, steps: steps);
  }

  Widget _buildSuccessCard(BitBox02ConnectViewModel vm) {
    final hasXpub = vm.xpub.isNotEmpty;
    final isMismatch = widget.psbtBase64 != null && hasXpub && _isWalletMismatch(vm);

    if (isMismatch) {
      final matchedWalletName = context.read<WalletProvider>().findWalletNameByXpub(vm.xpub);
      return WalletConnectMismatchCard(
        title: t.bitbox02_sign_screen.wrong_wallet_title,
        description: t.bitbox02_sign_screen.device_mismatch,
        footerText:
            matchedWalletName != null
                ? t.bitbox02_sign_screen.device_mismatch_other_wallet(wallet_name: matchedWalletName)
                : null,
        child: Column(
          children: [
            WalletConnectSectionLabel(label: t.wallet_connect_screen.guide_bitbox02.paired.master_fingerprint),
            FingerprintCompareCard(
              expectedFingerprint: widget.walletFingerprint ?? '',
              connectedFingerprint: vm.fingerprint,
            ),
            CoconutLayout.spacing_400h,
            WalletConnectSectionLabel(label: t.bitbox02_sign_screen.connected_wallet_label),
            HardwareWalletInfoCard(
              deviceName: vm.deviceName,
              fingerprint: vm.fingerprint,
              xpub: vm.xpub,
              deviceNameLabel: t.wallet_connect_screen.guide_bitbox02.paired.device_name,
              fingerprintLabel: t.wallet_connect_screen.guide_bitbox02.paired.master_fingerprint,
              derivationPathLabel: t.wallet_connect_screen.guide_bitbox02.paired.derivation_path,
              xpubLabel: t.wallet_connect_screen.guide_bitbox02.paired.xpub,
            ),
          ],
        ),
      );
    }

    return WalletConnectSuccessCard(
      title: t.wallet_connect_screen.guide_bitbox02.paired.title,
      child:
          hasXpub
              ? HardwareWalletInfoCard(
                deviceName: vm.deviceName,
                fingerprint: vm.fingerprint,
                xpub: vm.xpub,
                deviceNameLabel: t.wallet_connect_screen.guide_bitbox02.paired.device_name,
                fingerprintLabel: t.wallet_connect_screen.guide_bitbox02.paired.master_fingerprint,
                derivationPathLabel: t.wallet_connect_screen.guide_bitbox02.paired.derivation_path,
                xpubLabel: t.wallet_connect_screen.guide_bitbox02.paired.xpub,
              )
              : const WalletConnectWalletInfoSkeleton(),
    );
  }

  bool _isWalletMismatch(BitBox02ConnectViewModel vm) {
    final isSignFlow = widget.psbtBase64 != null;
    final isPaired = vm.step == BitBox02ConnectStep.paired;
    final hasXpub = vm.xpub.isNotEmpty;
    if (!isSignFlow || !isPaired || !hasXpub) return false;

    final wp = context.read<WalletProvider>();
    final matchedName = wp.findWalletNameByXpub(vm.xpub);
    return matchedName == null || matchedName != (widget.walletName ?? '');
  }

  Widget _buildErrorCard(BitBox02ConnectViewModel vm) {
    return WalletConnectErrorCard(
      title: t.wallet_connect_screen.guide_bitbox02.error.title,
      description:
          vm.errorDescription ??
          (Platform.isIOS
              ? t.wallet_connect_screen.guide_bitbox02.error.ble_description
              : t.wallet_connect_screen.guide_bitbox02.error.description),
      errorMessage: vm.errorMessage,
      steps: vm.errorSteps,
    );
  }

  Widget _buildPrimaryActionButton(BitBox02ConnectViewModel vm) {
    final bool isRetry = vm.step == BitBox02ConnectStep.error;
    final bool hasXpub = vm.xpub.isNotEmpty;
    final bool isPaired = vm.step == BitBox02ConnectStep.paired;
    final bool isSignFlow = widget.psbtBase64 != null;
    final bool isMismatch = _isWalletMismatch(vm);

    String buttonText;
    VoidCallback onPressed;

    if (isSignFlow && isPaired && isMismatch) {
      return FixedBottomButton(
        onButtonClicked: () {
          vm.reset();
          vm.connect(transport: vm.transport);
        },
        text: t.bitbox02_sign_screen.btn.connect_other_bitbox02,
        isActive: !_isAddingWallet && !vm.isConnecting,
      );
    } else if (isSignFlow && isPaired) {
      buttonText = t.wallet_connect_screen.guide_bitbox02.btn.start_signing;
      onPressed = () {
        // Dismiss the bottom sheet first, then push the sign screen on the main navigator.
        Navigator.pop(context);
        Navigator.pushNamed(
          context,
          '/bitbox02-sign',
          arguments: {
            'psbtBase64': widget.psbtBase64,
            'walletName': widget.walletName ?? '',
            'walletFingerprint': widget.walletFingerprint ?? '',
            'isFromSendFlow': true,
            'transport': BitBox02Transport.resolveForSign(),
          },
        );
      };
    } else if (!isSignFlow && isPaired && hasXpub) {
      buttonText = t.wallet_connect_screen.guide_bitbox02.btn.add_wallet;
      onPressed = () => _onAddWalletPressed(vm);
    } else if (isRetry) {
      buttonText = t.wallet_connect_screen.guide_bitbox02.btn.retry;
      onPressed = () => vm.connect(transport: vm.transport);
    } else if (Platform.isIOS) {
      buttonText = t.wallet_connect_screen.guide_bitbox02.btn.connect_via_ble;
      onPressed = () => vm.connect(transport: 'ble');
    } else {
      buttonText = t.wallet_connect_screen.guide_bitbox02.btn.connect_via_usb;
      onPressed = () => vm.connect(transport: 'usb');
    }

    return FixedBottomButton(
      onButtonClicked: onPressed,
      text: buttonText,
      isActive: !_isAddingWallet && !vm.isConnecting,
    );
  }
}
