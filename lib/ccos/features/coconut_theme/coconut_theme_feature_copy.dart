import 'package:coconut_wallet/localization/strings.g.dart';

class CoconutThemeFeatureCopy {
  const CoconutThemeFeatureCopy({
    required this.title,
    required this.description,
    required this.author,
    required this.authorBio,
    required this.authorIntent,
    required this.whyItBelongs,
    required this.featureHelp,
    required this.tags,
    required this.subtitle,
    required this.screenshotCaptions,
    required this.creatorParagraphs,
    required this.belief,
    required this.addedToast,
    required this.removedToast,
  });

  final String title;
  final String description;
  final String author;
  final String authorBio;
  final String authorIntent;
  final String whyItBelongs;
  final String featureHelp;
  final List<String> tags;
  final String subtitle;
  final List<String> screenshotCaptions;
  final List<String> creatorParagraphs;
  final String belief;
  final String addedToast;
  final String removedToast;
}

class CoconutThemeFeatureCopySource {
  static CoconutThemeFeatureCopy get current {
    switch (LocaleSettings.currentLocale) {
      case AppLocale.ko:
        return _ko;
      case AppLocale.en:
        return _en;
      case AppLocale.de:
        return _de;
      case AppLocale.es:
        return _es;
      case AppLocale.ja:
        return _ja;
    }
  }

  static const CoconutThemeFeatureCopy _ko = CoconutThemeFeatureCopy(
    title: '코코넛 테마',
    description: '코코넛과 해변의 따뜻한 색감을 담은\n코코넛 월렛의 새로운 밝은 테마입니다',
    author: '코코넛 팀',
    authorBio: '비트코인만을 위한 더 나은 지갑 경험을 만듭니다',
    authorIntent: '오픈 스토어를 통해 새로운 기능이 코코넛에 자연스럽게 더해질 수 있다는 첫 번째 예시를 만들고 싶었어요.',
    whyItBelongs: '오픈 스토어는 좋은 PoW를 발견하고 함께 사용하는 공간입니다. 이 테마는 앞으로 다양한 기능이 추가될 모습을 보여주는 첫 번째 PoW예요.',
    featureHelp: '오픈 스토어뿐 아니라 실제로 사용하는 테마 화면에서도 기능을 확인하고 사용할 수 있어요.',
    tags: ['밝은 테마'],
    subtitle: '코코넛과 해변의 따뜻한 밝은 테마',
    screenshotCaptions: ['코코넛과 모래사장 색상의 밝은 홈', '지갑 상세', '코코넛 껍질 색의 버튼', '해변을 연상시키는 거래 흐름'],
    creatorParagraphs: [
      '코코넛 팀은 비트코인 전용 지갑 코코넛 월렛과 볼트를 만들고 있어요.',
      '처음에 코코넛 월렛은 볼트와 구분하기 위해 의도적으로 어두운 테마만 제공했어요.',
      '하지만 코코넛 오픈 스토어를 구상하며, \'누구나 새로운 기능을 제안하고 함께 만들어가는 경험\'을 잘 보여줄 수 있는 예시가 무얼까 고민하며 코코넛 테마를 추가하게 되었어요.',
    ],
    belief: '코코넛 테마를 선보이며 누구나 기여할 수 있는 코코넛 오픈 스토어를 그릴 수 있길 바랐어요',
    addedToast: '설정 > 테마에서 코코넛 테마를 고를 수 있어요',
    removedToast: '테마 목록에서 코코넛 테마를 제거했어요',
  );

  static const CoconutThemeFeatureCopy _en = CoconutThemeFeatureCopy(
    title: 'Coconut Theme',
    description: 'A bright new Coconut Wallet theme inspired by the warm colors of coconut flesh and the beach.',
    author: 'Coconut Team',
    authorBio: 'Building a better wallet experience',
    authorIntent:
        'We wanted to create the first example showing how new features can be added naturally to Coconut through the Open Store.',
    whyItBelongs:
        'The Open Store is a place to discover and use good PoW together. This theme is the first PoW showing how more features can grow inside Coconut.',
    featureHelp:
        'You can find and use this feature not only in the Open Store, but also later in the actual theme screen.',
    tags: ['Light theme'],
    subtitle: 'A warm, bright theme',
    screenshotCaptions: [
      'A bright home in coconut and sand colors',
      'Wallet details',
      'Buttons in coconut husk brown',
      'Transaction flow that recalls the beach',
    ],
    creatorParagraphs: [
      'The Coconut team builds Coconut Wallet and Coconut Vault, bitcoin-only wallets.',
      'At first, Coconut Wallet offered only a dark theme on purpose, to set it apart from the Vault.',
      'But while planning the Coconut Open Store, we asked what example could best show \'anyone proposing new features and building them together\', and added the Coconut Theme.',
    ],
    belief: 'With the Coconut Theme, we hoped to sketch a Coconut Open Store anyone can contribute to',
    addedToast: 'Pick Coconut Theme in Settings > Theme',
    removedToast: 'Removed Coconut Theme from your themes',
  );

  static const CoconutThemeFeatureCopy _de = CoconutThemeFeatureCopy(
    title: 'Coconut-Theme',
    description:
        'Ein helles neues Theme fuer Coconut Wallet mit warmen Farben, inspiriert von Kokosnussfleisch und Strand.',
    author: 'Coconut Team',
    authorBio: 'Bessere Wallet-Erlebnisse',
    authorIntent:
        'Wir wollten das erste Beispiel schaffen, das zeigt, wie neue Funktionen ueber den Open Store natuerlich zu Coconut hinzukommen koennen.',
    whyItBelongs:
        'Der Open Store ist ein Ort, an dem gute PoW entdeckt und gemeinsam genutzt werden. Dieses Theme ist das erste PoW und zeigt, wie weitere Funktionen in Coconut wachsen koennen.',
    featureHelp:
        'Diese Funktion laesst sich nicht nur im Open Store finden, sondern spaeter auch direkt im Theme-Bildschirm wiedersehen und nutzen.',
    tags: ['Helles Theme'],
    subtitle: 'Ein warmes, helles Theme',
    screenshotCaptions: [
      'Helles Home in Kokos- und Sandfarben',
      'Wallet-Details',
      'Buttons in Kokosschalenbraun',
      'Transaktionsfluss, der an den Strand erinnert',
    ],
    creatorParagraphs: [
      'Das Coconut-Team entwickelt Coconut Wallet und Coconut Vault, reine Bitcoin-Wallets.',
      'Anfangs bot Coconut Wallet bewusst nur ein dunkles Theme, um sich vom Vault abzuheben.',
      'Bei der Planung des Coconut Open Store fragten wir uns, welches Beispiel am besten zeigt, wie jeder neue Funktionen vorschlagen und gemeinsam bauen kann, und fügten das Coconut-Theme hinzu.',
    ],
    belief: 'Mit dem Coconut-Theme wollten wir einen Coconut Open Store skizzieren, zu dem jeder beitragen kann',
    addedToast: 'Coconut-Theme unter Einstellungen > Design wählen',
    removedToast: 'Coconut-Theme aus den Designs entfernt',
  );

  static const CoconutThemeFeatureCopy _es = CoconutThemeFeatureCopy(
    title: 'Tema Coconut',
    description: 'Un nuevo tema claro para Coconut Wallet inspirado en los tonos calidos del coco y la playa.',
    author: 'Equipo Coconut',
    authorBio: 'Creamos una mejor experiencia de wallet',
    authorIntent:
        'Queríamos crear el primer ejemplo de cómo nuevas funciones pueden sumarse de forma natural a Coconut a través del Open Store.',
    whyItBelongs:
        'El Open Store es un espacio para descubrir y usar buen PoW juntos. Este tema es el primer PoW que muestra cómo más funciones pueden crecer dentro de Coconut.',
    featureHelp:
        'Puedes encontrar y usar esta función no solo en el Open Store, sino también más tarde en la pantalla real de temas.',
    tags: ['Tema claro'],
    subtitle: 'Un tema claro y cálido',
    screenshotCaptions: [
      'Inicio claro en tonos de coco y arena',
      'Detalle de billetera',
      'Botones color cáscara de coco',
      'Flujo de transacción que evoca la playa',
    ],
    creatorParagraphs: [
      'El equipo Coconut crea Coconut Wallet y Coconut Vault, billeteras solo de bitcoin.',
      'Al principio, Coconut Wallet ofrecía a propósito solo un tema oscuro para diferenciarse del Vault.',
      'Pero al idear el Coconut Open Store, buscamos un ejemplo que mostrara bien \'cualquiera propone nuevas funciones y las construimos juntos\', y añadimos el tema Coconut.',
    ],
    belief: 'Con el tema Coconut quisimos dibujar un Coconut Open Store al que cualquiera pueda contribuir',
    addedToast: 'Elige Tema Coconut en Ajustes > Tema',
    removedToast: 'Tema Coconut quitado de tus temas',
  );

  static const CoconutThemeFeatureCopy _ja = CoconutThemeFeatureCopy(
    title: 'ココナッツテーマ',
    description: 'ココナッツと浜辺のあたたかい色合いを込めた、Coconut Wallet の新しい明るいテーマです',
    author: 'Coconut Team',
    authorBio: 'Bitcoin 専用のより良いウォレット体験をつくっています',
    authorIntent: 'Open Store を通じて、新しい機能が Coconut に自然に加わっていく最初の例をつくりたかったのです。',
    whyItBelongs: 'Open Store は、良い PoW を見つけて一緒に使うための場所です。このテーマは、これからさまざまな機能が Coconut に加わっていく姿を見せる最初の PoW です。',
    featureHelp: 'Open Store だけでなく、実際のテーマ画面でもこの機能を確認して使えます。',
    tags: ['明るいテーマ'],
    subtitle: 'あたたかい明るいテーマ',
    screenshotCaptions: ['ココナッツと砂浜の色の明るいホーム', 'ウォレット詳細', 'ココナッツの殻の色のボタン', 'ビーチを思わせる取引の流れ'],
    creatorParagraphs: [
      'Coconutチームは、ビットコイン専用ウォレットのCoconut WalletとVaultをつくっています。',
      '最初、Coconut WalletはVaultと区別するため、あえてダークテーマだけを提供していました。',
      'しかしCoconut Open Storeを構想する中で、「誰でも新しい機能を提案し、一緒につくっていく体験」をよく伝えられる例は何かを考え、Coconutテーマを追加しました。',
    ],
    belief: 'Coconutテーマを通じて、誰もが貢献できるCoconut Open Storeを描きたいと願いました',
    addedToast: '設定 > テーマでココナッツテーマを選べます',
    removedToast: 'テーマ一覧からココナッツテーマを削除しました',
  );
}
