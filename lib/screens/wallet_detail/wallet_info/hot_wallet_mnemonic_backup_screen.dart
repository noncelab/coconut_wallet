import 'dart:ui';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HotWalletMnemonicBackupScreen extends StatefulWidget {
  const HotWalletMnemonicBackupScreen({
    super.key,
    required this.mnemonic,
    this.passphrase = '',
    this.enterPassphraseWhenSigning = false,
    this.descriptor = '',
    this.walletId,
    this.continueToAppLockGuide = false,
  });

  final String mnemonic;
  final String passphrase;
  final bool enterPassphraseWhenSigning;
  final String descriptor;
  final int? walletId;
  final bool continueToAppLockGuide;

  @override
  State<HotWalletMnemonicBackupScreen> createState() => _HotWalletMnemonicBackupScreenState();
}

class _HotWalletMnemonicBackupScreenState extends State<HotWalletMnemonicBackupScreen> {
  late final List<String> _words;
  bool _isWarningVisible = true;
  bool _isPassphraseVisible = false;

  @override
  void initState() {
    super.initState();
    _words = widget.mnemonic.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final strings = t.wallet_home_screen.hot_wallet_setup;

    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(
        title: strings.backup_title,
        context: context,
        backgroundColor: context.coconutColors.background,
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(top: 48, bottom: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.passphrase.isNotEmpty && !widget.enterPassphraseWhenSigning) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _PassphraseCard(
                        passphrase: widget.passphrase,
                        isVisible: _isPassphraseVisible,
                        onPressed: () => setState(() => _isPassphraseVisible = !_isPassphraseVisible),
                      ),
                    ),
                    CoconutLayout.spacing_600h,
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      strings.mnemonic_backup_guide,
                      style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.danger),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  CoconutLayout.spacing_600h,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _words.length,
                        itemBuilder: (context, index) => _MnemonicWordItem(index: index, word: _words[index]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            FixedBottomButton(
              onButtonClicked: _startBackupConfirmation,
              text: strings.backup_check_button,
              isActive: !_isWarningVisible,
              surroundingsColor: context.coconutColors.background,
            ),
            if (_isWarningVisible)
              Positioned.fill(
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: ColoredBox(
                      color: context.coconutColors.background.withValues(alpha: 0.16),
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: _MnemonicWarningCard(onConfirm: () => setState(() => _isWarningVisible = false)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _startBackupConfirmation() async {
    final isConfirmed = await Navigator.pushNamed(
      context,
      '/mnemonic-backup-confirm',
      arguments: {
        'mnemonic': widget.mnemonic,
        'passphrase': widget.passphrase,
        'descriptor': widget.descriptor,
        'confirmPassphrase': widget.enterPassphraseWhenSigning || widget.passphrase.isNotEmpty,
        'walletId': widget.walletId,
        'continueToAppLockGuide': widget.continueToAppLockGuide,
      },
    );
    if (!mounted || isConfirmed != true) return;
    Navigator.pop(context, true);
  }
}

class _PassphraseCard extends StatelessWidget {
  const _PassphraseCard({required this.passphrase, required this.isVisible, required this.onPressed});

  final String passphrase;
  final bool isVisible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = t.wallet_home_screen.hot_wallet_setup;

    return Material(
      color: context.coconutColors.surface,
      borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      child: InkWell(
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.passphrase_title,
                      style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
                    ),
                    CoconutLayout.spacing_100h,
                    Text(
                      isVisible ? passphrase : '••••••••',
                      maxLines: isVisible ? null : 1,
                      style: CoconutTypography.body1_16.setColor(context.coconutColors.secondaryText),
                    ),
                  ],
                ),
              ),
              CoconutLayout.spacing_300w,
              SvgPicture.asset(
                isVisible ? CommonVisibilityIconPath.eye : CommonVisibilityIconPath.eyeCrossed,
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MnemonicWordItem extends StatelessWidget {
  const _MnemonicWordItem({required this.index, required this.word});

  final int index;
  final String word;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: context.coconutColors.primaryText.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Text(
            (index + 1).toString().padLeft(2, '0'),
            style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
          ),
          CoconutLayout.spacing_300w,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(word, style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MnemonicWarningCard extends StatelessWidget {
  const _MnemonicWarningCard({required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final strings = t.wallet_home_screen.hot_wallet_setup;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      decoration: BoxDecoration(color: context.coconutColors.danger, borderRadius: BorderRadius.circular(12)),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              CommonStateIconPath.triangleWarning,
              width: 32,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            CoconutLayout.spacing_300h,
            Text(
              LocaleSettings.currentLocale == AppLocale.ko
                  ? TextUtils.preventLineBreakInsideWords(strings.mnemonic_warning_title)
                  : strings.mnemonic_warning_title,
              style: CoconutTypography.heading3_21_Bold.setColor(Colors.white),
              textAlign: TextAlign.center,
            ),
            CoconutLayout.spacing_400h,
            Text(
              LocaleSettings.currentLocale == AppLocale.ko
                  ? TextUtils.preventLineBreakInsideWords(strings.mnemonic_warning_description)
                  : strings.mnemonic_warning_description,
              style: CoconutTypography.heading4_18.setColor(Colors.white),
              textAlign: TextAlign.center,
            ),
            CoconutLayout.spacing_600h,
            ShrinkAnimationButton(
              borderRadius: 12,
              defaultColor: Colors.white,
              pressedColor: Colors.white.withValues(alpha: 0.85),
              onPressed: onConfirm,
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    strings.mnemonic_warning_confirm,
                    style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.danger),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
            CoconutLayout.spacing_300h,
          ],
        ),
      ),
    );
  }
}
