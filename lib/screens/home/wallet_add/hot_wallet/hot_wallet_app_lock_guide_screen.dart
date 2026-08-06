import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/screens/settings/pin_setting_screen.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/pin/pin_input_pad.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HotWalletAppLockGuideScreen extends StatefulWidget {
  const HotWalletAppLockGuideScreen({super.key});

  @override
  State<HotWalletAppLockGuideScreen> createState() => _HotWalletAppLockGuideScreenState();
}

class _HotWalletAppLockGuideScreenState extends State<HotWalletAppLockGuideScreen> {
  bool _isIconVisible = false;
  bool _isPinPadVisible = false;
  bool _isBottomButtonVisible = false;

  @override
  void initState() {
    super.initState();
    _showGuideContent();
  }

  Future<void> _showGuideContent() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _isIconVisible = true);

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _isPinPadVisible = true);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _isBottomButtonVisible = true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = t.wallet_home_screen.hot_wallet_setup;

    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(
        title: strings.pin_title,
        context: context,
        isBottom: true,
        onBackPressed: _finish,
        backgroundColor: context.coconutColors.background,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Align(
                    alignment: const Alignment(0, -0.72),
                    child: Text(
                      strings.pin_description,
                      textAlign: TextAlign.center,
                      style: CoconutTypography.heading3_21_Bold.setColor(context.coconutColors.primaryText),
                    ).fadeInAnimation(duration: const Duration(milliseconds: 350)),
                  ),
                  if (_isIconVisible)
                    Align(
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 228,
                        height: 328,
                        child: Stack(
                          children: [
                            Positioned(
                              top: 0,
                              left: 14,
                              child: SizedBox(
                                width: 200,
                                height: 200,
                                child: ShaderMask(
                                  blendMode: BlendMode.dstIn,
                                  shaderCallback:
                                      (bounds) => const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.white, Colors.white, Colors.transparent],
                                        stops: [0, 0.6, 1],
                                      ).createShader(bounds),
                                  child: Image.asset('assets/images/pin-screen-mockup.png', fit: BoxFit.contain),
                                ),
                              ).fadeInAnimation(duration: const Duration(milliseconds: 350)),
                            ),
                            if (_isPinPadVisible)
                              Positioned(
                                top: 160,
                                left: 0,
                                right: 0,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: _openAppLockSetting,
                                  child: Container(
                                    height: 168,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: CoconutColors.gray700, width: 1),
                                      borderRadius: BorderRadius.circular(16),
                                      color: context.coconutColors.background,
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: PinInputPad(
                                      title: '',
                                      pin: '',
                                      errorMessage: '',
                                      onKeyTap: (_) {},
                                      pinShuffleNumbers: const [
                                        '1',
                                        '2',
                                        '3',
                                        '4',
                                        '5',
                                        '6',
                                        '7',
                                        '8',
                                        '9',
                                        '',
                                        '0',
                                        '<',
                                      ],
                                      onClosePressed: _finish,
                                      step: 0,
                                      appBarVisible: false,
                                      showOnlyKeypad: true,
                                      isKeypadInteractive: false,
                                    ),
                                  ),
                                ).slideUpAnimation(
                                  duration: const Duration(milliseconds: 400),
                                  offset: const Offset(0, 16),
                                  curve: Curves.easeOutCubic,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_isBottomButtonVisible)
            FixedBottomButton(
              onButtonClicked: _openAppLockSetting,
              text: strings.pin_action,
              subWidget: CoconutUnderlinedButton(onTap: _finish, text: strings.skip),
            ).slideUpAnimation(
              duration: const Duration(milliseconds: 350),
              delay: const Duration(milliseconds: 200),
              offset: const Offset(0, 8),
              curve: Curves.easeOutCubic,
            ),
        ],
      ),
    );
  }

  Future<void> _openAppLockSetting() async {
    await CommonBottomSheets.showCustomHeightBottomSheet<void>(
      context: context,
      heightRatio: 0.9,
      child: const CustomLoadingOverlay(child: PinSettingScreen(useBiometrics: true, popParentOnComplete: false)),
    );
    if (!mounted || !context.read<AuthProvider>().isAuthEnabled) return;
    _finish();
  }

  void _finish() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
