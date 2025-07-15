import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
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
          title: t.fiat.fiat,
          selectedValue: selectedFiat,
          items: [
            SelectionItem<FiatCode>(
              title: t.fiat.krw_code,
              subtitle: t.fiat.krw_price,
              value: FiatCode.KRW,
              onTap: () async {
                vibrateExtraLight();
                await context.read<PreferenceProvider>().changeFiat(FiatCode.KRW);

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
            SelectionItem<FiatCode>(
              title: t.fiat.usd_code,
              subtitle: t.fiat.usd_price,
              value: FiatCode.USD,
              onTap: () async {
                vibrateExtraLight();
                await context.read<PreferenceProvider>().changeFiat(FiatCode.USD);

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }
}
