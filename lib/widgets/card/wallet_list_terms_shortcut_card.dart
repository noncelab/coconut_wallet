import 'package:coconut_wallet/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WalletListTermsShortcutCard extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onCloseTap;

  const WalletListTermsShortcutCard({
    super.key,
    required this.onTap,
    required this.onCloseTap,
  });

  @override
  State<WalletListTermsShortcutCard> createState() =>
      _WalletListTermsShortcutCardState();
}

class _WalletListTermsShortcutCardState
    extends State<WalletListTermsShortcutCard> {
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) {
        setState(() {
          _isTapped = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _isTapped = false;
        });
      },
      onTapCancel: () {
        setState(() {
          _isTapped = false;
        });
      },
      child: Container(
        width: double.maxFinite,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _isTapped
                ? MyColors.transparentWhite_20
                : MyColors.transparentWhite_12),
        margin: const EdgeInsets.only(left: 8, right: 8, bottom: 16),
        padding: const EdgeInsets.only(left: 26, top: 16, bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('모르는 용어가 있으신가요?',
                    style: Styles.body1
                        .merge(const TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width - 100,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: '오른쪽 위 ',
                          style: Styles.label,
                        ),
                        TextSpan(
                          text: '•••',
                          style: Styles.label
                              .merge(const TextStyle(letterSpacing: -2.0)),
                        ),
                        const TextSpan(
                          text: ' - 용어집 또는 여기를 눌러 바로가기',
                          style: Styles.label,
                        ),
                      ],
                    ),
                    maxLines: 2,
                  ),
                )
              ],
            ),
            GestureDetector(
              onTap: widget.onCloseTap,
              child: Container(
                color: Colors.transparent,
                padding: const EdgeInsets.all(16),
                child: SvgPicture.asset('assets/svg/close.svg',
                    width: 10,
                    height: 10,
                    colorFilter: const ColorFilter.mode(
                        MyColors.white, BlendMode.srcIn)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
