import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/ark/ark_vtxo.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

String vtxoExpiryText(ArkVtxo vtxo, BlockTimestamp? tip) {
  if (tip == null) return t.ark.vtxo.at_block(height: vtxo.expiryHeight);
  final blocks = vtxo.expiryHeight - tip.height;
  final estimatedDate = tip.timestamp.toLocal().add(Duration(minutes: blocks * 10));
  final formattedDate = DateFormat(t.wallet_card_detail_screen.chart_date_format).format(estimatedDate);
  final formattedDateTime = '$formattedDate ${DateFormat('HH:mm').format(estimatedDate)}';
  return blocks <= 0 || estimatedDate.isBefore(DateTime.now())
      ? t.ark.vtxo.expiry_date(date: formattedDateTime)
      : t.ark.vtxo.estimated_expiry(date: formattedDateTime);
}

String? vtxoExpiryStatusText(ArkVtxo vtxo, BlockTimestamp? tip) {
  if (vtxo.isLocked) return t.ark.vtxo.state_locked;
  if (tip == null) return null;
  final blocks = vtxo.expiryHeight - tip.height;
  return blocks <= 0 ? t.ark.vtxo.refresh_due : t.ark.vtxo.in_blocks(count: blocks);
}

class VtxoPreviewList extends StatelessWidget {
  static const rows = 3;

  const VtxoPreviewList({
    super.key,
    required this.vtxos,
    required this.unit,
    required this.tip,
    required this.onSelected,
  });

  final List<ArkVtxo> vtxos;
  final BitcoinUnit unit;
  final BlockTimestamp? tip;
  final ValueChanged<ArkVtxo> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    if (vtxos.isEmpty) {
      return HomeWidgetCard(
        child: Center(child: Text(t.ark.vtxo.empty, style: CoconutTypography.body3_12.setColor(colors.secondaryText))),
      );
    }
    final shown = vtxos.take(rows).toList();
    final emptyRows = rows - shown.length;
    Widget divider() => Container(margin: const EdgeInsets.symmetric(horizontal: 16), height: 1, color: colors.divider);
    return HomeWidgetCard(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final rowHeight = (constraints.maxHeight - (rows - 1)) / rows;
          return Column(
            children: [
              for (final (index, vtxo) in shown.indexed) ...[
                if (index > 0) divider(),
                VtxoListRow(
                  vtxo: vtxo,
                  unit: unit,
                  tip: tip,
                  height: rowHeight,
                  cardStyle: false,
                  onPressed: () => onSelected(vtxo),
                ),
              ],
              if (emptyRows > 0) ...[
                divider(),
                SizedBox(
                  height: rowHeight * emptyRows + emptyRows - 1,
                  child: Center(
                    child: Text(
                      t.ark.vtxo.waiting_for_vtxos,
                      textAlign: TextAlign.center,
                      style: CoconutTypography.body3_12.setColor(colors.tertiaryText),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class VtxoListRow extends StatelessWidget {
  const VtxoListRow({
    super.key,
    required this.vtxo,
    required this.unit,
    required this.tip,
    required this.onPressed,
    this.height = 72,
    this.isSelecting = false,
    this.isSelected = false,
    this.cardStyle = true,
  });

  final ArkVtxo vtxo;
  final BitcoinUnit unit;
  final BlockTimestamp? tip;
  final VoidCallback onPressed;
  final double height;
  final bool isSelecting;
  final bool isSelected;
  final bool cardStyle;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final enabled = !isSelecting || !vtxo.isLocked;
    final statusText = vtxoExpiryStatusText(vtxo, tip);
    final isRefreshDue = tip != null && vtxo.expiryHeight - tip!.height <= 0;
    final selectionIcon = SvgPicture.asset(
      CommonFormIconPath.circleCheck,
      width: 20,
      height: 20,
      colorFilter: ColorFilter.mode(
        isSelected ? colors.borderStrong : colors.borderStrong.withValues(alpha: 0.2),
        BlendMode.srcIn,
      ),
    );
    final row =
        cardStyle
            ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(CoconutStyles.radius_300),
                border: Border.all(
                  color: isSelecting && isSelected ? colors.borderStrong : Colors.transparent,
                  width: 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isSelecting) ...[selectionIcon, const SizedBox(width: 8)],
                      Expanded(
                        child: Text(
                          vtxoExpiryText(vtxo, tip),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: CoconutTypography.body3_12_Number.setColor(colors.secondaryText).copyWith(height: 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        unit.displayBitcoinAmount(vtxo.amountSats),
                        textAlign: TextAlign.right,
                        style: CoconutTypography.heading4_18_NumberBold.setColor(colors.primaryText),
                      ),
                    ],
                  ),
                  if (statusText != null) ...[
                    const SizedBox(height: 2),
                    Padding(
                      padding: EdgeInsets.only(left: isSelecting ? 28 : 0),
                      child: Row(
                        children: [
                          if (isRefreshDue) ...[
                            SvgPicture.asset(
                              CommonStateIconPath.circleWarning,
                              width: 14,
                              height: 14,
                              colorFilter: ColorFilter.mode(colors.secondaryText, BlendMode.srcIn),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              statusText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: CoconutTypography.body2_14_Number
                                  .setColor(colors.secondaryText)
                                  .copyWith(height: 1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            )
            : SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    if (isSelecting) ...[selectionIcon, const SizedBox(width: 8)],
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vtxoExpiryText(vtxo, tip),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: CoconutTypography.body3_12.setColor(colors.primaryText),
                          ),
                          if (statusText != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              statusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: CoconutTypography.caption_10.setColor(colors.tertiaryText),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      unit.displayBitcoinAmount(vtxo.amountSats, withUnit: true),
                      textAlign: TextAlign.right,
                      style: CoconutTypography.body2_14_NumberBold.setColor(colors.primaryText),
                    ),
                  ],
                ),
              ),
            );
    final button =
        cardStyle
            ? ShrinkAnimationButton(
              onPressed: enabled ? onPressed : () {},
              isActive: enabled,
              defaultColor: colors.surface,
              disabledColor: colors.surface,
              pressedOverlayColor: colors.surfacePressOverlay,
              borderRadius: CoconutStyles.radius_300,
              borderWidth: 0,
              child: row,
            )
            : HomePressableRow(onTap: enabled ? onPressed : () {}, child: row);
    return Opacity(opacity: enabled ? 1 : 0.4, child: button);
  }
}

class VtxoListSkeleton extends StatelessWidget {
  const VtxoListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Shimmer.fromColors(
      baseColor: colors.surfaceSkeletonBase,
      highlightColor: colors.surfaceSkeletonHighlight,
      child: Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              height: 88,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(CoconutStyles.radius_300),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 96, height: 12, color: Colors.white),
                        const SizedBox(height: 8),
                        Container(width: 56, height: 10, color: Colors.white),
                      ],
                    ),
                  ),
                  Container(width: 76, height: 14, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
