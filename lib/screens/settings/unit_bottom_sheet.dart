import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/widgets/bottom_sheet/selection_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UnitBottomSheet extends StatelessWidget {
  const UnitBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<PreferenceProvider, BitcoinUnit>(
      selector: (_, provider) => provider.currentUnit,
      builder: (context, currentUnit, child) {
        return SelectionBottomSheet<BitcoinUnit>(
          title: t.unit_bottom_sheet.title,
          headerText: currentUnit.isBip177Unit ? t.unit_bottom_sheet.bip177_text : t.unit_bottom_sheet.header_text,
          selectedValue: currentUnit,
          items:
              BitcoinUnit.values
                  .map(
                    (unit) => SelectionItem<BitcoinUnit>(
                      title: unit.fullName,
                      subtitle: unit.symbol,
                      value: unit,
                      onTap: () {
                        context.read<PreferenceProvider>().changeBitcoinUnit(unit);
                        Navigator.of(context).pop();
                      },
                    ),
                  )
                  .toList(),
        );
      },
    );
  }
}
