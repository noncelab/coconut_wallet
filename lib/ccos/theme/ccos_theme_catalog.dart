import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';

enum CcosThemePriceType { free, oneTimePurchase }

class CcosOpenStoreIntro {
  const CcosOpenStoreIntro({
    required this.badgeLabel,
    required this.title,
    required this.headline,
    required this.description,
    required this.ctaLabel,
  });

  final String badgeLabel;
  final String title;
  final String headline;
  final String description;
  final String ctaLabel;
}

class CcosThemeContributionCta {
  const CcosThemeContributionCta({required this.title, required this.description, required this.ctaLabel});

  final String title;
  final String description;
  final String ctaLabel;
}

class CcosOpenStoreFeature {
  const CcosOpenStoreFeature({required this.title, required this.description, required this.iconKey});

  final String title;
  final String description;
  final String iconKey;
}

class CcosDeveloperAction {
  const CcosDeveloperAction({required this.label, required this.iconKey});

  final String label;
  final String iconKey;
}

class CcosDeveloperSection {
  const CcosDeveloperSection({required this.title, required this.description, required this.actions});

  final String title;
  final String description;
  final List<CcosDeveloperAction> actions;
}

class CcosThemeOffer {
  const CcosThemeOffer({
    required this.id,
    required this.title,
    required this.description,
    required this.author,
    required this.priceType,
    this.tags = const [],
    this.priceLabel,
    this.linkedVariant,
  });

  final String id;
  final String title;
  final String description;
  final String author;
  final CcosThemePriceType priceType;
  final List<String> tags;
  final String? priceLabel;
  final CoconutThemeVariant? linkedVariant;

  bool get isSelectableTheme => linkedVariant != null;

  String get pricingText => switch (priceType) {
    CcosThemePriceType.free => 'Free',
    CcosThemePriceType.oneTimePurchase => priceLabel ?? 'One-time purchase',
  };
}

class CcosThemeCatalogSource {
  static const CcosOpenStoreIntro intro = CcosOpenStoreIntro(
    badgeLabel: 'NEW',
    title: '코코넛 오픈 스토어',
    headline: '코코넛은 커뮤니티와 함께 성장합니다.',
    description: '테마를 시작으로 다양한 기능을 커뮤니티와 함께 만들어갑니다. 오픈 스토어에서 앞으로 추가될 기능들을 함께 지켜봐 주세요.',
    ctaLabel: '오픈 스토어 둘러보기',
  );

  static const CcosThemeOffer featuredOffer = CcosThemeOffer(
    id: 'ccos-theme-gwayout-preview',
    title: '코코넛 과육',
    author: '코코넛 팀',
    description: '코코넛 과육의 따뜻하고 자연스러운 색감을 담은 밝은 테마입니다.',
    priceType: CcosThemePriceType.free,
    tags: ['밝은 테마', '구조'],
    linkedVariant: CoconutThemeVariant.coconutPulp,
  );

  static const CcosThemeContributionCta featuredContributionCta = CcosThemeContributionCta(
    title: '여러분의 테마로 코코넛 월렛을 더 풍성하게',
    description: '테마 제작 가이드를 확인하고 테마를 제안해 보세요.',
    ctaLabel: '테마 제안하기',
  );

  static const List<CcosOpenStoreFeature> plannedFeatures = [
    CcosOpenStoreFeature(title: '분석', description: '자산과 거래를 더 깊이 이해할 수 있도록', iconKey: 'analysis'),
    CcosOpenStoreFeature(title: '레이어2', description: '다양한 레이어2와 자연스럽게 연결하도록', iconKey: 'layers'),
    CcosOpenStoreFeature(title: '위젯', description: '원하는 정보를 더 빠르게 확인하도록', iconKey: 'widget'),
    CcosOpenStoreFeature(title: '도구', description: '지갑을 더 편리하고 풍부하게', iconKey: 'tools'),
    CcosOpenStoreFeature(title: '그리고 아직 상상하지 못한\n반짝이는 아이디어들', description: '', iconKey: 'idea'),
  ];

  static const CcosDeveloperSection developerSection = CcosDeveloperSection(
    title: '개발자로 참여하고 싶으신가요?',
    description: '무료 또는 유료 기능 제안을 할 수 있으며,\n승인된 기능은 오픈 스토어를 통해 제공됩니다.',
    actions: [
      CcosDeveloperAction(label: 'GitHub 바로가기', iconKey: 'code'),
      CcosDeveloperAction(label: '개발자 가이드 보기', iconKey: 'guide'),
    ],
  );

  static final List<CcosThemeOffer> offers = [
    CcosThemeOffer(
      id: 'ccos-theme-preview',
      title: featuredOffer.title,
      author: featuredOffer.author,
      description: '기존 월렛 동작은 그대로 두고, 새로운 시각 스타일이 어떤 식으로 제안될 수 있는지 보여주는 첫 예시다.',
      priceType: CcosThemePriceType.free,
      tags: featuredOffer.tags,
      linkedVariant: CoconutThemeVariant.coconutPulp,
    ),
    const CcosThemeOffer(
      id: 'ccos-theme-sepia-pack',
      title: '세피아 팩',
      author: 'CCOS 예시',
      description: '향후 one-time purchase 형태의 사용자 지정 테마가 어떤 식으로 소개될 수 있는지 보여주는 예시다.',
      priceType: CcosThemePriceType.oneTimePurchase,
      priceLabel: '1회 구매',
    ),
  ];
}
