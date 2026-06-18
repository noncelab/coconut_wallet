import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

class RoleDescriptionCard extends StatelessWidget {
  final String description;
  final Color themeColor;
  final Color backgroundColor;
  final RegExp? highlightPattern;

  const RoleDescriptionCard({
    super.key,
    required this.description,
    required this.themeColor,
    required this.backgroundColor,
    this.highlightPattern,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: themeColor.withValues(alpha: 0.5), width: 1),
      ),
      child: RichText(
        text: TextSpan(
          style: CoconutTypography.body3_12.setColor(themeColor),
          children: _buildTextSpans(description, highlightPattern, themeColor),
        ),
      ),
    );
  }

  List<TextSpan> _buildTextSpans(String text, RegExp? pattern, Color textColor) {
    if (pattern == null) return [TextSpan(text: text)];

    final newlineIndex = text.indexOf('\n');
    final targetText = newlineIndex == -1 ? text : text.substring(0, newlineIndex);
    final tail = newlineIndex == -1 ? '' : text.substring(newlineIndex);

    final List<TextSpan> spans = [];
    final matches = pattern.allMatches(targetText);

    if (matches.isEmpty) {
      spans.add(TextSpan(text: targetText));
    } else {
      int lastMatchEnd = 0;
      for (final match in matches) {
        if (match.start > lastMatchEnd) {
          spans.add(TextSpan(text: targetText.substring(lastMatchEnd, match.start)));
        }
        spans.add(TextSpan(text: match.group(0), style: CoconutTypography.body3_12_Bold.setColor(textColor)));
        lastMatchEnd = match.end;
      }
      if (lastMatchEnd < targetText.length) {
        spans.add(TextSpan(text: targetText.substring(lastMatchEnd)));
      }
    }

    if (tail.isNotEmpty) {
      spans.add(TextSpan(text: tail));
    }

    return spans;
  }
}

/// 역할 별 스타일 및 설정 정의
class RoleDescriptionTheme {
  final Color themeColor;
  final Color backgroundColor;
  final RegExp highlightPattern;

  const RoleDescriptionTheme({required this.themeColor, required this.backgroundColor, required this.highlightPattern});

  static RoleDescriptionTheme get cosigner => RoleDescriptionTheme(
    themeColor: CoconutColors.purple,
    backgroundColor: CoconutColors.purple.withValues(alpha: 0.2),
    highlightPattern: RegExp(
      '${t.taproot.role_description_card.signer}|${t.taproot.role_description_card.co_signer}',
      caseSensitive: false,
    ),
  );

  static RoleDescriptionTheme get heir => RoleDescriptionTheme(
    themeColor: CoconutColors.sky,
    backgroundColor: CoconutColors.sky.withValues(alpha: 0.2),
    highlightPattern: RegExp(t.taproot.role_description_card.heir, caseSensitive: false),
  );
}
