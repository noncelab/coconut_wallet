import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/bottom_sheet/selection_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LanguageBottomSheet extends StatelessWidget {
  LanguageBottomSheet({super.key});

  final List<_LanguageOption> _languages = <_LanguageOption>[
    _LanguageOption(code: 'kr', title: t.language_bottom_sheet.korean),
    _LanguageOption(code: 'en', title: t.language_bottom_sheet.english),
    _LanguageOption(code: 'jp', title: t.language_bottom_sheet.japanese),
    _LanguageOption(code: 'es', title: t.language_bottom_sheet.spanish),
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
          title: t.language_bottom_sheet.title,
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
