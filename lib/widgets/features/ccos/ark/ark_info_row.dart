import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/utils/clipboard_copy_util.dart';
import 'package:coconut_wallet/widgets/common/info/info_section.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_info_tooltip.dart';
import 'package:flutter/material.dart';

/// 왼쪽 이름, 오른쪽 값. 값은 오른쪽 정렬로 줄바꿈
class ArkInfoRow extends StatelessWidget {
  const ArkInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.isNumber = false,
    this.valueColor,
    this.detail,
    this.onTap,
    this.labelTooltip,
  });

  /// 있으면 줄 전체를 눌러 고를 수 있고 값 뒤에 화살표. 보조 글자는 화살표까지 포함한 오른쪽 끝에 맞춤
  final VoidCallback? onTap;

  final String label;
  final String value;

  /// 값 아래 붙는 보조 정보(예: 지갑 잔액)
  final String? detail;

  /// 있으면 이름 옆 인포 아이콘, 누르면 지갑 정보 화면과 같은 말풍선
  final String? labelTooltip;
  final bool isNumber;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final valueStyle = (isNumber ? CoconutTypography.body2_14_Number : CoconutTypography.body2_14).setColor(
      valueColor ?? colors.primaryText,
    );
    final labelText = Text(label, style: CoconutTypography.body2_14.setColor(colors.secondaryText));
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          labelText,
          if (labelTooltip != null) ArkInfoTooltip(message: labelTooltip!, iconKey: const Key('ark-info-row-tooltip')),
          CoconutLayout.spacing_400w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (onTap == null)
                  Text(value, textAlign: TextAlign.right, style: valueStyle)
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(child: Text(value, textAlign: TextAlign.right, style: valueStyle)),
                      CoconutLayout.spacing_200w,
                      const InfoRowArrow(),
                    ],
                  ),
                if (detail != null) ...[
                  Text(
                    detail!,
                    textAlign: TextAlign.right,
                    style: CoconutTypography.body3_12_Number.setColor(colors.secondaryText),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: row);
  }
}

/// [ArkInfoRow] 줄들을 담는 상자(출금 완료·거래 상세·갱신과 같은 모양)
class ArkInfoBox extends StatelessWidget {
  const ArkInfoBox({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(CoconutStyles.radius_400),
      color: context.coconutColors.surface,
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}

/// 누르면 값을 복사하는 줄, 주소·거래 ID처럼 긴 값. 값은 오른쪽 정렬, [detail]은 아래 보조 글자
class ArkCopyRow extends StatelessWidget {
  const ArkCopyRow({super.key, required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => ClipboardCopyUtil.copyWithToast(context, text: value),
    child: ArkInfoRow(label: label, value: value, isNumber: true, detail: detail),
  );
}
