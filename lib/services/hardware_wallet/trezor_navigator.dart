import 'dart:io';

import 'package:coconut_wallet/screens/home/wallet_add/connected/trezor_ble_connect_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/trezor_transport_select_screen.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';

class TrezorNavigator {
  TrezorNavigator._();

  static Future<T?> showConnectScreen<T>({
    required BuildContext context,
    String? psbtBase64,
    String? walletName,
    String? walletFingerprint,
  }) {
    if (Platform.isIOS) {
      return CommonBottomSheets.showCustomHeightBottomSheet<T>(
        context: context,
        heightRatio: 0.9,
        child: TrezorBleConnectScreen(
          psbtBase64: psbtBase64,
          walletName: walletName,
          walletFingerprint: walletFingerprint,
        ),
      );
    }
    return CommonBottomSheets.showCustomHeightBottomSheet<T>(
      context: context,
      heightRatio: 0.9,
      child: TrezorTransportSelectScreen(
        psbtBase64: psbtBase64,
        walletName: walletName,
        walletFingerprint: walletFingerprint,
      ),
    );
  }
}
