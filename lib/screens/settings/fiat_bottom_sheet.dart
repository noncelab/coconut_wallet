import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/bottom_sheet/selection_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FiatBottomSheet extends StatelessWidget {
  const FiatBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<PreferenceProvider, FiatCode>(
      selector: (_, provider) => provider.selectedFiat,
      builder: (context, selectedFiat, child) {
        return SelectionBottomSheet<FiatCode>(
          title: t.fiat_bottom_sheet.title,
          selectedValue: selectedFiat,
          items: [
            SelectionItem<FiatCode>(
              title: FiatCode.KRW.code,
              subtitle: t.fiat_bottom_sheet.krw_price,
              value: FiatCode.KRW,
              onTap: () => _onFiatSelected(context, FiatCode.KRW),
            ),
            SelectionItem<FiatCode>(
              title: FiatCode.USD.code,
              subtitle: t.fiat_bottom_sheet.usd_price,
              value: FiatCode.USD,
              onTap: () => _onFiatSelected(context, FiatCode.USD),
            ),
            SelectionItem<FiatCode>(
              title: FiatCode.JPY.code,
              subtitle: t.fiat_bottom_sheet.jpy_price,
              value: FiatCode.JPY,
              onTap: () => _onFiatSelected(context, FiatCode.JPY),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onFiatSelected(BuildContext context, FiatCode fiatCode) async {
    vibrateExtraLight();
    await context.read<PreferenceProvider>().changeFiat(fiatCode);

    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }
}
