import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';

enum CcosListingPriceType { free, oneTimePurchase, subscription }

class CcosFeatureListing {
  const CcosFeatureListing({
    required this.id,
    required this.title,
    required this.description,
    required this.author,
    required this.authorDescription,
    required this.authorIntent,
    required this.whyInCoconut,
    required this.discoverabilityNote,
    required this.priceType,
    this.tags = const [],
    this.priceLabel,
    this.linkedVariant,
  });

  final String id;
  final String title;
  final String description;
  final String author;
  final String authorDescription;
  final String authorIntent;
  final String whyInCoconut;
  final String discoverabilityNote;
  final CcosListingPriceType priceType;
  final List<String> tags;
  final String? priceLabel;
  final CoconutThemeVariant? linkedVariant;

  bool get isSelectableTheme => linkedVariant != null;

  bool get requiresEntitlement => priceType != CcosListingPriceType.free;

  String get pricingText => switch (priceType) {
    CcosListingPriceType.free => '무료',
    CcosListingPriceType.oneTimePurchase => priceLabel ?? '1회 구매',
    CcosListingPriceType.subscription => priceLabel ?? '구독',
  };
}

/// 실제로 런타임에서 조회/활성화/구매 상태를 판단할 수 있는 기능만 등록합니다.
class CcosFeatureRegistrySource {
  static const CcosFeatureListing featuredListing = CcosFeatureListing(
    id: 'ccos-feature-theme-coconut-pulp',
    title: '코코넛 과육 테마',
    author: '코코넛 팀',
    authorDescription: '비트코인만을 위한 더 나은 지갑 경험을 만듭니다',
    authorIntent: '오픈 스토어를 통해 새로운 기능이 코코넛에 자연스럽게 더해질 수 있다는 첫 번째 예시를 만들고 싶었어요.',
    whyInCoconut: '오픈 스토어는 좋은 PoW를 발견하고 함께 사용하는 공간입니다. 이 테마는 앞으로 다양한 기능이 추가될 모습을 보여주는 첫 번째 PoW예요.',
    // '이건 테마 하나를 보여주기 위한 카드이기도 하지만, 앞으로 더 다양한 기능이 어떤 모습으로 추가될지 미리 상상해 볼 수 있도록 준비한 첫 출발점이기도 해요. 오픈 스토어는 단순히 기능을 모아두는 공간이 아니라, 좋은 PoW를 발견하고 함께 사용하는 공간이 되었으면 합니다.',
    discoverabilityNote: '오픈 스토어뿐 아니라 실제로 사용하는 테마 화면에서도 기능을 확인하고 사용할 수 있어요.',
    description: '코코넛과 해변의 따뜻한 색감을 담은\n코코넛 월렛의 새로운 밝은 테마입니다',
    priceType: CcosListingPriceType.free,
    tags: ['밝은 테마', '무료'],
    linkedVariant: CoconutThemeVariant.coconutPulp,
  );

  static final List<CcosFeatureListing> listings = [
    CcosFeatureListing(
      id: 'ccos-feature-theme-preview',
      title: featuredListing.title,
      author: featuredListing.author,
      authorDescription: featuredListing.authorDescription,
      authorIntent: featuredListing.authorIntent,
      whyInCoconut: featuredListing.whyInCoconut,
      discoverabilityNote: featuredListing.discoverabilityNote,
      description: '기존 지갑 동작은 그대로 두고, 새로운 기능이 코코넛 안에 어떤 모습으로 들어올 수 있는지 보여드리는 첫 예시예요.',
      priceType: CcosListingPriceType.free,
      tags: featuredListing.tags,
      linkedVariant: CoconutThemeVariant.coconutPulp,
    ),
    const CcosFeatureListing(
      id: 'ccos-feature-sepia-pack',
      title: '세피아 팩',
      author: 'CCOS 예시',
      authorDescription: '유료 기능 예시',
      authorIntent: '앞으로 유료 후보 기능이 생기더라도, 먼저 무엇을 위한 기능인지 충분히 이해하고 선택할 수 있어야 한다는 점을 보여드리기 위한 예시예요.',
      whyInCoconut: '나중에 1회 구매나 인앱 결제가 붙더라도, 기능 소개와 활성화, 구매 정보가 섞이지 않도록 차근차근 연결할 수 있어야 해요.',
      discoverabilityNote: '유료 기능이라도 먼저 누가 만들었는지, 왜 필요한지부터 충분히 보여드릴 거예요.',
      description: '나중에 1회 구매 기능이 추가된다면 어떤 방식으로 소개하면 좋을지 보여드리는 예시예요.',
      priceType: CcosListingPriceType.oneTimePurchase,
      priceLabel: '1회 구매',
    ),
  ];

  static List<CcosFeatureListing> get allListings => [featuredListing, ...listings];

  static CcosFeatureListing? findListingById(String featureId) {
    for (final listing in allListings) {
      if (listing.id == featureId) {
        return listing;
      }
    }
    return null;
  }
}
