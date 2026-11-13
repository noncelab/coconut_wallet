import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/widgets/common/icon/coconut_logo_icon.dart';
import 'package:coconut_wallet/widgets/common/text/keep_words.dart';
import 'package:coconut_wallet/widgets/common/text/label_value_row.dart';

/// 앱이 보낼 알림 내용의 예시. 머리 줄(앱 아이콘·앱 이름·시각) 아래에 제목과 본문을 가로 전체로 둔다.
/// 실제 알림 내용과 같은 글을 넘긴다. 기기마다 잠금 화면 모양·노출 설정이 달라 그 모양을 그대로 보장하지는 않는다.
class NotificationPreview extends StatelessWidget {
  final String title;
  final String body;

  /// 본문 글의 key(테스트에서 본문만 찾을 때)
  final Key? bodyKey;

  const NotificationPreview({super.key, required this.title, required this.body, this.bodyKey});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final meta = CoconutTypography.caption_10.copyWith(color: colors.tertiaryText);
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: colors.homeBackground, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const CoconutLogoIcon(size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: LabelValueRow(
                    label: t.license_bottom_sheet.coconut_wallet,
                    labelStyle: meta,
                    value: t.relative_time.just_now,
                    valueStyle: meta,
                    gap: 8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 줄바꿈 막기는 보이는 글에만 하고, 화면 읽기에는 원문을 넘긴다.
            Text(
              keepWords(title),
              semanticsLabel: title,
              style: CoconutTypography.body3_12_Bold.copyWith(color: colors.primaryText),
            ),
            const SizedBox(height: 2),
            Text(
              keepWords(body),
              key: bodyKey,
              semanticsLabel: body,
              style: CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong),
            ),
          ],
        ),
      ),
    );
  }
}
