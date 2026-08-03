import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/features/auth/pin/key_button.dart';
import 'package:coconut_wallet/widgets/trezor_digit_box.dart';
import 'package:coconut_wallet/widgets/textfield/passphrase_input_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Loading card with spinner, title, and optional description.
class TrezorWalletMismatchWarning extends StatelessWidget {
  final String? matchedWalletName;

  const TrezorWalletMismatchWarning({super.key, this.matchedWalletName});

  @override
  Widget build(BuildContext context) {
    final message =
        matchedWalletName != null
            ? t.trezor_sign_screen.device_mismatch_other_wallet(wallet_name: matchedWalletName!)
            : t.trezor_sign_screen.device_mismatch;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: context.coconutColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
        border: Border.all(color: context.coconutColors.danger.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SvgPicture.asset(
              'assets/svg/triangle-warning.svg',
              colorFilter: ColorFilter.mode(context.coconutColors.danger, BlendMode.srcIn),
              width: 16,
              height: 16,
            ),
          ),
          CoconutLayout.spacing_200w,
          Expanded(child: Text(message, style: CoconutTypography.body3_12.setColor(context.coconutColors.danger))),
        ],
      ),
    );
  }
}

class TrezorWalletMismatchActionButton extends StatelessWidget {
  final VoidCallback onButtonClicked;
  final bool isActive;

  const TrezorWalletMismatchActionButton({super.key, required this.onButtonClicked, this.isActive = true});

  @override
  Widget build(BuildContext context) {
    return FixedBottomButton(
      onButtonClicked: onButtonClicked,
      text: t.trezor_sign_screen.btn.connect_other_trezor,
      isActive: isActive,
    );
  }
}

class TrezorLoadingCard extends StatelessWidget {
  final String title;
  final String? description;

  const TrezorLoadingCard({super.key, required this.title, this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.coconutColors.surface,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(color: context.coconutColors.primary, strokeWidth: 3),
          ),
          CoconutLayout.spacing_400h,
          Text(
            title,
            style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
            textAlign: TextAlign.center,
          ),
          if (description != null && description!.isNotEmpty) ...[
            CoconutLayout.spacing_200h,
            Text(
              description!,
              style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

/// Option button used in passphrase selection cards.
class TrezorPassphraseOptionButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;

  const TrezorPassphraseOptionButton({super.key, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ShrinkAnimationButton(
        defaultColor: context.coconutColors.surfaceButton,
        borderRadius: CoconutStyles.radius_200,
        isActive: onTap != null,
        onPressed: onTap ?? () {},
        child: SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: CoconutTypography.body2_14.setColor(
                onTap != null ? context.coconutColors.primaryText : context.coconutColors.tertiaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Step 1: "Do you want to use a passphrase?"
class TrezorPassphraseUseQuestionCard extends StatelessWidget {
  final VoidCallback onUsePassphrase;
  final VoidCallback onNoPassphrase;

  const TrezorPassphraseUseQuestionCard({super.key, required this.onUsePassphrase, required this.onNoPassphrase});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            t.wallet_connect_screen.guide_trezor.usb.passphrase_use_question,
            textAlign: TextAlign.center,
            style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
          ),
          CoconutLayout.spacing_400h,
          TrezorPassphraseOptionButton(
            text: t.wallet_connect_screen.guide_trezor.usb.passphrase_use_yes,
            onTap: onUsePassphrase,
          ),
          CoconutLayout.spacing_200h,
          TrezorPassphraseOptionButton(
            text: t.wallet_connect_screen.guide_trezor.usb.passphrase_use_no,
            onTap: onNoPassphrase,
          ),
        ],
      ),
    );
  }
}

/// Step 3: "Where do you want to enter your passphrase?"
class TrezorPassphraseSourceSelectionCard extends StatelessWidget {
  final VoidCallback onAppEntry;
  final VoidCallback onDeviceEntry;

  const TrezorPassphraseSourceSelectionCard({super.key, required this.onAppEntry, required this.onDeviceEntry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.wallet_connect_screen.guide_trezor.usb.passphrase_where_to_enter,
            style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
          ),
          CoconutLayout.spacing_400h,
          TrezorPassphraseOptionButton(text: t.wallet_connect_screen.guide_trezor.usb.enter_in_app, onTap: onAppEntry),
          CoconutLayout.spacing_200h,
          TrezorPassphraseOptionButton(
            text: t.wallet_connect_screen.guide_trezor.usb.enter_on_trezor,
            onTap: onDeviceEntry,
          ),
        ],
      ),
    );
  }
}

/// Step 4-1: "Enter your passphrase" (app input)
class TrezorPassphraseInputCard extends StatelessWidget {
  final TextEditingController passphraseController;
  final FocusNode passphraseFocusNode;
  final ValueChanged<String> onChanged;

  const TrezorPassphraseInputCard({
    super.key,
    required this.passphraseController,
    required this.passphraseFocusNode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.coconutColors.surface,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PassphraseTextField(
            passphraseController: passphraseController,
            passphraseFocusNode: passphraseFocusNode,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// Step 4-2: "Enter your passphrase on Trezor" (loading)
class TrezorPassphraseOnDeviceCard extends StatelessWidget {
  const TrezorPassphraseOnDeviceCard({super.key});

  @override
  Widget build(BuildContext context) {
    return TrezorLoadingCard(title: t.wallet_connect_screen.guide_trezor.usb.enter_on_trezor_description);
  }
}

/// Step 5: "Confirm passphrase on Trezor" (loading)
class TrezorPassphraseConfirmCard extends StatelessWidget {
  const TrezorPassphraseConfirmCard({super.key});

  @override
  Widget build(BuildContext context) {
    return TrezorLoadingCard(title: t.wallet_connect_screen.guide_trezor.usb.passphrase_confirm_on_device);
  }
}

/// Step 6: Processing — getXPub in progress (loading)
class TrezorPassphraseProcessingCard extends StatelessWidget {
  final bool usesThp;
  final bool usePassphrase;
  const TrezorPassphraseProcessingCard({super.key, this.usesThp = true, this.usePassphrase = false});

  @override
  Widget build(BuildContext context) {
    final showDevicePrompt = !usesThp && usePassphrase;
    return TrezorLoadingCard(
      title:
          showDevicePrompt
              ? t.wallet_connect_screen.guide_trezor.usb.connecting_step1
              : t.wallet_connect_screen.common.loading_wallet_info,
    );
  }
}

/// Pairing code input card with digit boxes and keypad.
/// Used by both USB and BLE connect screens.
class TrezorPairingCard extends StatelessWidget {
  final String pairingCode;
  final bool isVerifying;
  final bool hasError;
  final String? errorMessage;
  final ValueChanged<String> onKeyTap;
  final double minHeight;

  static const int _codeLength = 6;
  static const List<String> _keypadKeys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '<'];

  const TrezorPairingCard({
    super.key,
    required this.pairingCode,
    required this.isVerifying,
    required this.hasError,
    required this.errorMessage,
    required this.onKeyTap,
    this.minHeight = 0,
  });

  @override
  Widget build(BuildContext context) {
    final childAspectRatio = MediaQuery.sizeOf(context).width > 600 ? 2.5 : 1.4;
    final gridWidth = MediaQuery.sizeOf(context).width - 48;
    final keypadHeight = gridWidth / 3 / childAspectRatio * 4;

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: IntrinsicHeight(
        child: Column(
          children: [
            Text(
              t.wallet_connect_screen.guide_trezor.pairing_dialog.title,
              style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              t.wallet_connect_screen.guide_trezor.pairing_dialog.description,
              style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 84,
              child: Stack(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (int index = 0; index < _codeLength; index++) ...[
                        if (index > 0) SizedBox(width: index == 3 ? 12 : 4),
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 40),
                            child: TrezorDigitBox(
                              digit: index < pairingCode.length ? pairingCode[index] : '',
                              hasError: hasError,
                              isVerifying: isVerifying,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (isVerifying)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(color: context.coconutColors.primary, strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t.wallet_connect_screen.guide_trezor.pairing_dialog.verifying,
                            style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                          ),
                        ],
                      ),
                    )
                  else if (errorMessage != null)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Text(
                        errorMessage!,
                        style: CoconutTypography.body3_12.setColor(context.coconutColors.danger),
                        textAlign: TextAlign.center,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: keypadHeight + 48),
                child: Center(
                  child: SizedBox(
                    height: keypadHeight,
                    child: GridView.count(
                      crossAxisCount: 3,
                      childAspectRatio: childAspectRatio,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children:
                          _keypadKeys.map((key) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: KeyButton(keyValue: key, onKeyTap: isVerifying ? (_) {} : onKeyTap),
                            );
                          }).toList(),
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
}

/// Passphrase input action button (FixedBottomButton).
class TrezorPassphraseInputActionButton extends StatelessWidget {
  final VoidCallback onSubmit;
  final TextEditingController passphraseController;

  const TrezorPassphraseInputActionButton({super.key, required this.onSubmit, required this.passphraseController});

  @override
  Widget build(BuildContext context) {
    return FixedBottomButton(
      onButtonClicked: onSubmit,
      text: t.confirm,
      isActive: passphraseController.text.isNotEmpty,
    );
  }
}
