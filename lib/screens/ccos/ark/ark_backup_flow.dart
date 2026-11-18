import 'dart:typed_data';

import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_wallet_home_view_model.dart';
import 'package:coconut_wallet/screens/common/flutter_hot_wallet_authenticator.dart';
import 'package:flutter/widgets.dart';

/// 인증 뒤 코코넛 니모닉 백업 화면(단어 보기 → 확인 퀴즈)을 열고, 확인을 마치면 백업 완료로 기록
Future<void> startArkWalletBackup(BuildContext context, ArkWalletProvider wallet) async {
  final viewModel = ArkWalletHomeViewModel(wallet, FlutterHotWalletAuthenticator(context));
  final mnemonic = await AppGuard.runWithoutPrivacyScreen(viewModel.unlockForBackup);
  if (mnemonic == null || !context.mounted) {
    mnemonic?.fillRange(0, mnemonic.length, 0);
    return;
  }
  try {
    final confirmed = await Navigator.pushNamed(
      context,
      AppRouteNames.hotWalletMnemonicBackup,
      arguments: HotWalletMnemonicBackupRouteArgs(mnemonic: mnemonic, passphrase: Uint8List(0)),
    );
    await viewModel.finishBackup(confirmed: confirmed == true);
  } finally {
    mnemonic.fillRange(0, mnemonic.length, 0);
  }
}
