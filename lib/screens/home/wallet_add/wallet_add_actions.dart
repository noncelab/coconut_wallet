import 'dart:io';

import 'package:coconut_wallet/analytics/wallet_add_analytics.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// 지갑 추가 탑 시트와 지갑 추가 화면이 함께 쓰는 동작
abstract final class WalletAddActions {
  /// QR로 주고받는 기기와 확장 공개키
  static const airGappedSources = [
    WalletImportSource.coconutVault,
    WalletImportSource.keystone,
    WalletImportSource.seedSigner,
    WalletImportSource.jade,
    WalletImportSource.coldCard,
    WalletImportSource.krux,
    WalletImportSource.passport,
    WalletImportSource.extendedPublicKey,
  ];

  /// USB·블루투스로 연결하는 기기
  static const connectedSources = [WalletImportSource.trezor, WalletImportSource.bitbox02];

  static void openSource(BuildContext context, NavigatorState navigator, WalletImportSource source) {
    context.read<AnalyticsService>().logWalletAddScreenEntered(source);
    switch (source) {
      case WalletImportSource.bitbox02:
        navigator.pushNamed(
          AppRouteNames.bitbox02Connect,
          arguments: const BitBox02ConnectRouteArgs(importSource: WalletImportSource.bitbox02),
        );
      case WalletImportSource.trezor:
        navigator.pushNamed(
          Platform.isAndroid ? AppRouteNames.trezorTransportSelect : AppRouteNames.trezorBleConnect,
          arguments: Platform.isAndroid ? const TrezorTransportSelectRouteArgs() : const TrezorBleConnectRouteArgs(),
        );
      default:
        navigator.pushNamed(
          AppRouteNames.walletAddScanner,
          arguments: WalletAddScannerRouteArgs(walletImportSource: source),
        );
    }
  }

  /// 핫월렛 만들기·복원 전에 기기 비밀번호를 확인한다. 진행할 수 있으면 true
  static Future<bool> prepareHotWallet(BuildContext context, {required bool restore}) async {
    context.read<AnalyticsService>().logHotWalletActionSelected(isRestore: restore);
    final authProvider = context.read<AuthProvider>();
    final isDevicePasscodeSet = await authProvider.isDevicePasscodeSet();
    if (!context.mounted) return false;
    if (isDevicePasscodeSet) return true;

    await showConfirmDialog(
      context,
      context.read<PreferenceProvider>().language,
      t.wallet_home_screen.hot_wallet_add.device_passcode_required.title,
      t.wallet_home_screen.hot_wallet_add.device_passcode_required.description,
      leftButtonText: t.close,
      rightButtonText: t.go_to_settings,
      onTapLeft: () => Navigator.pop(context),
      onTapRight: () async {
        Navigator.pop(context);
        await authProvider.openDeviceSecuritySettings();
      },
    );
    return false;
  }

  static String hotWalletRoute({required bool restore}) =>
      restore ? AppRouteNames.hotWalletRestore : AppRouteNames.hotWalletCreate;
}
