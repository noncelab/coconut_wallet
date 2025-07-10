import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';

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
            child: Divider(
              color: CoconutColors.white.withOpacity(0.12),
              height: 1,
            ),
          ),
        );
      }
    }

    return Container(
      decoration: defaultBoxDecoration,
      child: Column(
        children: buttonListWithDividers,
      ),
    );
  }
}
