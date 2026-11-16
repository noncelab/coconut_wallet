import 'package:coconut_wallet/localization/strings.g.dart';

class ArkFeatureCopy {
  const ArkFeatureCopy({
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

class ArkFeatureCopySource {
  static ArkFeatureCopy get current {
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

  static const ArkFeatureCopy _ko = ArkFeatureCopy(
    title: '아크',
    description: '핫월렛에서 아크와 라이트닝으로\n빠르고 싸게 주고받아요',
    author: '코코넛 팀',
    authorBio: '비트코인만을 위한 더 나은 지갑 경험을 만듭니다',
    authorIntent: '채널 관리 없이 라이트닝을 쓰고, 작은 금액도 수수료 부담 없이 주고받게 하고 싶었어요.',
    whyItBelongs: '아크 서버가 사라져도 내 몫은 혼자 온체인으로 꺼낼 수 있어, 자기 수탁을 지키면서 쓸 수 있어요.',
    featureHelp: '기능을 추가하면 핫월렛을 만들거나 복원할 때, 그리고 지갑 정보에서 아크를 켤 수 있어요.',
    tags: ['아크', '라이트닝'],
  );

  static const ArkFeatureCopy _en = ArkFeatureCopy(
    title: 'Ark',
    description: 'Send and receive fast and cheap\nwith Ark and Lightning from a hot wallet.',
    author: 'Coconut Team',
    authorBio: 'Building a better wallet experience',
    authorIntent: 'We wanted Lightning without channel management, and small payments without heavy fees.',
    whyItBelongs:
        'If the Ark server goes away, you can still take your share on-chain alone, so it stays self-custodial.',
    featureHelp: 'Once added, you can turn on Ark when creating or restoring a hot wallet, and in wallet info.',
    tags: ['Ark', 'Lightning'],
  );

  static const ArkFeatureCopy _de = ArkFeatureCopy(
    title: 'Ark',
    description: 'Schnell und günstig senden und empfangen\nmit Ark und Lightning in einer Hot Wallet.',
    author: 'Coconut-Team',
    authorBio: 'Wir bauen ein besseres Wallet-Erlebnis',
    authorIntent: 'Lightning ohne Kanalverwaltung und kleine Zahlungen ohne hohe Gebühren.',
    whyItBelongs: 'Fällt der Ark-Server weg, holst du deinen Anteil allein on-chain zurück. Du bleibst selbstverwahrt.',
    featureHelp:
        'Danach kannst du Ark beim Erstellen oder Wiederherstellen einer Hot Wallet und in den Wallet-Infos aktivieren.',
    tags: ['Ark', 'Lightning'],
  );

  static const ArkFeatureCopy _es = ArkFeatureCopy(
    title: 'Ark',
    description: 'Envía y recibe rápido y barato\ncon Ark y Lightning desde una hot wallet.',
    author: 'Equipo Coconut',
    authorBio: 'Creamos una mejor experiencia de billetera',
    authorIntent: 'Queríamos Lightning sin gestionar canales y pagos pequeños sin comisiones altas.',
    whyItBelongs: 'Si el servidor Ark desaparece, puedes sacar tu parte on-chain tú solo. Sigue siendo autocustodia.',
    featureHelp: 'Al añadirla, puedes activar Ark al crear o restaurar una hot wallet y en la info de la billetera.',
    tags: ['Ark', 'Lightning'],
  );

  static const ArkFeatureCopy _ja = ArkFeatureCopy(
    title: 'Ark',
    description: 'ホットウォレットでArkとLightningを使い\n速く安く送受金できます',
    author: 'Coconutチーム',
    authorBio: 'より良いウォレット体験をつくっています',
    authorIntent: 'チャネル管理なしでLightningを使い、少額でも手数料を気にせず送受金できるようにしたかった。',
    whyItBelongs: 'Arkサーバーがなくなっても自分の分は一人でオンチェーンに戻せるので、セルフカストディのままです。',
    featureHelp: '追加すると、ホットウォレットの作成・復元時とウォレット情報でArkをオンにできます。',
    tags: ['Ark', 'Lightning'],
  );
}
