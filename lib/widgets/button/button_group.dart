import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/material.dart';

class ButtonGroup extends StatelessWidget {
  final List<Widget> buttons;

  const ButtonGroup({super.key, required this.buttons});

  @override
  Widget build(BuildContext context) {
    List<Widget> buttonListWithDividers = [];

    for (int i = 0; i < buttons.length; i++) {
      buttonListWithDividers.add(buttons[i]);
      if (i < buttons.length - 1) {
        buttonListWithDividers.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.size20),
            child: Divider(color: context.coconutColors.borderSubtle.withValues(alpha: 0.21), height: 1),
          ),
        );
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: context.coconutColors.surface,
        borderRadius: const BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(children: buttonListWithDividers),
    );
  }
}
