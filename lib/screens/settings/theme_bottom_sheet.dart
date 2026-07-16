import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ccos/theme/ccos_theme_catalog.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/settings/coconut_open_store_screen.dart';
import 'package:coconut_wallet/widgets/button/shrink_tap_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class ThemeBottomSheet extends StatelessWidget {
  const ThemeBottomSheet({super.key});

  static const CcosOpenStoreIntro _intro = CcosThemeCatalogSource.intro;

  List<_ThemeOption> get _builtInThemes => [
    _ThemeOption(variant: CoconutThemeVariant.dark, title: t.theme_dark),
    _ThemeOption(variant: CoconutThemeVariant.light, title: t.theme_light),
    _ThemeOption(variant: CoconutThemeVariant.coconutPulp, title: t.theme_coconut_pulp),
  ];

  Future<void> _onThemeSelected(BuildContext context, CoconutThemeVariant variant) async {
    await context.read<PreferenceProvider>().changeThemeVariant(variant);
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _openThemeStore(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CoconutOpenStoreScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Consumer<PreferenceProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          backgroundColor: colors.background,
          appBar: CoconutAppBar.build(
            title: t.theme,
            context: context,
            onBackPressed: null,
            isBottom: true,
            actionButtonList: [
              IconButton(
                onPressed: () => _openThemeStore(context),
                icon: SvgPicture.asset(
                  'assets/svg/coconut-planet.svg',
                  width: Sizes.size24,
                  height: Sizes.size24,
                  colorFilter: ColorFilter.mode(colors.iconDefault, BlendMode.srcIn),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.size16),
            children: [
              const SizedBox(height: Sizes.size8),
              if (provider.shouldShowOpenStoreIntroCard) ...[
                _buildOpenStoreIntroCard(context),
                const SizedBox(height: Sizes.size20),
              ],
              ..._buildThemeRows(context, provider.themeVariant, _builtInThemes),
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
      widgets.add(
        InkWell(
          onTap: () => _onThemeSelected(context, option.variant),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: Sizes.size20),
            child: Row(
              children: [
                Expanded(
                  child: Text(option.title, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
                ),
                if (isSelected)
                  SvgPicture.asset(
                    'assets/svg/check.svg',
                    colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
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

  Widget _buildOpenStoreIntroCard(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      padding: const EdgeInsets.all(Sizes.size16),
      decoration: BoxDecoration(color: colors.surfaceMuted, borderRadius: BorderRadius.circular(Sizes.size12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/svg/coconut-planet.svg',
                width: Sizes.size18,
                height: Sizes.size18,
                colorFilter: ColorFilter.mode(colors.iconDefault, BlendMode.srcIn),
              ),
              CoconutLayout.spacing_200w,
              Text('코코넛 오픈 스토어', style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
              CoconutLayout.spacing_100w,
              Container(
                padding: const EdgeInsets.symmetric(horizontal: Sizes.size6, vertical: Sizes.size2),
                decoration: BoxDecoration(color: const Color(0xFFFF7A1A), borderRadius: BorderRadius.circular(4)),
                child: Text(_intro.badgeLabel, style: CoconutTypography.caption_10.setColor(colors.primaryText)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => context.read<PreferenceProvider>().hideOpenStoreIntroCardForOneMonth(),
                child: SvgPicture.asset(
                  'assets/svg/close.svg',
                  width: Sizes.size20,
                  height: Sizes.size20,
                  colorFilter: ColorFilter.mode(colors.iconSubDefault, BlendMode.srcIn),
                ),
              ),
            ],
          ),
          CoconutLayout.spacing_300h,
          Text(_intro.headline, style: CoconutTypography.body3_12_Bold.setColor(colors.primaryText)),
          CoconutLayout.spacing_100h,
          Text(
            _intro.description,
            style: CoconutTypography.body3_12.setColor(colors.secondaryText),
          ),
          CoconutLayout.spacing_200h,
          Align(
            alignment: Alignment.centerRight,
            child: ShrinkTapWrapper(
              onTap: () => _openThemeStore(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_intro.ctaLabel, style: CoconutTypography.caption_10_Bold.setColor(colors.primaryText)),
                  CoconutLayout.spacing_300w,
                  SvgPicture.asset(
                    'assets/svg/arrow-right.svg',
                    width: Sizes.size10,
                    height: Sizes.size10,
                    colorFilter: ColorFilter.mode(colors.iconDefault, BlendMode.srcIn),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption {
  const _ThemeOption({required this.variant, required this.title});

  final CoconutThemeVariant variant;
  final String title;
}
