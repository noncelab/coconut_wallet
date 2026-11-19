import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_exit.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_movement_labels.dart';
import 'package:coconut_wallet/screens/common/single_text_field_bottom_sheet.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_info_row.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_signed_amount.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 아크 거래 상세. 경로·날짜·메모만 보이고, 주소·보낸 금액·수수료·기술 정보는 접힌 "자세히" 안에(Noah와 같음)
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

class _ArkMovementDetailScreenState extends State<ArkMovementDetailScreen> with SingleTickerProviderStateMixin {
  bool _showDetails = false;
  late final AnimationController _details = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  )..addStatusListener((_) => setState(() {}));
  late final Animation<double> _detailsSize = CurvedAnimation(parent: _details, curve: Curves.easeInOut);

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  void _toggleDetails() {
    setState(() => _showDetails = !_showDetails);
    _showDetails ? _details.forward() : _details.reverse();
  }

  String _status(ArkMovement movement) {
    final named = arkMovementStatusText(movement);
    if (named != null) return named;
    if (movement.isFailed) return t.ark_wallet.failed;
    if (movement.isPending) {
      return movement.isSend ? t.ark_wallet.status_pending_send : t.ark_wallet.status_pending_receive;
    }
    return movement.isSend ? t.ark_wallet.status_sent : t.ark_wallet.status_received;
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
    final exit = context.select<ArkWalletProvider, ArkExitSession?>((wallet) => wallet.exitOf(movement));
    final unit = context.select<ArkWalletProvider, BitcoinUnit>((wallet) => wallet.unit);
    String sats(int value) => unit.displayBitcoinAmount(value, withUnit: true);
    final amount = movement.effectiveBalanceSats.abs();
    final fee = movement.offchainFeeSats;
    final counterparty = movement.counterparty;
    final invoice =
        movement.lightningInvoice ??
        (counterparty != null && counterparty.toLowerCase().startsWith('ln') ? counterparty : null);
    final lightningMemo = invoice == null ? null : ArkPaymentRequest.bolt11Description(invoice);
    final counterpartyIsInvoice = invoice != null && counterparty?.toLowerCase() == invoice.toLowerCase();
    final date = DateTimeUtil.formatTimestamp(movement.timestamp).join(' ');
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(context: context, backgroundColor: colors.background, title: ''),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Center(child: ArkSignedAmount(unit: unit, sats: movement.effectiveBalanceSats, struck: movement.isFailed)),
          Center(
            child: FiatPrice(
              key: const Key('ark-movement-fiat'),
              satoshiAmount: amount,
              sign: movement.isSend ? '-' : '+',
              textColor: colors.secondaryText,
            ),
          ),
          if (movement.isPending || movement.isFailed) ...[
            CoconutLayout.spacing_200h,
            Center(
              child: Text(
                _status(movement),
                style: CoconutTypography.body2_14.setColor(movement.isFailed ? colors.danger : colors.secondaryText),
              ),
            ),
          ],
          CoconutLayout.spacing_500h,
          ArkInfoBox(
            children: [
              ArkInfoRow(label: t.ark_wallet.route, value: arkMovementRouteLabel(movement)),
              ArkInfoRow(label: t.ark_wallet.date, value: date, isNumber: true),
              if (lightningMemo != null) ArkInfoRow(label: t.ark_wallet.lightning_memo, value: lightningMemo),
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
              GestureDetector(
                key: const Key('ark-movement-details'),
                behavior: HitTestBehavior.opaque,
                onTap: _toggleDetails,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Text(t.ark_wallet.details, style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
                      const Spacer(),
                      Icon(
                        _showDetails ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: colors.iconSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),
              if (!_details.isDismissed)
                SizeTransition(
                  sizeFactor: _detailsSize,
                  axisAlignment: -1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: arkInfoRowsWithDividers(context, [
                      if (movement.kind == ArkMovementKind.exit) ...[
                        ArkInfoRow(label: t.ark_wallet.exit_amount_done, value: sats(amount), isNumber: true),
                        if (exit?.receivedSats case final received?)
                          ArkInfoRow(label: t.ark_wallet.exit_received, value: sats(received), isNumber: true),
                        if (exit?.paidFeeSats case final paid?)
                          ArkInfoRow(label: t.fee, value: sats(paid), isNumber: true),
                        if (exit != null)
                          ArkCopyRow(
                            label: exit.receivedSats == null ? t.ark_wallet.recipient : t.ark_wallet.from,
                            value: exit.destination,
                            detail: exit.destinationPath,
                          ),
                        if (exit?.claimTxid case final txid?) ArkCopyRow(label: t.tx_id, value: txid),
                      ] else ...[
                        if (movement.isSend) ...[
                          ArkInfoRow(label: t.ark_wallet.sent_amount, value: sats(amount - fee), isNumber: true),
                          ArkInfoRow(label: t.fee, value: sats(fee), isNumber: true),
                        ],
                        if (counterparty != null)
                          ArkCopyRow(
                            label:
                                counterpartyIsInvoice
                                    ? t.ark_wallet.invoice
                                    : (movement.isSend ? t.ark_wallet.recipient : t.ark_wallet.from),
                            value: counterparty,
                          ),
                        if (movement.paymentHash != null)
                          ArkCopyRow(label: t.ark_wallet.payment_hash, value: movement.paymentHash!),
                        if (movement.lightningInvoice != null && !counterpartyIsInvoice)
                          ArkCopyRow(label: t.ark_wallet.invoice, value: movement.lightningInvoice!),
                        ArkCopyRow(label: t.ark_wallet.movement_id, value: '${movement.id}'),
                        if (movement.outputVtxoIds.isNotEmpty)
                          ArkCopyRow(label: 'VTXO', value: movement.outputVtxoIds.join('\n')),
                      ],
                    ]),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
