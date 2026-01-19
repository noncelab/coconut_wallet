import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/widgets/bottom_sheet/selection_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UnitBottomSheet extends StatelessWidget {
  const UnitBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<PreferenceProvider, bool>(
      selector: (_, provider) => provider.isBtcUnit,
      builder: (context, isBtcUnit, child) {
        return SelectionBottomSheet<bool>(
          title: t.unit_bottom_sheet.basic_unit,
          headerText: t.unit_bottom_sheet.header_text,
          selectedValue: isBtcUnit,
          items: [
            SelectionItem<bool>(
              title: t.bitcoin_name,
              subtitle: t.btc,
              value: true,
              onTap: () {
                context.read<PreferenceProvider>().changeIsBtcUnit(true);
                Navigator.of(context).pop();
              },
            ),
            SelectionItem<bool>(
              title: t.satoshi,
              subtitle: t.sats,
              value: false,
              onTap: () {
                context.read<PreferenceProvider>().changeIsBtcUnit(false);
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
