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
    required this.subtitle,
    required this.screenshotCaptions,
    required this.creatorParagraphs,
    required this.belief,
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
    title: '아크 지갑',
    description:
        '아크는 비트코인 레이어 2 프로토콜이에요. 아크 서버가 여러 사람의 거래를 모아 처리해서, 빠르고 적은 수수료로 주고받을 수 있어요. 아크 서버는 내 비트코인을 보관하는 수탁자가 아니라 거래를 조율하는 코디네이터예요. 그래서 서버가 멈춰도 내 비트코인을 서버에 의존하지 않고 온체인으로 출금할 수 있는 셀프 커스터디얼 방식이에요.\n\n주요 기능\n• 온체인에서 잔액 채우기\n• 온체인으로 잔액 내보내기\n• 아크 안에서 주고받기\n• 라이트닝 주고받기',
    author: 'Bark 팀',
    authorBio: 'Bark로 아크를 만드는 팀',
    authorIntent: '채널 관리 없이 라이트닝을 쓰고, 작은 금액도 수수료 부담 없이 주고받게 하고 싶었어요.',
    whyItBelongs: '아크 서버가 사라져도 내 몫은 혼자 온체인으로 꺼낼 수 있어, 자기 수탁을 지키면서 쓸 수 있어요.',
    featureHelp: '기능을 추가하면 홈 화면의 아크 지갑 바로가기와 위젯으로 아크 지갑을 쓸 수 있어요.',
    tags: ['아크', '라이트닝'],
    subtitle: '코코넛 월렛에서 아크 사용하기',
    screenshotCaptions: [
      '아크 지갑을 앱처럼 열어요',
      '아크 지갑 홈에서 잔액과 최근 거래를 봐요',
      '아크 주소나 라이트닝 인보이스로 받아요',
      '핫월렛 잔액으로 아크 지갑을 채워요',
      '라이트닝으로도 바로 보내요',
      'VTXO를 확인하고 만료 전에 갱신해요',
    ],
    creatorParagraphs: [
      'Bark 팀은 Second.tech에서 아크 구현체 Bark를 만드는 팀이에요. Bark는 Bitcoin Ark에서 따온 이름으로, 비트코인만 다뤄요.',
      '2026년 BTC Prague에서 코코넛에 아크를 연동한 데모를 보여 주었고, 이후 Bark로 개념 증명을 해 주셨어요. 그 후 코코넛 팀과 함께 다듬어 오픈 스토어의 아크 지갑으로 선보이게 되었어요.',
    ],
    belief: '생소한 레이어 2 프로토콜도 최대한 쉽게 사용하실 수 있도록 신경 썼어요',
  );

  static const ArkFeatureCopy _en = ArkFeatureCopy(
    title: 'Ark Wallet',
    description:
        'Ark is a Bitcoin layer 2 protocol. An Ark server batches many people\'s payments, so they are fast and cheap. The Ark server is not a custodian holding your bitcoin, but a coordinator of transactions. It is self-custodial: even if the server stops, you can withdraw your bitcoin on-chain without relying on it.\n\nKey features\n• Add funds from on-chain\n• Withdraw to on-chain\n• Send and receive within Ark\n• Send and receive over Lightning',
    author: 'Bark Team',
    authorBio: 'Building Ark with Bark',
    authorIntent: 'We wanted Lightning without channel management, and small payments without heavy fees.',
    whyItBelongs:
        'If the Ark server goes away, you can still take your share on-chain alone, so it stays self-custodial.',
    featureHelp: 'Once added, open your Ark Wallet from its shortcut and widget on the home screen.',
    tags: ['Ark', 'Lightning'],
    subtitle: 'Use Ark in Coconut Wallet',
    screenshotCaptions: [
      'Opens like its own app',
      'See your balance and recent activity',
      'Receive with an Ark address or a Lightning invoice',
      'Fill your Ark wallet from a hot wallet',
      'Pay Lightning invoices too',
      'Check your VTXOs and renew them before they expire',
    ],
    creatorParagraphs: [
      'The Bark team at Second.tech builds Bark, an Ark implementation. Bark is named after Bitcoin Ark, and it handles only bitcoin.',
      'At BTC Prague 2026 they showed a demo of Ark integrated into Coconut, then built a proof of concept with Bark. It was then refined with the Coconut team and launched as the Ark Wallet in the Open Store.',
    ],
    belief: 'We worked to make an unfamiliar layer 2 protocol as easy to use as possible',
  );

  static const ArkFeatureCopy _de = ArkFeatureCopy(
    title: 'Ark Wallet',
    description:
        'Ark ist ein Layer-2-Protokoll für Bitcoin. Ein Ark-Server bündelt viele Zahlungen, darum sind sie schnell und günstig. Der Ark-Server verwahrt deine Bitcoin nicht, sondern koordiniert nur die Transaktionen. Ark ist selbstverwahrend: Fällt der Server aus, hebst du deine Bitcoin ohne ihn on-chain ab.\n\nWichtigste Funktionen\n• Guthaben von On-Chain auffüllen\n• Guthaben auf On-Chain auszahlen\n• Innerhalb von Ark senden und empfangen\n• Über Lightning senden und empfangen',
    author: 'Bark-Team',
    authorBio: 'Baut Ark mit Bark',
    authorIntent: 'Lightning ohne Kanalverwaltung und kleine Zahlungen ohne hohe Gebühren.',
    whyItBelongs: 'Fällt der Ark-Server weg, holst du deinen Anteil allein on-chain zurück. Du bleibst selbstverwahrt.',
    featureHelp: 'Danach öffnest du dein Ark Wallet über die Verknüpfung und das Widget auf dem Startbildschirm.',
    tags: ['Ark', 'Lightning'],
    subtitle: 'Ark in Coconut Wallet nutzen',
    screenshotCaptions: [
      'Öffnet sich wie eine eigene App',
      'Guthaben und letzte Aktivitäten auf einen Blick',
      'Mit Ark-Adresse oder Lightning-Rechnung empfangen',
      'Ark Wallet aus einer Hot Wallet auffüllen',
      'Auch Lightning-Rechnungen bezahlen',
      'VTXOs prüfen und vor Ablauf erneuern',
    ],
    creatorParagraphs: [
      'Das Bark-Team bei Second.tech entwickelt Bark, eine Ark-Umsetzung. Bark ist nach Bitcoin Ark benannt und arbeitet nur mit Bitcoin.',
      'Auf der BTC Prague 2026 zeigte es eine Demo von Ark in Coconut und baute danach mit Bark einen Proof of Concept. Gemeinsam mit dem Coconut-Team verfeinert, erschien es als Ark Wallet im Open Store.',
    ],
    belief: 'Wir wollten ein unbekanntes Layer-2-Protokoll so einfach wie möglich nutzbar machen',
  );

  static const ArkFeatureCopy _es = ArkFeatureCopy(
    title: 'Ark Wallet',
    description:
        'Ark es un protocolo de capa 2 para Bitcoin. Un servidor Ark agrupa los pagos de muchas personas, así que son rápidos y baratos. El servidor Ark no es un custodio de tus bitcoins, sino un coordinador de transacciones. Es autocustodia: aunque el servidor se detenga, puedes retirar tus bitcoins on-chain sin depender de él.\n\nFunciones principales\n• Recargar saldo desde on-chain\n• Retirar saldo a on-chain\n• Enviar y recibir dentro de Ark\n• Enviar y recibir por Lightning',
    author: 'Equipo de Bark',
    authorBio: 'Construimos Ark con Bark',
    authorIntent: 'Queríamos Lightning sin gestionar canales y pagos pequeños sin comisiones altas.',
    whyItBelongs: 'Si el servidor Ark desaparece, puedes sacar tu parte on-chain tú solo. Sigue siendo autocustodia.',
    featureHelp: 'Al añadirla, abre tu Ark Wallet desde su acceso directo y su widget en la pantalla de inicio.',
    tags: ['Ark', 'Lightning'],
    subtitle: 'Usa Ark en Coconut Wallet',
    screenshotCaptions: [
      'Se abre como una app propia',
      'Mira tu saldo y la actividad reciente',
      'Recibe con una dirección Ark o una factura Lightning',
      'Recarga tu Ark Wallet desde una hot wallet',
      'Paga también facturas Lightning',
      'Revisa tus VTXO y renuévalos antes de que caduquen',
    ],
    creatorParagraphs: [
      'El equipo de Bark en Second.tech desarrolla Bark, una implementación de Ark. Bark viene de Bitcoin Ark y solo maneja bitcoin.',
      'En BTC Prague 2026 mostró una demo de Ark integrado en Coconut y luego hizo una prueba de concepto con Bark. Después, junto al equipo de Coconut, se pulió y llegó como Ark Wallet a la Open Store.',
    ],
    belief: 'Cuidamos que un protocolo de capa 2 poco conocido sea lo más fácil de usar posible',
  );

  static const ArkFeatureCopy _ja = ArkFeatureCopy(
    title: 'Arkウォレット',
    description:
        'Arkはビットコインのレイヤー2プロトコルです。Arkサーバーが多くの人の取引をまとめて処理するので、速く少ない手数料で送受金できます。Arkサーバーはビットコインを預かるカストディアンではなく、取引を調整するコーディネーターです。そのため、サーバーが止まっても、サーバーに頼らず自分のビットコインをオンチェーンに出金できるセルフカストディ方式です。\n\n主な機能\n• オンチェーンから残高を入金\n• オンチェーンへ残高を出金\n• Ark内で送受金\n• ライトニングで送受金',
    author: 'Barkチーム',
    authorBio: 'BarkでArkをつくるチーム',
    authorIntent: 'チャネル管理なしでLightningを使い、少額でも手数料を気にせず送受金できるようにしたかった。',
    whyItBelongs: 'Arkサーバーがなくなっても自分の分は一人でオンチェーンに戻せるので、セルフカストディのままです。',
    featureHelp: '追加すると、ホーム画面のショートカットとウィジェットからArkウォレットを開けます。',
    tags: ['Ark', 'Lightning'],
    subtitle: 'Coconut WalletでArkを使う',
    screenshotCaptions: [
      '専用アプリのように開く',
      '残高と最近の取引をひと目で',
      'Arkアドレスやライトニングインボイスで受け取る',
      'ホットウォレットからArkウォレットに入金',
      'ライトニングでも送金',
      'VTXOを確認して期限前に更新',
    ],
    creatorParagraphs: [
      'Barkチームは、Second.techでArk実装のBarkを開発するチームです。BarkはBitcoin Arkに由来する名前で、ビットコインだけを扱います。',
      '2026年のBTC Pragueで、CoconutにArkを連携したデモを見せ、その後Barkで概念実証を行ってくれました。その後Coconutチームと磨き上げ、オープンストアのArkウォレットとして公開されました。',
    ],
    belief: 'なじみのないレイヤー2プロトコルも、できるだけ簡単に使えるよう心がけました',
  );
}
