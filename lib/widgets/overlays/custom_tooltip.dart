import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:flutter/material.dart';

// TODO: 임시 위젯, wallet_info_screen에서만 쓰임
// FIXME: 동일하게 CustomTooltip 이름을 사용하는 위젯이 또 있어 통합하거나 리네임해야함.
class CustomTooltip extends StatelessWidget {
  final double top;
  final double right;
  final String text;
  final VoidCallback onTap;
  final double topPadding;
  final bool isVisible;

  const CustomTooltip({
    super.key,
    required this.top,
    required this.right,
    required this.text,
    required this.onTap,
    required this.topPadding,
    required this.isVisible,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Positioned(
      top: top,
      right: right,
      child: GestureDetector(
        onTap: onTap,
        child: ClipPath(
          clipper: RightTriangleBubbleClipper(),
          child: Container(
            padding: const EdgeInsets.only(
              top: 25,
              left: 10,
              right: 10,
              bottom: 10,
            ),
            color: MyColors.white,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: Styles.caption.merge(
                    TextStyle(
                      height: 1.3,
                      fontFamily: CustomFonts.text.getFontFamily,
                      color: MyColors.darkgrey,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
