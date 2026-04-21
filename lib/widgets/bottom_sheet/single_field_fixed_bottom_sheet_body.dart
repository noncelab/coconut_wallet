import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
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
  });

  final Widget textField;
  final bool isCompleteEnabled;
  final VoidCallback onComplete;
  final String? completeLabel;
  final double collapsedHeight;
  final double fieldHorizontalPadding;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final minVisibleHeight =
        FixedBottomButton.fixedBottomButtonDefaultHeight +
        FixedBottomButton.fixedBottomButtonDefaultBottomPadding +
        bottomPadding +
        120;

    return SizedBox(
      height: keyboardInset > 0 ? minVisibleHeight : collapsedHeight,
      child: Stack(
        children: [
          Padding(padding: EdgeInsets.symmetric(horizontal: fieldHorizontalPadding), child: textField),
          FixedBottomButton(
            backgroundColor: CoconutColors.white,
            isVisibleAboveKeyboard: false,
            isActive: isCompleteEnabled,
            showGradient: true,
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
  }
}
