import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature_copy.dart';

class ArkFeature {
  static const String id = 'ccos-feature-ark';

  static CcosFeatureListing get listing {
    final copy = ArkFeatureCopySource.current;
    return CcosFeatureListing(
      id: id,
      category: CcosFeatureCategory.payment,
      title: copy.title,
      description: copy.description,
      author: copy.author,
      authorBio: copy.authorBio,
      authorIntent: copy.authorIntent,
      whyItBelongs: copy.whyItBelongs,
      featureHelp: copy.featureHelp,
      priceType: CcosListingPriceType.free,
      tags: copy.tags,
    );
  }
}
