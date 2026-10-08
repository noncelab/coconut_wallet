import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/selection_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class NumberFormatBottomSheet extends StatelessWidget {
  NumberFormatBottomSheet({super.key});

  final List<_NumberFormatOption> _options =
      NumberFormatPreset.values
          .map((preset) => _NumberFormatOption(value: preset, title: preset.displayLabel))
          .toList();

  Future<void> _onNumberFormatSelected(BuildContext context, NumberFormatPreset preset) async {
    await context.read<PreferenceProvider>().changeNumberFormatPreset(preset);
  }

  @override
  Widget build(BuildContext context) {
    return Selector<PreferenceProvider, NumberFormatPreset>(
      selector: (_, provider) => provider.numberFormatPreset,
      builder: (context, preset, child) {
        return SelectionBottomSheet<NumberFormatPreset>(
          title: t.number_format_bottom_sheet.title,
          selectedValue: preset,
          items:
              _options
                  .map(
                    (option) => SelectionItem<NumberFormatPreset>(
                      title: option.title,
                      value: option.value,
                      titleStyle: const TextStyle(fontFamily: 'SpaceGrotesk'),
                      onTap: () => _onNumberFormatSelected(context, option.value),
                    ),
                  )
                  .toList(),
        );
      },
    );
  }
}

class _NumberFormatOption {
  const _NumberFormatOption({required this.value, required this.title});

  final NumberFormatPreset value;
  final String title;
}
