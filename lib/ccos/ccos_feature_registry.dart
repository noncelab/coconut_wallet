import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/ccos/ccos_home_entry.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/ccos/features/coconut_theme/coconut_theme_feature.dart';

enum CcosListingPriceType { free, oneTimePurchase, subscription }

/// `docs/ccos/getting_started/feature_boundary.md`가 Green 예시로 드는
/// 카테고리를 반영한다. 새 카테고리를 여기 추가하는 것 자체는 안전하지만,
/// 그것만으로 기능이 앱 안 어딘가에 자동으로 노출되지는 않는다 — 각 카테고리는
/// 별도의 host surface(예: 테마는 `theme_bottom_sheet.dart`)에 연결되어야
/// 실제로 동작한다. 새 카테고리를 추가할 때는:
/// 1. 이 enum에 값을 추가하고
/// 2. 그 카테고리가 노출될 host surface(기존 화면 안의 진입점)를 정하고 —
///    지금은 `theme` 카테고리만 실제 host surface(`theme_bottom_sheet.dart`)가
///    연결되어 있다. 새 카테고리는 registry에 등록하는 것만으로 화면에
///    나타나지 않으므로, 이 단계에서 반드시 실제 진입점 코드를 함께 작성한다.
///    `theme_bottom_sheet.dart`는 테마이기 때문에 자연스러운 예시일 뿐,
///    다른 카테고리가 그대로 따라야 할 표준 패턴은 아니다 — 카테고리마다
///    맞는 진입점을 새로 설계한다.
/// 3. `lib/ccos/features/<feature-id>/`에 실제 기능을 구현한 뒤
/// 4. [CcosFeatureRegistrySource.allListings]에 연결한다.
///
/// 자세한 설명: `docs/ccos/foundation/architecture.md` 6.1절 "카테고리와 진입점".
enum CcosFeatureCategory {
  /// 앱 전체 테마 variant. host surface: `lib/screens/settings/theme_bottom_sheet.dart`.
  theme,

  /// 지갑 데이터를 읽기 전용으로 보여주는 분석/대시보드류 화면.
  analysis,

  /// 반복 작업을 돕는 도구성 화면 (예: 단위 변환, 계산기류).
  tool,

  /// 홈 화면 등에 카드/위젯 형태로 붙는 표시 전용 모듈.
  widget,

  /// 온체인과 따로 쓰는 레이어 2 지갑.
  /// host surface: 홈 바로가기·위젯([CcosFeatureListing.homeShortcut], [CcosFeatureListing.homeWidget]).
  layer2,
}

/// 기능 상세 FEATURE 장의 스틸 사진. 한국어 외 언어는 영어 사진
class CcosFeatureScreenshot {
  const CcosFeatureScreenshot({required this.koAssetPath, required this.enAssetPath, required this.caption});

  final String koAssetPath;
  final String enAssetPath;
  final String caption;

  String assetPathFor(AppLocale locale) => locale == AppLocale.ko ? koAssetPath : enAssetPath;
}

/// 기능 상세 CREATOR 장의 이야기
class CcosCreatorStory {
  const CcosCreatorStory({this.quote, this.quoteAttribution, required this.paragraphs, required this.belief});

  final String? quote;
  final String? quoteAttribution;
  final List<String> paragraphs;
  final String belief;
}

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
    required this.subtitle,
    required this.iconPath,
    required this.creatorStory,
    this.isListed = _alwaysListed,
    this.unavailableNotice = _noNotice,
    this.homeShortcut,
    this.homeWidget,
    this.addedToast,
    this.removedToast,
    this.thumbnailImagePath,
    this.screenshots = const [],
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
  final String subtitle;
  final String iconPath;
  final CcosCreatorStory creatorStory;

  /// 이 빌드에서 스토어·검색에 보일지
  final bool Function() isListed;

  /// 이 빌드에서 추가할 수 없는 이유. 값이 있으면 스토어에서 보기만 가능
  final String? Function() unavailableNotice;

  /// 켜면 기능이 홈 바로가기의 이름·아이콘·실행을 제공한다
  final CcosHomeShortcut? homeShortcut;

  /// 켜면 기능이 홈 위젯 정의를 제공한다
  final CcosHomeWidget? homeWidget;

  /// 추가·제거 직후 알림. 기능이 어디에 나타나고 빠지는지 알려 준다
  final String? addedToast;
  final String? removedToast;

  /// 스토어 카드 썸네일 이미지. 없으면 아이콘
  final String? thumbnailImagePath;
  final List<CcosFeatureScreenshot> screenshots;
  final List<String> tags;
  final String? priceLabel;
  final CoconutThemeVariant? linkedVariant;

  bool get isSelectableTheme => linkedVariant != null;

  bool get requiresEntitlement => priceType != CcosListingPriceType.free;

  bool get isUnavailable => unavailableNotice() != null;

  static bool _alwaysListed() => true;

  static String? _noNotice() => null;
}

/// 실제로 런타임에서 조회/활성화/구매 상태를 판단할 수 있는 기능만 등록합니다.
///
/// 외부 기여자가 늘어나 등록 기능이 많아지면, 이 목록을 리터럴로 계속
/// 나열하기보다 `lib/ccos/features/` 아래를 스캔해 자동으로 모으는 방식으로
/// 바꾸는 것을 고려한다. 지금은 기능 수가 적어 명시적 리스트가 오히려
/// 리뷰하기 쉽다.
class CcosFeatureRegistrySource {
  static CcosFeatureListing get featuredListing => CoconutThemeFeature.listing;

  static List<CcosFeatureListing> get allListings =>
      [ArkFeature.listing, featuredListing].where((listing) => listing.isListed()).toList();

  static CcosFeatureListing? findListingById(String featureId) {
    for (final listing in allListings) {
      if (listing.id == featureId) {
        return listing;
      }
    }
    return null;
  }
}
