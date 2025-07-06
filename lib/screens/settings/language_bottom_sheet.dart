import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class LanguageBottomSheet extends StatefulWidget {
  const LanguageBottomSheet({super.key});

  @override
  State<LanguageBottomSheet> createState() => _LanguageBottomSheetState();
}

class _LanguageBottomSheetState extends State<LanguageBottomSheet> {
  @override
  Widget build(BuildContext context) {
    return Selector<PreferenceProvider, String>(
        selector: (_, viewModel) => viewModel.language,
        builder: (context, language, child) {
          return Scaffold(
              backgroundColor: CoconutColors.black,
              appBar: CoconutAppBar.build(
                title: t.settings_screen.language,
                context: context,
                onBackPressed: null,
                isBottom: true,
              ),
              body: Padding(
                  padding: const EdgeInsets.only(left: Sizes.size16, right: Sizes.size16),
                  child: Column(children: [
                    _buildUnitItem(
                        t.settings_screen.korean, t.settings_screen.korean, language == 'kr',
                        () async {
                      await context.read<PreferenceProvider>().changeLanguage('kr');
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }),
                    Divider(
                      color: CoconutColors.white.withOpacity(0.12),
                      height: 1,
                    ),
                    _buildUnitItem(
                        t.settings_screen.english, t.settings_screen.english, language == 'en',
                        () async {
                      await context.read<PreferenceProvider>().changeLanguage('en');
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }),
                  ])));
        });
  }

  Widget _buildUnitItem(String title, String subtitle, bool isChecked, VoidCallback onPress) {
    return GestureDetector(
      onTap: onPress,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: Sizes.size20),
        child: Row(
          children: [
            Expanded(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white)),
              ],
            )),
            if (isChecked)
              Padding(
                padding: const EdgeInsets.only(right: Sizes.size8),
                child: SvgPicture.asset('assets/svg/check.svg'),
              ),
          ],
        ),
      ),
    );
  }
}
