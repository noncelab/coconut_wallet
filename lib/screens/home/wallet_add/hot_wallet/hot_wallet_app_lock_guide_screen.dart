import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/screens/settings/pin_setting_screen.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/auth/pin/pin_box.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Future<bool?> showHotWalletAppLockGuideBottomSheet(BuildContext context) async {
  final sheetKey = GlobalKey();
  final result = await CommonBottomSheets.showBottomSheet<bool>(
    context: context,
    title: t.wallet_home_screen.hot_wallet_setup.pin_title,
    showDragHandle: true,
    showCloseButton: true,
    adjustForKeyboardInset: false,
    child: HotWalletAppLockGuideScreen(key: sheetKey),
  );
  // showModalBottomSheet의 Future가 먼저 반환되더라도, 시트가 오버레이에서 실제로
  // 제거될 때까지 기다린 후 호출부의 다음 화면 전환을 진행한다.
  while (sheetKey.currentContext != null) {
    await WidgetsBinding.instance.endOfFrame;
  }
  return result;
}

class HotWalletAppLockGuideScreen extends StatefulWidget {
  const HotWalletAppLockGuideScreen({super.key});

  @override
  State<HotWalletAppLockGuideScreen> createState() => _HotWalletAppLockGuideScreenState();
}

class _HotWalletAppLockGuideScreenState extends State<HotWalletAppLockGuideScreen> {
  bool _arePinBoxesVisible = false;
  bool _isDescriptionVisible = false;
  bool _isBottomButtonVisible = false;

  @override
  void initState() {
    super.initState();
    _showGuideContent();
  }

  Future<void> _showGuideContent() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _isDescriptionVisible = true);

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    setState(() => _arePinBoxesVisible = true);

    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _isBottomButtonVisible = true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = t.wallet_home_screen.hot_wallet_setup;

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  CoconutLayout.spacing_300h,
                  AnimatedSlide(
                    offset: _isDescriptionVisible ? Offset.zero : const Offset(0, 0.12),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: _isDescriptionVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 350),
                      child: Text(
                        strings.pin_description,
                        textAlign: TextAlign.center,
                        style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
                      ),
                    ),
                  ),
                  CoconutLayout.spacing_600h,
                  AnimatedOpacity(
                    opacity: _arePinBoxesVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOut,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var index = 0; index < 4; index++) ...[
                          PinBox(
                            isSet: true,
                            pinColor: context.coconutColors.iconSecondary,
                            backgroundColor: context.coconutColors.iconBackgroundSubtle,
                          ),
                          if (index < 3) CoconutLayout.spacing_200w,
                        ],
                      ],
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
              subWidget: CoconutUnderlinedButton(
                onTap: _finish,
                text: strings.skip,
                defaultColor: context.coconutColors.mutedText,
              ),
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
      child: const PinSettingScreen(useBiometrics: true, popParentOnComplete: false),
    );
    if (!mounted || !context.read<AuthProvider>().isAuthEnabled) return;
    Navigator.of(context).pop(true);
  }

  void _finish() {
    Navigator.of(context).pop(false);
  }
}
