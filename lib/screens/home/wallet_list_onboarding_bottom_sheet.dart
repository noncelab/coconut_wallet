import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';

class OnboardingBottomSheet extends StatefulWidget {
  const OnboardingBottomSheet({super.key});

  @override
  State<OnboardingBottomSheet> createState() => _OnboardingBottomSheetState();
}

class _OnboardingBottomSheetState extends State<OnboardingBottomSheet> {
  int _countdown = 5;
  bool _isCountdownFinished = false;

  @override
  void initState() {
    super.initState();
    startCountdown();
  }

  void startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_countdown > 1) {
        setState(() {
          _countdown--;
        });
        startCountdown();
      } else {
        setState(() {
          _isCountdownFinished = true;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
          backgroundColor: MyColors.nero,
          body: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: Stack(children: [
              Positioned(
                right: 16,
                top: 60,
                child: ShrinkAnimationButton(
                  onPressed: () =>
                      _isCountdownFinished ? Navigator.pop(context) : null,
                  borderRadius: 8,
                  border: _isCountdownFinished
                      ? Border.all(color: MyColors.white, width: 1)
                      : Border.all(
                          color: MyColors.transparentWhite_50, width: 1),
                  defaultColor: MyColors.nero,
                  pressedColor:
                      _isCountdownFinished ? MyColors.grey : MyColors.nero,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                    child: Row(
                      children: [
                        Text(
                          t.onboarding_bottom_sheet.skip,
                          style: Styles.caption.merge(
                            TextStyle(
                              color: _isCountdownFinished
                                  ? MyColors.white
                                  : MyColors.transparentWhite_50,
                              fontFamily: 'Pretendard',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: _isCountdownFinished
                              ? SvgPicture.asset(
                                  'assets/svg/status-complete.svg',
                                  width: 16,
                                  colorFilter: const ColorFilter.mode(
                                    MyColors.primary,
                                    BlendMode.srcIn,
                                  ),
                                )
                              : SizedBox(
                                  width: 16,
                                  child: Text(
                                    _countdown.toString(),
                                    textAlign: TextAlign.center,
                                    style: Styles.caption.merge(
                                      const TextStyle(
                                        color: MyColors.white,
                                        fontFamily: 'Pretendard',
                                      ),
                                    ),
                                  ),
                                ),
                          transitionBuilder:
                              (Widget child, Animation<double> animation) {
                            return ScaleTransition(
                                scale: animation, child: child);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/onboarding.png',
                      width: 200,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      t.onboarding_bottom_sheet.when_need_help,
                      style: Styles.h3.merge(
                        const TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    RichText(
                      text: TextSpan(
                        text: t.onboarding_bottom_sheet.guide_btn,
                        style: Styles.h3,
                        children: <TextSpan>[
                          TextSpan(
                            text: t.onboarding_bottom_sheet.press,
                            style: Styles.h3.merge(
                              const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            ]),
          )),
    );
  }
}
