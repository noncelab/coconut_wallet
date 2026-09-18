import 'package:coconut_wallet/localization/strings.g.dart';

class CcosOpenStoreIntro {
  const CcosOpenStoreIntro({
    required this.title,
    required this.headline,
    required this.description,
    required this.ctaLabel,
  });

  final String title;
  final String headline;
  final String description;
  final String ctaLabel;
}

class CcosContributionCta {
  const CcosContributionCta({
    required this.title,
    required this.description,
    required this.steps,
    required this.reviewNote,
    required this.ctaLabel,
  });

  final String title;
  final String description;
  final List<String> steps;
  final String reviewNote;
  final String ctaLabel;
}

class CcosPlannedFeature {
  const CcosPlannedFeature({
    required this.title,
    required this.description,
    required this.iconKey,
    required this.discoveryLabel,
  });

  final String title;
  final String description;
  final String iconKey;
  final String discoveryLabel;
}

class CcosUserSafetySection {
  const CcosUserSafetySection({
    required this.title,
    required this.description,
    required this.points,
    required this.closingNote,
  });

  final String title;
  final String description;
  final List<String> points;
  final String closingNote;
}

class CcosDeveloperAction {
  const CcosDeveloperAction({required this.label, required this.iconKey});

  final String label;
  final String iconKey;
}

class CcosDeveloperSection {
  const CcosDeveloperSection({
    required this.title,
    required this.description,
    required this.principles,
    required this.actions,
  });

  final String title;
  final String description;
  final List<String> principles;
  final List<CcosDeveloperAction> actions;
}

class CcosOpenStoreContentSource {
  static CcosOpenStoreIntro get intro => CcosOpenStoreIntro(
    title: t.ccos.intro_card.title,
    headline: t.ccos.intro_card.headline,
    description: t.ccos.intro_card.description,
    ctaLabel: t.ccos.intro_card.cta_label,
  );

  static const CcosContributionCta featuredContributionCta = CcosContributionCta(
    title: '좋은 PoW는 좋은 설명에서 시작됩니다.',
    description: '코드를 보내기 전에 왜 만들었는지, 누구에게 도움이 되는지, 사용자가 어디서 만나게 될지를 먼저 함께 고민해요.',
    steps: [
      'PR에는 기능 이름보다 먼저 어떤 불편을 덜어주고 싶은지 적어 주세요.',
      '이 기능이 누구에게 왜 필요한지, 어디까지 안전하게 쓸 수 있는지도 함께 설명해 주세요.',
      '스토어와 실제 화면에서 개발자의 이름, 제작 의도, 사용 방법이 어떻게 보이면 좋을지도 같이 제안해 주세요.',
    ],
    reviewNote:
        '좋은 기능을 만드는 것만큼, 사용자가 그 기능을 이해하는 경험도 중요해요. 많이 쓰이고 사랑받는 PoW는 더 많은 피드백을 만나고, 그 피드백은 다시 더 좋은 기능으로 이어질 거예요.',
    ctaLabel: '기능 제안 방법 보기',
  );

  static const List<CcosPlannedFeature> plannedFeatures = [
    CcosPlannedFeature(
      title: '분석',
      description: '더 잘 이해할 수 있도록',
      iconKey: 'analysis',
      discoveryLabel: '숫자만 보여주는 기능이 아니라, 누가 왜 만들었는지도 함께 전해질 수 있어요.',
    ),
    CcosPlannedFeature(
      title: '도구',
      description: '더 쉽게 사용할 수 있도록',
      iconKey: 'tools',
      discoveryLabel: '복잡한 작업도 덜 헤매게 만들고, 필요 없으면 언제든 다시 끌 수 있게 이어질 거예요.',
    ),
    CcosPlannedFeature(
      title: '위젯',
      description: '원하는 정보를 원하는 곳에',
      iconKey: 'widget',
      discoveryLabel: '자주 보고 싶은 정보가 있다면, 더 자연스럽게 꺼내 볼 수 있는 방식으로 자라날 수 있어요.',
    ),
    CcosPlannedFeature(
      title: '레이어2',
      description: '비트코인의 가능성을 더 넓게',
      iconKey: 'layers',
      discoveryLabel: '새로운 연결과 흐름도 코코넛 안에서 안심하고 이해할 수 있는 모습으로 소개될 수 있어요.',
    ),
    CcosPlannedFeature(
      title: '그리고\n아직 이름조차 없는\n누군가의 좋은 아이디어',
      description: '',
      iconKey: 'idea',
      discoveryLabel: '중요한 건 기능을 많이 넣는 것이 아니라, 좋은 아이디어가 발견되고 이해되고 오래 살아남을 수 있게 돕는 일이에요.',
    ),
  ];

  static const CcosUserSafetySection userSafetySection = CcosUserSafetySection(
    title: '안심하고 사용하세요',
    description: '새로운 기능이 늘어나도 앱이 갑자기 복잡해지지 않도록, 코코넛은 기능을 천천히 고르고 켤 수 있는 방향으로 준비하고 있어요.',
    points: ['새로운 기능은 원할 때만 활성화할 수 있어요.', '필요 없어지면 언제든 다시 끌 수 있어요.', '핵심 지갑 기능과는 분리된 자리에서 동작하도록 차근차근 확장할 거예요.'],
    closingNote: '내 지갑은 내가 원하는 모습으로, 천천히 채워가면 돼요.',
  );

  static const CcosDeveloperSection developerSection = CcosDeveloperSection(
    title: '함께 만들어 보고 싶으신가요?',
    description:
        '내가 만든 기능은 단순히 다운로드되는 것으로 끝나지 않아요. 왜 만들었는지, 어떤 문제를 풀고 싶은지, 누구에게 도움이 되는지까지 사용자가 기능을 만나는 순간마다 함께 소개되는 구조를 만들고 싶어요.',
    principles: [
      '좋은 PoW는 더 많은 사용자에게 발견되고, 사용자의 피드백은 다시 더 좋은 기능으로 이어질 거예요.',
      '기능 소개, 구매 여부, 활성화 상태는 헷갈리지 않게 나눠서 보여드릴 거예요.',
      '스토어에서 본 개발자의 이름과 제작 의도는 실제 사용하는 화면 안에서도 다시 만날 수 있어야 해요.',
    ],
    actions: [
      CcosDeveloperAction(label: '내 PoW 제안하러 가기', iconKey: 'code'),
      CcosDeveloperAction(label: '스토어 기여 가이드 보기', iconKey: 'guide'),
    ],
  );
}
