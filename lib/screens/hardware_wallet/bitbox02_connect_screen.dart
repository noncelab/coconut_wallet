import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/providers/view_model/hardware_wallet/bitbox02_connect_viewmodel.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_transport.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Color _darker(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
}

class BitBox02ConnectScreen extends StatefulWidget {
  final WalletImportSource importSource;

  const BitBox02ConnectScreen({super.key, required this.importSource});

  @override
  State<BitBox02ConnectScreen> createState() => _BitBox02ConnectScreenState();
}

class _BitBox02ConnectScreenState extends State<BitBox02ConnectScreen> {
  late BitBox02ConnectViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = BitBox02ConnectViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: CoconutColors.black,
        appBar: AppBar(
          title: Text(widget.importSource.displayName),
          backgroundColor: CoconutColors.black,
          foregroundColor: CoconutColors.white,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Consumer<BitBox02ConnectViewModel>(
                builder: (context, vm, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Mock', style: CoconutTypography.body3_12.setColor(CoconutColors.gray400)),
                    CoconutLayout.spacing_100w,
                    SizedBox(
                      height: 24,
                      child: Switch(
                        value: vm.mockMode,
                        onChanged: (v) => vm.setMockMode(v),
                        activeColor: CoconutColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: Consumer<BitBox02ConnectViewModel>(
          builder: (context, vm, _) {
            return SafeArea(
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
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 16,
                      child: _buildMainButton(vm),
                    ),
                ],
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
        return _buildInstructionCard([
          '1. Connect BitBox02 Nova via USB',
          '2. Unlock the device with your password',
          '3. Tap "Connect via USB" below',
        ]);
      case BitBox02ConnectStep.connecting:
        return _buildProgressCard('Connecting to BitBox02...');
      case BitBox02ConnectStep.pairing:
        return _buildProgressCard('Initializing...\nCheck your BitBox02 screen.');
      case BitBox02ConnectStep.retrievingXPub:
        return _buildProgressCard('Retrieving extended public key...');
      case BitBox02ConnectStep.paired:
        return _buildSuccessCard(vm);
      case BitBox02ConnectStep.error:
        return _buildErrorCard(vm);
      case BitBox02ConnectStep.scanning:
        return _buildProgressCard('Scanning...');
    }
  }

  Widget _buildInstructionCard(List<String> steps) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CoconutColors.gray900,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: steps.asMap().entries.map((e) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${e.key + 1}. ',
                  style: CoconutTypography.body2_14.setColor(CoconutColors.primary),
                ),
                Expanded(
                  child: Text(e.value, style: CoconutTypography.body2_14),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildProgressCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CoconutColors.gray900,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 40, height: 40,
            child: CircularProgressIndicator(color: CoconutColors.primary, strokeWidth: 3),
          ),
          CoconutLayout.spacing_400h,
          Text(message, style: CoconutTypography.body2_14, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildSuccessCard(BitBox02ConnectViewModel vm) {
    final hasXpub = vm.xpub.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CoconutColors.gray900,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
        border: Border.all(color: CoconutColors.green.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_outline, color: CoconutColors.green, size: 48),
          CoconutLayout.spacing_300h,
          Text('Connected', style: CoconutTypography.heading3_21_Bold.setColor(CoconutColors.green)),
          CoconutLayout.spacing_200h,
          Text('BitBox02 is paired and ready.', style: CoconutTypography.body2_14, textAlign: TextAlign.center),
          if (vm.device != null) ...[
            CoconutLayout.spacing_400h,
            Text('Device ID: ${vm.device!.id}', style: CoconutTypography.body3_12.setColor(CoconutColors.gray400)),
          ],
          if (hasXpub) ...[
            CoconutLayout.spacing_600h,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CoconutColors.black,
                borderRadius: BorderRadius.circular(CoconutStyles.radius_100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Master Fingerprint', style: CoconutTypography.body3_12.setColor(CoconutColors.gray400)),
                  CoconutLayout.spacing_100h,
                  Text(vm.fingerprint, style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.cyan)),
                  CoconutLayout.spacing_300h,
                  Text('Derivation Path', style: CoconutTypography.body3_12.setColor(CoconutColors.gray400)),
                  CoconutLayout.spacing_100h,
                  Text(
                    NetworkType.currentNetworkType.isTestnet ? "m/84'/1'/0'" : "m/84'/0'/0'",
                    style: CoconutTypography.body2_14_Bold,
                  ),
                  CoconutLayout.spacing_300h,
                  Text('Extended Public Key', style: CoconutTypography.body3_12.setColor(CoconutColors.gray400)),
                  CoconutLayout.spacing_100h,
                  Text(
                    vm.xpub,
                    style: CoconutTypography.body3_12.setColor(CoconutColors.gray300),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorCard(BitBox02ConnectViewModel vm) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: CoconutColors.gray900,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
        border: Border.all(color: CoconutColors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: CoconutColors.red, size: 48),
          CoconutLayout.spacing_300h,
          Text('Connection Failed', style: CoconutTypography.heading3_21_Bold.setColor(CoconutColors.red)),
          CoconutLayout.spacing_200h,
          Text(vm.errorMessage ?? 'Unknown error', style: CoconutTypography.body2_14, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildMainButton(BitBox02ConnectViewModel vm) {
    final bool isRetry = vm.step == BitBox02ConnectStep.error;
    final bool hasXpub = vm.xpub.isNotEmpty;
    final bool isPaired = vm.step == BitBox02ConnectStep.paired;

    String buttonText;
    VoidCallback onPressed;

    if (isPaired && !hasXpub) {
      buttonText = 'Continue';
      onPressed = () => vm.retrieveXPub();
    } else if (isPaired && hasXpub) {
      buttonText = 'Import Wallet';
      onPressed = () {
        Navigator.pop(context, {
          'xpub': vm.xpub,
          'fingerprint': vm.fingerprint,
          'device': vm.device,
        });
      };
    } else if (isRetry) {
      buttonText = 'Retry';
      onPressed = () => vm.connect(transport: vm.transport);
    } else {
      buttonText = 'Connect via USB';
      onPressed = () => vm.connect(transport: 'usb');
    }

    final bool showSeedButtons = isPaired && !hasXpub;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showSeedButtons) ...[
          ShrinkAnimationButton(
            onPressed: () => vm.restoreWallet(),
            defaultColor: CoconutColors.gray700,
            pressedColor: CoconutColors.gray600,
            child: Container(
              height: 40,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
              child: Center(
                child: Text(
                  'Restore from Mnemonic',
                  style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                ),
              ),
            ),
          ),
          CoconutLayout.spacing_200h,
          ShrinkAnimationButton(
            onPressed: () => vm.createWallet(),
            defaultColor: CoconutColors.gray700,
            pressedColor: CoconutColors.gray600,
            child: Container(
              height: 40,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
              child: Center(
                child: Text(
                  'Create New Wallet',
                  style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                ),
              ),
            ),
          ),
          CoconutLayout.spacing_200h,
        ],
        ShrinkAnimationButton(
          onPressed: onPressed,
          defaultColor: (isPaired && hasXpub) ? CoconutColors.primary : CoconutColors.primary,
          pressedColor: _darker(CoconutColors.primary),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                buttonText,
                style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.black),
              ),
            ),
          ),
        ),
        if (vm.step == BitBox02ConnectStep.idle) ...[
          CoconutLayout.spacing_200h,
          if (BitBox02Transport.canUseTcp)
            ShrinkAnimationButton(
            onPressed: () {
              vm.connect(transport: 'tcp', host: '10.0.2.2', port: 15423);
            },
            defaultColor: CoconutColors.gray800,
            pressedColor: CoconutColors.gray700,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Connect via Simulator (TCP)',
                  style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                ),
              ),
            ),
          ),
        ],
        if (isRetry) ...[
          CoconutLayout.spacing_200h,
          ShrinkAnimationButton(
            onPressed: () {
              vm.reset();
            },
            defaultColor: CoconutColors.gray900,
            pressedColor: CoconutColors.gray800,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Cancel',
                  style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                ),
              ),
            ),
          ),
        ],
        if (isPaired && hasXpub) ...[
          CoconutLayout.spacing_200h,
          ShrinkAnimationButton(
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/bitbox02-sign',
                arguments: {
                  'psbtBase64': 'cHNidP8BAP1aAQI...',
                  'walletName': 'BitBox02 Test',
                  'transport': vm.device?.transport ?? 'usb',
                },
              );
            },
            defaultColor: CoconutColors.gray800,
            pressedColor: CoconutColors.gray700,
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'Sign Test Transaction',
                  style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
