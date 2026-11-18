import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_consent_sheet.dart';
import 'package:coconut_wallet/screens/home/wallet_add/hot_wallet/hot_wallet_restore_screen.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 아크 지갑 시작 화면의 두 갈래. [context]는 아크 지갑 화면
class ArkOnboardingFlow {
  ArkOnboardingFlow(this.context);

  final BuildContext context;

  Future<void> createNew() async {
    if (!await showArkConsentSheet(context) || !context.mounted) return;
    _run((wallet) => wallet.createNew());
  }

  Future<void> restore() {
    final navigator = Navigator.of(context);
    return navigator.push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletRestore),
        builder:
            (_) => HotWalletRestoreScreen(
              mnemonicOnly: MnemonicOnlyRestore(
                title: t.ark_wallet.restore_title,
                submitLabel: t.ark_wallet.restore_button,
                onSubmit: (mnemonic) async {
                  if (!await showArkConsentSheet(navigator.context)) {
                    mnemonic.fillRange(0, mnemonic.length, 0);
                    return;
                  }
                  _backToWallet(navigator);
                  _run((wallet) => wallet.restore(mnemonic));
                },
              ),
            ),
      ),
    );
  }

  void _backToWallet(NavigatorState navigator) =>
      navigator.popUntil((route) => route.settings.name == AnalyticsScreenNames.ccosArkWalletHome || route.isFirst);

  void _run(Future<void> Function(ArkWalletProvider wallet) action) {
    action(context.read<ArkWalletProvider>()).catchError((Object error) {
      Logger.error('ArkOnboardingFlow: creating the Ark wallet failed: $error');
      if (!context.mounted) return;
      CoconutToast.showToast(context: context, text: t.ark_wallet.create_failed, isVisibleIcon: true);
    });
  }
}
