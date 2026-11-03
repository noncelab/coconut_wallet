import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/hardware_wallet_connect_mode.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/bitbox02_connect_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/trezor_ble_connect_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/trezor_usb_connect_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final device in ['bitbox02', 'trezor-ble', 'trezor-usb']) {
    dynamic screen({int? walletId, String? psbt, HardwareWalletConnectMode? mode}) => switch (device) {
      'bitbox02' => BitBox02ConnectScreen(
        importSource: WalletImportSource.bitbox02,
        walletId: walletId,
        psbtBase64: psbt,
        mode: mode,
      ),
      'trezor-ble' => TrezorBleConnectScreen(walletId: walletId, psbtBase64: psbt, mode: mode),
      _ => TrezorUsbConnectScreen(walletId: walletId, psbtBase64: psbt, mode: mode),
    };
    test('$device: wallet ID alone never silently enables reconnection', () {
      expect(screen().connectionMode, HardwareWalletConnectMode.addWallet);
      expect(screen(walletId: 1).connectionMode, HardwareWalletConnectMode.addWallet);
      expect(screen(walletId: 1, psbt: 'psbt').connectionMode, HardwareWalletConnectMode.sign);
      expect(
        screen(walletId: 1, mode: HardwareWalletConnectMode.reconnect).connectionMode,
        HardwareWalletConnectMode.reconnect,
      );
    });
    test('$device: invalid explicit reconnect or signing arguments are rejected', () {
      expect(() => screen(mode: HardwareWalletConnectMode.reconnect), throwsAssertionError);
      expect(() => screen(walletId: 1, psbt: 'psbt', mode: HardwareWalletConnectMode.reconnect), throwsAssertionError);
      expect(() => screen(walletId: 1, mode: HardwareWalletConnectMode.sign), throwsAssertionError);
      expect(() => screen(psbt: 'psbt', mode: HardwareWalletConnectMode.addWallet), throwsAssertionError);
    });
  }
}
