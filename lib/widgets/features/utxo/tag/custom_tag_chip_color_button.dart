import 'dart:math';

import 'package:coconut_design_system/coconut_design_system.dart'
    hide CoconutUnderlinedButton;
import 'package:coconut_wallet/ui/coconut/coconut_underlined_button.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/wallet_visual_style_util.dart';
import 'package:flutter/material.dart';

class CustomTagChipColorButton extends StatefulWidget {
  final Function(int) onTap;
  final int colorIndex;
  final bool isCreate;
  const CustomTagChipColorButton({
    super.key,
    required this.onTap,
    required this.colorIndex,
    this.isCreate = false,
  });

  @override
  State<CustomTagChipColorButton> createState() =>
      _CustomTagChipColorButtonState();
}

class _CustomTagChipColorButtonState extends State<CustomTagChipColorButton> {
  int _colorIndex = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isCreate) {
      final random = Random();
      _colorIndex = random.nextInt(10);
    } else {
      _colorIndex = widget.colorIndex;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isCreate) {
        widget.onTap.call(_colorIndex);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_colorIndex < backgroundColorPalette.length - 1) {
          setState(() {
            _colorIndex += 1;
          });
        } else {
          setState(() {
            _colorIndex = 0;
          });
        }
        widget.onTap.call(_colorIndex);
      },
      child: Container(
        width: 72,
        height: 32,
        decoration: BoxDecoration(
          color: WalletVisualStyleUtil.getColor(_colorIndex).backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: WalletVisualStyleUtil.getColor(_colorIndex).color,
            width: 1,
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: IgnorePointer(
              child: CoconutUnderlinedButton(
                text: t.change_color,
                textStyle: CoconutTypography.caption_10,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );
  }
}
