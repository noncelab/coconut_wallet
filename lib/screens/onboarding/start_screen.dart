import 'dart:async';
import 'dart:io';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/tokens/coconut_colors.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/view_model/onboarding/start_view_model.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/widgets/common/icon/coconut_logo_icon.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

const Color kNativeSplashBackgroundColor = Color(0xFF121416);
const Color kNativeSplashIconColor = Colors.white;
const Duration kSplashTransitionDelay = Duration(milliseconds: 100);
const Duration kSplashTransitionDuration = Duration(milliseconds: 3500);

class StartScreen extends StatefulWidget {
  final void Function(AppEntryFlow nextScreen) onComplete;

  const StartScreen({super.key, required this.onComplete});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> with SingleTickerProviderStateMixin {
  late StartViewModel _viewModel;
  late final AnimationController _appearanceController;
  late final Animation<double> _appearanceAnimation;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    return AnimatedBuilder(
      animation: _appearanceAnimation,
      builder: (context, _) {
        final progress = _appearanceAnimation.value;
        final themeLayerOpacity = Curves.easeInOutCubic.transform(progress);
        final nativeLayerOpacity = 1 - Curves.easeOutCubic.transform(progress);

        return Stack(
          fit: StackFit.expand,
          children: [
            Opacity(opacity: nativeLayerOpacity, child: const _NativeSplashAppearance()),
            Opacity(opacity: themeLayerOpacity, child: _ThemeSplashAppearance(colors: colors)),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _appearanceController = AnimationController(vsync: this, duration: kSplashTransitionDuration);
    _appearanceAnimation = CurvedAnimation(parent: _appearanceController, curve: Curves.easeOutCubic);
    _viewModel = StartViewModel(
      Provider.of<VisibilityProvider>(context, listen: false),
      Provider.of<AuthProvider>(context, listen: false),
    );

    _initialize();
    _scheduleBackgroundTransition();
  }

  @override
  void dispose() {
    _appearanceController.dispose();
    super.dispose();
  }

  void _initialize() async {
    await Future.wait([Future.delayed(const Duration(seconds: 3)), _viewModel.ensureVersionChecked()]);
    if (_viewModel.canUpdate) {
      bool finishDialogValue = await _showUpdateDialog();
      if (!finishDialogValue) {
        await _viewModel.setNextUpdateDialogDate();
      }
    }

    AppEntryFlow nextScreen = await _viewModel.determineStartScreen();
    widget.onComplete(nextScreen);
  }

  void _scheduleBackgroundTransition() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(kSplashTransitionDelay);
      if (!mounted) return;
      _appearanceController.forward();
    });
  }

  /// 업데이트 다이얼로그 표시
  Future<bool> _showUpdateDialog() async {
    return (await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder:
              (context) => CoconutPopup(
                languageCode: context.read<PreferenceProvider>().language,
                title: t.alert.update.title,
                description: t.alert.update.description,
                leftButtonText: t.alert.update.btn_do_later,
                rightButtonText: t.alert.update.btn_update,
                onTapRight: () async {
                  await _viewModel.launchUpdate();
                  if (!context.mounted) return;
                  Navigator.pop(context, true);
                },
                onTapLeft: () => Navigator.pop(context, false),
                rightButtonColor: context.coconutColors.primary,
              ),
        )) ??
        false;
  }
}

class _NativeSplashAppearance extends StatelessWidget {
  const _NativeSplashAppearance();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: kNativeSplashBackgroundColor,
      child: Center(child: _StartScreenLogoSlot(isNativeSplashAppearance: true)),
    );
  }
}

class _ThemeSplashAppearance extends StatelessWidget {
  const _ThemeSplashAppearance({required this.colors});

  final CoconutColors colors;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: colors.background, child: const Center(child: _StartScreenLogoSlot()));
  }
}

class _StartScreenLogoSlot extends StatelessWidget {
  const _StartScreenLogoSlot({this.isNativeSplashAppearance = false});

  final bool isNativeSplashAppearance;

  @override
  Widget build(BuildContext context) {
    final Widget logo =
        isNativeSplashAppearance
            ? AppIconPath.isMainnet
                ? const CoconutLogoIcon(size: 60)
                : const CoconutLogoIcon(size: 60, colorOverride: kNativeSplashIconColor, disableThemeGradient: true)
            : const CoconutLogoIcon(size: 60);

    if (Platform.isIOS) {
      return Transform.translate(offset: const Offset(0, -21), child: logo);
    }

    return Transform.translate(offset: const Offset(0, 24), child: logo);
  }
}
