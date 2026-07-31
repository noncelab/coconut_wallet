import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_ble_connectivity_service.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TrezorSection extends StatefulWidget {
  final String walletFingerprint;
  final Future<void> Function() onDisconnect;

  const TrezorSection({super.key, required this.walletFingerprint, required this.onDisconnect});

  @override
  State<TrezorSection> createState() => _TrezorSectionState();
}

class _TrezorSectionState extends State<TrezorSection> {
  bool _isConnected = false;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _checkAndSubscribe();
  }

  bool _isWalletMatch() {
    final device = TrezorDevice.lastConnected;
    if (device == null) return false;
    final fp = device.cachedFingerprint;
    if (fp == null || widget.walletFingerprint.isEmpty) return false;
    return fp.toLowerCase() == widget.walletFingerprint.toLowerCase();
  }

  Future<void> _checkAndSubscribe() async {
    final transport = TrezorDevice.lastConnected?.transport ?? TrezorTransport.ble;
    final physicallyConnected = await TrezorBleConnectivityService.isDeviceConnected(transport);
    if (!mounted) return;
    setState(() {
      _isConnected = physicallyConnected && _isWalletMatch();
    });
    _sub = TrezorBleConnectivityService.onConnectionChanged.listen((connected) {
      if (!mounted) return;
      setState(() {
        _isConnected = connected && _isWalletMatch();
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _confirmDisconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => CoconutPopup(
            languageCode: ctx.read<PreferenceProvider>().language,
            title: t.wallet_info_screen.connected_hardware_wallet.disconnect_confirm_title,
            description: t.wallet_info_screen.connected_hardware_wallet.disconnect_confirm_description,
            leftButtonText: t.cancel,
            rightButtonText: t.wallet_info_screen.connected_hardware_wallet.disconnect_button,
            onTapLeft: () => Navigator.pop(ctx, false),
            onTapRight: () => Navigator.pop(ctx, true),
          ),
    );
    if (confirmed == true && mounted) {
      await widget.onDisconnect();
      setState(() {
        _isConnected = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: context.coconutColors.surface, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.wallet_info_screen.connected_hardware_wallet.title,
            style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.secondaryText),
          ),
          CoconutLayout.spacing_300h,
          Divider(color: context.coconutColors.divider, height: 1),
          CoconutLayout.spacing_300h,
          _InfoRow(
            label: t.wallet_info_screen.connected_hardware_wallet.connection_status,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnected ? context.coconutColors.primary : context.coconutColors.surfaceDisabled,
                  ),
                ),
                CoconutLayout.spacing_100w,
                Text(
                  _isConnected
                      ? t.wallet_info_screen.connected_hardware_wallet.connected
                      : t.wallet_info_screen.connected_hardware_wallet.disconnected,
                  style: CoconutTypography.body3_12_Bold.setColor(
                    _isConnected ? context.coconutColors.primary : context.coconutColors.secondaryText,
                  ),
                ),
                if (_isConnected) ...[
                  CoconutLayout.spacing_100w,
                  GestureDetector(
                    onTap: _confirmDisconnect,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: context.coconutColors.primaryText.withValues(alpha: 0.06),
                      ),
                      child: Text(
                        t.wallet_info_screen.connected_hardware_wallet.disconnect_button,
                        style: CoconutTypography.caption_10.setColor(context.coconutColors.primaryText),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final Widget child;

  const _InfoRow({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText)),
        const SizedBox(width: 12),
        child,
      ],
    );
  }
}
