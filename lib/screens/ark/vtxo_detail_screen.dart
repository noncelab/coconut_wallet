import 'package:coconut_design_system/coconut_design_system.dart'
    hide CoconutAppBar, CoconutToolTip, CoconutTooltipType, CoconutTooltipState, CoconutToast, CoconutPopup;
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
      onTap: () => setState(() => _isTooltipVisible = false),
      child: Stack(children: [_buildScaffold(context), if (_isTooltipVisible) _buildTooltip(context)]),
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
                Padding(
                  padding: const EdgeInsets.only(bottom: 28),
                  child: HighlightedInfoArea(
                    textList: [t.ark.vtxo.at_block(height: vtxo.expiryHeight), if (blocks != null) blocks],
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
        UnderlineButtonItemCard(label: t.ark.vtxo.kind, child: Text(vtxo.kind, style: valueStyle)),
        UnderlineButtonItemCard(
          label: t.ark.vtxo.exit_depth,
          showDivider: false,
          child: Text('${vtxo.exitDepth}', style: valueStyle),
        ),
      ],
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
  const _VtxoStateChip({required this.isLocked, this.isRefreshing = false});

  final bool isLocked;
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
