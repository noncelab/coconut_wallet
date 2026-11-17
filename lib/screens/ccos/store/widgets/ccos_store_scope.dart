import 'package:coconut_wallet/design_system/theme/coconut_theme_extension.dart';
import 'package:coconut_wallet/widgets/features/ccos/coconut_open_store_backdrop.dart';
import 'package:flutter/material.dart';

/// 오픈 스토어 화면은 앱 테마와 상관없이 소개 화면과 같은 밝은 모습
class CcosStoreScope extends StatelessWidget {
  const CcosStoreScope({super.key, required this.child});

  /// 소개 화면 카드와 같은 반투명 흰색
  static const Color cardColor = Color(0x80FFFFFF);

  /// 카드 안 썸네일 영역. 카드보다 조금 더 밝게
  static const Color thumbnailColor = Color(0x80FFFFFF);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        brightness: Brightness.light,
        colorScheme: theme.colorScheme.copyWith(brightness: Brightness.light),
        extensions: [CoconutThemeExtension.light()],
      ),
      child: Stack(fit: StackFit.expand, children: [const CoconutOpenStoreBackdrop(), child]),
    );
  }
}
