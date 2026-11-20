import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature_copy.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 아크 지갑을 만든 사람. Bark 팀과 Second.tech 소개
class ArkCreatorScreen extends StatelessWidget {
  const ArkCreatorScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletCreator),
      builder: (_) => const ArkCreatorScreen(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(
        context: context,
        backgroundColor: colors.background,
        title: t.ark_wallet.creator_row,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          Text(ArkFeature.listing.author, style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText)),
          CoconutLayout.spacing_100h,
          Text(t.ark_wallet.creator_tagline, style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
          CoconutLayout.spacing_600h,
          for (final paragraph in ArkFeatureCopySource.current.companyParagraphs) ...[
            Text(paragraph, style: CoconutTypography.body2_14.setColor(colors.secondaryTextStrong)),
            CoconutLayout.spacing_300h,
          ],
          CoconutLayout.spacing_300h,
          SingleButton(
            key: const Key('ark-creator-github'),
            enableShrinkAnim: true,
            buttonPosition: SingleButtonPosition.none,
            title: t.ark_wallet.creator_github,
            leftElement: SvgPicture.asset(
              CommonCommunicationIconPath.githubLogoWhite,
              width: 24,
              height: 24,
              fit: BoxFit.cover,
              colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
            ),
            onPressed: () => launchURL(context, GITHUB_URL_BARK, destination: ExternalLinkDestination.github),
          ),
        ],
      ),
    );
  }
}
