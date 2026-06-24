import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/hardware_wallet/bitbox02_sign_viewmodel.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Color _darker(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - 0.15).clamp(0.0, 1.0)).toColor();
}

class BitBox02SignScreen extends StatefulWidget {
  final String psbtBase64;
  final String walletName;
  final bool isFromSendFlow;
  final String transport;

  const BitBox02SignScreen({
    super.key,
    required this.psbtBase64,
    required this.walletName,
    this.isFromSendFlow = false,
    this.transport = 'usb',
  });

  @override
  State<BitBox02SignScreen> createState() => _BitBox02SignScreenState();
}

class _BitBox02SignScreenState extends State<BitBox02SignScreen> {
  late BitBox02SignViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = BitBox02SignViewModel(
      psbtBase64: widget.psbtBase64,
      walletName: widget.walletName,
      transport: widget.transport,
    );
    _viewModel.addListener(_onStateChanged);
  }

  void _onStateChanged() {
    if (_viewModel.step == BitBox02SignStep.done) {
      _viewModel.removeListener(_onStateChanged);
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
          title: Text(widget.walletName),
          backgroundColor: CoconutColors.black,
          foregroundColor: CoconutColors.white,
          actions: [
            if (!widget.isFromSendFlow)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Consumer<BitBox02SignViewModel>(
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
        body: Consumer<BitBox02SignViewModel>(
          builder: (context, vm, _) {
            return SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                      child: Column(
                        children: [
                          _buildTransactionSummaryCard(),
                          CoconutLayout.spacing_600h,
                          _buildStatusSection(vm),
                        ],
                      ),
                    ),
                  ),
                  if (vm.step != BitBox02SignStep.signing &&
                      vm.step != BitBox02SignStep.done)
                    Positioned(
                      left: 24,
                      right: 24,
                      bottom: 16,
                      child: _buildBottomButton(vm),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTransactionSummaryCard() {
    final summary = _parsePsbtSummary();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: CoconutColors.gray900,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.swap_horiz, color: CoconutColors.primary, size: 20),
              CoconutLayout.spacing_200w,
              Text('Transaction', style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.primary)),
            ],
          ),
          CoconutLayout.spacing_500h,
          if (summary != null) ...[
            _buildDetailRow('Send', '${UnitUtil.convertSatoshiToBitcoin(summary.amount)} BTC'),
            CoconutLayout.spacing_300h,
            if (summary.address.isNotEmpty)
              _buildDetailRow('To', _truncateAddress(summary.address)),
            CoconutLayout.spacing_300h,
            _buildDetailRow('Fee', '${UnitUtil.convertSatoshiToBitcoin(summary.fee)} BTC'),
            CoconutLayout.spacing_300h,
            _buildDetailRow('Total Cost', '${UnitUtil.convertSatoshiToBitcoin(summary.amount + summary.fee)} BTC'),
          ] else ...[
            _buildDetailRow('Send', '-- BTC'),
            _buildDetailRow('Fee', '-- BTC'),
          ],
          CoconutLayout.spacing_500h,
          Container(
            width: double.infinity,
            height: 1,
            color: CoconutColors.gray700,
          ),
          CoconutLayout.spacing_300h,
          Row(
            children: [
              const Icon(Icons.usb_rounded, color: CoconutColors.gray400, size: 16),
              CoconutLayout.spacing_100w,
              Text(
                'BitBox02 will verify these details on its screen',
                style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _PsbtSummary? _parsePsbtSummary() {
    try {
      final psbt = Psbt.parse(widget.psbtBase64);

      int amount = (psbt.outputs)
          .where((o) => o.isChange != true)
          .fold<int>(0, (sum, o) => sum + (o.outAmount ?? 0));
      int fee = psbt.fee;

      String address = '';
      final outputs = psbt.outputs;
      if (outputs.isNotEmpty) {
        final firstNonChange = outputs.firstWhere(
          (o) => o.isChange != true,
          orElse: () => outputs.first,
        );
        address = firstNonChange.outAddress;
      }

      return _PsbtSummary(amount: amount, fee: fee, address: address);
    } catch (_) {
      return null;
    }
  }

  String _truncateAddress(String addr) {
    if (addr.length <= 10) return addr;
    return '${addr.substring(0, 8)}...${addr.substring(addr.length - 4)}';
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: CoconutTypography.body3_12.setColor(CoconutColors.gray400)),
        ),
        Expanded(
          child: Text(value, style: CoconutTypography.body3_12_Bold, textAlign: TextAlign.right),
        ),
      ],
    );
  }

  Widget _buildStatusSection(BitBox02SignViewModel vm) {
    switch (vm.step) {
      case BitBox02SignStep.idle:
        return _buildIdleCard(vm);
      case BitBox02SignStep.connecting:
        return _buildProgressCard(vm.statusMessage);
      case BitBox02SignStep.signing:
        return _buildProgressCard(vm.statusMessage);
      case BitBox02SignStep.done:
        return _buildSuccessCard();
      case BitBox02SignStep.error:
        return _buildErrorCard(vm);
    }
  }

  Widget _buildIdleCard(BitBox02SignViewModel vm) {
    final status = vm.deviceStatus;
    final IconData statusIcon;
    final Color statusColor;
    final String statusText;
    final String? subText;

    switch (status) {
      case BitBox02DeviceStatus.disconnected:
        statusIcon = Icons.usb_off_rounded;
        statusColor = CoconutColors.gray500;
        statusText = 'Not connected';
        subText = 'Tap Sign to connect';
      case BitBox02DeviceStatus.locked:
        statusIcon = Icons.lock_outline;
        statusColor = CoconutColors.orange;
        statusText = 'Locked';
        subText = vm.fingerprint != null
            ? 'Device found: ${vm.fingerprint}'
            : 'Device found — PIN required';
      case BitBox02DeviceStatus.ready:
        statusIcon = Icons.check_circle_outline;
        statusColor = CoconutColors.green;
        statusText = 'Ready';
        subText = vm.fingerprint;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CoconutColors.gray900,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          CoconutLayout.spacing_200w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('BitBox02', style: CoconutTypography.body3_12_Bold),
                Text(statusText, style: CoconutTypography.body3_12.setColor(statusColor)),
              ],
            ),
          ),
          if (subText != null) ...[
            CoconutLayout.spacing_200w,
            Flexible(
              child: Text(
                subText,
                style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
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
          Consumer<BitBox02SignViewModel>(
            builder: (ctx, vm, _) {
              if (vm.fingerprint == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.fingerprint, size: 14, color: CoconutColors.gray400),
                    CoconutLayout.spacing_100w,
                    Text(vm.fingerprint!, style: CoconutTypography.body3_12.setColor(CoconutColors.gray400)),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessCard() {
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
          Text('Signed', style: CoconutTypography.heading3_21_Bold.setColor(CoconutColors.green)),
          CoconutLayout.spacing_200h,
          const Text('Transaction has been signed by BitBox02.', style: CoconutTypography.body2_14, textAlign: TextAlign.center),
          CoconutLayout.spacing_200h,
          Text('Ready to broadcast.', style: CoconutTypography.body3_12.setColor(CoconutColors.gray400), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BitBox02SignViewModel vm) {
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
          Text('Signing Failed', style: CoconutTypography.heading3_21_Bold.setColor(CoconutColors.red)),
          CoconutLayout.spacing_200h,
          Text(vm.errorMessage ?? 'Unknown error', style: CoconutTypography.body2_14, textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildBottomButton(BitBox02SignViewModel vm) {
    final bool isError = vm.step == BitBox02SignStep.error;
    final bool isBusy = vm.step == BitBox02SignStep.connecting ||
        vm.step == BitBox02SignStep.signing;

    String buttonText;
    VoidCallback onPressed;

    if (isError) {
      buttonText = 'Retry';
      onPressed = () {
        vm.reset();
        vm.signTransaction();
      };
    } else if (isBusy) {
      buttonText = vm.statusMessage.length > 30
          ? '${vm.statusMessage.substring(0, 30)}...'
          : vm.statusMessage;
      onPressed = () {}; // no-op while busy
    } else {
      buttonText = 'Sign with BitBox02';
      onPressed = () => vm.signTransaction();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShrinkAnimationButton(
          onPressed: onPressed,
          defaultColor: isBusy
              ? CoconutColors.gray700
              : CoconutColors.primary,
          pressedColor: isBusy
              ? CoconutColors.gray700
              : _darker(CoconutColors.primary),
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: isBusy
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(color: CoconutColors.gray400, strokeWidth: 2),
                        ),
                        CoconutLayout.spacing_200w,
                        Text(
                          buttonText,
                          style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.gray400),
                        ),
                      ],
                    )
                  : Text(
                      buttonText,
                      style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.black),
                    ),
            ),
          ),
        ),
        if (isError) ...[
          CoconutLayout.spacing_200h,
          ShrinkAnimationButton(
            onPressed: () {
              vm.disconnect();
              Navigator.pop(context);
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
      ],
    );
  }
}

class _PsbtSummary {
  final int amount;
  final int fee;
  final String address;
  const _PsbtSummary({required this.amount, required this.fee, required this.address});
}
