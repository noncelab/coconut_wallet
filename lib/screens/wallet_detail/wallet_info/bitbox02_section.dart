import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_connectivity_service.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_device.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BitBox02Section extends StatefulWidget {
  final Future<void> Function() onDisconnect;

  const BitBox02Section({super.key, required this.onDisconnect});

  @override
  State<BitBox02Section> createState() => _BitBox02SectionState();
}

class _BitBox02SectionState extends State<BitBox02Section> {
  bool _isConnected = false;
  String? _deviceId;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _checkAndSubscribe();
  }

  Future<void> _checkAndSubscribe() async {
    final connected = await BitBox02ConnectivityService.isDeviceConnected();
    if (!mounted) return;
    setState(() {
      _isConnected = connected;
      _deviceId = BitBox02Device.lastConnected?.id;
    });
    _sub = BitBox02ConnectivityService.onConnectionChanged.listen((connected) {
      if (!mounted) return;
      setState(() {
        _isConnected = connected;
        if (!connected) _deviceId = null;
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
            title: t.wallet_info_screen.bitbox02_device.disconnect_confirm_title,
            description: t.wallet_info_screen.bitbox02_device.disconnect_confirm_description,
            leftButtonText: t.cancel,
            rightButtonText: t.wallet_info_screen.bitbox02_device.disconnect_button,
            onTapLeft: () => Navigator.pop(ctx, false),
            onTapRight: () => Navigator.pop(ctx, true),
          ),
    );
    if (confirmed == true && mounted) {
      await widget.onDisconnect();
      setState(() {
        _isConnected = false;
        _deviceId = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(color: context.coconutColors.surfaceCard, borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.wallet_info_screen.bitbox02_device.title,
            style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.secondaryText),
          ),
          CoconutLayout.spacing_300h,
          Divider(color: context.coconutColors.divider, height: 1),
          CoconutLayout.spacing_300h,
          _InfoRow(
            label: t.wallet_info_screen.bitbox02_device.connection_status,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _isConnected ? context.coconutColors.textHighlight : context.coconutColors.surfaceDisabled,
                  ),
                ),
                CoconutLayout.spacing_100w,
                Text(
                  _isConnected
                      ? t.wallet_info_screen.bitbox02_device.connected
                      : t.wallet_info_screen.bitbox02_device.disconnected,
                  style: CoconutTypography.body3_12_Bold.setColor(
                    _isConnected ? context.coconutColors.textHighlight : context.coconutColors.secondaryText,
                  ),
                ),
                if (_isConnected) ...[
                  Divider(color: context.coconutColors.divider, height: 1),
                  CoconutLayout.spacing_300w,
                  GestureDetector(
                    onTap: _confirmDisconnect,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: context.coconutColors.primaryText.withValues(alpha: 0.06),
                      ),
                      child: Text(
                        t.wallet_info_screen.bitbox02_device.disconnect_button,
                        style: CoconutTypography.caption_10.setColor(context.coconutColors.primaryText),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (_isConnected && _deviceId != null) ...[
            const SizedBox(height: 10),
            _InfoRow(
              label: t.wallet_info_screen.bitbox02_device.device_id,
              child: Text(
                _deviceId!,
                style: CoconutTypography.body3_12_NumberBold.setColor(context.coconutColors.primaryText),
              ),
            ),
          ],
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
