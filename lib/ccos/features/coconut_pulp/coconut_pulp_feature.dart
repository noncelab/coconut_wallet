import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/features/coconut_pulp/coconut_pulp_feature_copy.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';

class CoconutPulpFeature {
  static const String id = 'ccos-feature-theme-coconut-pulp';

  static CcosFeatureListing get listing {
    final copy = CoconutPulpFeatureCopySource.current;
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
      linkedVariant: CoconutThemeVariant.coconutPulp,
    );
  }
}
