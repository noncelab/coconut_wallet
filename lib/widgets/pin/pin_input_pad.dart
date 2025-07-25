import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  final int pinLength;
  final Widget? centerWidget;

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
    this.pinLength = 4,
    this.centerWidget,
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
      backgroundColor: CoconutColors.black,
      appBar: widget.appBarVisible
          ? AppBar(
              backgroundColor: Colors.transparent,
              toolbarHeight: 62,
              leading: widget.step == 0
                  ? IconButton(
                      onPressed: widget.onClosePressed,
                      icon: const Icon(
                        Icons.close,
                        color: CoconutColors.white,
                        size: 22,
                      ),
                    )
                  : IconButton(
                      onPressed: widget.onBackPressed,
                      icon: SvgPicture.asset(
                        'assets/svg/back.svg',
                        colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
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
              style: CoconutTypography.body1_16_Bold,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.pinLength, (index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: PinBox(
                        isSet: widget.pin.length > index, size: widget.pinLength == 4 ? null : 40),
                  );
                }),
              ),
            ),
            if (widget.centerWidget == null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(widget.errorMessage,
                    style: CoconutTypography.body3_12.setColor(CoconutColors.hotPink),
                    textAlign: TextAlign.center),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: SizedBox(height: 40, child: widget.centerWidget ?? const SizedBox()),
            ),
            const SizedBox(height: 16),
            if (widget.centerWidget != null)
              Text(widget.errorMessage,
                  style: CoconutTypography.body3_12.setColor(CoconutColors.hotPink),
                  textAlign: TextAlign.center),
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
            SizedBox(height: widget.initOptionVisible ? 40 : 50),
            if (widget.initOptionVisible)
              Padding(
                  padding: const EdgeInsets.only(bottom: 60.0),
                  child: GestureDetector(
                    onTap: () {
                      widget.onReset?.call();
                    },
                    child: Text(
                      t.forgot_password,
                      style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.gray600),
                      textAlign: TextAlign.center,
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
