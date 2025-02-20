import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/button/key_button.dart';
import 'package:coconut_wallet/widgets/pin/pin_box.dart';

class PinInputPad extends StatefulWidget {
  final String title;
  final String pin;
  final String errorMessage;
  final List<String> pinShuffleNumbers;
  final void Function(String) onKeyTap;
  final Function? onReset;
  final bool initOptionVisible;

  const PinInputPad({
    super.key,
    required this.title,
    required this.pin,
    required this.errorMessage,
    required this.onKeyTap,
    required this.pinShuffleNumbers,
    this.onReset,
    this.initOptionVisible = false,
  });

  @override
  PinInputPadState createState() => PinInputPadState();
}

class PinInputPadState extends State<PinInputPad> {
  List<String> _pinShuffleNumbers = [];

  @override
  void initState() {
    super.initState();
    _pinShuffleNumbers = widget.pinShuffleNumbers;
  }

  @override
  void didUpdateWidget(covariant PinInputPad oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.pinShuffleNumbers != oldWidget.pinShuffleNumbers) {
      _pinShuffleNumbers = widget.pinShuffleNumbers;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        SizedBox(height: widget.initOptionVisible ? 60 : 24),
        Text(
          widget.title,
          style:
              Styles.body1.merge(const TextStyle(fontWeight: FontWeight.bold)),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            PinBox(isSet: widget.pin.isNotEmpty),
            const SizedBox(width: 8),
            PinBox(isSet: widget.pin.length > 1),
            const SizedBox(width: 8),
            PinBox(isSet: widget.pin.length > 2),
            const SizedBox(width: 8),
            PinBox(isSet: widget.pin.length > 3),
          ],
        ),
        const SizedBox(height: 16),
        Text(widget.errorMessage,
            style: Styles.warning, textAlign: TextAlign.center),
        const SizedBox(height: 40),
        Expanded(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GridView.count(
              crossAxisCount: 3,
              childAspectRatio: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: _pinShuffleNumbers.map((key) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: KeyButton(
                    keyValue: key,
                    onKeyTap: widget.onKeyTap,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        SizedBox(height: widget.initOptionVisible ? 60 : 100),
        if (widget.initOptionVisible)
          Padding(
              padding: const EdgeInsets.only(bottom: 60.0),
              child: GestureDetector(
                onTap: () {
                  widget.onReset?.call();
                },
                child: Text(
                  t.forgot_password,
                  style: Styles.body2.merge(const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: MyColors.transparentWhite_70)),
                  textAlign: TextAlign.center,
                ),
              )),
      ],
    );
  }
}
