import 'package:coconut_wallet/constants/app_language.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/widgets/bottom_sheet/selection_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LanguageBottomSheet extends StatelessWidget {
  LanguageBottomSheet({super.key});

  final List<_LanguageOption> _languages = <_LanguageOption>[
    _LanguageOption(code: AppLanguage.kr.code, title: t.language_bottom_sheet.korean),
    _LanguageOption(code: AppLanguage.en.code, title: t.language_bottom_sheet.english),
    _LanguageOption(code: AppLanguage.jp.code, title: t.language_bottom_sheet.japanese),
    _LanguageOption(code: AppLanguage.es.code, title: t.language_bottom_sheet.spanish),
    _LanguageOption(code: AppLanguage.de.code, title: t.language_bottom_sheet.german),
  ];

  Future<void> _onLanguageSelected(BuildContext context, String code) async {
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
