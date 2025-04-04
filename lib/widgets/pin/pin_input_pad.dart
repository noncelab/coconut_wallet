import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/button/key_button.dart';
import 'package:coconut_wallet/widgets/pin/pin_box.dart';

class PinInputPad extends StatefulWidget {
  final String title;
  final String pin;
  final String errorMessage;
  final void Function(String) onKeyTap;
  final List<String> pinShuffleNumbers;
  final VoidCallback onClosePressed;
  final VoidCallback? onBackPressed;
  final Function? onReset;
  final int step;
  final bool appBarVisible;
  final bool initOptionVisible;

  const PinInputPad({
    super.key,
    required this.title,
    required this.pin,
    required this.errorMessage,
    required this.onKeyTap,
    required this.pinShuffleNumbers,
    required this.onClosePressed,
    this.onBackPressed,
    this.onReset,
    required this.step,
    this.appBarVisible = true,
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
    return Scaffold(
      backgroundColor: MyColors.black,
      appBar: widget.appBarVisible
          ? AppBar(
              backgroundColor: Colors.transparent,
              toolbarHeight: 62,
              leading: widget.step == 0
                  ? IconButton(
                      onPressed: widget.onClosePressed,
                      icon: const Icon(
                        Icons.close,
                        color: MyColors.white,
                        size: 22,
                      ),
                    )
                  : IconButton(
                      onPressed: widget.onBackPressed,
                      icon: SvgPicture.asset(
                        'assets/svg/back.svg',
                        colorFilter: const ColorFilter.mode(MyColors.white, BlendMode.srcIn),
                      ),
                    ),
            )
          : null,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            SizedBox(height: widget.initOptionVisible ? 60 : 24),
            Text(
              widget.title,
              style: Styles.body1.merge(const TextStyle(fontWeight: FontWeight.bold)),
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
            Text(widget.errorMessage, style: Styles.warning, textAlign: TextAlign.center),
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
                      '비밀번호가 기억나지 않나요?',
                      style: Styles.body2.merge(const TextStyle(
                          fontWeight: FontWeight.bold, color: MyColors.transparentWhite_70)),
                      textAlign: TextAlign.center,
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
