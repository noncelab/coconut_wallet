import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;

import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_backup_flow.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_backup_nudge.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_onboarding_flow.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_progress_view.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_settings_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_welcome_view.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/common/amount/animated_balance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class ArkWalletHomeScreen extends StatelessWidget {
  const ArkWalletHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final wallet = context.watch<ArkWalletProvider>();
    final flow = ArkOnboardingFlow(context);
    final step = wallet.step;
    return Scaffold(
      backgroundColor: colors.homeBackground,
      appBar: CoconutAppBar.build(
        context: context,
        backgroundColor: colors.homeBackground,
        title: '',
        actionButtonList: [
          if (wallet.hasWallet && !ArkWalletProgressView.isInProgress(step))
            CoconutAppBarActionButton(
              key: const Key('ark-wallet-settings'),
              onPressed:
                  () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletSettings),
                      builder: (_) => const ArkWalletSettingsScreen(),
                    ),
                  ),
              icon: SvgPicture.asset(
                FeatureSettingsIconPath.settings,
                colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
              ),
            ),
        ],
      ),
      body:
          ArkWalletProgressView.isInProgress(step)
              ? ArkWalletProgressView(step: step!)
              : !wallet.hasWallet
              ? ArkWalletWelcomeView(onCreateNew: flow.createNew, onRestore: flow.restore)
              : wallet.state == ArkWalletState.failed
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(t.ark_wallet.open_failed, style: CoconutTypography.body1_16.setColor(colors.primaryText)),
                    CoconutLayout.spacing_400h,
                    CoconutButton(
                      text: t.retry,
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      onPressed: wallet.openAfterAppEntrance,
                      backgroundColor: colors.primaryText,
                      foregroundColor: colors.background,
                    ),
                  ],
                ),
              )
              : _ArkWalletBody(wallet: wallet),
    );
  }
}

class _ArkWalletBody extends StatelessWidget {
  const _ArkWalletBody({required this.wallet});

  final ArkWalletProvider wallet;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final balance = wallet.balance.total;
    final unit = context.select<PreferenceProvider, BitcoinUnit>((preferences) => preferences.currentUnit);
    final amountStyle = CoconutTypography.heading2_28_NumberBold.setColor(colors.primaryText);
    final unitStyle = CoconutTypography.heading4_18_Number.setColor(colors.primaryText);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      children: [
        Text(t.ark_wallet.balance_label, style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
        CoconutLayout.spacing_100h,
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (unit.isPrefixSymbol) ...[Text(unit.symbol, style: unitStyle), CoconutLayout.spacing_100w],
            AnimatedBalance(prevValue: balance, value: balance, currentUnit: unit, textStyle: amountStyle),
            if (!unit.isPrefixSymbol) ...[CoconutLayout.spacing_100w, Text(unit.symbol, style: unitStyle)],
          ],
        ),
        if (wallet.isRecoveryPending) ...[
          CoconutLayout.spacing_200h,
          Text(t.ark_wallet.recovery_pending, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
        ],
        if (wallet.needsBackup) ...[
          CoconutLayout.spacing_500h,
          ArkBackupNudge(onBackup: () => startArkWalletBackup(context, wallet)),
        ],
      ],
    );
  }
}
