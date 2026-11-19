import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_vtxo.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_move_parts.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_expiry_text.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_renew_sheet.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_vtxo_groups.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_info_row.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// VTXO 하나. 금액, 상태, 만료, 남은 블록, VTXO ID, 아래에 갱신
class ArkVtxoDetailScreen extends StatelessWidget {
  const ArkVtxoDetailScreen({super.key, required this.vtxo});

  final ArkVtxo vtxo;

  static Future<void> open(BuildContext context, ArkVtxo vtxo) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletVtxo),
      builder: (_) => ArkVtxoDetailScreen(vtxo: vtxo),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final wallet = context.watch<ArkWalletProvider>();
    final unit = context.select<ArkWalletProvider, BitcoinUnit>((wallet) => wallet.unit);
    final current = wallet.vtxos.where((candidate) => candidate.id == vtxo.id).firstOrNull ?? vtxo;
    final blocksLeft = current.blocksLeft(wallet.tipHeight);
    final renewing = wallet.isRenewing(current.id);
    final status =
        renewing
            ? t.ark_wallet.vtxo_renewing
            : current.isLocked
            ? t.ark_wallet.group_locked
            : (blocksLeft ?? 1) <= 0
            ? t.ark_wallet.expiry_expired
            : wallet.vtxosToRenew.any((due) => due.id == current.id)
            ? t.ark_wallet.group_expiring
            : t.ark_wallet.group_spendable;
    final canRenew = canRenewArkVtxo(current, tipHeight: wallet.tipHeight, isRenewing: wallet.isRenewing);
    final used = arkVtxoLifetimeUsed(current, tipHeight: wallet.tipHeight, lifetime: wallet.vtxoLifetime);
    final dueSoon = blocksLeft != null && blocksLeft <= ArkWalletProvider.renewWindowBlocks;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(context: context, title: ''),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              BitcoinAmountUnit(
                currentUnit: unit,
                unitStyle: CoconutTypography.heading4_18_Number.setColor(colors.primaryText),
                spacing: CoconutLayout.spacing_100w,
                child: Text(
                  unit.displayBitcoinAmount(current.amountSats),
                  style: CoconutTypography.heading2_28_NumberBold.setColor(colors.primaryText),
                ),
              ),
              if (used != null) ...[
                CoconutLayout.spacing_500h,
                Text(t.ark_wallet.vtxo_lifetime, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
                CoconutLayout.spacing_200h,
                ClipRRect(
                  key: const Key('ark-vtxo-lifetime'),
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: used,
                    minHeight: 4,
                    backgroundColor: colors.divider,
                    color: dueSoon ? colors.warning : colors.secondaryText,
                  ),
                ),
                CoconutLayout.spacing_100h,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      arkBlockText(current.expiryHeight - wallet.vtxoLifetime!),
                      style: CoconutTypography.caption_10_Number.setColor(colors.tertiaryText),
                    ),
                    Text(
                      arkBlockText(current.expiryHeight),
                      style: CoconutTypography.caption_10_Number.setColor(colors.tertiaryText),
                    ),
                  ],
                ),
                CoconutLayout.spacing_200h,
                Text(
                  t.ark_wallet.vtxo_lifetime_line(
                    total: arkDurationText(wallet.vtxoLifetime!),
                    left: arkDurationText(blocksLeft == null || blocksLeft < 0 ? 0 : blocksLeft),
                  ),
                  key: const Key('ark-vtxo-lifetime-line'),
                  style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                ),
              ],
              CoconutLayout.spacing_500h,
              ArkInfoBox(
                children: [
                  ArkInfoRow(label: t.ark_wallet.vtxo_status, value: status),
                  ArkInfoRow(label: t.ark_wallet.vtxo_expires, value: arkExpiryText(blocksLeft)),
                  ArkInfoRow(
                    label: t.ark_wallet.vtxo_expiry_height,
                    value: arkBlockText(current.expiryHeight),
                    isNumber: true,
                  ),
                  if (blocksLeft != null)
                    ArkInfoRow(
                      label: t.ark_wallet.vtxo_blocks_left,
                      value: '${blocksLeft < 0 ? 0 : blocksLeft}',
                      isNumber: true,
                    ),
                  ArkCopyRow(key: const Key('ark-vtxo-id'), label: t.ark_wallet.vtxo_id, value: current.id),
                ],
              ),
            ],
          ),
          if (canRenew)
            FixedBottomButton(
              text: t.ark_wallet.renew_button,
              isActive: current.amountSats >= ArkVtxo.minRenewSats,
              subWidget:
                  current.amountSats >= ArkVtxo.minRenewSats
                      ? null
                      : arkMoveProblemText(
                        context,
                        t.ark_wallet.renew_alone_too_small(
                          amount: unit.displayBitcoinAmount(ArkVtxo.minRenewSats, withUnit: true),
                        ),
                      ),
              onButtonClicked: () => showArkRenewSheet(context, [current]),
            ),
        ],
      ),
    );
  }
}
