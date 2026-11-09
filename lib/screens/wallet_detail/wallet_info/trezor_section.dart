import 'dart:async';

import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/hardware_wallet_connection_rows.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_connectivity_service.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TrezorSection extends StatefulWidget {
  final String walletFingerprint;
  final Future<void> Function() onDisconnect;
  final Future<void> Function() onReconnect;

  const TrezorSection({
    super.key,
    required this.walletFingerprint,
    required this.onDisconnect,
    required this.onReconnect,
  });

  @override
  State<TrezorSection> createState() => _TrezorSectionState();
}

class _TrezorSectionState extends State<TrezorSection> {
  bool _isConnected = false;
  bool _reconnecting = false;
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
    await _sub?.cancel();
    if (!mounted) return;
    final physicallyConnected = await TrezorConnectivityService.isDeviceConnected(transport);
    if (!mounted) return;
    setState(() {
      _isConnected = physicallyConnected && _isWalletMatch();
    });
    _sub = TrezorConnectivityService.onConnectionChanged.listen((connected) {
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
      if (!mounted) return;
      setState(() {
        _isConnected = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return HardwareWalletConnectionRows(
      isConnected: _isConnected,
      isBusy: _reconnecting,
      onDisconnect: _confirmDisconnect,
      onReconnect: () async {
        if (_reconnecting) return;
        setState(() => _reconnecting = true);
        try {
          await widget.onReconnect();
          if (mounted) await _checkAndSubscribe();
        } finally {
          if (mounted) setState(() => _reconnecting = false);
        }
      },
    );
  }
}
