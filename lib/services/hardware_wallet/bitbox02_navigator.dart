import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/bitbox02_connect_screen.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';

/// Navigation helpers for BitBox02 connect/pairing flow.
class BitBox02Navigator {
  BitBox02Navigator._();

  /// Shows the BitBox02 connect screen as a bottom sheet.
  /// When [resumeFromExistingSession] is true, the screen attempts to reuse
  /// [BitBox02Device.lastConnected] and skips the pairing flow.
  static Future<T?> showConnectScreen<T>({
    required BuildContext context,
    String? psbtBase64,
    String? walletName,
    String? walletFingerprint,
    bool resumeFromExistingSession = false,
  }) {
    return CommonBottomSheets.showCustomHeightBottomSheet<T>(
      context: context,
      heightRatio: 0.9,
      child: BitBox02ConnectScreen(
        importSource: WalletImportSource.bitbox02,
        psbtBase64: psbtBase64,
        walletName: walletName,
        walletFingerprint: walletFingerprint,
        resumeFromExistingSession: resumeFromExistingSession,
      ),
    );
  }
}
