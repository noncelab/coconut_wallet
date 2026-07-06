import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/widgets/bottom_sheet/selection_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ThemeBottomSheet extends StatelessWidget {
  const ThemeBottomSheet({super.key});

  List<_ThemeOption> get _themes => [
    _ThemeOption(variant: CoconutThemeVariant.dark, title: t.theme_dark),
    _ThemeOption(variant: CoconutThemeVariant.light, title: t.theme_light),
  ];

  Future<void> _onThemeSelected(BuildContext context, CoconutThemeVariant variant) async {
    await context.read<PreferenceProvider>().changeThemeVariant(variant);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<PreferenceProvider, CoconutThemeVariant>(
      selector: (_, provider) => provider.themeVariant,
      builder: (context, themeVariant, child) {
        return SelectionBottomSheet<CoconutThemeVariant>(
          title: t.theme,
          selectedValue: themeVariant,
          items:
              _themes
                  .map(
                    (option) => SelectionItem<CoconutThemeVariant>(
                      title: option.title,
                      value: option.variant,
                      onTap: () => _onThemeSelected(context, option.variant),
                    ),
                  )
                  .toList(),
        );
      },
    );
  }
}

class _ThemeOption {
  const _ThemeOption({required this.variant, required this.title});

  final CoconutThemeVariant variant;
  final String title;
}
