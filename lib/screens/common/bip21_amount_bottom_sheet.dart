import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/common/single_text_field_bottom_sheet.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/text_field_filter_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// [Bip21AmountBottomSheet]에서 사용되는 결과 DTO
class Bip21AmountBottomSheetResult {
  final bool didEdit;
  final int? amountInSats;

  const Bip21AmountBottomSheetResult({required this.didEdit, required this.amountInSats});
}

/// BIP21 금액 입력 BottomSheet 공통 호출 유틸
class Bip21AmountBottomSheet {
  static Future<Bip21AmountBottomSheetResult?> show({
    required BuildContext context,
    required BitcoinUnit currentUnit,
    required int? initialAmountSats,
  }) {
    final initialText = BalanceFormatUtil.formatSatsToBip21InputText(
      currentUnit: currentUnit,
      initialAmountSats: initialAmountSats,
    );

    return SingleTextFieldBottomSheet.showWithResult<Bip21AmountBottomSheetResult>(
      context: context,
      title: t.address_list_screen.set_amount,
      originalText: initialText,
      placeholder: t.address_list_screen.enter_receive_amount,
      keyboardType: currentUnit.isBtcUnit ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
      visibleTextLimit: false,
      collapsedHeight: 240,
      textInputFormatters:
          currentUnit.isBtcUnit
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')), const BtcAmountInputFormatter()]
              : [FilteringTextInputFormatter.digitsOnly, const SatoshiAmountInputFormatter()],
      completeEnabledWhen: (current, original) => current != original,
      focusOnlyWhenOriginalNotEmpty: false,
      prefix:
          currentUnit.isBip177Unit
              ? Padding(
                padding: const EdgeInsets.only(left: 12, right: 6),
                child: Text(currentUnit.symbol, style: CoconutTypography.body2_14_Bold),
              )
              : null,
      suffix:
          (currentUnit.isBtcUnit || currentUnit.isSatsUnit)
              ? Text(currentUnit.symbol, style: CoconutTypography.body2_14_Bold)
              : null,
      resultBuilder: (currentText, originalText) {
        final sats = BalanceFormatUtil.parseBip21AmountTextToSats(currentUnit: currentUnit, inputText: currentText);
        return Bip21AmountBottomSheetResult(didEdit: currentText != originalText, amountInSats: sats);
      },
    );
  }
}
