import 'package:coconut_design_system/coconut_design_system.dart'
    hide CoconutAppBar, CoconutToolTip, CoconutTooltipType, CoconutTooltipState, CoconutToast, CoconutPopup;
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/widgets/features/ark/ark_texts.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/model/ark/ark_movement.dart';
import 'package:coconut_wallet/screens/ark/ark_movement_detail_screen.dart';
import 'package:coconut_wallet/model/wallet/wallet_activity.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/ark/ark_vtxo.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ark/ark_unlock_flow.dart';
import 'package:coconut_wallet/screens/ark/vtxo_refresh_flow.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/copy_text_container.dart';
import 'package:coconut_wallet/widgets/common/clipper/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/common/info/highlighted_info_area.dart';
import 'package:coconut_wallet/widgets/features/transaction/card/underline_button_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

/// One VTXO, laid out like the UTXO detail: its expiry where a UTXO shows its date, the amount,
/// then its id, state, expiry (with a refresh of just this VTXO), type and exit depth. Reads the
/// cache, so it stays current while the Ark wallet syncs and works while it is locked.
class VtxoDetailScreen extends StatefulWidget {
  const VtxoDetailScreen({super.key, required this.id, required this.vtxo});

  final int id;

  /// The VTXO as it was tapped; the cached one with the same id replaces it while it exists.
  final ArkVtxo vtxo;

  @override
  State<VtxoDetailScreen> createState() => _VtxoDetailScreenState();
}

class _VtxoDetailScreenState extends State<VtxoDetailScreen> {
  final GlobalKey _tooltipIconKey = GlobalKey();
  Offset _tooltipIconPosition = Offset.zero;
  Size _tooltipIconSize = Size.zero;
  bool _isTooltipVisible = false;
  final GlobalKey _exitDepthInfoKey = GlobalKey();
  Rect? _exitDepthAnchor;
  bool _isRefreshing = false;
  late BitcoinUnit _unit;

  @override
  void initState() {
    super.initState();
    _unit = context.read<PreferenceProvider>().currentUnit;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _tooltipIconKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !mounted) return;
      setState(() {
        _tooltipIconPosition = box.localToGlobal(Offset.zero);
        _tooltipIconSize = box.size;
      });
    });
  }

  void _toggleUnit() => setState(() => _unit = _unit.next);

  void _toggleTooltip() {
    final box = _tooltipIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() {
      _tooltipIconPosition = box.localToGlobal(Offset.zero);
      _tooltipIconSize = box.size;
      _isTooltipVisible = !_isTooltipVisible;
    });
  }

  Future<void> _refresh(ArkVtxo vtxo) async {
    if (!await openArkWalletForSession(context, widget.id, userInitiated: true) || !mounted) return;
    setState(() => _isRefreshing = true);
    try {
      await refreshVtxosWithConfirmation(context, walletId: widget.id, ids: [vtxo.id], unit: _unit);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          () => setState(() {
            _isTooltipVisible = false;
            _exitDepthAnchor = null;
          }),
      child: Stack(
        children: [
          _buildScaffold(context),
          if (_isTooltipVisible) _buildTooltip(context),
          if (_exitDepthAnchor case final anchor?) _buildExitDepthTooltip(context, anchor),
        ],
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final colors = context.coconutColors;
    final cached = context.select<ArkProvider, ArkVtxo?>((ark) {
      for (final vtxo in ark.snapshot(widget.id)?.vtxos ?? const <ArkVtxo>[]) {
        if (vtxo.id == widget.vtxo.id) return vtxo;
      }
      return null;
    });
    final vtxo = cached ?? widget.vtxo;
    final createdAt = context.readArkProviderOrNull()?.vtxoHistory(widget.id, vtxo.id).firstOrNull?.timestamp;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(
        title: t.ark.vtxo.detail_title,
        context: context,
        onBackPressed: () => Navigator.pop(context),
        actionButtonList: [
          CoconutAppBarActionButton(
            key: _tooltipIconKey,
            icon: SvgPicture.asset(
              CommonStateIconPath.circleInfo,
              width: 24,
              height: 24,
              colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
            ),
            onPressed: _toggleTooltip,
          ),
        ],
      ),
      body: ValueListenableBuilder<BlockTimestamp?>(
        valueListenable: context.read<NodeProvider>().currentBlockNotifier,
        builder: (context, tip, _) {
          final blocks = _blocksLeft(vtxo.expiryHeight, tip?.height);
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 20),
                if (createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 28),
                    child: HighlightedInfoArea(
                      textList: DateTimeUtil.formatTimestamp(createdAt),
                      textStyle: CoconutTypography.body2_14_Number,
                    ),
                  ),
                _buildAmount(vtxo),
                Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: Center(
                    child: GestureDetector(onTap: _toggleUnit, child: FiatPrice(satoshiAmount: vtxo.amountSats)),
                  ),
                ),
                CoconutLayout.spacing_800h,
                _buildRows(vtxo, blocks, isInWallet: cached != null),
                _buildHistory(vtxo),
                CoconutLayout.spacing_1000h,
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAmount(ArkVtxo vtxo) {
    final colors = context.coconutColors;
    return GestureDetector(
      onTap: _toggleUnit,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Center(
          child: FittedBox(
            child: BitcoinAmountUnit(
              currentUnit: _unit,
              unitStyle: CoconutTypography.heading4_18_Number.setColor(colors.primaryText),
              child: Text(
                _unit.displayBitcoinAmount(vtxo.amountSats),
                style: CoconutTypography.heading2_28_NumberBold.setColor(colors.primaryText),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRows(ArkVtxo vtxo, String? blocks, {required bool isInWallet}) {
    final hasHistory = _hasRefreshHistory(vtxo);
    final valueStyle = CoconutTypography.body2_14_Number.setColor(context.coconutColors.primaryText);
    // A VTXO that is still in the wallet and not held by an operation can be refreshed alone.
    final canRefresh = isInWallet && !vtxo.isLocked && !_isRefreshing;
    return Column(
      children: [
        UnderlineButtonItemCard(
          label: t.ark.vtxo.vtxo_id,
          child: CopyTextContainer(text: vtxo.id, textStyle: valueStyle),
        ),
        UnderlineButtonItemCard(
          label: t.ark.vtxo.state,
          child: _VtxoStateChip(
            isLocked: vtxo.isLocked,
            isLightning: vtxo.kind.startsWith('ServerHtlc'),
            isRefreshing: context.readArkProviderOrNull()?.isRefreshingVtxo(vtxo.id) ?? false,
          ),
        ),
        UnderlineButtonItemCard(
          label: t.ark.vtxo.expiry,
          underlineButtonLabel: canRefresh ? t.ark.vtxo.refresh_button : '',
          onTapUnderlineButton: canRefresh ? () => _refresh(vtxo) : null,
          child: Text(
            blocks == null
                ? t.ark.vtxo.at_block(height: vtxo.expiryHeight)
                : '${t.ark.vtxo.at_block(height: vtxo.expiryHeight)} · $blocks',
            style: valueStyle,
          ),
        ),
        UnderlineButtonItemCard(
          label: t.ark.vtxo.exit_depth,
          showDivider: hasHistory,
          labelTrailing: GestureDetector(
            key: _exitDepthInfoKey,
            behavior: HitTestBehavior.opaque,
            onTap: _toggleExitDepthTooltip,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.info_outline_rounded, color: context.coconutColors.iconSecondary, size: 18),
            ),
          ),
          child: Text('${vtxo.exitDepth}', style: valueStyle),
        ),
      ],
    );
  }

  bool _hasRefreshHistory(ArkVtxo vtxo) =>
      (context.readArkProviderOrNull()?.vtxoHistory(widget.id, vtxo.id) ?? const <ArkMovement>[]).any(
        (movement) => movement.kind == ArkMovementKind.refresh,
      );

  void _toggleExitDepthTooltip() {
    if (_exitDepthAnchor != null) {
      setState(() => _exitDepthAnchor = null);
      return;
    }
    final box = _exitDepthInfoKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    setState(() => _exitDepthAnchor = box.localToGlobal(Offset.zero) & box.size);
  }

  Widget _buildExitDepthTooltip(BuildContext context, Rect anchor) {
    final style = CoconutTypography.body3_12
        .setColor(context.coconutColors.popoverText)
        .merge(const TextStyle(height: 1.3));
    final text =
        LocaleSettings.currentLocale == AppLocale.ko
            ? TextUtils.preventLineBreakInsideWords(t.ark.vtxo.exit_depth_tooltip)
            : t.ark.vtxo.exit_depth_tooltip;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: MediaQuery.sizeOf(context).width * 0.6);
    final width = painter.width + 32;
    painter.dispose();
    final arrowHeight = LeftTriangleBubbleClipper.arrowTip.dy + 10;
    return Positioned(
      top: anchor.bottom - LeftTriangleBubbleClipper.arrowTip.dy + 2,
      left: anchor.center.dx - LeftTriangleBubbleClipper.arrowTip.dx,
      child: SizedBox(
        width: width,
        child: CoconutToolTip(
          width: width,
          isBubbleClipperSideLeft: true,
          tooltipType: CoconutTooltipType.placement,
          isPlacementTooltipVisible: true,
          backgroundColor: context.coconutColors.popoverBackground,
          padding: EdgeInsets.fromLTRB(16, arrowHeight + 12, 16, 12),
          richText: RichText(text: TextSpan(text: text, style: style)),
          onTapRemove: () => setState(() => _exitDepthAnchor = null),
        ),
      ),
    );
  }

  Widget _buildHistory(ArkVtxo vtxo) {
    final ark = context.readArkProviderOrNull();
    final history = ark?.vtxoHistory(widget.id, vtxo.id) ?? const <ArkMovement>[];
    if (!history.any((movement) => movement.kind == ArkMovementKind.refresh)) return const SizedBox.shrink();
    final colors = context.coconutColors;
    final lineColor = colors.feeBumpingHistoryLine;
    final textScaler = MediaQuery.textScalerOf(context);
    final chipWidth =
        [t.ark.vtxo.history_refresh, t.ark.vtxo.history_received]
            .map(
              (label) =>
                  (TextPainter(
                    text: TextSpan(
                      text: label,
                      style: const TextStyle(
                        fontFamily: CoconutTypography.kTextFontFamily,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    textScaler: textScaler,
                    textDirection: TextDirection.ltr,
                  )..layout()).width,
            )
            .reduce((a, b) => a > b ? a : b) +
        18;
    final refreshes = history.where((movement) => movement.kind == ArkMovementKind.refresh).toList();
    final origins = history.where((movement) => movement.kind != ArkMovementKind.refresh).toList();
    final nodes = [...refreshes, if (origins.length == 1) origins.single];
    final isMerged = origins.length > 1;
    final nodeCount = nodes.length + (isMerged ? 1 : 0);
    final textStyle = CoconutTypography.body2_14_Number.setColor(colors.primaryText);

    Widget node({
      required int index,
      required String label,
      required String text,
      required VoidCallback? onTap,
      Key? key,
    }) {
      final isLast = index == nodeCount - 1;
      return Row(
        key: key,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  Container(width: 1, height: isLast ? 16 : 40, color: lineColor),
                  if (isLast) SizedBox(width: 1, height: isMerged ? 16 : 24),
                ],
              ),
              Container(width: 7, height: 7, decoration: BoxDecoration(color: lineColor, shape: BoxShape.circle)),
            ],
          ),
          const SizedBox(width: 8),
          CoconutChip(
            minWidth: chipWidth,
            color: index == 0 ? colors.primaryText : colors.surface,
            label: label,
            labelColor: index == 0 ? colors.background : colors.primaryText,
            isSelected: index == 0,
            onTap: onTap ?? () {},
          ),
          CoconutLayout.spacing_200w,
          Expanded(child: Text(text, style: textStyle)),
        ],
      );
    }

    String dateOf(ArkMovement movement) => DateTimeUtil.formatTimestamp(movement.timestamp).join(' ');
    void open(ArkMovement movement) => openWalletActivityDetail(context, widget.id, ArkActivity(movement));

    return UnderlineButtonItemCard(
      label: t.ark.vtxo.history_title,
      showDivider: false,
      child: Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 7, child: Center(child: Container(width: 1, height: 4, color: lineColor))),
            for (final (index, movement) in nodes.indexed)
              node(
                key: Key('vtxo-history-${movement.id}'),
                index: index,
                label:
                    movement.kind == ArkMovementKind.refresh ? t.ark.vtxo.history_refresh : t.ark.vtxo.history_received,
                text: [
                  dateOf(movement),
                  movement.kind == ArkMovementKind.refresh
                      ? t.ark.vtxo.history_fee(fee: formatSats(_unit, movement.offchainFeeSats))
                      : formatSats(_unit, movement.effectiveBalanceSats),
                ].join(' · '),
                onTap: () => open(movement),
              ),
            if (isMerged) ...[
              node(
                key: const Key('vtxo-history-merged'),
                index: nodes.length,
                label: t.ark.vtxo.history_received,
                text: [
                  t.ark.vtxo.history_merged(count: origins.length),
                  formatSats(_unit, origins.fold(0, (sum, movement) => sum + movement.effectiveBalanceSats)),
                ].join(' · '),
                onTap: null,
              ),
              for (final movement in origins)
                GestureDetector(
                  key: Key('vtxo-history-${movement.id}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => open(movement),
                  child: Padding(
                    padding: EdgeInsets.only(left: 7 + 8 + chipWidth + 8, top: 4, bottom: 4),
                    child: Text(
                      '•  ${dateOf(movement)} · ${formatSats(_unit, movement.effectiveBalanceSats)}',
                      style: CoconutTypography.body2_14_Number.setColor(colors.secondaryText),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTooltip(BuildContext context) {
    final colors = context.coconutColors;
    final anchor = _tooltipIconPosition & _tooltipIconSize;
    return Positioned(
      top: _tooltipIconPosition.dy + _tooltipIconSize.height - 10,
      right: RightTriangleBubbleClipper.rightOffsetForAnchor(
        viewportWidth: MediaQuery.sizeOf(context).width,
        anchor: anchor,
      ),
      child: GestureDetector(
        onTap: () => setState(() => _isTooltipVisible = false),
        child: ClipPath(
          clipper: RightTriangleBubbleClipper(),
          child: Container(
            width: MediaQuery.sizeOf(context).width * 0.68,
            padding: const EdgeInsets.only(top: 28, left: 16, right: 16, bottom: 12),
            color: colors.popoverBackground,
            child: Text(
              t.ark.vtxo.detail_tooltip,
              style: CoconutTypography.body3_12.copyWith(color: colors.popoverText, height: 1.3),
            ),
          ),
        ),
      ),
    );
  }

  static String? _blocksLeft(int height, int? tipHeight) {
    if (tipHeight == null) return null;
    final left = height - tipHeight;
    return left <= 0 ? t.ark.vtxo.expired : t.ark.vtxo.in_blocks(count: left);
  }
}

/// Spendable or locked, in the UTXO detail's lock-status chip.
class _VtxoStateChip extends StatelessWidget {
  const _VtxoStateChip({required this.isLocked, this.isLightning = false, this.isRefreshing = false});

  final bool isLocked;
  final bool isLightning;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    final color = context.coconutColors.primaryText;
    return Row(
      children: [
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(CoconutStyles.radius_300),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  isRefreshing
                      ? CommonActionIconPath.arrowReload
                      : isLightning
                      ? CommonStateIconPath.lightning
                      : isLocked
                      ? CommonSecurityIconPath.lock
                      : CommonSecurityIconPath.unlock,
                  width: 14,
                  height: 14,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                ),
                CoconutLayout.spacing_100w,
                Flexible(
                  child: Text(
                    isRefreshing
                        ? t.ark.vtxo.state_refreshing
                        : isLightning
                        ? t.ark.vtxo.state_lightning
                        : isLocked
                        ? t.ark.vtxo.state_locked
                        : t.ark.vtxo.spendable,
                    style: CoconutTypography.body3_12.copyWith(color: color, height: 1.2),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
