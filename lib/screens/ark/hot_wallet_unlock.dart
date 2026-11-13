import 'dart:typed_data';

import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/screens/common/flutter_hot_wallet_authenticator.dart';
import 'package:coconut_wallet/screens/send/hot_wallet_passphrase_input_sheet.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 핫월렛 서명 전 인증. 서명 때 패스프레이즈를 받는 지갑이면 시트로 받아 확인함.
/// 취소하면 null, 성공하면 패스프레이즈(없으면 빈 값). 받은 패스프레이즈는 호출한 쪽이 지움
Future<({Uint8List? passphrase})?> unlockHotWalletForSigning(
  BuildContext context, {
  required bool needsPassphrase,
  required Future<bool> Function(Uint8List passphrase) validatePassphrase,
  required String screenName,
}) async {
  final requiresAuthentication = context.read<AuthProvider>().isAuthEnabled;
  if (!needsPassphrase) {
    if (!requiresAuthentication) return (passphrase: null);
    final authenticated = await AppGuard.runWithoutPrivacyScreen(
      () => FlutterHotWalletAuthenticator(context).authenticate(),
    );
    return authenticated ? (passphrase: null) : null;
  }
  var showIncorrectError = false;
  while (true) {
    if (!context.mounted) return null;
    final passphrase = await CommonBottomSheets.showBottomSheet<Uint8List>(
      context: context,
      screenName: screenName,
      title: t.send_confirm_screen.passphrase_input_title,
      showCloseButton: true,
      backgroundColor: context.coconutColors.surfaceBottomSheet,
      showDragHandle: true,
      titlePadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      keyboardInsetAnimationDuration: Duration.zero,
      child: HotWalletPassphraseInputSheet(
        requiresAuthentication: requiresAuthentication,
        showIncorrectError: showIncorrectError,
        onAuthenticationStarted: () async {},
        onPassphraseInputResumed: () {},
      ),
    );
    if (!context.mounted || passphrase == null) return null;
    if (await AppGuard.runWithoutPrivacyScreen(() => validatePassphrase(passphrase))) return (passphrase: passphrase);
    passphrase.fillRange(0, passphrase.length, 0);
    if (!context.mounted) return null;
    showIncorrectError = true;
  }
}
