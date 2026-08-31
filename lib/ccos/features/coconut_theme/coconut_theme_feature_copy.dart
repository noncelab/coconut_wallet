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
  });

  final String title;
  final String description;
  final String author;
  final String authorBio;
  final String authorIntent;
  final String whyItBelongs;
  final String featureHelp;
  final List<String> tags;
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
  );

  static const CoconutThemeFeatureCopy _en = CoconutThemeFeatureCopy(
    title: 'Coconut Theme',
    description:
        'A bright new Coconut Wallet theme inspired by the warm colors of coconut flesh and the beach.',
    author: 'Coconut Team',
    authorBio: 'Building a better wallet experience',
    authorIntent:
        'We wanted to create the first example showing how new features can be added naturally to Coconut through the Open Store.',
    whyItBelongs:
        'The Open Store is a place to discover and use good PoW together. This theme is the first PoW showing how more features can grow inside Coconut.',
    featureHelp:
        'You can find and use this feature not only in the Open Store, but also later in the actual theme screen.',
    tags: ['Light theme'],
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
  );

  static const CoconutThemeFeatureCopy _es = CoconutThemeFeatureCopy(
    title: 'Tema Coconut',
    description:
        'Un nuevo tema claro para Coconut Wallet inspirado en los tonos calidos del coco y la playa.',
    author: 'Equipo Coconut',
    authorBio: 'Creamos una mejor experiencia de wallet',
    authorIntent:
        'Queríamos crear el primer ejemplo de cómo nuevas funciones pueden sumarse de forma natural a Coconut a través del Open Store.',
    whyItBelongs:
        'El Open Store es un espacio para descubrir y usar buen PoW juntos. Este tema es el primer PoW que muestra cómo más funciones pueden crecer dentro de Coconut.',
    featureHelp:
        'Puedes encontrar y usar esta función no solo en el Open Store, sino también más tarde en la pantalla real de temas.',
    tags: ['Tema claro'],
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
  );
}
