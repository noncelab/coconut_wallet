import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/widgets/features/auth/pin/key_button.dart';
import 'package:coconut_wallet/widgets/features/auth/pin/pin_box.dart';

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
      backgroundColor: context.coconutColors.background,
      appBar:
          widget.appBarVisible
              ? CoconutAppBar.build(
                context: context,
                title: '',
                customTitle: const SizedBox.shrink(),
                backgroundColor: Colors.transparent,
                isBottom: widget.step == 0,
                isBackButton: widget.step != 0,
                height: 62,
                onBackPressed: widget.step == 0 ? widget.onClosePressed : widget.onBackPressed,
              )
              : null,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // initOptionVisible: 앱진입 핀체크 화면(true), 핀 설정 화면(false)
          // centerWidget: 앱진입 핀체크 화면(null), 핀 설정 화면(notNull)
          if (widget.initOptionVisible) const SizedBox(height: 60),
          Text(
            widget.title,
            style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
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
                  child: PinBox(isSet: widget.pin.length > index, size: widget.pinLength == 4 ? null : 40),
                );
              }),
            ),
          ),
          Visibility(
            visible: widget.errorMessage.isNotEmpty,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                widget.errorMessage,
                style: CoconutTypography.body3_12.setColor(context.coconutColors.danger),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          if (!widget.initOptionVisible)
            Visibility(
              visible: widget.centerWidget != null,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(height: 40, child: widget.centerWidget ?? const SizedBox()),
              ),
            ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GridView.count(
                  crossAxisCount: 3,
                  childAspectRatio:
                      MediaQuery.of(context).size.width > 600
                          ? 2.5 // 폴드 펼친화면에서는 버튼 사이즈 줄여서 공간 확보
                          : 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children:
                      _pinShuffleNumbers.map((key) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: KeyButton(keyValue: key, onKeyTap: widget.onKeyTap),
                        );
                      }).toList(),
                ),
                if (widget.initOptionVisible)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 50, top: 8),
                    child: GestureDetector(
                      onTap: () {
                        widget.onReset?.call();
                      },
                      child: Text(
                        t.forgot_password,
                        style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.mutedText),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
