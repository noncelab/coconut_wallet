import 'package:flutter/material.dart';
import 'package:coconut_wallet/widgets/button/button_container.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';

import '../../styles.dart';

class ButtonGroup extends StatelessWidget {
  final List<SingleButton> buttons;

  const ButtonGroup({super.key, required this.buttons});

  @override
  Widget build(BuildContext context) {
    List<Widget> buttonListWithDividers = [];

    for (int i = 0; i < buttons.length; i++) {
      buttonListWithDividers.add(buttons[i]);
      if (i < buttons.length - 1) {
        buttonListWithDividers.add(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20.0),
            child: Divider(
              color:
                  MyColors.transparentWhite_12, // Adjust this color as needed
              height: 1,
            ),
          ),
        );
      }
    }

    return ButtonContainer(
        child: Column(
      children: buttonListWithDividers,
    ));
  }
}
