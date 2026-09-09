import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/features/coconut_theme/coconut_theme_feature_copy.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';

class CoconutThemeFeature {
  // 기존 활성화/구매 기록과의 호환을 위해 id 값 자체는 변경하지 않습니다.
  static const String id = 'ccos-feature-theme-coconut-pulp';

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
    );
  }
}
