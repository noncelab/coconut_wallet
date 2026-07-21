import 'dart:io' show Platform;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/connected/bitbox02_connect_viewmodel.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_transport.dart';
import 'package:coconut_wallet/utils/wallet_sync_result_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/overlays/coconut_loading_overlay.dart';
import 'package:coconut_wallet/widgets/wallet_connect_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BitBox02ConnectScreen extends StatefulWidget {
  final WalletImportSource importSource;

  /// When non-null, the screen is in "sign flow" mode:
  /// after pairing, the button navigates to /bitbox02-sign instead of adding the wallet.
  final String? psbtBase64;
  final String? walletName;
  final String? walletFingerprint;

  const BitBox02ConnectScreen({
    super.key,
    required this.importSource,
    this.psbtBase64,
    this.walletName,
    this.walletFingerprint,
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
        '/wallet-detail',
        arguments: {'id': result.walletId, 'entryPoint': kEntryPointWalletHome},
      );
      return;
    }

    setState(() => _isAddingWallet = false);

    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
    showWalletSyncResultErrorDialog(context, result, walletProvider);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: context.coconutColors.background,
        appBar: CoconutAppBar.build(title: widget.importSource.displayName, context: context, isBottom: true),
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
                        vm.step == BitBox02ConnectStep.paired)
                      Stack(alignment: Alignment.center, children: [_buildMainButton(vm)]),
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
    return WalletConnectSuccessCard(
      title: t.wallet_connect_screen.guide_bitbox02.paired.title,
      child: hasXpub ? _buildWalletInfoCard(vm) : const WalletConnectWalletInfoSkeleton(),
    );
  }

  Widget _buildWalletInfoCard(BitBox02ConnectViewModel vm) {
    return WalletConnectWalletInfoCard(
      children: [
        WalletConnectInfoRow(
          label: t.wallet_connect_screen.guide_bitbox02.paired.master_fingerprint,
          value: vm.fingerprint.toUpperCase(),
        ),
        CoconutLayout.spacing_300h,
        WalletConnectInfoRow(
          label: t.wallet_connect_screen.guide_bitbox02.paired.derivation_path,
          value: NetworkType.currentNetworkType.isTestnet ? "m/84'/1'/0'" : "m/84'/0'/0'",
        ),
        CoconutLayout.spacing_300h,
        WalletConnectInfoRow(
          label: t.wallet_connect_screen.guide_bitbox02.paired.xpub,
          value: vm.xpub,
          direction: Axis.vertical,
        ),
      ],
    );
  }

  Widget _buildErrorCard(BitBox02ConnectViewModel vm) {
    return WalletConnectErrorCard(
      title: t.wallet_connect_screen.guide_bitbox02.error.title,
      description:
          Platform.isIOS
              ? t.wallet_connect_screen.guide_bitbox02.error.ble_description
              : t.wallet_connect_screen.guide_bitbox02.error.description,
      errorMessage: vm.errorMessage,
    );
  }

  Widget _buildMainButton(BitBox02ConnectViewModel vm) {
    final bool isRetry = vm.step == BitBox02ConnectStep.error;
    final bool hasXpub = vm.xpub.isNotEmpty;
    final bool isPaired = vm.step == BitBox02ConnectStep.paired;
    final bool isSignFlow = widget.psbtBase64 != null;

    String buttonText;
    VoidCallback onPressed;

    if (isSignFlow && isPaired) {
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
