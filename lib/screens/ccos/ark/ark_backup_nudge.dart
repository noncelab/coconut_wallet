import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

/// 아크 지갑 홈의 안내 카드 하나. 제목, 한 줄 설명, 오른쪽 버튼
class ArkNudgeCard extends StatelessWidget {
  const ArkNudgeCard({
    super.key,
    required this.title,
    required this.line,
    required this.buttonText,
    required this.onPressed,
  });

  final String title;
  final String line;
  final String buttonText;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText)),
                  CoconutLayout.spacing_100h,
                  Text(line, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
                ],
              ),
            ),
            CoconutLayout.spacing_300w,
            CoconutButton(
              text: buttonText,
              height: 36,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              onPressed: onPressed,
              backgroundColor: colors.primaryText,
              foregroundColor: colors.background,
            ),
          ],
        ),
      ),
    );
  }
}

/// 새로 만든 아크 지갑의 백업 안내. 백업을 마칠 때까지 보임
class ArkBackupNudge extends StatelessWidget {
  const ArkBackupNudge({super.key, required this.onBackup});

  final VoidCallback onBackup;

  @override
  Widget build(BuildContext context) => ArkNudgeCard(
    title: t.ark_wallet.backup_title,
    line: t.ark_wallet.backup_line,
    buttonText: t.ark_wallet.backup_button,
    onPressed: onBackup,
  );
}
