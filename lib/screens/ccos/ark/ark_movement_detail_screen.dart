import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_movement_labels.dart';
import 'package:coconut_wallet/screens/common/single_text_field_bottom_sheet.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/common/buttons/copy_text_container.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_info_row.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 아크 거래 상세. 기술 정보는 접힌 "자세히" 안에
class ArkMovementDetailScreen extends StatefulWidget {
  const ArkMovementDetailScreen({super.key, required this.movement});

  final ArkMovement movement;

  static Future<void> open(BuildContext context, ArkMovement movement) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletMovement),
      builder: (_) => ArkMovementDetailScreen(movement: movement),
    ),
  );

  @override
  State<ArkMovementDetailScreen> createState() => _ArkMovementDetailScreenState();
}

class _ArkMovementDetailScreenState extends State<ArkMovementDetailScreen> {
  bool _showDetails = false;

  String _status(ArkMovement movement) {
    if (movement.isFailed) return t.ark_wallet.failed;
    if (movement.isPending) {
      return movement.isSend ? t.ark_wallet.status_pending_send : t.ark_wallet.status_pending_receive;
    }
    return movement.isSend ? t.ark_wallet.status_sent : t.ark_wallet.status_received;
  }

  Widget _copyRow(String label, String value) {
    final colors = context.coconutColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
          CoconutLayout.spacing_200h,
          CopyTextContainer(text: value, textStyle: CoconutTypography.body2_14_Number.setColor(colors.primaryText)),
        ],
      ),
    );
  }

  void _editMemo(String? memo) {
    final wallet = context.read<ArkWalletProvider>();
    SingleTextFieldBottomSheet.show(
      context: context,
      title: t.ark_wallet.memo,
      screenName: AnalyticsScreenNames.ccosArkWalletMemo,
      originalText: memo ?? '',
      placeholder: t.ark_wallet.memo_hint,
      maxLength: 50,
      completeButtonText: t.done,
      collapsedHeight: 300,
      onComplete: (text) => wallet.setMemo(widget.movement.id, text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final movement = widget.movement;
    final memo = context.select<ArkWalletProvider, String?>((wallet) => wallet.memoOf(movement.id));
    final unit = context.select<PreferenceProvider, BitcoinUnit>((preferences) => preferences.currentUnit);
    String sats(int value) => unit.displayBitcoinAmount(value, withUnit: true);
    final amount = movement.effectiveBalanceSats.abs();
    final fee = movement.offchainFeeSats;
    final counterparty = movement.counterparty;
    final date = DateTimeUtil.formatTimestamp(movement.timestamp).join(' ');
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(context: context, title: ''),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          BitcoinAmountUnit(
            currentUnit: unit,
            unitStyle: CoconutTypography.heading4_18_Number.setColor(colors.primaryText),
            spacing: CoconutLayout.spacing_100w,
            child: Text(
              '${movement.isSend ? '-' : '+'}${unit.displayBitcoinAmount(amount)}',
              style: CoconutTypography.heading2_28_NumberBold
                  .setColor(colors.primaryText)
                  .copyWith(decoration: movement.isFailed ? TextDecoration.lineThrough : null),
            ),
          ),
          CoconutLayout.spacing_200h,
          Text(
            _status(movement),
            style: CoconutTypography.body1_16.setColor(movement.isFailed ? colors.danger : colors.secondaryText),
          ),
          CoconutLayout.spacing_500h,
          if (counterparty != null)
            ArkInfoRow(
              label: movement.isSend ? t.ark_wallet.recipient : t.ark_wallet.from,
              value: counterparty,
              isNumber: true,
            ),
          ArkInfoRow(label: t.ark_wallet.route, value: arkMovementRouteLabel(movement)),
          if (movement.isSend) ...[
            ArkInfoRow(label: t.fee, value: fee == 0 ? t.ark_wallet.fee_free : sats(fee), isNumber: fee != 0),
            ArkInfoRow(label: t.ark_wallet.total, value: sats(amount), isNumber: true),
          ],
          ArkInfoRow(label: t.ark_wallet.date, value: date, isNumber: true),
          GestureDetector(
            key: const Key('ark-movement-memo'),
            behavior: HitTestBehavior.opaque,
            onTap: () => _editMemo(memo),
            child: ArkInfoRow(
              label: t.ark_wallet.memo,
              value: memo ?? t.ark_wallet.memo_add,
              valueColor: memo == null ? colors.secondaryText : null,
            ),
          ),
          CoconutLayout.spacing_300h,
          GestureDetector(
            key: const Key('ark-movement-details'),
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _showDetails = !_showDetails),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Text(t.ark_wallet.details, style: CoconutTypography.body2_14.setColor(colors.primaryText)),
                  const Spacer(),
                  Icon(
                    _showDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: colors.iconPrimary,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_showDetails) ...[
            if (movement.paymentHash != null) _copyRow(t.ark_wallet.payment_hash, movement.paymentHash!),
            if (movement.lightningInvoice != null) _copyRow(t.ark_wallet.invoice, movement.lightningInvoice!),
            _copyRow(t.ark_wallet.movement_id, '${movement.id}'),
            for (final vtxo in movement.outputVtxoIds) _copyRow('VTXO', vtxo),
          ],
        ],
      ),
    );
  }
}
