import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter/material.dart';

/// 단일 입력 필드 + 하단 [FixedBottomButton]
/// 키보드 유무에 따라 본문 높이만 조절
class SingleFieldFixedBottomSheetBody extends StatelessWidget {
  const SingleFieldFixedBottomSheetBody({
    super.key,
    required this.textField,
    required this.isCompleteEnabled,
    required this.onComplete,
    this.completeLabel,
    this.collapsedHeight = 240,
    this.fieldHorizontalPadding = 16,
    this.keyboardContentHeight = 120,
  });

  final Widget textField;
  final bool isCompleteEnabled;
  final VoidCallback onComplete;
  final String? completeLabel;
  final double collapsedHeight;
  final double fieldHorizontalPadding;
  final double keyboardContentHeight;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final textScale = (MediaQuery.textScalerOf(context).scale(14) / 14).clamp(1.0, double.infinity);
    return LayoutBuilder(
      builder: (context, constraints) {
        final label = completeLabel ?? t.done;
        final textPainter = TextPainter(
          text: TextSpan(text: label, style: CoconutTypography.body2_14_Bold.copyWith(height: 1)),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(
          maxWidth: (constraints.maxWidth - 2 * (CoconutLayout.defaultPadding + 16)).clamp(1.0, double.infinity),
        );
        final minimumButtonHeight = FixedBottomButton.fixedBottomButtonDefaultHeight + (Platform.isAndroid ? 0 : 3);
        final buttonHeight = (textPainter.height + 24).clamp(minimumButtonHeight, double.infinity);
        textPainter.dispose();
        final buttonAreaHeight = buttonHeight + FixedBottomButton.fixedBottomButtonDefaultBottomPadding + bottomPadding;
        final minVisibleHeight = buttonAreaHeight + keyboardContentHeight * textScale;

        return SizedBox(
          height: keyboardInset > 0 ? minVisibleHeight : collapsedHeight * textScale,
          child: Stack(
            children: [
              Positioned.fill(
                bottom: buttonAreaHeight,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: fieldHorizontalPadding),
                  child: textField,
                ),
              ),
              FixedBottomButton(
                isVisibleAboveKeyboard: false,
                isActive: isCompleteEnabled,
                showSurroundings: false,
                bottomPadding: FixedBottomButton.fixedBottomButtonDefaultBottomPadding,
                onButtonClicked: () {
                  if (!isCompleteEnabled) return;
                  onComplete();
                },
                text: completeLabel ?? t.done,
              ),
            ],
          ),
        );
      },
    );
  }
}
