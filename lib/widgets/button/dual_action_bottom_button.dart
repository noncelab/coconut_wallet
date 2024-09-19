import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:coconut_wallet/styles.dart';

class DualActionBottomButton extends StatefulWidget {
  final String text1;
  final VoidCallback onPressed1;
  final String text2;
  final VoidCallback onPressed2;

  final StatelessWidget? icon1;
  final StatelessWidget? icon2;

  const DualActionBottomButton(
      {super.key,
      required this.text1,
      required this.onPressed1,
      required this.text2,
      required this.onPressed2,
      this.icon1,
      this.icon2});

  @override
  State<DualActionBottomButton> createState() => _DualActionBottomButtonState();
}

class _DualActionBottomButtonState extends State<DualActionBottomButton> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.9,
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ActionIconButton(
              onPressed: widget.onPressed1,
              icon: widget.icon1,
              text: widget.text1),
          const SizedBox(
            width: 10,
          ),
          ActionIconButton(
              onPressed: widget.onPressed2,
              icon: widget.icon2,
              text: widget.text2),
        ],
      ),
    );
  }
}

class MyWidget extends StatelessWidget {
  const MyWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}

class ActionIconButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final Widget? icon;

  const ActionIconButton(
      {super.key, required this.onPressed, required this.text, this.icon});

  @override
  Widget build(BuildContext context) {
    return Flexible(
        child: ClipRRect(
      borderRadius: MyBorder.defaultRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
        child: CupertinoButton(
            borderRadius: MyBorder.defaultRadius,
            padding: EdgeInsets.zero,
            onPressed: onPressed,
            color: MyColors.transparentWhite_15,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (icon != null) icon!,
                  if (icon != null)
                    const SizedBox(
                      width: 5,
                    ),
                  Text(
                    textAlign: TextAlign.center,
                    text,
                    style: const TextStyle(
                      color: MyColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )),
      ),
    ));
  }
}
