import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'dart:io';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_add/connected/trezor_connect_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/utils/wallet_sync_result_util.dart';
import 'package:coconut_wallet/widgets/button/key_button.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/overlays/coconut_loading_overlay.dart';
import 'package:coconut_wallet/utils/app_settings_util.dart';
import 'package:coconut_wallet/widgets/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class TrezorConnectScreen extends StatefulWidget {
  const TrezorConnectScreen({super.key});

  @override
  State<TrezorConnectScreen> createState() => _TrezorConnectScreenState();
}

class _TrezorConnectScreenState extends State<TrezorConnectScreen> {
  late TrezorConnectViewModel _viewModel;
  bool _isAddingWallet = false;
  bool _isVerifyingPairingCode = false;
  TrezorConnectStep? _lastStep;

  static const int _codeLength = 6;
  static const List<String> _keypadKeys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '<'];
  String _pairingCode = '';

  @override
  void initState() {
    super.initState();
    _viewModel = TrezorConnectViewModel(Provider.of<WalletProvider>(context, listen: false));
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

  Future<void> _onAddWalletPressed(TrezorConnectViewModel vm) async {
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

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: context.coconutColors.background,
        appBar: CoconutAppBar.build(title: WalletImportSource.trezor.displayName, context: context, isBottom: true),
        body: Consumer<TrezorConnectViewModel>(
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
                    if (vm.step == TrezorConnectStep.idle ||
                        vm.step == TrezorConnectStep.error ||
                        (vm.step == TrezorConnectStep.paired && vm.xpub.isNotEmpty))
                      Stack(alignment: Alignment.center, children: [_buildMainButton(vm)]),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusSection(TrezorConnectViewModel vm) {
    switch (vm.step) {
      case TrezorConnectStep.idle:
        return _buildInstructionToolTip([
          t.wallet_connect_screen.guide_trezor.init.ble_step1,
          [
            TextSpan(
              text: t.wallet_connect_screen.guide_trezor.init.ble_step2_prefix,
              style: TextStyle(color: context.coconutColors.primaryText),
            ),
            TextSpan(
              text: t.wallet_connect_screen.guide_trezor.init.ble_step2_bold,
              style: TextStyle(color: context.coconutColors.primaryText, fontWeight: FontWeight.bold),
            ),
            TextSpan(
              text: t.wallet_connect_screen.guide_trezor.init.ble_step2_suffix,
              style: TextStyle(color: context.coconutColors.primaryText),
            ),
          ],
          t.wallet_connect_screen.guide_trezor.init.ble_step3(
            btn: t.wallet_connect_screen.guide_trezor.btn.connect_via_ble,
          ),
        ], notice: t.wallet_connect_screen.guide_trezor.init.notice);
      case TrezorConnectStep.connecting:
        return _buildProgressCard(t.wallet_connect_screen.guide_trezor.connecting.title, [
          t.wallet_connect_screen.guide_trezor.connecting.step1,
          t.wallet_connect_screen.guide_trezor.connecting.step2,
          t.wallet_connect_screen.guide_trezor.connecting.step3,
          t.wallet_connect_screen.guide_trezor.connecting.step4,
        ]);
      case TrezorConnectStep.pairing:
        return _buildPairingCard(vm);
      case TrezorConnectStep.paired:
        return _buildSuccessCard(vm);
      case TrezorConnectStep.error:
        return _buildErrorCard(vm, steps: vm.peerRemovedPairingSteps);
    }
  }

  Widget _buildInstructionToolTip(List<Object> steps, {String? notice}) {
    return CoconutToolTip(
      backgroundColor: context.coconutColors.surface,
      borderColor: context.coconutColors.surface,
      icon: SvgPicture.asset(
        'assets/svg/circle-info.svg',
        width: 20,
        colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
      ),
      tooltipType: CoconutTooltipType.fixed,
      richText: RichText(
        text: TextSpan(
          style: CoconutTypography.body2_14,
          children: [
            if (notice != null) ...[
              TextSpan(
                text: notice,
                style: TextStyle(color: context.coconutColors.primaryText, fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: '\n\n'),
            ],
            ...steps.asMap().entries.expand((e) {
              final isLast = e.key == steps.length - 1;
              final stepSpans =
                  e.value is String
                      ? [TextSpan(text: e.value as String, style: TextStyle(color: context.coconutColors.primaryText))]
                      : e.value as List<TextSpan>;
              return [
                TextSpan(text: '${e.key + 1}. ', style: TextStyle(color: context.coconutColors.primaryText)),
                ...stepSpans,
                if (!isLast) const TextSpan(text: '\n'),
              ];
            }),
          ],
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
            child: CircularProgressIndicator(color: context.coconutColors.primary, strokeWidth: 3),
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

  Widget _buildSuccessCard(TrezorConnectViewModel vm) {
    final hasXpub = vm.xpub.isNotEmpty;
    final hasSilentError = !hasXpub && vm.errorMessage != null;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SvgPicture.asset(
            'assets/svg/circle-check.svg',
            colorFilter: ColorFilter.mode(context.coconutColors.textHighlight, BlendMode.srcIn),
            height: 48,
            width: 48,
          ),
          CoconutLayout.spacing_200h,
          Text(
            t.wallet_connect_screen.guide_trezor.paired.title,
            style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
            textAlign: TextAlign.center,
          ),
          CoconutLayout.spacing_200h,
          CoconutLayout.spacing_600h,
          if (hasXpub)
            _buildWalletInfoCard(vm)
          else if (hasSilentError)
            _buildXPubRetryCard(vm)
          else
            _buildWalletInfoSkeleton(),
        ],
      ),
    );
  }

  Widget _buildXPubRetryCard(TrezorConnectViewModel vm) {
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

  Widget _buildWalletInfoCard(TrezorConnectViewModel vm) {
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
          if (vm.deviceLabel.isNotEmpty) ...[
            _buildInfo(label: t.wallet_connect_screen.guide_trezor.paired.device_name, value: vm.deviceLabel),
            CoconutLayout.spacing_300h,
          ],
          _buildInfo(
            label: t.wallet_connect_screen.guide_trezor.paired.master_fingerprint,
            value: vm.fingerprint.toUpperCase(),
          ),
          CoconutLayout.spacing_300h,
          _buildInfo(
            label: t.wallet_connect_screen.guide_trezor.paired.derivation_path,
            value: NetworkType.currentNetworkType.isTestnet ? "m/84'/1'/0'" : "m/84'/0'/0'",
          ),
          CoconutLayout.spacing_300h,
          _buildInfo(label: t.wallet_connect_screen.guide_trezor.paired.xpub, value: vm.xpub, direction: Axis.vertical),
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
    final labelStyle = CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText);
    final valueStyle = CoconutTypography.body2_14_NumberBold.setColor(context.coconutColors.primaryText);

    if (direction == Axis.horizontal) {
      return Row(children: [Text(label, style: labelStyle), const Spacer(), Text(value, style: valueStyle)]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(label, style: labelStyle), CoconutLayout.spacing_100h, Text(value, style: valueStyle)],
    );
  }

  Widget _buildErrorCard(TrezorConnectViewModel vm, {List<String>? steps}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SvgPicture.asset(
            'assets/svg/circle-warning.svg',
            colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
            height: 48,
            width: 48,
          ),
          CoconutLayout.spacing_200h,
          Text(
            t.wallet_connect_screen.guide_trezor.error.title,
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
                  vm.errorDescription ?? t.wallet_connect_screen.guide_trezor.error.ble_description,
                  style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
                  textAlign: TextAlign.center,
                ),
                CoconutLayout.spacing_200h,
                Text(
                  vm.errorMessage ?? 'Unknown error',
                  style: CoconutTypography.body2_14_Number.setColor(context.coconutColors.secondaryText),
                  textAlign: TextAlign.center,
                ),
                if (steps != null && steps.isNotEmpty) ...[
                  CoconutLayout.spacing_300h,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children:
                        steps.asMap().entries.map((e) {
                          final isLast = e.key == steps.length - 1;
                          return Padding(
                            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${e.key + 1}. ',
                                    style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                                  ),
                                  TextSpan(
                                    text: e.value,
                                    style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.left,
                            ),
                          );
                        }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPairingCard(TrezorConnectViewModel vm) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int index = 0; index < _codeLength; index++) ...[
                if (index > 0) SizedBox(width: index == 3 ? 12 : 4),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 40),
                    child: _DigitBox(
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
            Padding(
              padding: const EdgeInsets.only(top: 12),
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
          else
            Visibility(
              visible: vm.pairingErrorMessage != null,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  vm.pairingErrorMessage ?? '',
                  style: CoconutTypography.body3_12.setColor(context.coconutColors.danger),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 3,
            childAspectRatio: MediaQuery.of(context).size.width > 600 ? 2.5 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children:
                _keypadKeys.map((key) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: KeyButton(keyValue: key, onKeyTap: _isVerifyingPairingCode ? (_) {} : _onPairingKeyTap),
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMainButton(TrezorConnectViewModel vm) {
    if (vm.step == TrezorConnectStep.pairing) return const SizedBox.shrink();

    final bool isRetry = vm.step == TrezorConnectStep.error;
    final bool hasXpub = vm.xpub.isNotEmpty;
    final bool isPaired = vm.step == TrezorConnectStep.paired;

    String buttonText;
    VoidCallback onPressed;

    if (isPaired && hasXpub) {
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

class _DigitBox extends StatelessWidget {
  final String digit;
  final bool hasError;
  final bool isVerifying;

  const _DigitBox({required this.digit, required this.hasError, this.isVerifying = false});

  @override
  Widget build(BuildContext context) {
    final filled = digit.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: context.coconutColors.inputPlaceholder,
          border: hasError && filled ? Border.all(color: context.coconutColors.danger, width: 1.5) : null,
        ),
        alignment: Alignment.center,
        child:
            filled
                ? Text(
                  digit,
                  style: CoconutTypography.heading3_21_Number.copyWith(
                    fontWeight: FontWeight.w700,
                    color:
                        hasError
                            ? context.coconutColors.danger
                            : isVerifying
                            ? context.coconutColors.mutedText
                            : context.coconutColors.primaryText,
                  ),
                )
                : null,
      ),
    );
  }
}
