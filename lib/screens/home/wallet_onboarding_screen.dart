import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/services/home/wallet_widget_definitions.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/features/home/wallet_onboarding_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 지갑이 필요한 기능을 지갑 없이 열었을 때: 지갑을 추가하면 할 수 있는 일을 보여 주고 첫 지갑 추가로 이끈다.
class WalletOnboardingScreen extends StatelessWidget {
  final FeatureItem feature;
  final FeatureRegistry registry;

  const WalletOnboardingScreen({super.key, required this.feature, required this.registry});

  static Future<void> open(BuildContext context, {required FeatureItem feature, required FeatureRegistry registry}) {
    return Navigator.of(context).push(
      CupertinoPageRoute(
        settings: const RouteSettings(name: '/wallet-onboarding'),
        builder: (_) => WalletOnboardingScreen(feature: feature, registry: registry),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final copy = t.wallet_onboarding;
    WalletOnboardingItem? item(String id, String description) {
      final unlocked = registry.byId(id);
      if (unlocked == null) return null;
      final iconPath = unlocked.iconPath;
      return WalletOnboardingItem(
        icon:
            iconPath == null
                ? const SizedBox.shrink()
                : WalletOnboardingView.svgIcon(context, iconPath, scale: unlocked.iconScale),
        title: unlocked.label(),
        description: description,
      );
    }

    return Scaffold(
      backgroundColor: colors.homeBackground,
      appBar: CoconutAppBar.build(context: context, backgroundColor: colors.homeBackground),
      body: SafeArea(
        child: WalletOnboardingView(
          title: copy.subtitle,
          onAddWallet: () => openWalletAddFor(context, WalletStackKind.all),
          items: [
            for (final unlocked in [
              item(FeatureIds.receive, copy.receive),
              item(FeatureIds.send, copy.send),
              item(FeatureIds.utxoOrganizer, copy.organize),
              item(FeatureIds.hodlInsights, copy.insights),
            ])
              if (unlocked != null) unlocked,
          ],
        ),
      ),
    );
  }
}
