import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/services/security/hot_wallet_authenticator.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FlutterHotWalletAuthenticator implements HotWalletAuthenticator {
  const FlutterHotWalletAuthenticator(this.context);

  final BuildContext context;

  @override
  Future<bool> authenticate() async {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isAuthEnabled) return true;

    if (await authProvider.isBiometricsAuthValid()) return true;
    if (!context.mounted) return false;

    final pinVerified = await CommonBottomSheets.showCustomHeightBottomSheet<bool>(
      context: context,
      heightRatio: 0.9,
      child: const PinCheckScreen(allowBiometrics: false),
    );
    return pinVerified == true;
  }
}
