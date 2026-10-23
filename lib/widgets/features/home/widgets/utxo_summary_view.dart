import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/utils/legible_color_util.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/activity_widget_views.dart' show UtxoStatusView;
import 'package:flutter/material.dart';

/// UTXO 요약. 전체 개수, 구간 비율 막대, 구간별 개수(비율)·금액 표. 호들 인사이트와 지갑 상세가 같이 쓴다.
class UtxoSummaryView extends StatelessWidget {
  static const _columnGap = 8.0;

  final HomeUtxoBuckets buckets;
  final List<Color> bucketColors;
  final String Function(int sats) amountText;

  /// 열리는 애니메이션 진행도. 개수·비율·금액·막대가 0에서 이 비율만큼 차오른다.
  final double shown;

  /// 위젯 키 앞부분. 화면마다 다른 키로 찾을 수 있게 한다.
  final String keyPrefix;

  const UtxoSummaryView({
    super.key,
    required this.buckets,
    required this.bucketColors,
    required this.amountText,
    required this.keyPrefix,
    this.shown = 1,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final total = buckets.total;
    final legibleColors = [for (final color in bucketColors) legibleOn(color, colors.homeSurface)];
    int counted(int value) => (value * shown).round();
    String bucketCountText(int index) {
      final percent = total == 0 ? 0.0 : buckets.counts[index] * 100 / total * shown;
      return '${counted(buckets.counts[index])} (${percent.toStringAsFixed(1)}%)';
    }

    return Column(
      key: Key('$keyPrefix-utxo'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.hodl_insights.total_utxos(count: counted(total)),
          key: Key('$keyPrefix-utxo-total'),
          style: CoconutTypography.body2_14_Bold.copyWith(color: colors.primaryText),
        ),
        CoconutLayout.spacing_300h,
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: ColoredBox(
              color: colors.surfaceMuted,
              child:
                  total == 0
                      ? const SizedBox.expand()
                      : LayoutBuilder(
                        builder:
                            (context, constraints) => Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                for (var i = 0; i < buckets.counts.length; i++)
                                  if (buckets.counts[i] > 0)
                                    Container(
                                      key: ValueKey('$keyPrefix-utxo-segment-$i'),
                                      width: constraints.maxWidth * buckets.counts[i] / total * shown,
                                      padding: const EdgeInsets.symmetric(horizontal: 1),
                                      child: ColoredBox(color: legibleColors[i]),
                                    ),
                              ],
                            ),
                      ),
            ),
          ),
        ),
        CoconutLayout.spacing_200h,
        Padding(
          padding: const EdgeInsets.only(left: 18),
          child: Text(
            t.hodl_insights.utxo_ranges_unit,
            key: Key('$keyPrefix-utxo-ranges-unit'),
            style: CoconutTypography.caption_10.copyWith(color: colors.secondaryTextStrong),
          ),
        ),
        CoconutLayout.spacing_100h,
        for (var i = 0; i < buckets.counts.length; i++) ...[
          if (i > 0) Divider(height: 1, color: colors.divider),
          Padding(
            key: ValueKey('$keyPrefix-utxo-row-$i'),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: legibleColors[i], shape: BoxShape.circle),
                ),
                CoconutLayout.spacing_200w,
                Expanded(
                  flex: 4,
                  child: FittedBox(
                    key: ValueKey('$keyPrefix-utxo-label-$i'),
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      UtxoStatusView.bucketLabels[i],
                      maxLines: 1,
                      style: CoconutTypography.body3_12_Number.copyWith(color: colors.secondaryTextStrong),
                    ),
                  ),
                ),
                const SizedBox(width: _columnGap),
                Expanded(
                  flex: 4,
                  child: FittedBox(
                    key: ValueKey('$keyPrefix-utxo-count-$i'),
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      bucketCountText(i),
                      maxLines: 1,
                      style: CoconutTypography.body3_12.copyWith(color: colors.primaryText),
                    ),
                  ),
                ),
                const SizedBox(width: _columnGap),
                Expanded(
                  flex: 4,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      buckets.amounts.length > i ? amountText(counted(buckets.amounts[i])) : '-',
                      maxLines: 1,
                      style: CoconutTypography.body3_12_Number.copyWith(color: colors.primaryText),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
