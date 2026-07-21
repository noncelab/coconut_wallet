import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/connected/trezor_sign_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/trezor_ble_connect_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/trezor_usb_connect_screen.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_tween_button.dart';
import 'package:coconut_wallet/widgets/button/key_button.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/trezor_usb_prompt.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class TrezorSignScreen extends StatefulWidget {
  final String psbtBase64;
  final String walletName;
  final String walletFingerprint;
  final bool isFromSendFlow;
  final TrezorTransport transport;

  const TrezorSignScreen({
    super.key,
    required this.psbtBase64,
    required this.walletName,
    this.walletFingerprint = '',
    this.isFromSendFlow = false,
    this.transport = TrezorTransport.ble,
  });

  @override
  State<TrezorSignScreen> createState() => _TrezorSignScreenState();
}

class _TrezorSignScreenState extends State<TrezorSignScreen> with SingleTickerProviderStateMixin {
  late TrezorSignViewModel _viewModel;
  late BitcoinUnit _currentUnit;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const int _codeLength = 6;
  static const List<String> _keypadKeys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '<'];
  String _pairingCode = '';
  bool _isVerifyingPairingCode = false;
  TrezorSignStep? _lastStep;
  Future<String?> Function()? _pinHandler;
  Future<TrezorPassphraseResponse> Function(bool)? _passphraseHandler;

  @override
  void initState() {
    super.initState();
    _currentUnit = context.read<PreferenceProvider>().currentUnit;
    _viewModel = TrezorSignViewModel(
      psbtBase64: widget.psbtBase64,
      walletName: widget.walletName,
      walletFingerprint: widget.walletFingerprint,
      walletProvider: context.read<WalletProvider>(),
      transport: widget.transport,
    );
    if (widget.transport == TrezorTransport.usb) {
      _pinHandler = _viewModel.requestPin;
      _passphraseHandler = (onDevice) => TrezorUsbPrompt.requestPassphrase(context, onDevice);
      TrezorDevice.onPinRequested = _pinHandler;
      TrezorDevice.onPassphraseRequested = _passphraseHandler;
    }
    _viewModel.addListener(_onStateChanged);

    _pulseController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this)
      ..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewModel.probeWalletMismatch();
    });
  }

  bool _lastIsWalletMismatch = false;

  Future<void> _onStateChanged() async {
    final step = _viewModel.step;
    final mismatchChanged = _lastIsWalletMismatch != _viewModel.isWalletMismatch;
    if (_lastStep != step || mismatchChanged) {
      _lastStep = step;
      _lastIsWalletMismatch = _viewModel.isWalletMismatch;
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
    if (_viewModel.step == TrezorSignStep.done) {
      _viewModel.removeListener(_onStateChanged);
      await Future.delayed(const Duration(seconds: 3));
      if (!mounted) return;
      if (widget.isFromSendFlow) {
        final sendInfoProvider = context.read<SendInfoProvider>();
        sendInfoProvider.setSignedResult(_viewModel.signedPsbt);
        Navigator.pushReplacementNamed(context, '/broadcasting');
      } else {
        Navigator.pop(context, {'signedPsbt': _viewModel.signedPsbt});
      }
    }
  }

  @override
  void dispose() {
    if (TrezorDevice.onPinRequested == _pinHandler) TrezorDevice.onPinRequested = null;
    if (TrezorDevice.onPassphraseRequested == _passphraseHandler) TrezorDevice.onPassphraseRequested = null;
    _pulseController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: context.coconutColors.background,
        appBar: CoconutAppBar.build(title: widget.walletName, context: context),
        body: Consumer<TrezorSignViewModel>(
          builder: (context, vm, _) {
            return SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                        child: Column(
                          children: [
                            _buildTransactionSummaryCard(),
                            CoconutLayout.spacing_400h,
                            _buildStatusSection(vm),
                          ],
                        ),
                      ),
                    ),
                    if (vm.step != TrezorSignStep.signing &&
                        vm.step != TrezorSignStep.done &&
                        vm.step != TrezorSignStep.pairing &&
                        vm.step != TrezorSignStep.pinEntry)
                      Stack(alignment: Alignment.center, children: [_buildBottomButton(vm)]),
                    if (vm.step == TrezorSignStep.pinEntry)
                      Stack(alignment: Alignment.center, children: [_buildPinButtons(vm)]),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTransactionSummaryCard() {
    final summary = _parsePsbtSummary();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            t.trezor_sign_screen.tx_card.title,
            style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
            textAlign: TextAlign.left,
          ),
        ),
        CoconutLayout.spacing_300h,
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.coconutColors.surface,
            borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
          ),
          child: Column(
            children: [
              if (summary != null) ...[
                _buildDetailRow(
                  t.trezor_sign_screen.tx_card.send,
                  _currentUnit.displayBitcoinAmount(summary.amount, withUnit: true),
                ),
                CoconutLayout.spacing_300h,
                if (summary.recipientAddresses.isNotEmpty)
                  _buildDetailRow(t.trezor_sign_screen.tx_card.to, summary.recipientAddresses.join('\n')),
                CoconutLayout.spacing_300h,
                _buildDetailRow(
                  t.trezor_sign_screen.tx_card.fee,
                  _currentUnit.displayBitcoinAmount(summary.fee, withUnit: true),
                ),
                CoconutLayout.spacing_300h,
                _buildDetailRow(
                  t.trezor_sign_screen.tx_card.total_cost,
                  _currentUnit.displayBitcoinAmount(summary.amount + summary.fee, withUnit: true),
                ),
              ] else ...[
                _buildDetailRow(
                  t.trezor_sign_screen.tx_card.send,
                  _currentUnit.isPrefixSymbol ? '${_currentUnit.symbol} --' : '-- ${_currentUnit.symbol}',
                ),
                _buildDetailRow(
                  t.trezor_sign_screen.tx_card.fee,
                  _currentUnit.isPrefixSymbol ? '${_currentUnit.symbol} --' : '-- ${_currentUnit.symbol}',
                ),
              ],
            ],
          ),
        ),
        CoconutLayout.spacing_300h,
      ],
    );
  }

  _PsbtSummary? _parsePsbtSummary() {
    try {
      final psbt = Psbt.parse(widget.psbtBase64);

      int amount = (psbt.outputs).where((o) => o.isChange != true).fold<int>(0, (sum, o) => sum + (o.outAmount ?? 0));
      int fee = psbt.fee;

      final outputs = psbt.outputs;

      final addresses = outputs.where((o) => o.isChange != true).map((o) => o.outAddress).whereType<String>().toList();

      return _PsbtSummary(amount: amount, fee: fee, recipientAddresses: addresses);
    } catch (_) {
      return null;
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText)),
        ),
        Expanded(
          child: Text(
            value,
            style: CoconutTypography.body3_12_NumberBold.setColor(context.coconutColors.primaryText),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection(TrezorSignViewModel vm) {
    if (vm.step == TrezorSignStep.pairing) {
      return _buildPairingCard(vm);
    }
    if (vm.step == TrezorSignStep.pinEntry) {
      return _buildPinCard(vm);
    }

    final bool isIdle = vm.step == TrezorSignStep.idle;
    final bool isBusy = vm.step == TrezorSignStep.signing;
    final bool isDone = vm.step == TrezorSignStep.done;

    final Color stateColor;
    final Widget stateIcon;
    final String stateLabel;
    final String? detailText;

    if (isIdle) {
      final color = context.coconutColors.success;
      stateColor = color;
      stateIcon = AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (_, __) {
          final v = _pulseAnimation.value;
          return Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.4 + v * 0.6), blurRadius: 2 + v * 10, spreadRadius: v * 0.3),
              ],
            ),
          );
        },
      );
      stateLabel = t.trezor_sign_screen.state_label.idle;
      detailText = null;
    } else if (isBusy) {
      final color = context.coconutColors.warning;
      stateColor = color;
      stateIcon = SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: color, strokeWidth: 2.5));
      stateLabel = t.trezor_sign_screen.state_label.signing;
      detailText = _subStatusText(vm.subStatus);
    } else if (isDone) {
      final color = context.coconutColors.success;
      stateColor = color;
      stateIcon = SvgPicture.asset(
        'assets/svg/circle-check-outline.svg',
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        width: 16,
        height: 16,
      );
      stateLabel = t.trezor_sign_screen.done.title;
      detailText = t.trezor_sign_screen.done.description;
    } else {
      final color = context.coconutColors.danger;
      stateColor = color;
      stateIcon = SvgPicture.asset(
        'assets/svg/triangle-warning.svg',
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        width: 16,
        height: 16,
      );
      stateLabel = t.trezor_sign_screen.error_title;
      detailText = vm.errorMessage;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0),
          child: Text(
            t.trezor_sign_screen.device_status.title,
            style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
          ),
        ),
        CoconutLayout.spacing_300h,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.coconutColors.surface,
            borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (vm.fingerprint != null) ...[
                    Icon(Icons.fingerprint, size: 14, color: context.coconutColors.secondaryText),
                    CoconutLayout.spacing_100w,
                    Text(
                      vm.fingerprint!.toUpperCase(),
                      style: CoconutTypography.body3_12_Number.setColor(context.coconutColors.secondaryText),
                    ),
                    const Spacer(),
                  ],
                  stateIcon,
                  CoconutLayout.spacing_200w,
                  Text(stateLabel, style: CoconutTypography.body2_14_Bold.setColor(stateColor)),
                ],
              ),
              if (detailText != null && detailText.isNotEmpty) ...[
                CoconutLayout.spacing_400h,
                Container(height: 1, color: context.coconutColors.divider),
                CoconutLayout.spacing_400h,
                Text(detailText, style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText)),
              ],
            ],
          ),
        ),
        if (vm.isWalletMismatch) ...[CoconutLayout.spacing_400h, _buildWalletMismatchWarning(vm)],
      ],
    );
  }

  String _subStatusText(TrezorSignSubStatus subStatus) {
    switch (subStatus) {
      case TrezorSignSubStatus.waiting:
        return t.trezor_sign_screen.idle.waiting;
      case TrezorSignSubStatus.connectingDevice:
        return t.trezor_sign_screen.status.connecting_device;
      case TrezorSignSubStatus.confirmOnDevice:
        return t.trezor_sign_screen.status.confirm_on_device;
    }
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

  Widget _buildPairingCard(TrezorSignViewModel vm) {
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
                      hasError: vm.errorMessage != null,
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
              visible: vm.errorMessage != null,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  vm.errorMessage ?? '',
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

  Widget _buildWalletMismatchWarning(TrezorSignViewModel vm) {
    final message =
        vm.mismatchedWalletName != null
            ? t.trezor_sign_screen.device_mismatch_other_wallet(wallet_name: vm.mismatchedWalletName!)
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

  void _onPinKeyTap(String value) {
    vibrateExtraLight();
    _viewModel.onPinKeyTap(value);
  }

  Widget _buildPinCard(TrezorSignViewModel vm) {
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
                _keypadKeys.map((key) {
                  return Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: _buildPinKeyButton(key));
                }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPinButtons(TrezorSignViewModel vm) {
    return FixedBottomTweenButton(
      leftButtonClicked: vm.cancelPin,
      rightButtonClicked: vm.submitPin,
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

  Widget _buildBottomButton(TrezorSignViewModel vm) {
    final bool isError = vm.step == TrezorSignStep.error;
    final bool isBusy = vm.step == TrezorSignStep.signing;

    if (vm.isWalletMismatch) {
      return FixedBottomButton(
        onButtonClicked: () async {
          await vm.disconnectForReconnect();
          if (!mounted) return;
          final navigator = Navigator.of(context);
          navigator.pop();
          final isUsb = widget.transport == TrezorTransport.usb;
          await CommonBottomSheets.showCustomHeightBottomSheet(
            context: navigator.context,
            heightRatio: 0.9,
            child:
                isUsb
                    ? TrezorUsbConnectScreen(
                      psbtBase64: widget.psbtBase64,
                      walletName: widget.walletName,
                      walletFingerprint: widget.walletFingerprint,
                    )
                    : TrezorBleConnectScreen(
                      psbtBase64: widget.psbtBase64,
                      walletName: widget.walletName,
                      walletFingerprint: widget.walletFingerprint,
                    ),
          );
        },
        text: t.trezor_sign_screen.btn.connect_other_trezor,
        isActive: true,
      );
    }

    final String buttonText = isError ? t.wallet_connect_screen.guide_trezor.btn.retry : t.trezor_sign_screen.btn.sign;
    final VoidCallback onPressed =
        isError
            ? () {
              vm.reset();
              vm.signTransaction();
            }
            : () => vm.signTransaction();

    return FixedBottomButton(
      onButtonClicked: onPressed,
      text: buttonText,
      isActive: !isBusy,
      subWidget:
          isError
              ? CoconutUnderlinedButton(
                text: t.cancel,
                textStyle: CoconutTypography.body3_12,
                onTap: () {
                  vm.disconnect();
                  Navigator.pop(context);
                },
              )
              : null,
    );
  }
}

class _PsbtSummary {
  final int amount;
  final int fee;
  final List<String> recipientAddresses;
  const _PsbtSummary({required this.amount, required this.fee, required this.recipientAddresses});
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
