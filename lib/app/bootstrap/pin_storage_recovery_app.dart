import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

/// 인증 저장소 확인이 실패했을 때 설정을 변경하지 않고 시작을 다시 시도한다.
class PinStorageRecoveryApp extends StatefulWidget {
  final Future<void> Function() onRetry;

  const PinStorageRecoveryApp({super.key, required this.onRetry});

  @override
  State<PinStorageRecoveryApp> createState() => _PinStorageRecoveryAppState();
}

class _PinStorageRecoveryAppState extends State<PinStorageRecoveryApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await widget.onRetry();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildCoconutThemeData(),
    home: Builder(
      builder: (context) {
        final colors = context.coconutColors;
        return Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.pin_check_screen.startup_authentication_unavailable,
                      textAlign: TextAlign.center,
                      style: CoconutTypography.body2_14.copyWith(color: colors.primaryText),
                    ),
                    const SizedBox(height: 24),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: ShrinkAnimationButton(
                        onPressed: _retry,
                        isActive: !_retrying,
                        borderRadius: 12,
                        defaultColor: colors.buttonPrimaryBackground,
                        disabledColor: colors.buttonPrimaryDisabledBackground,
                        pressedOverlayColor: colors.buttonPrimaryPressOverlay,
                        pressedOverlayOpacity: colors.buttonPrimaryPressOverlayOpacity,
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: Center(
                            child:
                                _retrying
                                    ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colors.buttonPrimaryDisabledForeground,
                                      ),
                                    )
                                    : Text(
                                      t.retry,
                                      style: CoconutTypography.body2_14_Bold.copyWith(
                                        color: colors.buttonPrimaryForeground,
                                      ),
                                    ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}
