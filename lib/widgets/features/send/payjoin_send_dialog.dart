import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_send_attempt.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

/// Shows a sender what its payjoin attempt is doing and lets it send the
/// Original without waiting any longer.
class PayjoinSendDialog extends StatelessWidget {
  const PayjoinSendDialog({super.key, required this.stage, required this.onSendWithoutPayjoin});

  final ValueListenable<PayjoinSendStage> stage;
  final VoidCallback onSendWithoutPayjoin;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.all(CoconutLayout.defaultPadding),
        backgroundColor: colors.popupBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CoconutStyles.radius_250)),
        child: Padding(
          padding: const EdgeInsets.all(CoconutLayout.defaultPadding),
          child: ValueListenableBuilder<PayjoinSendStage>(
            valueListenable: stage,
            builder: (context, stage, _) {
              final done = stage == PayjoinSendStage.receiverAddedInput;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 32,
                    height: 32,
                    child:
                        done
                            ? Icon(Icons.check_circle, color: colors.primary, size: 32)
                            : CircularProgressIndicator(strokeWidth: 3, color: colors.primary),
                  ),
                  CoconutLayout.spacing_300h,
                  Text(
                    switch (stage) {
                      PayjoinSendStage.contactingReceiver => t.payjoin.contacting_receiver,
                      PayjoinSendStage.waitingForReceiver => t.payjoin.waiting_for_receiver,
                      PayjoinSendStage.receiverAddedInput => t.payjoin.receiver_added_input,
                    },
                    key: const ValueKey('payjoin-send-stage'),
                    textAlign: TextAlign.center,
                    style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText),
                  ),
                  CoconutLayout.spacing_200h,
                  Text(
                    t.payjoin.waiting_description,
                    textAlign: TextAlign.center,
                    style: CoconutTypography.body2_14.setColor(colors.secondaryText),
                  ),
                  CoconutLayout.spacing_300h,
                  TextButton(
                    onPressed: done ? null : onSendWithoutPayjoin,
                    child: Text(
                      t.payjoin.send_without_payjoin,
                      style: CoconutTypography.body2_14_Bold.setColor(done ? colors.secondaryText : colors.primary),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
