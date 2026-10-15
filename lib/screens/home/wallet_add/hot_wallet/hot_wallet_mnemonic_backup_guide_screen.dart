import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/analytics/backup_analytics.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'dart:typed_data';

import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/constants/lottie_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart' show kEntryPointWalletHome;
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/security/hot_wallet_unlock_service.dart';
import 'package:coconut_wallet/screens/common/flutter_hot_wallet_authenticator.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
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
    required this.walletId,
    this.mnemonic,
    this.passphrase,
    this.secureStorageKey,
    required this.enterPassphraseWhenSigning,
    this.showWalletCreatedIntro = true,
    this.continueToAppLockGuide = true,
    this.returnToPreviousOnExit = false,
  });

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
  bool _isBottomButtonVisible = false;
  bool _hasStartedLottie = false;
  bool _hasShownPreparation = false;
  bool _isExitPopupOpen = false;
  bool _isPreparationTitleVisible = false;
  bool _isPreparationDescriptionVisible = false;
  bool _isPreparationContentVisible = false;
  late final AnalyticsService _analyticsService;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
    _analyticsService = context.read<AnalyticsService>();
    if (!widget.showWalletCreatedIntro) {
      _isIntroVisible = false;
      _isBackupStageVisible = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showBackupPreparation();
      });
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

    await _showBackupPreparation();
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
                context: context,
                customTitle: Text(
                  strings.backup_title,
                  style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
                  textScaler: const TextScaler.linear(1),
                ),
                onBackPressed: _onAppBarBackPressed,
                isBottom: true,
                isBackButton: widget.returnToPreviousOnExit,
                backgroundColor: context.coconutColors.background,
              ),
            ),
          ),
        ),
        body: Stack(
          children: [
            if (widget.showWalletCreatedIntro)
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
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: context.coconutColors.iconBackgroundSubtle,
                            shape: BoxShape.circle,
                          ),
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
                              textScaler: const TextScaler.linear(1),
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const lottieHeight = 96.0;
                      final lottieTop = (constraints.maxHeight - lottieHeight) * 0.14;
                      return SingleChildScrollView(
                        controller: _preparationScrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: EdgeInsets.only(top: lottieTop, bottom: 200),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: lottieHeight,
                              height: lottieHeight,
                              child: Lottie.asset(
                                ActionLottiePath.noteWriting,
                                fit: BoxFit.contain,
                                repeat: false,
                                delegates: LottieDelegates(
                                  values: [
                                    ValueDelegate.colorFilter([
                                      '**',
                                    ], value: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcATop)),
                                  ],
                                ),
                              ),
                            ).fadeInAnimation(duration: const Duration(milliseconds: 350)),
                            const SizedBox(height: 30),

                            _SequentialEntry(
                              visible: _isPreparationTitleVisible,
                              child: Text(
                                strings.backup_preparation_title,
                                textAlign: TextAlign.center,
                                style: CoconutTypography.heading3_21_Bold.setColor(context.coconutColors.primaryText),
                                textScaler: const TextScaler.linear(1),
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
              ),
            if (_isBottomButtonVisible)
              FixedBottomButton(
                onButtonClicked: _startMnemonicBackupFlow,
                text: strings.backup_start,
                subWidget:
                    widget.returnToPreviousOnExit
                        ? null
                        : CoconutUnderlinedButton(onTap: _requestExit, text: strings.skip),
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
    if (widget.showWalletCreatedIntro) {
      _analyticsService.logBackupPromptTapped(BackupPromptLocation.postCreate);
    }
    HotWalletPlaintext? plaintext;
    try {
      final Uint8List mnemonic;
      final Uint8List passphrase;
      if (widget.secureStorageKey != null) {
        plaintext = await AppGuard.runWithoutPrivacyScreen(
          () => HotWalletUnlockService(
            authenticator: FlutterHotWalletAuthenticator(context),
          ).unlock(widget.secureStorageKey!),
        );
        if (!mounted || plaintext == null) return;
        mnemonic = plaintext.mnemonic;
        passphrase = plaintext.passphrase;
      } else {
        final mnemonicBytes = widget.mnemonic;
        final passphraseBytes = widget.passphrase;
        if (mnemonicBytes == null || passphraseBytes == null) return;
        mnemonic = mnemonicBytes;
        passphrase = passphraseBytes;
      }

      final isBackupConfirmed = await Navigator.pushNamed(
        context,
        AppRouteNames.hotWalletMnemonicBackup,
        arguments: HotWalletMnemonicBackupRouteArgs(
          mnemonic: mnemonic,
          passphrase: passphrase,
          enterPassphraseWhenSigning: widget.enterPassphraseWhenSigning,
          walletId: widget.walletId,
          continueToAppLockGuide: widget.continueToAppLockGuide,
        ),
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
    } finally {
      // secureStorageKey 경로에서 unlock한 plaintext는 이 화면이 소유한다.
      // 바이트를 하위 화면에 전달한 뒤 하위 화면이 dispose될 때까지 기다렸다가
      // (await Navigator.pushNamed 완료 후) wipe한다.
      plaintext?.wipe();
    }
  }

  Future<void> _showBackupPreparation() async {
    if (!mounted || _hasShownPreparation) return;
    _hasShownPreparation = true;
    setState(() => _isBackupStageVisible = true);

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
    setState(() => _isBottomButtonVisible = true);
  }

  void _onAppBarBackPressed() => _requestExit();

  Future<void> _requestExit() async {
    if (widget.returnToPreviousOnExit) {
      _finish();
      return;
    }
    if (_isExitPopupOpen) return;
    _isExitPopupOpen = true;
    var confirmed = false;
    try {
      final strings = t.wallet_home_screen.hot_wallet_setup;
      await showInfoDialog(
        context,
        context.read<PreferenceProvider>().language,
        strings.backup_later_title,
        strings.backup_later_description,
        barrierDismissible: false,
        onTapButton: () {
          confirmed = true;
          Navigator.of(context).pop();
        },
      );
      if (!mounted || !confirmed) return;
      _finish();
    } finally {
      _isExitPopupOpen = false;
    }
  }

  void _finish() {
    if (widget.returnToPreviousOnExit) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRouteNames.walletDetail,
      (route) => route.isFirst,
      arguments: WalletDetailRouteArgs(id: widget.walletId, entryPoint: kEntryPointWalletHome),
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
