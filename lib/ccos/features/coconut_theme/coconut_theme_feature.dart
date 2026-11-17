import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/features/coconut_theme/coconut_theme_feature_copy.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';

class CoconutThemeFeature {
  // 기존 활성화/구매 기록과의 호환을 위해 id 값 자체는 변경하지 않습니다.
  static const String id = 'ccos-feature-theme-coconut-pulp';

  static const _screenshotNames = ['1_home', '2_wallet_detail', '3_send', '4_transaction_detail'];

  static CcosFeatureListing get listing {
    final copy = CoconutThemeFeatureCopySource.current;
    return CcosFeatureListing(
      id: id,
      category: CcosFeatureCategory.theme,
      title: copy.title,
      description: copy.description,
      author: copy.author,
      authorBio: copy.authorBio,
      authorIntent: copy.authorIntent,
      whyItBelongs: copy.whyItBelongs,
      featureHelp: copy.featureHelp,
      priceType: CcosListingPriceType.free,
      tags: copy.tags,
      linkedVariant: CoconutThemeVariant.coconutTheme,
      subtitle: copy.subtitle,
      iconPath: BrandIconPath.coconutPlanet,
      screenshots: [
        for (var i = 0; i < _screenshotNames.length; i++)
          CcosFeatureScreenshot(
            koAssetPath: 'assets/images/ccos/theme/ko/${_screenshotNames[i]}.png',
            enAssetPath: 'assets/images/ccos/theme/en/${_screenshotNames[i]}.png',
            caption: copy.screenshotCaptions[i],
          ),
      ],
      creatorStory: CcosCreatorStory(paragraphs: copy.creatorParagraphs, belief: copy.belief),
      isApplied: isApplied,
    );
  }

  /// 추가한 뒤 앱 테마로 골랐을 때 적용 중
  static bool isApplied(CcosFeatureUsage usage) =>
      usage.isActivated && usage.themeVariant == CoconutThemeVariant.coconutTheme;
}
