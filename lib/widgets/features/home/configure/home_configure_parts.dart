import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// 위젯·바로가기 설정 시트의 공통 틀: 닫기 앱 바, 제목·설명, 설정 목록, 하단 고정 버튼
class HomeConfigureSheetLayout extends StatelessWidget {
  final String title;
  final String heading;
  final String description;
  final List<Widget> children;
  final String buttonText;
  final Key buttonKey;
  final bool isButtonActive;
  final VoidCallback onSubmit;
  final ScrollController? scrollController;
  final bool showIntro;

  const HomeConfigureSheetLayout({
    super.key,
    required this.title,
    required this.heading,
    required this.description,
    required this.children,
    required this.buttonText,
    required this.buttonKey,
    required this.onSubmit,
    this.isButtonActive = true,
    this.scrollController,
    this.showIntro = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        child: Scaffold(
          backgroundColor: colors.surfaceBottomSheet,
          appBar: CoconutAppBar.build(
            context: context,
            isBottom: true,
            backgroundColor: colors.surfaceBottomSheet,
            title: title,
            onBackPressed: () => Navigator.pop(context),
          ),
          body: Stack(
            children: [
              SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(0, 16, 0, 140),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showIntro)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              heading,
                              style: CoconutTypography.heading4_18_Bold.copyWith(color: colors.primaryText),
                            ),
                            CoconutLayout.spacing_200h,
                            Text(description, style: CoconutTypography.body2_14.copyWith(color: colors.secondaryText)),
                          ],
                        ),
                      ),
                    ...children,
                  ],
                ),
              ),
              FixedBottomButton(
                buttonKey: buttonKey,
                text: buttonText,
                isActive: isButtonActive,
                surroundingsColor: colors.surfaceBottomSheet,
                onButtonClicked: onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeConfigureSectionTitle extends StatelessWidget {
  final String text;

  const HomeConfigureSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 8),
      child: Text(text, style: CoconutTypography.body1_16_Bold.copyWith(color: context.coconutColors.primaryText)),
    );
  }
}

class HomeConfigureCheckRow extends StatelessWidget {
  final String label;
  final String? note;
  final bool checked;
  final bool enabled;
  final bool showDivider;
  final VoidCallback onTap;

  const HomeConfigureCheckRow({
    super.key,
    required this.label,
    required this.checked,
    required this.onTap,
    this.note,
    this.enabled = true,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final color = enabled ? colors.primaryText : colors.tertiaryText;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(border: showDivider ? Border(bottom: BorderSide(color: colors.divider)) : null),
        child: Row(
          children: [
            Icon(checked ? CupertinoIcons.checkmark_square : CupertinoIcons.square, color: color, size: 24),
            CoconutLayout.spacing_300w,
            Flexible(child: Text(label, style: CoconutTypography.body2_14.copyWith(color: color))),
            if (note != null) ...[
              CoconutLayout.spacing_200w,
              Text(note!, style: CoconutTypography.body2_14.copyWith(color: colors.tertiaryText)),
            ],
          ],
        ),
      ),
    );
  }
}
