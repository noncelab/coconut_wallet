import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/open_store/coconut_open_store_content.dart';
import 'package:coconut_wallet/ccos/open_store/coconut_open_store_navigation.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/features/ccos/card/coconut_open_store_intro_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

class ThemeBottomSheet extends StatelessWidget {
  const ThemeBottomSheet({super.key});

  static const CcosOpenStoreIntro _intro = CcosOpenStoreContentSource.intro;

  Future<void> _onThemeSelected(BuildContext context, CoconutThemeVariant variant) async {
    await context.read<PreferenceProvider>().changeThemeVariant(variant);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Consumer<PreferenceProvider>(
      builder: (context, provider, child) {
        final builtInThemes = <_ThemeOption>[
          _ThemeOption(variant: CoconutThemeVariant.dark, title: t.theme_dark),
          _ThemeOption(variant: CoconutThemeVariant.light, title: t.theme_light),
          if (provider.getCcosFeatureAvailability(CcosFeatureRegistrySource.featuredListing.id).isActivated)
            _ThemeOption(variant: CoconutThemeVariant.coconutPulp, title: t.theme_coconut_pulp),
        ];
        return Scaffold(
          backgroundColor: colors.background,
          appBar: CoconutAppBar.build(
            title: t.theme,
            context: context,
            onBackPressed: null,
            isBottom: true,
            actionButtonList: [
              CoconutAppBarActionButton(
                onPressed: () => openCoconutOpenStoreIntroScreen(context),
                icon: SvgPicture.asset(
                  BrandIconPath.coconutPlanet,
                  width: Sizes.size24,
                  height: Sizes.size24,
                  colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.size16),
            children: [
              const SizedBox(height: Sizes.size8),
              if (provider.shouldShowOpenStoreIntroCard) ...[
                CoconutOpenStoreIntroCard(
                  intro: _intro,
                  onTap: () => openCoconutOpenStoreIntroScreen(context),
                  onDismiss: provider.hideOpenStoreIntroCardForOneMonth,
                ),
                const SizedBox(height: Sizes.size20),
              ],
              ..._buildThemeRows(context, provider.themeVariant, builtInThemes),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildThemeRows(BuildContext context, CoconutThemeVariant selectedVariant, List<_ThemeOption> options) {
    final colors = context.coconutColors;
    final widgets = <Widget>[];
    for (int index = 0; index < options.length; index++) {
      final option = options[index];
      final isSelected = option.variant == selectedVariant;
      final isCoconutPulp = option.variant == CoconutThemeVariant.coconutPulp;
      widgets.add(
        InkWell(
          onTap: () => _onThemeSelected(context, option.variant),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Sizes.size20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(option.title, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
                      if (isCoconutPulp) ...[
                        const SizedBox(height: Sizes.size4),
                        Text(
                          '${CcosFeatureRegistrySource.featuredListing.author} · ${CcosFeatureRegistrySource.featuredListing.authorDescription}',
                          style: CoconutTypography.caption_10.setColor(colors.secondaryText),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSelected)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: SvgPicture.asset(
                      CommonActionIconPath.check,
                      colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
      if (index < options.length - 1) {
        widgets.add(Divider(color: colors.primaryText.withValues(alpha: 0.12), height: 1));
      }
    }
    return widgets;
  }
}

class _ThemeOption {
  const _ThemeOption({required this.variant, required this.title});

  final CoconutThemeVariant variant;
  final String title;
}
