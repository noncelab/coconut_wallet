import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class GlossaryShortcutCard extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onCloseTap;

  const GlossaryShortcutCard({
    super.key,
    required this.onTap,
    required this.onCloseTap,
  });

  @override
  State<GlossaryShortcutCard> createState() => _GlossaryShortcutCardState();
}

class _GlossaryShortcutCardState extends State<GlossaryShortcutCard> {
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
            borderRadius: BorderRadius.circular(20),
            color: _isTapped ? MyColors.transparentWhite_20 : MyColors.transparentWhite_12),
        margin: const EdgeInsets.only(
            left: CoconutLayout.defaultPadding, right: CoconutLayout.defaultPadding, bottom: 12),
        padding: const EdgeInsets.only(left: 26, top: 16, bottom: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.wallet_list_glossary_shortcut_card.any_word_you_dont_know,
                    style: Styles.body1.merge(const TextStyle(fontWeight: FontWeight.w600))),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width - 100,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: t.wallet_list_glossary_shortcut_card.top_right,
                          style: Styles.label,
                        ),
                        TextSpan(
                          text: '•••',
                          style: Styles.label.merge(const TextStyle(letterSpacing: -2.0)),
                        ),
                        TextSpan(
                          text: t.wallet_list_glossary_shortcut_card.click_to_jump,
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
                padding: const EdgeInsets.only(right: 22),
                child: SvgPicture.asset('assets/svg/close.svg',
                    width: 12,
                    height: 12,
                    colorFilter: const ColorFilter.mode(MyColors.white, BlendMode.srcIn)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
