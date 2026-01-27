import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/bottom_sheet/selection_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LanguageBottomSheet extends StatelessWidget {
  LanguageBottomSheet({super.key});

  final List<_LanguageOption> _languages = <_LanguageOption>[
    _LanguageOption(code: 'kr', title: t.settings_screen.locales.korean),
    _LanguageOption(code: 'en', title: t.settings_screen.locales.english),
    _LanguageOption(code: 'jp', title: t.settings_screen.locales.japanese),
    _LanguageOption(code: 'es', title: t.settings_screen.locales.spanish),
  ];

  Future<void> _onLanguageSelected(BuildContext context, String code) async {
    vibrateExtraLight();
    await context.read<PreferenceProvider>().changeLanguage(code);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Selector<PreferenceProvider, String>(
      selector: (_, provider) => provider.language,
      builder: (context, language, child) {
        return SelectionBottomSheet<String>(
          title: t.settings_screen.language,
          selectedValue: language,
          items:
              _languages
                  .map(
                    (option) => SelectionItem<String>(
                      title: option.title,
                      value: option.code,
                      onTap: () => _onLanguageSelected(context, option.code),
                    ),
                  )
                  .toList(),
        );
      },
    );
  }
}

class _LanguageOption {
  const _LanguageOption({required this.code, required this.title});

  final String code;
  final String title;
}
