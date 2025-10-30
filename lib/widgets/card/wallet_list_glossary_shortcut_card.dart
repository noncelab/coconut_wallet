import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

class GlossaryShortcutCard extends StatefulWidget {
  final VoidCallback onTap;
  final VoidCallback onCloseTap;

  const GlossaryShortcutCard({super.key, required this.onTap, required this.onCloseTap});

  @override
  State<GlossaryShortcutCard> createState() => _GlossaryShortcutCardState();
}

class _GlossaryShortcutCardState extends State<GlossaryShortcutCard> with SingleTickerProviderStateMixin {
  bool _isTapped = false;
  bool _isVisible = true;
  double _opacity = 1.0;

  void _handleClose() {
    setState(() {
      _opacity = 0.0;
      _isVisible = false;
    });

    Future.delayed(const Duration(milliseconds: 400), () {
      widget.onCloseTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child:
          _isVisible
              ? AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: _opacity,
                child: GestureDetector(
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
                      borderRadius: BorderRadius.circular(CoconutStyles.radius_400),
                      color: _isTapped ? CoconutColors.gray900 : CoconutColors.gray800,
                    ),
                    margin: const EdgeInsets.only(
                      left: CoconutLayout.defaultPadding,
                      right: CoconutLayout.defaultPadding,
                      bottom: 12,
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 16, 4, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t.wallet_list_glossary_shortcut_card.any_word_you_dont_know,
                                style: CoconutTypography.body1_16_Bold,
                              ),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: t.wallet_list_glossary_shortcut_card.top_right,
                                      style: CoconutTypography.body2_14.setColor(CoconutColors.gray400),
                                    ),
                                    TextSpan(
                                      text: t.wallet_list_glossary_shortcut_card.kebab_button,
                                      style: CoconutTypography.body2_14.copyWith(color: CoconutColors.gray400),
                                    ),
                                    TextSpan(
                                      text: t.wallet_list_glossary_shortcut_card.click_to_jump,
                                      style: CoconutTypography.body2_14.setColor(CoconutColors.gray400),
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _handleClose,
                          icon: const Icon(Icons.close_rounded, size: 20, color: CoconutColors.gray200),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              : const SizedBox.shrink(),
    );
  }
}
