import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/ccos/features/coconut_pulp/coconut_pulp_feature.dart';

enum CcosListingPriceType { free, oneTimePurchase, subscription }

enum CcosFeatureCategory { theme }

class CcosFeatureListing {
  const CcosFeatureListing({
    required this.id,
    required this.category,
    required this.title,
    required this.description,
    required this.author,
    required this.authorBio,
    required this.authorIntent,
    required this.whyItBelongs,
    required this.featureHelp,
    required this.priceType,
    this.tags = const [],
    this.priceLabel,
    this.linkedVariant,
  });

  final String id;
  final CcosFeatureCategory category;
  final String title;
  final String description;
  final String author;
  final String authorBio;
  final String authorIntent;
  final String whyItBelongs;
  final String featureHelp;
  final CcosListingPriceType priceType;
  final List<String> tags;
  final String? priceLabel;
  final CoconutThemeVariant? linkedVariant;

  bool get isSelectableTheme => linkedVariant != null;

  bool get requiresEntitlement => priceType != CcosListingPriceType.free;
}

/// 실제로 런타임에서 조회/활성화/구매 상태를 판단할 수 있는 기능만 등록합니다.
class CcosFeatureRegistrySource {
  static CcosFeatureListing get featuredListing => CoconutPulpFeature.listing;

  static List<CcosFeatureListing> get allListings => [featuredListing];

  static CcosFeatureListing? findListingById(String featureId) {
    for (final listing in allListings) {
      if (listing.id == featureId) {
        return listing;
      }
    }
    return null;
  }
}
