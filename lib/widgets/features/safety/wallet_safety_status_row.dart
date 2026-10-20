import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/providers/rescue_ready_provider.dart';
import 'package:coconut_wallet/providers/safety_provider.dart';
import 'package:coconut_wallet/screens/safety/rescue/rescue_ready_screen.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_sheets.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WalletSafetyStatusRow extends StatelessWidget {
  const WalletSafetyStatusRow({super.key, required this.walletId});

  final int walletId;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SafetyProvider?>();
    if (provider == null) return const SizedBox.shrink();
    final report = provider.report;
    final colors = context.coconutColors;
    final copy = t.wallet_health.wallet_info;
    final issues = report?.reviewItems.where((item) => item.walletId == walletId).toList() ?? [];
    final critical =
        issues.any((item) => item.severity == SafetySeverity.critical) ||
        (report?.criticalIncidents.any((incident) => incident.walletId == walletId) ?? false);
    final count =
        issues
            .where((item) => item.severity == SafetySeverity.actionNeeded || item.severity == SafetySeverity.warning)
            .length;
    final checked =
        (report?.recovery.any((item) => item.walletId == walletId) ?? false) ||
        (report?.allGoodItems.any((item) => item.walletId == walletId) ?? false);
    final caution = provider.isCaution(walletId);
    final text =
        critical
            ? copy.critical
            : caution
            ? copy.caution
            : count > 0
            ? copy.needs_attention(n: count)
            : checked
            ? copy.no_issues
            : copy.waiting;
    final color =
        critical || caution
            ? colors.dangerText
            : count > 0
            ? colors.warningText
            : checked
            ? colors.success
            : colors.secondaryText;
    return _WalletInfoStatusRow(
      key: const Key('wallet-safety-status-row'),
      title: copy.safety_status,
      value: text,
      valueColor: color,
      onPressed: () => showWalletContributionSheet(context, walletId),
    );
  }
}

class WalletRescueDestinationRow extends StatelessWidget {
  const WalletRescueDestinationRow({super.key, required this.walletId});

  final int walletId;

  @override
  Widget build(BuildContext context) {
    final entitlement = context.watch<EntitlementService?>();
    final rescue = context.watch<RescueReadyProvider?>();
    if (entitlement == null || rescue == null) return const SizedBox.shrink();
    return ValueListenableBuilder<PremiumState>(
      valueListenable: entitlement.state,
      builder: (context, state, _) {
        if (!state.isActive && rescue.destinationOf(walletId) == null) return const SizedBox.shrink();
        return _WalletInfoStatusRow(
          key: const Key('wallet-rescue-destination-row'),
          title: t.premium.rescue.destination,
          value: rescue.destinationLabel(walletId) ?? t.premium.rescue.not_set,
          valueColor: context.coconutColors.secondaryText,
          onPressed: () => RescueReadyScreen.open(context, walletId: walletId),
        );
      },
    );
  }
}

class _WalletInfoStatusRow extends StatelessWidget {
  const _WalletInfoStatusRow({
    super.key,
    required this.title,
    required this.value,
    required this.valueColor,
    required this.onPressed,
  });

  final String title, value;
  final Color valueColor;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return ShrinkAnimationButton(
      defaultColor: colors.primaryText.withValues(alpha: 0),
      pressedOverlayColor: colors.primaryText,
      pressedOverlayOpacity: 0.08,
      borderRadius: 12,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            Expanded(child: Text(title, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText))),
            CoconutLayout.spacing_200w,
            Flexible(
              child: Text(value, textAlign: TextAlign.end, style: CoconutTypography.body2_14.setColor(valueColor)),
            ),
            CoconutLayout.spacing_100w,
            Icon(Icons.keyboard_arrow_right_rounded, color: colors.iconSecondary),
          ],
        ),
      ),
    );
  }
}
