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
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/connected/bitbox02_connect_viewmodel.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_transport.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/loading/loading_indicator.dart';
import 'package:coconut_wallet/widgets/common/overlays/coconut_loading_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

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

    String message;
    switch (result.result) {
      case WalletSyncResult.existingWalletUpdateImpossible:
        message = 'This wallet is already added.';
        break;
      case WalletSyncResult.existingName:
        message = 'A wallet with the same name already exists.';
        break;
      default:
        message = 'Failed to import wallet.';
    }

    showDialog(
      context: context,
      builder:
          (context) => CoconutPopup(
            languageCode: context.read<PreferenceProvider>().language,
            title: 'Import Failed',
            description: message,
            onTapRight: () => Navigator.pop(context),
            rightButtonText: 'OK',
          ),
    );
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
          style: CoconutTypography.body2_14,
          children:
              steps.asMap().entries.expand((e) {
                final isLast = e.key == steps.length - 1;
                return [
                  TextSpan(text: '${e.key + 1}. ', style: TextStyle(color: context.coconutColors.primaryText)),
                  TextSpan(text: e.value, style: TextStyle(color: context.coconutColors.primaryText)),
                  if (!isLast) const TextSpan(text: '\n'),
                ];
              }).toList(),
        ),
      ),
    );
  }

  Widget _buildProgressCard(String title, List<String> steps) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: InlineLoadingIndicator(padding: EdgeInsets.zero, color: context.coconutColors.primary, radius: 20),
          ),
          CoconutLayout.spacing_400h,
          Text(
            title,
            style: CoconutTypography.body2_14.setColor(context.coconutColors.primary),
            textAlign: TextAlign.center,
          ),
          CoconutLayout.spacing_400h,
          _buildInstructionToolTip(steps),
        ],
      ),
    );
  }

  Widget _buildSuccessCard(BitBox02ConnectViewModel vm) {
    final hasXpub = vm.xpub.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SvgPicture.asset(
            CommonFormIconPath.circleCheck,
            colorFilter: ColorFilter.mode(context.coconutColors.accentForeground, BlendMode.srcIn),
            height: 48,
            width: 48,
          ),
          CoconutLayout.spacing_200h,
          Text(
            t.wallet_connect_screen.guide_bitbox02.paired.title,
            style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
            textAlign: TextAlign.center,
          ),
          CoconutLayout.spacing_200h,
          CoconutLayout.spacing_600h,
          hasXpub ? _buildWalletInfoCard(vm) : _buildWalletInfoSkeleton(),
        ],
      ),
    );
  }

  Widget _buildWalletInfoCard(BitBox02ConnectViewModel vm) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: context.coconutColors.surface,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfo(
            label: t.wallet_connect_screen.guide_bitbox02.paired.master_fingerprint,
            value: vm.fingerprint.toUpperCase(),
          ),
          CoconutLayout.spacing_300h,
          _buildInfo(
            label: t.wallet_connect_screen.guide_bitbox02.paired.derivation_path,
            value: NetworkType.currentNetworkType.isTestnet ? "m/84'/1'/0'" : "m/84'/0'/0'",
          ),
          CoconutLayout.spacing_300h,
          _buildInfo(
            label: t.wallet_connect_screen.guide_bitbox02.paired.xpub,
            value: vm.xpub,
            direction: Axis.vertical,
          ),
        ],
      ),
    );
  }

  Widget _buildWalletInfoSkeleton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: context.coconutColors.surface,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRowSkeleton(labelWidth: 100, valueWidth: 90),
          CoconutLayout.spacing_300h,
          _buildInfoRowSkeleton(labelWidth: 90, valueWidth: 70),
          CoconutLayout.spacing_300h,
          _buildInfoColumnSkeleton(labelWidth: 120),
        ],
      ),
    );
  }

  Widget _buildSkeletonBox({required double width, double height = 12}) {
    return Shimmer.fromColors(
      baseColor: context.coconutColors.surfaceSkeletonBase,
      highlightColor: context.coconutColors.surfaceSkeletonHighlight,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.coconutColors.surfaceSkeletonBase,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _buildInfoRowSkeleton({required double labelWidth, required double valueWidth}) {
    return Row(children: [_buildSkeletonBox(width: labelWidth), const Spacer(), _buildSkeletonBox(width: valueWidth)]);
  }

  Widget _buildInfoColumnSkeleton({required double labelWidth}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSkeletonBox(width: labelWidth),
        CoconutLayout.spacing_100h,
        _buildSkeletonBox(width: double.infinity, height: 14),
      ],
    );
  }

  Widget _buildInfo({required String label, required String value, Axis direction = Axis.horizontal}) {
    TextStyle labelStyle = CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText);
    TextStyle valueStyle = CoconutTypography.body2_14_NumberBold.setColor(context.coconutColors.primaryText);

    if (direction == Axis.horizontal) {
      return Row(children: [Text(label, style: labelStyle), const Spacer(), Text(value, style: valueStyle)]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(label, style: labelStyle), CoconutLayout.spacing_100h, Text(value, style: valueStyle)],
    );
  }

  Widget _buildErrorCard(BitBox02ConnectViewModel vm) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),

      child: Column(
        children: [
          SvgPicture.asset(
            CommonStateIconPath.circleWarning,
            colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
            height: 48,
            width: 48,
          ),
          CoconutLayout.spacing_200h,
          Text(
            t.wallet_connect_screen.guide_bitbox02.error.title,
            style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.danger),
          ),
          CoconutLayout.spacing_400h,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: context.coconutColors.surface,
              borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
            ),
            child: Column(
              children: [
                Text(
                  Platform.isIOS
                      ? t.wallet_connect_screen.guide_bitbox02.error.ble_description
                      : t.wallet_connect_screen.guide_bitbox02.error.description,
                  style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                  textAlign: TextAlign.center,
                ),
                CoconutLayout.spacing_200h,
                Text(
                  vm.errorMessage ?? 'Unknown error',
                  style: CoconutTypography.body3_12_Number.setColor(context.coconutColors.secondaryText),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
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
