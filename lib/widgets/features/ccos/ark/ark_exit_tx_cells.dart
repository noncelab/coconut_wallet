import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_glow.dart';
import 'package:flutter/material.dart';

/// 서버 없이 출금의 거래 진행. 거래 하나에 칸 하나, 한 줄에 다 들어가지 않으면 VTXO 수명과 같은 막대
class ArkExitTxCells extends StatelessWidget {
  const ArkExitTxCells({super.key, required this.done, required this.total, required this.maxWidth});

  static const double _cellSize = 14;
  static const double _gap = 4;

  final int done;
  final int total;

  /// 칸을 놓을 수 있는 폭. 단계 줄이 높이를 미리 재서 LayoutBuilder를 쓸 수 없음
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoconutLayout.spacing_100h,
        Builder(
          builder: (context) {
            final perLine = ((maxWidth + _gap) / (_cellSize + _gap)).floor();
            if (total > perLine) {
              return ClipRRect(
                key: const Key('ark-exit-tx-bar'),
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 4,
                  backgroundColor: colors.divider,
                  color: colors.primaryText,
                ),
              );
            }
            return Wrap(
              key: const Key('ark-exit-tx-cells'),
              spacing: _gap,
              children: [
                for (var index = 0; index < total; index++)
                  if (index == done)
                    ArkGlow(
                      key: const Key('ark-exit-tx-sending'),
                      builder:
                          (context, strength) => DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: colors.primaryText, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: colors.primaryText.withValues(alpha: 0.15 + 0.45 * strength),
                                  blurRadius: 2 + 6 * strength,
                                ),
                              ],
                            ),
                            child: const SizedBox.square(dimension: _cellSize),
                          ),
                    )
                  else
                    Container(
                      width: _cellSize,
                      height: _cellSize,
                      decoration: BoxDecoration(
                        color: index < done ? colors.primaryText : null,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: index < done ? colors.primaryText : colors.tertiaryText),
                      ),
                    ),
              ],
            );
          },
        ),
        CoconutLayout.spacing_100h,
        Text(
          t.ark_wallet.exit_step_send_detail(done: done, total: total),
          style: CoconutTypography.body3_12.setColor(colors.secondaryText),
        ),
      ],
    );
  }
}
