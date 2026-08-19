import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/constants/lottie_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/services/security/hot_wallet_unlock_service.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

class HotWalletMnemonicBackupGuideScreen extends StatefulWidget {
  const HotWalletMnemonicBackupGuideScreen({
    super.key,
    required this.walletName,
    required this.walletId,
    this.mnemonic,
    this.passphrase,
    this.secureStorageKey,
    required this.enterPassphraseWhenSigning,
    this.showWalletCreatedIntro = true,
    this.continueToAppLockGuide = true,
    this.returnToPreviousOnExit = false,
  });

  final String walletName;
  final int walletId;
  final Uint8List? mnemonic;
  final Uint8List? passphrase;
  final String? secureStorageKey;
  final bool enterPassphraseWhenSigning;
  final bool showWalletCreatedIntro;
  final bool continueToAppLockGuide;
  final bool returnToPreviousOnExit;

  @override
  State<HotWalletMnemonicBackupGuideScreen> createState() => _HotWalletMnemonicBackupGuideScreenState();
}

class _HotWalletMnemonicBackupGuideScreenState extends State<HotWalletMnemonicBackupGuideScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _lottieController;
  final ScrollController _preparationScrollController = ScrollController();
  bool _isCreatedTitleVisible = false;
  bool _isIntroVisible = true;
  bool _isBackupStageVisible = false;
  bool _isBackupTitleMoved = false;
  bool _isBackupLottieVisible = false;
  bool _isBottomButtonVisible = false;
  bool _hasStartedLottie = false;
  bool _isBackupPreparationStage = false;
  bool _isPreparationTitleVisible = false;
  bool _isPreparationDescriptionVisible = false;
  bool _isPreparationContentVisible = false;
  bool _isStageTransitioning = false;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
    if (!widget.showWalletCreatedIntro) {
      _isIntroVisible = false;
      _isBackupStageVisible = true;
      _isBackupTitleMoved = true;
      _isBackupLottieVisible = true;
      _isBackupPreparationStage = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _showBackupPreparation());
    }
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

    await _showBackupGuide();
  }

  Future<void> _showBackupGuide() async {
    if (!mounted || _isBackupStageVisible) return;
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
    _preparationScrollController.dispose();
    widget.mnemonic?.fillRange(0, widget.mnemonic!.length, 0);
    widget.passphrase?.fillRange(0, widget.passphrase!.length, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = t.wallet_home_screen.hot_wallet_setup;
    final backupTipLineHeight =
        MediaQuery.textScalerOf(context).scale(CoconutTypography.body2_14.fontSize!) *
        CoconutTypography.body2_14.height!;
    final backupTipIconTopPadding = ((backupTipLineHeight - 24) / 2).clamp(0.0, double.infinity);
    final backupTipTextTopPadding = ((24 - backupTipLineHeight) / 2).clamp(0.0, double.infinity);
    return PopScope(
      canPop: widget.returnToPreviousOnExit,
      child: Scaffold(
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
                onBackPressed: _onAppBarBackPressed,
                isBottom: true,
                isBackButton: _isBackupPreparationStage,
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
                          StateLottiePath.checkComplete,
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
                          child: AnimatedOpacity(
                            opacity: _isBackupPreparationStage ? 0 : 1,
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              strings.backup_intro_title,
                              textAlign: TextAlign.center,
                              style: CoconutTypography.heading3_21_Bold.setColor(context.coconutColors.primaryText),
                            ).fadeInAnimation(duration: const Duration(milliseconds: 350)),
                          ),
                        ),
                      ),
                      if (_isBackupLottieVisible)
                        AnimatedAlign(
                          alignment: _isBackupPreparationStage ? const Alignment(0, -0.72) : Alignment.center,
                          duration: const Duration(milliseconds: 650),
                          curve: Curves.easeInOutCubic,
                          child: AnimatedBuilder(
                            animation: _preparationScrollController,
                            builder: (context, child) {
                              final scrollOffset =
                                  _isBackupPreparationStage && _preparationScrollController.hasClients
                                      ? _preparationScrollController.offset
                                      : 0.0;
                              return Transform.translate(offset: Offset(0, -scrollOffset), child: child);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 650),
                              curve: Curves.easeInOutCubic,
                              transform: Matrix4.translationValues(0, _isBackupPreparationStage ? 0 : -30, 0),
                              child: SizedBox(
                                width: 96,
                                height: 96,
                                child: Lottie.asset(ActionLottiePath.noteWriting, fit: BoxFit.contain, repeat: false),
                              ).fadeInAnimation(duration: const Duration(milliseconds: 350)),
                            ),
                          ),
                        ),
                      if (_isBackupPreparationStage) ...[
                        Positioned.fill(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              const lottieHeight = 96.0;
                              const gapBelowLottie = 30.0;
                              final lottieTop = (constraints.maxHeight - lottieHeight) * 0.14;

                              return SingleChildScrollView(
                                controller: _preparationScrollController,
                                physics: const ClampingScrollPhysics(),
                                padding: EdgeInsets.only(top: lottieTop + lottieHeight + gapBelowLottie, bottom: 140),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _SequentialEntry(
                                      visible: _isPreparationTitleVisible,
                                      child: Text(
                                        strings.backup_preparation_title,
                                        textAlign: TextAlign.center,
                                        style: CoconutTypography.heading3_21_Bold.setColor(
                                          context.coconutColors.primaryText,
                                        ),
                                      ),
                                    ),
                                    CoconutLayout.spacing_300h,
                                    _SequentialEntry(
                                      visible: _isPreparationDescriptionVisible,
                                      child: Text(
                                        strings.backup_preparation_description,
                                        textAlign: TextAlign.center,
                                        style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                                      ),
                                    ),
                                    const SizedBox(height: 30),
                                    _SequentialEntry(
                                      visible: _isPreparationContentVisible,
                                      child: Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          color: context.coconutColors.surface,
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        padding: const EdgeInsets.only(left: 16, top: 20, right: 8, bottom: 20),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: EdgeInsets.only(top: backupTipIconTopPadding),
                                                  child: Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: BoxDecoration(
                                                      color: context.coconutColors.iconPrimary,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: SvgPicture.asset(
                                                      CommonActionIconPath.editOutlinedSmall,
                                                      width: 14,
                                                      height: 14,
                                                      colorFilter: ColorFilter.mode(
                                                        context.coconutColors.iconButtonHighlight,
                                                        BlendMode.srcIn,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                CoconutLayout.spacing_200w,
                                                Expanded(
                                                  child: Padding(
                                                    padding: EdgeInsets.only(top: backupTipTextTopPadding),
                                                    child: Text(
                                                      LocaleSettings.currentLocale == AppLocale.ko
                                                          ? TextUtils.preventLineBreakInsideWords(strings.backup_tips_1)
                                                          : strings.backup_tips_1,
                                                      style: CoconutTypography.body2_14.setColor(
                                                        context.coconutColors.primaryText,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            CoconutLayout.spacing_400h,
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: EdgeInsets.only(top: backupTipIconTopPadding),
                                                  child: Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: BoxDecoration(
                                                      color: context.coconutColors.iconPrimary,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: SvgPicture.asset(
                                                      CommonStateIconPath.stopSign,
                                                      width: 14,
                                                      height: 14,
                                                      colorFilter: ColorFilter.mode(
                                                        context.coconutColors.iconButtonHighlight,
                                                        BlendMode.srcIn,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                CoconutLayout.spacing_200w,
                                                Expanded(
                                                  child: Padding(
                                                    padding: EdgeInsets.only(top: backupTipTextTopPadding),
                                                    child: Text(
                                                      LocaleSettings.currentLocale == AppLocale.ko
                                                          ? TextUtils.preventLineBreakInsideWords(strings.backup_tips_2)
                                                          : strings.backup_tips_2,
                                                      style: CoconutTypography.body2_14.setColor(
                                                        context.coconutColors.primaryText,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            CoconutLayout.spacing_400h,
                                            Row(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding: EdgeInsets.only(top: backupTipIconTopPadding),
                                                  child: Container(
                                                    width: 24,
                                                    height: 24,
                                                    decoration: BoxDecoration(
                                                      color: context.coconutColors.iconPrimary,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    alignment: Alignment.center,
                                                    child: SvgPicture.asset(
                                                      CommonSecurityIconPath.lock,
                                                      width: 14,
                                                      height: 14,
                                                      colorFilter: ColorFilter.mode(
                                                        context.coconutColors.iconButtonHighlight,
                                                        BlendMode.srcIn,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                CoconutLayout.spacing_200w,
                                                Expanded(
                                                  child: Padding(
                                                    padding: EdgeInsets.only(top: backupTipTextTopPadding),
                                                    child: Text(
                                                      LocaleSettings.currentLocale == AppLocale.ko
                                                          ? TextUtils.preventLineBreakInsideWords(strings.backup_tips_3)
                                                          : strings.backup_tips_3,
                                                      style: CoconutTypography.body2_14.setColor(
                                                        context.coconutColors.primaryText,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (_isBottomButtonVisible)
              FixedBottomButton(
                onButtonClicked: _isBackupPreparationStage ? _startMnemonicBackupFlow : _showBackupPreparation,
                text: _isBackupPreparationStage ? strings.backup_start : strings.backup_title,
                subWidget:
                    _isBackupPreparationStage ? null : CoconutUnderlinedButton(onTap: _finish, text: strings.skip),
              ).slideUpAnimation(
                duration: const Duration(milliseconds: 350),
                delay: const Duration(milliseconds: 200),
                offset: const Offset(0, 8),
                curve: Curves.easeOutCubic,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _startMnemonicBackupFlow() async {
    try {
      String mnemonic;
      String passphrase;
      if (widget.secureStorageKey != null) {
        final plaintext = await HotWalletUnlockService().unlockPreferBiometrics(
          context: context,
          storageKey: widget.secureStorageKey!,
        );
        if (!mounted || plaintext == null) return;
        mnemonic = plaintext.mnemonic;
        passphrase = plaintext.passphrase;
      } else {
        final mnemonicBytes = widget.mnemonic;
        final passphraseBytes = widget.passphrase;
        if (mnemonicBytes == null || passphraseBytes == null) return;
        mnemonic = utf8.decode(mnemonicBytes);
        passphrase = utf8.decode(passphraseBytes);
      }

      final isBackupConfirmed = await Navigator.pushNamed(
        context,
        '/hot-wallet-mnemonic-backup',
        arguments: {
          'mnemonic': mnemonic,
          'passphrase': passphrase,
          'enterPassphraseWhenSigning': widget.enterPassphraseWhenSigning,
          'walletId': widget.walletId,
          'continueToAppLockGuide': widget.continueToAppLockGuide,
        },
      );
      if (!mounted || isBackupConfirmed != true) return;
      if (!widget.continueToAppLockGuide) {
        _finish();
      }
    } catch (error) {
      if (!mounted) return;
      await showInfoDialog(
        context,
        context.read<PreferenceProvider>().language,
        t.alert.error_occurs,
        error.toString(),
      );
    }
  }

  Future<void> _showBackupPreparation() async {
    if (_isStageTransitioning) return;
    _isStageTransitioning = true;
    setState(() {
      _isBottomButtonVisible = false;
      _isBackupPreparationStage = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _isPreparationTitleVisible = true);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    setState(() => _isPreparationDescriptionVisible = true);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    setState(() => _isPreparationContentVisible = true);
    await Future<void>.delayed(const Duration(milliseconds: 140));
    if (!mounted) return;
    setState(() {
      _isBottomButtonVisible = true;
      _isStageTransitioning = false;
    });
  }

  Future<void> _hideBackupPreparation() async {
    if (_isStageTransitioning) return;
    _isStageTransitioning = true;
    setState(() => _isBottomButtonVisible = false);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _isPreparationContentVisible = false);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _isPreparationDescriptionVisible = false);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    setState(() => _isPreparationTitleVisible = false);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    setState(() => _isBackupPreparationStage = false);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _isBottomButtonVisible = true;
      _isStageTransitioning = false;
    });
  }

  void _onAppBarBackPressed() {
    if (widget.returnToPreviousOnExit) {
      _finish();
      return;
    }
    if (_isBackupPreparationStage) {
      _hideBackupPreparation();
      return;
    }
    _finish();
  }

  void _finish() {
    if (widget.returnToPreviousOnExit) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/wallet-detail',
      (route) => route.isFirst,
      arguments: {'id': widget.walletId, 'entryPoint': kEntryPointWalletHome},
    );
  }
}

class _SequentialEntry extends StatelessWidget {
  const _SequentialEntry({required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, 0.12),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
        child: IgnorePointer(ignoring: !visible, child: child),
      ),
    );
  }
}
