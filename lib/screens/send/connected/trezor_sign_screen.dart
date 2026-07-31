import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/connected/trezor_sign_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/trezor_connect_shared_widgets.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_navigator.dart';

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

  TrezorSignStep? _lastStep;
  bool _lastIsWalletMismatch = false;
  final ScrollController _scrollController = ScrollController();

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
    _viewModel.addListener(_onStateChanged);

    _pulseController = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this)
      ..repeat(reverse: true);
    _pulseAnimation = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _viewModel.probeWalletMismatch();
    });
  }

  Future<void> _onStateChanged() async {
    final step = _viewModel.step;
    final mismatchChanged = _lastIsWalletMismatch != _viewModel.isWalletMismatch;
    if (_lastStep != step || mismatchChanged) {
      _lastStep = step;
      _lastIsWalletMismatch = _viewModel.isWalletMismatch;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      if (mounted) setState(() {});
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
    _scrollController.dispose();
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
                        controller: _scrollController,
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
                    if (vm.step != TrezorSignStep.signing && vm.step != TrezorSignStep.done)
                      Stack(alignment: Alignment.center, children: [_buildPrimaryActionButton(vm)]),
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
        if (vm.isWalletMismatch) ...[
          CoconutLayout.spacing_400h,
          TrezorWalletMismatchWarning(matchedWalletName: vm.mismatchedWalletName),
        ],
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

  Widget _buildPrimaryActionButton(TrezorSignViewModel vm) {
    final bool isError = vm.step == TrezorSignStep.error;
    final bool isBusy = vm.step == TrezorSignStep.signing;

    if (vm.isWalletMismatch) {
      return TrezorWalletMismatchActionButton(
        onButtonClicked: () async {
          await vm.disconnectForReconnect();
          if (!mounted) return;
          final navigator = Navigator.of(context);
          navigator.pop();
          await TrezorNavigator.showConnectScreen(
            context: navigator.context,
            psbtBase64: widget.psbtBase64,
            walletName: widget.walletName,
            walletFingerprint: widget.walletFingerprint,
          );
        },
      );
    }

    final String buttonText = isError ? t.wallet_connect_screen.guide_trezor.btn.retry : t.trezor_sign_screen.btn.sign;
    final VoidCallback onPressed =
        isError
            ? () {
              if (vm.isConnectionError) {
                vm.disconnectForReconnect();
                if (!mounted) return;
                final navigator = Navigator.of(context);
                navigator.pop();
                TrezorNavigator.showConnectScreen(
                  context: navigator.context,
                  psbtBase64: widget.psbtBase64,
                  walletName: widget.walletName,
                  walletFingerprint: widget.walletFingerprint,
                );
              } else {
                vm.reset();
                vm.signTransaction();
              }
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
