import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/send_view_model.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

enum ArkHandoffChoice { bitcoin, proceed }

/// 온체인 보내기에 들어온 라이트닝·아크 결제를 어떻게 할지 묻는 팝업
Future<ArkHandoffChoice?> showArkHandoffPopup(
  BuildContext context,
  SendArkHandoff handoff, {
  required BitcoinUnit unit,
}) {
  String amount(int? sats) => unit.displayBitcoinAmount(sats, withUnit: true);
  final copy = t.ark_wallet;
  final (String title, String description, String left, String right) = switch (handoff.kind) {
    SendArkHandoffKind.send when handoff.offersBitcoin => (
      copy.handoff_choose_title,
      [
        copy.handoff_choose_line,
        if (handoff.showsAmounts)
          copy.handoff_amounts(bitcoin: amount(handoff.bitcoinAmountSats), ark: amount(handoff.arkAmountSats)),
      ].join('\n'),
      copy.handoff_bitcoin,
      copy.handoff_ark,
    ),
    SendArkHandoffKind.send => (copy.handoff_ark_title, copy.handoff_ark_line, t.cancel, copy.handoff_ark),
    SendArkHandoffKind.lowBalance => (
      copy.handoff_low_title,
      copy.handoff_low_line(balance: amount(handoff.arkBalanceSats), amount: amount(handoff.arkAmountSats)),
      t.close,
      copy.handoff_open_wallet,
    ),
    SendArkHandoffKind.addArk || SendArkHandoffKind.createWallet => (
      copy.handoff_ark_title,
      handoff.isInvoice ? copy.handoff_need_invoice_line : copy.handoff_need_line,
      t.close,
      handoff.kind == SendArkHandoffKind.addArk ? copy.handoff_learn : copy.handoff_create,
    ),
  };
  final leftChoice = handoff.offersBitcoin ? ArkHandoffChoice.bitcoin : null;
  return showDialog<ArkHandoffChoice>(
    context: context,
    builder:
        (dialogContext) => CoconutPopup(
          key: const Key('ark-handoff-popup'),
          languageCode: dialogContext.read<PreferenceProvider>().language,
          title: title,
          description: description.split('\n').map(TextUtils.preventLineBreakInsideWords).join('\n'),
          leftButtonText: left,
          rightButtonText: right,
          rightButtonColor: context.coconutColors.primaryText,
          onTapLeft: () => Navigator.pop(dialogContext, leftChoice),
          onTapRight: () => Navigator.pop(dialogContext, ArkHandoffChoice.proceed),
        ),
  );
}
