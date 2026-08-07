import 'dart:io';

import 'package:coconut_wallet/screens/home/wallet_add/connected/trezor_ble_connect_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/trezor_transport_select_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/trezor_usb_connect_screen.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';

class TrezorNavigator {
  TrezorNavigator._();

  static Future<T?> showConnectScreen<T>({
    required BuildContext context,
    String? psbtBase64,
    String? walletName,
    String? walletFingerprint,

    /// When true, skips the pairing flow entirely and shows the connect
    /// screen for [TrezorDevice.lastConnected]'s transport directly in its
    /// paired state (e.g. to surface a wallet mismatch immediately).
    bool resumeFromExistingSession = false,
  }) {
    final lastConnected = TrezorDevice.lastConnected;
    if (resumeFromExistingSession && lastConnected != null) {
      if (lastConnected.transport == TrezorTransport.ble) {
        return CommonBottomSheets.showCustomHeightBottomSheet<T>(
          context: context,
          heightRatio: 0.9,
          child: TrezorBleConnectScreen(
            psbtBase64: psbtBase64,
            walletName: walletName,
            walletFingerprint: walletFingerprint,
            resumeFromExistingSession: true,
          ),
        );
      }
      return CommonBottomSheets.showCustomHeightBottomSheet<T>(
        context: context,
        heightRatio: 0.9,
        child: TrezorUsbConnectScreen(
          psbtBase64: psbtBase64,
          walletName: walletName,
          walletFingerprint: walletFingerprint,
          resumeFromExistingSession: true,
        ),
      );
    }
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
