import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/screens/common/single_text_field_bottom_sheet.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_lib/coconut_lib.dart' show NetworkType, Transaction;
import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/extensions/num_extensions.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/services/mempool_transaction_service.dart';
import 'package:coconut_wallet/utils/payment_request_parser.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/features/transaction/card/transaction_input_output_card.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/ark/ark_movement.dart';
import 'package:coconut_wallet/model/wallet/wallet_activity.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:coconut_wallet/widgets/common/buttons/copy_text_container.dart';
import 'package:coconut_wallet/widgets/common/info/highlighted_info_area.dart';
import 'package:coconut_wallet/widgets/features/ark/ark_texts.dart';
import 'package:coconut_wallet/widgets/features/ark/ark_info_tooltip.dart';
import 'package:coconut_wallet/widgets/features/transaction/card/underline_button_item_card.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Opens the detail screen of a history entry: the on-chain transaction or the Ark movement.
void openWalletActivityDetail(BuildContext context, int walletId, WalletActivity activity) {
  switch (activity) {
    case OnchainActivity(:final tx):
      Navigator.pushNamed(
        context,
        AppRouteNames.transactionDetail,
        arguments: TransactionDetailRouteArgs(id: walletId, txHash: tx.transactionHash),
      );
    case ArkActivity(:final movement):
      Navigator.pushNamed(
        context,
        AppRouteNames.arkMovementDetail,
        arguments: ArkMovementDetailRouteArgs(id: walletId, movementId: movement.id),
      );
  }
}

/// Details of one Ark movement (bark's history entry), from the cache, laid out like the
/// transaction detail screen.
class ArkMovementDetailScreen extends StatefulWidget {
  const ArkMovementDetailScreen({super.key, required this.id, required this.movementId});

  final int id;
  final int movementId;

  @override
  State<ArkMovementDetailScreen> createState() => _ArkMovementDetailScreenState();
}

class _ArkMovementDetailScreenState extends State<ArkMovementDetailScreen> {
  late final ArkProvider _arkProvider;
  late BitcoinUnit _unit;

  /// The on-chain transaction of an offboard or an on-chain payment from Ark that isn't one of
  /// this wallet's own (it paid a vault or someone else), looked up like any transaction.
  TransactionRecord? _onchainTx;
  ({String txid, bool pending})? _onchainTxRequest;
  ({Rect anchor, String text})? _tooltip;

  // Syncs every few seconds while shown, so a payment that's still going (e.g. over Lightning)
  // settles on screen.
  @override
  void initState() {
    super.initState();
    _arkProvider = context.read<ArkProvider>();
    _unit = context.read<PreferenceProvider>().currentUnit;
    _arkProvider.setFastSync(widget.id, true);
  }

  @override
  void dispose() {
    _arkProvider.setFastSync(widget.id, false);
    super.dispose();
  }

  void _toggleUnit() => setState(() => _unit = _unit.isBasedOnSatoshi ? BitcoinUnit.btc : BitcoinUnit.sats);

  void _hideTooltip() {
    if (_tooltip != null) setState(() => _tooltip = null);
  }

  /// Looks up [movement]'s offboard transaction on the block explorer, again whenever the
  /// movement settles, so the inputs, fee and confirmations show as on the transaction detail
  /// screen. Until then, the transaction from bark's record shows its outputs.
  void _loadOnchainTx(ArkMovement movement) {
    final hex = movement.offboardTxHex;
    final txid = movement.linkedTxid;
    if (hex == null || txid == null) return;
    final request = (txid: txid, pending: movement.isPending);
    if (_onchainTxRequest == request) return;
    _onchainTxRequest = request;
    _onchainTx ??= _recordFromHex(hex, txid);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final explorerUrl = context.read<BlockExplorerProvider>().blockExplorerUrl;
      try {
        final record = await MempoolTransactionService(explorerUrl).fetch(txid);
        if (mounted) setState(() => _onchainTx = record);
      } catch (error) {
        Logger.error('ArkMovementDetailScreen: looking up $txid failed: $error');
      }
    });
  }

  /// The outputs of bark's copy of the transaction, for before the node knows it.
  static TransactionRecord? _recordFromHex(String hex, String txid) {
    try {
      final tx = Transaction.parse(hex);
      return TransactionRecord.fromTransactions(
        transactionHash: txid,
        timestamp: DateTime.now(),
        blockHeight: 0,
        transactionType: TransactionType.sent,
        amount: 0,
        fee: 0,
        inputAddressList: const [],
        outputAddressList: [for (final output in tx.outputs) TransactionAddress(output.getAddress(), output.amount)],
        vSize: tx.getVirtualByte(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Consumer<ArkProvider>(
      builder: (context, arkProvider, _) {
        final movement = arkProvider.movements(widget.id).where((m) => m.id == widget.movementId).firstOrNull;
        if (movement != null) _loadOnchainTx(movement);
        final scaffold = Scaffold(
          backgroundColor: colors.background,
          appBar: CoconutAppBar.build(context: context, title: t.view_tx_details, backgroundColor: colors.background),
          body:
              movement == null
                  ? Center(
                    child: Text(t.ark.movement.gone, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
                  )
                  : NotificationListener<ScrollNotification>(
                    onNotification: (_) {
                      _hideTooltip();
                      return false;
                    },
                    child: _MovementDetails(
                      walletId: widget.id,
                      movement: movement,
                      onchainTx: _onchainTx,
                      unit: _unit,
                      onToggleUnit: _toggleUnit,
                      onInfoTap:
                          (anchor, text) =>
                              setState(() => _tooltip = _tooltip?.text == text ? null : (anchor: anchor, text: text)),
                    ),
                  ),
        );
        return GestureDetector(
          onTap: _hideTooltip,
          child: Stack(
            children: [
              scaffold,
              if (_tooltip case final tooltip?)
                ArkInfoTooltip(anchor: tooltip.anchor, text: tooltip.text, onDismiss: _hideTooltip),
            ],
          ),
        );
      },
    );
  }
}

class _MovementDetails extends StatelessWidget {
  const _MovementDetails({
    required this.walletId,
    required this.movement,
    required this.onchainTx,
    required this.unit,
    required this.onToggleUnit,
    required this.onInfoTap,
  });

  final int walletId;
  final ArkMovement movement;

  /// The offboard transaction, when it isn't one of the wallet's own (see the state).
  final TransactionRecord? onchainTx;
  final BitcoinUnit unit;
  final VoidCallback onToggleUnit;

  /// 정보 아이콘을 누르면 그 위치와 설명
  final void Function(Rect anchor, String text) onInfoTap;

  /// 인보이스·아크 주소·라이트닝 주소면 그 종류를, 비트코인 주소면 [fallback]을 이름으로
  /// 온체인 트랜잭션 ID, 이 지갑 내역에 있으면 상세로 가는 링크
  Widget _buildTxRow(BuildContext context, String label, String txid, TextStyle valueStyle) {
    final known = context.read<TransactionProvider>().getTransactionRecord(walletId, txid) != null;
    return UnderlineButtonItemCard(
      label: label,
      underlineButtonLabel: known ? t.ark.movement.view_transaction : null,
      onTapUnderlineButton:
          known
              ? () => Navigator.pushNamed(
                context,
                AppRouteNames.transactionDetail,
                arguments: TransactionDetailRouteArgs(id: walletId, txHash: txid),
              )
              : null,
      child: CopyTextContainer(text: txid, textStyle: valueStyle),
    );
  }

  /// 이 지갑 주소면 '파생 경로 · 지갑 이름'
  String? _ownAddressSuffix(BuildContext context, String address) {
    final wallets = context.read<WalletProvider>();
    final path = wallets.derivationPathOf(walletId, address);
    return path == null ? null : '$path · ${wallets.getWalletById(walletId).name}';
  }

  String _destinationLabel(String value, String fallback) {
    return switch (PaymentRequest.parse(value, NetworkType.currentNetworkType).kind) {
      PaymentRequestKind.lightningInvoice => t.ark.movement.lightning_invoice,
      _ => fallback,
    };
  }

  @override
  Widget build(BuildContext context) {
    final transactions = context.watch<TransactionProvider>();
    final isExit = movement.kind == ArkMovementKind.exit;
    final activity = ArkActivity(
      movement,
      linkedTx: _record(transactions, movement.linkedTxid),
      relatedTxs: [
        if (isExit)
          for (final txid in movement.exitRelatedTxids)
            if (_record(transactions, txid) case final tx?) tx,
      ],
    );
    final colors = context.coconutColors;
    final valueStyle = CoconutTypography.body2_14_Number.setColor(colors.primaryText);
    final linkedTxid = movement.linkedTxid;
    final hasLinkedTx =
        linkedTxid != null && context.read<TransactionProvider>().getTransactionRecord(walletId, linkedTxid) != null;
    final copyable = <(String, String)>[
      if (isExit && movement.exitDestination != null) (t.ark.movement.received_on, movement.exitDestination!),
      // 내 온체인으로 옮긴 경우 보낸 곳이 곧 받은 주소
      if (!isExit)
        for (final destination in movement.sentToDestinations)
          (
            _destinationLabel(destination.value, activity.isMove ? t.ark.movement.received_on : t.ark.movement.sent_to),
            destination.value,
          ),
      for (final destination in movement.receivedOnDestinations)
        (_destinationLabel(destination.value, t.ark.movement.received_on), destination.value),
      // 보낸·받은 주소에 이미 인보이스가 있으면 다시 보여 주지 않음
      if (movement.lightningInvoice case final invoice?
          when ![
            ...movement.sentToDestinations,
            ...movement.receivedOnDestinations,
          ].any((d) => d.value.toLowerCase() == invoice.toLowerCase()))
        (t.ark.movement.lightning_invoice, invoice),
    ];
    final invoice =
        movement.lightningInvoice ??
        [
          ...movement.sentToDestinations,
          ...movement.receivedOnDestinations,
        ].map((destination) => destination.value).where((value) => value.toLowerCase().startsWith('ln')).firstOrNull;
    final memo =
        (invoice == null ? null : PaymentRequest.bolt11Description(invoice)) ??
        context.readArkProviderOrNull()?.paymentMemo(walletId, movement.id);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          HighlightedInfoArea(textList: DateTimeUtil.formatTimestamp(movement.timestamp)),
          CoconutLayout.spacing_500h,
          _buildAmount(context, activity.linkedTx != null ? activity.displayAmount : movement.effectiveBalanceSats),
          CoconutLayout.spacing_400h,
          CoconutLayout.spacing_400h,
          UnderlineButtonItemCard(
            label: t.ark.movement.status,
            child: Text(activityStatusText(activity), style: valueStyle),
          ),
          if (memo != null)
            UnderlineButtonItemCard(
              label: t.ark.movement.memo,
              child: Text(memo, style: CoconutTypography.body2_14.setColor(colors.primaryText)),
            ),
          // 받은 거래가 생긴 뒤에야 받은 금액과 수수료가 정해짐
          if (isExit) ...[
            if (activity.linkedTx != null) ...[
              UnderlineButtonItemCard(
                label: t.ark.movement.moved_amount,
                child: Text(formatSats(unit, activity.linkedTx!.amount), style: valueStyle),
              ),
              UnderlineButtonItemCard(
                label: t.ark.movement.exit_onchain_fee,
                child: Text(formatSats(unit, -activity.amount), style: valueStyle),
              ),
            ],
          ] else if (activity.isMove) ...[
            UnderlineButtonItemCard(
              label: t.ark.movement.moved_amount,
              child: Text(
                formatSats(
                  unit,
                  movement.kind == ArkMovementKind.board ? movement.effectiveBalanceSats : activity.linkedTx!.amount,
                ),
                style: valueStyle,
              ),
            ),
            if (-activity.amount - movement.offchainFeeSats > 0)
              UnderlineButtonItemCard(
                label: t.ark.movement.exit_onchain_fee,
                child: Text(formatSats(unit, -activity.amount - movement.offchainFeeSats), style: valueStyle),
              ),
            if (movement.offchainFeeSats > 0)
              UnderlineButtonItemCard(
                label: t.ark.movement.fee,
                child: Text(formatSats(unit, movement.offchainFeeSats), style: valueStyle),
              ),
          ] else
            UnderlineButtonItemCard(
              label: t.ark.movement.fee,
              child: Text(formatSats(unit, movement.offchainFeeSats), style: valueStyle),
            ),
          for (final (label, value) in copyable)
            UnderlineButtonItemCard(
              label: label,
              child: CopyTextContainer(
                text: value,
                textStyle: valueStyle,
                suffixText: _ownAddressSuffix(context, value),
                suffixTextStyle: CoconutTypography.body3_12_Number.setColor(colors.secondaryText),
              ),
            ),
          if (movement.kind == ArkMovementKind.exit) ...[
            if (movement.exitRelatedTxids.isNotEmpty)
              _buildTxRow(context, t.ark.movement.exit_fee_tx, movement.exitRelatedTxids.first, valueStyle),
            if (linkedTxid != null) _buildTxRow(context, t.ark.movement.exit_claim_tx, linkedTxid, valueStyle),
            if (movement.exitRelatedTxids.length > 1)
              _buildTxRow(context, t.ark.movement.exit_refund_tx, movement.exitRelatedTxids[1], valueStyle),
          ] else if (onchainTx != null && !hasLinkedTx)
            ..._buildOnchainTx(context, onchainTx!)
          else if (linkedTxid != null)
            _buildTxRow(context, t.ark.movement.onchain_tx, linkedTxid, valueStyle),
          _buildTxMemo(context, activity),
          // bark's own record, for support and debugging.
          UnderlineButtonItemCard(
            label: t.ark.movement.technical,
            showDivider: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail(
                  context,
                  t.ark.movement.movement_id,
                  ['${movement.id}'],
                  labelTrailing: ArkInfoIcon(onTap: (anchor) => onInfoTap(anchor, t.ark.movement.movement_id_tooltip)),
                ),
                if (movement.paymentHash case final hash?) _detail(context, t.ark.movement.payment_hash, [hash]),
                if (isExit)
                  _detail(context, t.ark.movement.exit_requested, [
                    formatSats(unit, -movement.effectiveBalanceSats),
                  ], copyable: false),
                if (isExit)
                  for (final destination in movement.sentToDestinations)
                    _detail(
                      context,
                      t.ark.movement.exit_output_address,
                      [destination.value],
                      labelTrailing: ArkInfoIcon(
                        onTap: (anchor) => onInfoTap(anchor, t.ark.movement.exit_output_address_tooltip),
                      ),
                    ),
                if (movement.inputVtxoIds.isNotEmpty)
                  _detail(context, t.ark.movement.vtxos_spent, movement.inputVtxoIds),
                if (movement.outputVtxoIds.isNotEmpty)
                  _detail(context, t.ark.movement.vtxos_created, movement.outputVtxoIds),
                if (movement.exitedVtxoIds.isNotEmpty)
                  _detail(context, t.ark.movement.vtxos_exited, movement.exitedVtxoIds),
              ],
            ),
          ),
          CoconutLayout.spacing_1000h,
        ],
      ),
    );
  }

  /// 나만 보는 거래 메모. 온체인 거래가 붙은 내역은 그 거래의 메모를 함께 씀
  Widget _buildTxMemo(BuildContext context, ArkActivity activity) {
    final memo = activity.memo;
    return UnderlineButtonItemCard(
      label: t.tx_memo,
      underlineButtonLabel: t.edit,
      onTapUnderlineButton: () {
        SingleTextFieldBottomSheet.show(
          context: context,
          title: t.tx_memo,
          screenName: AnalyticsScreenNames.arkMovementDetailEditMemoSheet,
          originalText: memo ?? '',
          completeButtonText: t.done,
          collapsedHeight: 300,
          onComplete: (text) async {
            final linkedTx = activity.linkedTx;
            final saved =
                linkedTx != null
                    ? context.read<TransactionProvider>().updateTransactionMemo(
                      walletId,
                      linkedTx.transactionHash,
                      text,
                    )
                    : await context.read<ArkProvider>().updateMovementMemo(walletId, movement.id, text);
            if (!saved && context.mounted) {
              CoconutToast.showToast(
                context: context,
                isVisibleIcon: true,
                iconPath: CommonStateIconPath.triangleWarning,
                text: t.toast.memo_update_failed,
                level: CoconutToastLevel.warning,
              );
            }
          },
        );
      },
      child: Text(
        memo?.isNotEmpty == true ? memo! : '-',
        style: CoconutTypography.body2_14_Number.setColor(context.coconutColors.primaryText),
      ),
    );
  }

  /// The offboard transaction as the transaction detail screen shows a transaction: its id with
  /// the explorer link and the inputs and outputs, the fee rate and the block.
  List<Widget> _buildOnchainTx(BuildContext context, TransactionRecord tx) {
    final colors = context.coconutColors;
    final valueStyle = CoconutTypography.body2_14_Number.setColor(colors.primaryText);
    final explorer = context.read<BlockExplorerProvider>();
    final destinations = movement.sentToDestinations.map((destination) => destination.value).toSet();
    final tip = context.read<NodeProvider>().currentBlockNotifier.value?.height;
    final confirmations = tx.blockHeight != 0 && tip != null ? tip - tx.blockHeight + 1 : null;
    return [
      UnderlineButtonItemCard(
        label: t.tx_id,
        underlineButtonLabel: t.view_mempool,
        onTapUnderlineButton:
            () => launchURL(
              context,
              explorer.explorerUrlFor(BlockExplorerPathType.tx, tx.transactionHash),
              openInApp: true,
              destination: ExternalLinkDestination.explorerTx,
            ),
        child: Column(
          children: [
            CopyTextContainer(text: tx.transactionHash, textStyle: valueStyle),
            CoconutLayout.spacing_300h,
            TransactionInputOutputCard(
              // A new card per record: the card can't take a changed transaction (it re-assigns a
              // late final field), and the explorer's record replaces bark's once it arrives.
              key: ObjectKey(tx),
              transaction: tx,
              // The card colours the outputs that aren't "own" as the recipients of a send; here
              // that's the movement's destinations, and the Ark server's change and anchors read
              // like change.
              isSameAddress: (address, _) => !destinations.contains(address),
              currentUnit: unit,
            ),
          ],
        ),
      ),
      UnderlineButtonItemCard(
        label: t.fee_rate,
        child: Text(
          tx.inputAddressList.isNotEmpty ? '${tx.feeRate.toLocaleString(maxDecimalPlaces: 2)} sats/vB' : '-',
          style: valueStyle,
        ),
      ),
      UnderlineButtonItemCard(
        label: t.block_num,
        underlineButtonLabel: tx.blockHeight != 0 ? t.view_mempool : '',
        onTapUnderlineButton:
            tx.blockHeight == 0
                ? null
                : () => launchURL(
                  context,
                  explorer.explorerUrlFor(BlockExplorerPathType.block, '${tx.blockHeight}'),
                  openInApp: true,
                  destination: ExternalLinkDestination.explorerBlock,
                ),
        child: Text(
          tx.blockHeight != 0
              ? t.transaction_detail_screen.confirmation(
                height: '${tx.blockHeight}',
                count: confirmations == null ? '' : '$confirmations ',
              )
              : '-',
          style: valueStyle,
        ),
      ),
    ];
  }

  /// The signed amount in the receiving or sending colour, as on the transaction detail screen.
  TransactionRecord? _record(TransactionProvider transactions, String? txid) =>
      txid == null ? null : transactions.getTransactionRecord(walletId, txid);

  Widget _buildAmount(BuildContext context, int amount) {
    final colors = context.coconutColors;
    final isIncoming = amount > 0;
    final color = amount == 0 ? colors.primaryText : (isIncoming ? colors.receivingColor : colors.sendingColor);
    final sign = amount == 0 ? '' : (isIncoming ? '+' : '-');
    final boldStyle = CoconutTypography.heading2_28_NumberBold.copyWith(fontSize: 24, color: color);
    final unitStyle = CoconutTypography.heading4_18_NumberBold.copyWith(color: color);
    final absAmount = unit.displayBitcoinAmount(amount.abs(), shouldCheckZero: true, defaultWhenZero: '0');
    return GestureDetector(
      onTap: onToggleUnit,
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children:
                  unit.isPrefixSymbol
                      ? [
                        Text(sign, style: boldStyle),
                        Text(unit.symbol, style: unitStyle),
                        CoconutLayout.spacing_50w,
                        Text(absAmount, style: boldStyle),
                      ]
                      : [
                        Text('$sign$absAmount', style: boldStyle),
                        CoconutLayout.spacing_50w,
                        Text(unit.symbol, style: unitStyle),
                      ],
            ),
          ),
          CoconutLayout.spacing_100h,
          FiatPrice(
            satoshiAmount: amount.abs(),
            textStyle: CoconutTypography.body2_14_Number.setColor(color.withValues(alpha: 0.7)),
          ),
        ],
      ),
    );
  }

  /// 값이 여럿이면 한 상자에 줄마다 하나씩
  Widget _detail(
    BuildContext context,
    String label,
    List<String> values, {
    Widget? labelTrailing,
    bool copyable = true,
  }) {
    final colors = context.coconutColors;
    final labelText = Text(label, style: CoconutTypography.body3_12.setColor(colors.secondaryText));
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (labelTrailing == null)
            labelText
          else
            Row(mainAxisSize: MainAxisSize.min, children: [labelText, labelTrailing]),
          CoconutLayout.spacing_200h,
          copyable
              ? CopyTextContainer(
                text: values.join('\n\n'),
                copyText: values.join('\n'),
                textStyle: CoconutTypography.body3_12_Number.setColor(colors.primaryText),
              )
              : Text(values.join('\n'), style: CoconutTypography.body3_12_Number.setColor(colors.primaryText)),
        ],
      ),
    );
  }
}
