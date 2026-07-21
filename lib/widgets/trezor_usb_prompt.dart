import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:flutter/material.dart';

class TrezorUsbPrompt {
  static Future<String?> requestPin(BuildContext context) async {
    var pin = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  backgroundColor: context.coconutColors.surfaceBottomSheet,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoconutStyles.radius_300)),
                  title: Text(
                    t.wallet_connect_screen.guide_trezor.usb.pin_title,
                    style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        t.wallet_connect_screen.guide_trezor.usb.pin_description,
                        style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                        textAlign: TextAlign.center,
                      ),
                      CoconutLayout.spacing_300h,
                      Text(
                        '●' * pin.length,
                        style: CoconutTypography.heading3_21_Number.setColor(context.coconutColors.primaryText),
                      ),
                      CoconutLayout.spacing_300h,
                      GridView.count(
                        crossAxisCount: 3,
                        shrinkWrap: true,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        children: [
                          for (final value in const ['7', '8', '9', '4', '5', '6', '1', '2', '3'])
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                backgroundColor: context.coconutColors.inputSurface,
                                foregroundColor: context.coconutColors.primaryText,
                                disabledBackgroundColor: context.coconutColors.surfaceDisabled,
                                side: BorderSide(color: context.coconutColors.inputBorder),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
                                ),
                              ),
                              onPressed: pin.length == 9 ? null : () => setDialogState(() => pin += value),
                              child: const Text('●'),
                            ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: context.coconutColors.secondaryText),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: Text(t.cancel),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: context.coconutColors.primary,
                        disabledForegroundColor: context.coconutColors.secondaryText,
                      ),
                      onPressed: pin.isEmpty ? null : () => Navigator.pop(dialogContext, pin),
                      child: Text(t.OK),
                    ),
                  ],
                ),
          ),
    );
  }

  static Future<TrezorPassphraseResponse> requestPassphrase(BuildContext context, bool onDevice) async {
    if (onDevice) {
      return const TrezorPassphraseResponse(TrezorPassphraseType.onDevice);
    }
    final controller = TextEditingController();
    final response = await showDialog<TrezorPassphraseResponse>(
      context: context,
      barrierDismissible: false,
      builder:
          (dialogContext) => AlertDialog(
            title: Text(t.wallet_connect_screen.guide_trezor.usb.passphrase_title),
            content: TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(hintText: t.wallet_connect_screen.guide_trezor.usb.passphrase_hint),
            ),
            actions: [
              TextButton(
                onPressed:
                    () => Navigator.pop(dialogContext, const TrezorPassphraseResponse(TrezorPassphraseType.cancel)),
                child: Text(t.cancel),
              ),
              TextButton(
                onPressed:
                    () => Navigator.pop(dialogContext, const TrezorPassphraseResponse(TrezorPassphraseType.standard)),
                child: Text(t.wallet_connect_screen.guide_trezor.usb.standard_wallet),
              ),
              TextButton(
                onPressed:
                    () => Navigator.pop(
                      dialogContext,
                      TrezorPassphraseResponse(TrezorPassphraseType.hidden, value: controller.text),
                    ),
                child: Text(t.OK),
              ),
            ],
          ),
    );
    controller.dispose();
    return response ?? const TrezorPassphraseResponse(TrezorPassphraseType.cancel);
  }
}
