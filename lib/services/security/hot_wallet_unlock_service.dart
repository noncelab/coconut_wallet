import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 핫월렛 평문에 접근하는 단일 인증 진입점이다.
///
/// 앱 잠금이 설정되어 있으면 생체인증을 우선 시도하고, 실패하거나 사용할 수
/// 없으면 앱 PIN으로 폴백한다. 인증을 취소하면 평문을 반환하지 않는다.
class HotWalletUnlockService {
  HotWalletUnlockService({HotWalletSecretRepository? secretRepository})
    : _secretRepository = secretRepository ?? HotWalletSecretRepository();

  final HotWalletSecretRepository _secretRepository;

  Future<HotWalletPlaintext?> unlockPreferBiometrics({
    required BuildContext context,
    required String storageKey,
    VoidCallback? onDecrypting,
  }) async {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.isAuthEnabled) {
      final biometricsSucceeded = await authProvider.isBiometricsAuthValid();
      if (!biometricsSucceeded) {
        if (!context.mounted) return null;
        final pinVerified = await CommonBottomSheets.showCustomHeightBottomSheet<bool>(
          context: context,
          heightRatio: 0.9,
          child: const PinCheckScreen(allowBiometrics: false),
        );
        if (pinVerified != true) return null;
      }
    }

    onDecrypting?.call();
    if (onDecrypting != null) {
      await WidgetsBinding.instance.endOfFrame;
      if (!context.mounted) return null;
    }
    return _secretRepository.unlockAfterAuthentication(storageKey);
  }
}
