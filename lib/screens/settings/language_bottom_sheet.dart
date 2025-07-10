import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/bottom_sheet/selection_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LanguageBottomSheet extends StatelessWidget {
  const LanguageBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<PreferenceProvider, String>(
      selector: (_, provider) => provider.language,
      builder: (context, language, child) {
        return SelectionBottomSheet<String>(
          title: t.settings_screen.language,
          selectedValue: language,
          items: [
            SelectionItem<String>(
              title: t.settings_screen.korean,
              value: 'kr',
              onTap: () async {
                vibrateExtraLight();
                await context.read<PreferenceProvider>().changeLanguage('kr');

                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
            SelectionItem<String>(
              title: t.settings_screen.english,
              value: 'en',
              onTap: () async {
                vibrateExtraLight();
                await context.read<PreferenceProvider>().changeLanguage('en');
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
