import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class HotWalletMnemonicBackupGuideScreen extends StatefulWidget {
  const HotWalletMnemonicBackupGuideScreen({
    super.key,
    required this.walletName,
    required this.walletId,
    required this.mnemonic,
    required this.passphrase,
    required this.enterPassphraseWhenSigning,
  });

  final String walletName;
  final int walletId;
  final Uint8List mnemonic;
  final Uint8List passphrase;
  final bool enterPassphraseWhenSigning;

  @override
  State<HotWalletMnemonicBackupGuideScreen> createState() => _HotWalletMnemonicBackupGuideScreenState();
}

class _HotWalletMnemonicBackupGuideScreenState extends State<HotWalletMnemonicBackupGuideScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lottieController;
  bool _isCreatedTitleVisible = false;
  bool _isIntroVisible = true;
  bool _isBackupStageVisible = false;
  bool _isBackupTitleMoved = false;
  bool _isBackupLottieVisible = false;
  bool _isBottomButtonVisible = false;
  bool _hasStartedLottie = false;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
  }

  Future<void> _playIntroAnimation(LottieComposition composition) async {
    if (_hasStartedLottie) return;
    _hasStartedLottie = true;

    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    final visibleFrameDuration = Duration(milliseconds: (composition.duration.inMilliseconds * 0.85).round());
    _lottieController.duration = composition.duration;
    await _lottieController.animateTo(0.85, duration: visibleFrameDuration);
    if (!mounted) return;

    setState(() => _isCreatedTitleVisible = true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;

    setState(() => _isIntroVisible = false);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    setState(() => _isBackupStageVisible = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() => _isBackupTitleMoved = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    setState(() => _isBackupLottieVisible = true);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;

    setState(() => _isBottomButtonVisible = true);
  }

  @override
  void dispose() {
    _lottieController.dispose();
    widget.mnemonic.fillRange(0, widget.mnemonic.length, 0);
    widget.passphrase.fillRange(0, widget.passphrase.length, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = t.wallet_home_screen.hot_wallet_setup;
    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: IgnorePointer(
          ignoring: !_isBackupStageVisible,
          child: AnimatedOpacity(
            opacity: _isBackupStageVisible ? 1 : 0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            child: CoconutAppBar.build(
              title: strings.backup_title,
              context: context,
              onBackPressed: _finish,
              isBottom: true,
              backgroundColor: context.coconutColors.background,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          AnimatedOpacity(
            opacity: _isIntroVisible ? 1 : 0,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
            child: IgnorePointer(
              ignoring: !_isIntroVisible,
              child: Align(
                alignment: const Alignment(0, -0.14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 72,
                      child: Lottie.asset(
                        'assets/lottie/check-complete.json',
                        controller: _lottieController,
                        fit: BoxFit.contain,
                        repeat: false,
                        onLoaded: _playIntroAnimation,
                      ),
                    ),
                    CoconutLayout.spacing_300h,
                    AnimatedSlide(
                      offset: _isCreatedTitleVisible ? Offset.zero : const Offset(0, 0.15),
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      child: AnimatedOpacity(
                        opacity: _isCreatedTitleVisible ? 1 : 0,
                        duration: const Duration(milliseconds: 350),
                        child: Text(
                          strings.wallet_created_title,
                          textAlign: TextAlign.center,
                          style: CoconutTypography.heading3_21_Bold.setColor(context.coconutColors.primaryText),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isBackupStageVisible)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedAlign(
                      alignment: _isBackupTitleMoved ? const Alignment(0, -0.72) : Alignment.center,
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeInOutCubic,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeInOutCubic,
                        transform: Matrix4.translationValues(0, _isBackupTitleMoved ? 0 : -30, 0),
                        child: Text(
                          strings.backup_intro_title,
                          textAlign: TextAlign.center,
                          style: CoconutTypography.heading3_21_Bold.setColor(context.coconutColors.primaryText),
                        ).fadeInAnimation(duration: const Duration(milliseconds: 350)),
                      ),
                    ),
                    if (_isBackupLottieVisible)
                      Align(
                        alignment: Alignment.center,
                        child: Transform.translate(
                          offset: const Offset(0, -30),
                          child: SizedBox(
                            width: 96,
                            height: 96,
                            child: Lottie.asset(
                              'assets/lottie/note-write-pencil.json',
                              fit: BoxFit.contain,
                              repeat: false,
                            ),
                          ).fadeInAnimation(duration: const Duration(milliseconds: 350)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (_isBottomButtonVisible)
            FixedBottomButton(
              onButtonClicked: _startMnemonicBackupFlow,
              text: strings.backup_title,
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

  Future<void> _startMnemonicBackupFlow() async {
    final isBackupConfirmed = await Navigator.pushNamed(
      context,
      '/hot-wallet-mnemonic-backup',
      arguments: {
        'mnemonic': utf8.decode(widget.mnemonic),
        'passphrase': utf8.decode(widget.passphrase),
        'enterPassphraseWhenSigning': widget.enterPassphraseWhenSigning,
        'walletId': widget.walletId,
        'continueToAppLockGuide': true,
      },
    );
    if (!mounted || isBackupConfirmed != true) return;
  }

  void _finish() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}
