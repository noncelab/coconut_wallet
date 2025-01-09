import 'dart:math';

import 'package:coconut_wallet/styles.dart';
import 'package:flutter/material.dart';

class CustomTagChipColorButton extends StatefulWidget {
  final Function(int) onTap;
  final int colorIndex;
  final bool isCreate;
  const CustomTagChipColorButton(
      {super.key,
      required this.onTap,
      required this.colorIndex,
      this.isCreate = false});

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
        if (_colorIndex < BackgroundColorPalette.length - 1) {
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
        width: 55,
        height: 28,
        decoration: BoxDecoration(
          color: BackgroundColorPalette[_colorIndex].withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: ColorPalette[_colorIndex].withOpacity(1),
            width: 1,
          ),
        ),
        child: const Center(
          child: Text(
            '색 변경',
            style: TextStyle(
              decoration: TextDecoration.underline, // 밑줄 설정
              height: 0.5,
              fontSize: 10,
              fontFamily: 'Pretendard',
              color: MyColors.white,
            ),
          ),
        ),
      ),
    );
  }
}
