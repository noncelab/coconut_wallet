import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/analytics/wallet_add_analytics.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/ccos/open_store/coconut_open_store_navigation.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/screens/home/hodl_insights_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_dialog.dart';
import 'package:coconut_wallet/screens/settings/app_settings/app_settings_screen.dart';
import 'package:coconut_wallet/screens/settings/tools/glossary_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart' show kEntryPointWalletHome;
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';

class FeatureIds {
  static const appSettings = 'app_settings';
  static const walletAddHot = 'wallet_add_hot';
  static const walletAddWatchOnly = 'wallet_add_watch_only';
  static const myWallets = 'my_wallets';
  static const transactionDraft = 'transaction_draft';
  static const calculator = 'calculator';
  static const labelManagement = 'label_management';
  static const mnemonicWordList = 'mnemonic_word_list';
  static const glossary = 'glossary';
  static const tutorial = 'tutorial';
  static const hodlInsights = 'hodl_insights';
  static const openStore = 'open_store';
  static const walletDetail = 'wallet_detail';
  static const receive = 'receive';
  static const send = 'send';
  static const transactions = 'transactions';
  static const utxoOverview = 'utxo_overview';
  static const utxoOrganizer = 'utxo_organizer';
  static const addresses = 'addresses';
  static const utxoTags = 'utxo_tags';
}

/// All Features 분류 안에서 먼저 보여 줄 순서. 없는 기능은 이 뒤에 기능 목록 순서대로 온다.
const allFeaturesOrder = [
  FeatureIds.myWallets,
  FeatureIds.walletDetail,
  FeatureIds.addresses,
  FeatureIds.walletAddWatchOnly,
  FeatureIds.walletAddHot,
];

FeatureItem _sub(String parentId, String id, List<String> keywords) {
  return FeatureItem(id: '$parentId.$id', label: () => keywords.first, keywords: keywords, parentId: parentId);
}

Future<void> _openWalletAdd(BuildContext context, WalletAddDialogMode mode) {
  context.read<AnalyticsService>().logWalletAddButtonClicked(entrySource: WalletAddEntrySource.feature);
  return WalletAddDialog.show(context, mode);
}

Future<void> _push(BuildContext context, String route, [Object? arguments]) {
  return Navigator.pushNamed(context, route, arguments: arguments);
}

List<FeatureItem> builtinFeatures() {
  final labels = t.feature_registry;
  return [
    FeatureItem(
      id: FeatureIds.appSettings,
      category: FeatureCategory.settings,
      label: () => labels.app_settings,
      iconPath: FeatureSettingsIconPath.settings,
      keywords: ['settings', '설정'],
      launch:
          (context, _) => Navigator.of(context).push(
            CupertinoPageRoute(
              settings: const RouteSettings(name: '/app-settings'),
              builder: (_) => const AppSettingsScreen(),
            ),
          ),
    ),
    _sub(FeatureIds.appSettings, 'pin', ['비밀번호 설정하기', 'PIN', '핀', '암호', '잠금', '앱 잠금', 'app lock']),
    _sub(FeatureIds.appSettings, 'biometrics', ['생체 인증 사용하기', '지문', '얼굴 인식', 'Face ID', 'biometrics']),
    _sub(FeatureIds.appSettings, 'pin_change', ['비밀번호 바꾸기', 'PIN 변경', '암호 변경']),
    _sub(FeatureIds.appSettings, 'unit', ['비트코인 단위', 'BTC', 'sats', '사토시', 'BIP177', 'unit']),
    _sub(FeatureIds.appSettings, 'fiat', ['법정 화폐', '통화', '원화', 'KRW', 'USD', 'JPY', 'EUR', 'currency']),
    _sub(FeatureIds.appSettings, 'language', ['언어', '한국어', 'English', '日本語', 'Español', 'Deutsch', 'language']),
    _sub(FeatureIds.appSettings, 'theme', ['테마', '다크 모드', '라이트 모드', '화면 모드', 'theme']),
    _sub(FeatureIds.appSettings, 'utxo_selection', ['UTXO 수동 선택', '코인 선택', '코인 컨트롤', 'coin control']),
    _sub(FeatureIds.appSettings, 'electrum', ['일렉트럼 서버', '노드', '서버', 'electrum', 'SSL', '포트']),
    _sub(FeatureIds.appSettings, 'explorer', ['블록 익스플로러', 'mempool', '멤풀', 'explorer']),
    _sub(FeatureIds.appSettings, 'log_viewer', ['로그 뷰어', '로그', '오류 보고']),
    _sub(FeatureIds.appSettings, 'app_info', ['앱 정보 보기', '버전', 'version', '문의', '라이선스', '약관', '개인정보']),
    FeatureItem(
      id: FeatureIds.walletAddWatchOnly,
      category: FeatureCategory.wallet,
      label: () => labels.wallet_add_watch_only,
      shortLabel: () => labels.wallet_add_watch_only_short,
      iconPath: FeatureWalletIconPath.walletAddWatchOnly,
      keywords: ['add wallet', 'watch-only', '지갑 추가', '보기 전용', '콜드월렛', '하드웨어 지갑'],
      shortcutEligible: true,
      launch: (context, _) => _openWalletAdd(context, WalletAddDialogMode.watchOnlySource),
    ),
    _sub(FeatureIds.walletAddWatchOnly, 'devices', [
      '하드웨어 지갑 연결',
      'vault',
      '볼트',
      'keystone',
      'seedsigner',
      'jade',
      'coldcard',
      'krux',
      'passport',
      'trezor',
      'bitbox',
    ]),
    _sub(FeatureIds.walletAddWatchOnly, 'manual', ['직접 입력', 'xpub', 'zpub', '디스크립터']),
    FeatureItem(
      id: FeatureIds.walletAddHot,
      category: FeatureCategory.wallet,
      label: () => labels.wallet_add_hot,
      shortLabel: () => labels.wallet_add_hot_short,
      iconPath: FeatureShortcutIconPath.walletAddHot,
      keywords: ['add wallet', 'hot wallet', '지갑 추가', '핫월렛', '핫 월렛', '소프트웨어 지갑', '모바일 지갑'],
      shortcutEligible: true,
      launch: (context, _) => _openWalletAdd(context, WalletAddDialogMode.hotWalletAction),
    ),
    _sub(FeatureIds.walletAddHot, 'create', ['새 지갑 만들기', '지갑 생성', '새 니모닉', '시드 생성', '12단어', '24단어']),
    _sub(FeatureIds.walletAddHot, 'restore', ['지갑 복원하기', '복구', '니모닉 복원', '시드 복원', 'SeedQR']),
    FeatureItem(
      id: FeatureIds.myWallets,
      category: FeatureCategory.wallet,
      label: () => labels.my_wallets,
      iconPath: FeatureShortcutIconPath.myWallets,
      shortcutEligible: true,
      launch: (context, _) => _push(context, AppRouteNames.walletList),
    ),
    _sub(FeatureIds.myWallets, 'filter', ['지갑 종류', '필터']),
    _sub(FeatureIds.myWallets, 'order', ['순서 편집', '순서 변경', '정렬', '지갑 삭제']),
    _sub(FeatureIds.myWallets, 'primary', ['대표 지갑', '총액에서 제외']),
    FeatureItem(
      id: FeatureIds.transactionDraft,
      category: FeatureCategory.transactions,
      label: () => labels.transaction_draft,
      shortLabel: () => labels.transaction_draft_short,
      iconPath: FeatureShortcutIconPath.transactionDraft,
      shortcutEligible: true,
      launch: (context, _) => _push(context, AppRouteNames.transactionDraft, const TransactionDraftRouteArgs()),
    ),
    _sub(FeatureIds.transactionDraft, 'signed', ['서명 완료', '서명된 거래', '전송 대기']),
    _sub(FeatureIds.transactionDraft, 'unsigned', ['서명 전', '초안', '작성 중인 거래']),
    FeatureItem(
      id: FeatureIds.calculator,
      category: FeatureCategory.tools,
      label: () => labels.calculator,
      iconPath: FeatureShortcutIconPath.calculator,
      keywords: ['P2P', '개인 간 거래', '환산', '시세', '프리미엄'],
      shortcutEligible: true,
      launch: (context, _) => _push(context, AppRouteNames.p2pCalculator),
    ),
    FeatureItem(
      id: FeatureIds.labelManagement,
      category: FeatureCategory.tools,
      label: () => labels.label_management,
      shortLabel: () => labels.label_management_short,
      iconPath: FeatureShortcutIconPath.labelManagement,
      shortcutEligible: true,
      keywords: ['라벨', 'BIP329', '메모 백업', '가져오기', '내보내기'],
      launch:
          (context, _) => _push(
            context,
            AppRouteNames.labelManagement,
            const LabelManagementRouteArgs(id: null, showImportMemosFromOtherWalletsOption: false),
          ),
    ),
    FeatureItem(
      id: FeatureIds.mnemonicWordList,
      category: FeatureCategory.tools,
      label: () => labels.mnemonic_word_list,
      shortLabel: () => labels.mnemonic_word_list_short,
      iconPath: FeatureShortcutIconPath.mnemonicWordList,
      shortcutEligible: true,
      keywords: ['BIP39', '시드 단어', '단어 목록'],
      launch: (context, _) => _push(context, AppRouteNames.mnemonicWordList),
    ),
    FeatureItem(
      id: FeatureIds.glossary,
      category: FeatureCategory.tools,
      label: () => labels.glossary,
      iconPath: FeatureShortcutIconPath.glossary,
      shortcutEligible: true,
      keywords: ['용어', '사전', '뜻'],
      launch:
          (context, _) => CommonBottomSheets.showCustomHeightBottomSheet(
            context: context,
            screenName: AnalyticsScreenNames.walletHomeGlossarySheet,
            child: const GlossaryBottomSheet(),
            heightRatio: 0.9,
          ),
    ),
    FeatureItem(
      id: FeatureIds.hodlInsights,
      category: FeatureCategory.tools,
      label: () => labels.hodl_insights,
      shortLabel: () => labels.hodl_insights_short,
      iconPath: FeatureWalletIconPath.pie,
      shortcutEligible: true,
      keywords: ['인사이트', '통계', '분석', '잔액 추이', 'insights'],
      launch: (context, _) => HodlInsightsScreen.open(context),
    ),
    FeatureItem(
      id: FeatureIds.tutorial,
      category: FeatureCategory.tools,
      label: () => labels.tutorial,
      iconPath: FeatureShortcutIconPath.tutorial,
      keywords: ['사용법', '도움말', '가이드', 'guide'],
      launch:
          (context, _) =>
              launchURL(context, TUTORIAL_URL, destination: ExternalLinkDestination.tutorial, openInApp: true),
    ),
    FeatureItem(
      id: FeatureIds.openStore,
      label: () => labels.open_store,
      shortLabel: () => labels.open_store_short,
      iconPath: BrandIconPath.coconutPlanet,
      keywords: ['CCOS', '스토어', '확장 기능', '코코넛 테마'],
      launch: (context, _) => openCoconutOpenStoreIntroScreen(context),
    ),
    FeatureItem(
      id: FeatureIds.walletDetail,
      category: FeatureCategory.wallet,
      label: () => labels.wallet_detail,
      iconPath: FeatureShortcutIconPath.walletDetail,
      keywords: ['지갑', '잔액', '지갑 홈', '지갑 정보', '지갑 설정'],
      context: FeatureContext.wallet,
      launch:
          (context, wallet) => _push(
            context,
            AppRouteNames.walletDetail,
            WalletDetailRouteArgs(id: wallet!.id, entryPoint: kEntryPointWalletHome),
          ),
    ),
    FeatureItem(
      id: FeatureIds.receive,
      category: FeatureCategory.transactions,
      label: () => labels.receive,
      iconPath: FeatureTransactionIconPath.receivePlane,
      keywords: ['입금', '수신', '받는 주소', 'QR', 'BIP21'],
      context: FeatureContext.wallet,
      shortcutEligible: true,
      launch:
          (context, wallet) => _push(context, AppRouteNames.receiveAddress, ReceiveAddressRouteArgs(id: wallet!.id)),
    ),
    FeatureItem(
      id: FeatureIds.send,
      category: FeatureCategory.transactions,
      label: () => labels.send,
      iconPath: FeatureShortcutIconPath.send,
      keywords: ['송금', '출금', '전송', '모두 보내기', '수수료율', 'fee'],
      context: FeatureContext.wallet,
      shortcutEligible: true,
      launch:
          (context, wallet) =>
              _push(context, AppRouteNames.send, SendRouteArgs(id: wallet!.id, sendEntryPoint: SendEntryPoint.home)),
    ),
    FeatureItem(
      id: FeatureIds.transactions,
      category: FeatureCategory.transactions,
      label: () => labels.transactions,
      iconPath: FeatureShortcutIconPath.transactions,
      keywords: ['내역', '히스토리', '트랜잭션 목록', 'txid', 'RBF', 'CPFP', '거래 메모'],
      context: FeatureContext.wallet,
      launch:
          (context, wallet) => _push(
            context,
            AppRouteNames.transactionList,
            WalletDetailRouteArgs(id: wallet!.id, entryPoint: kEntryPointWalletHome),
          ),
    ),
    FeatureItem(
      id: FeatureIds.utxoOverview,
      category: FeatureCategory.utxo,
      label: () => labels.utxo_overview,
      iconPath: FeatureShortcutIconPath.utxos,
      keywords: ['UTXO', '코인', '모아보기', 'UTXO 분석', '코인 분포', '사용 잠금', 'freeze', '잔돈'],
      context: FeatureContext.wallet,
      shortcutEligible: true,
      launch: (context, wallet) => _push(context, AppRouteNames.utxoOverview, UtxoOverviewRouteArgs(id: wallet!.id)),
    ),
    FeatureItem(
      id: FeatureIds.utxoOrganizer,
      category: FeatureCategory.utxo,
      label: () => labels.utxo_organizer,
      shortLabel: () => labels.utxo_organizer_short,
      iconPath: FeatureUtxoIconPath.mergeUtxos,
      keywords: ['합치기', '통합', 'consolidation', '나누기', '분할', 'split', 'dust'],
      context: FeatureContext.wallet,
      shortcutEligible: true,
      launch: (context, wallet) => _push(context, AppRouteNames.utxoOrganizer, UtxoOrganizerRouteArgs(id: wallet!.id)),
    ),
    FeatureItem(
      id: FeatureIds.addresses,
      category: FeatureCategory.wallet,
      label: () => labels.addresses,
      iconPath: FeatureWalletIconPath.bc1,
      keywords: ['주소 목록', '전체 주소'],
      context: FeatureContext.wallet,
      shortcutEligible: true,
      launch: (context, wallet) => _push(context, AppRouteNames.addressList, AddressListRouteArgs(id: wallet!.id)),
    ),
    _sub(FeatureIds.addresses, 'search', ['주소 검색', '내 주소 확인', '주소 찾기']),
    _sub(FeatureIds.addresses, 'unused', ['사용 전 주소만 보기', '미사용 주소', '새 주소']),
    _sub(FeatureIds.addresses, 'watched', ['모니터링 중인 주소만 보기', '감시 주소', '구독 주소']),
    FeatureItem(
      id: FeatureIds.utxoTags,
      category: FeatureCategory.utxo,
      label: () => labels.utxo_tags,
      iconPath: FeatureTagIconPath.tag,
      keywords: ['태그', '라벨', '태그 추가', '태그 색상'],
      context: FeatureContext.wallet,
      shortcutEligible: true,
      launch: (context, wallet) => _push(context, AppRouteNames.utxoTag, UtxoTagCrudRouteArgs(id: wallet!.id)),
    ),
    _sub(FeatureIds.walletDetail, 'rename', ['지갑 이름 편집', '이름 변경', '아이콘', '색상']),
    _sub(FeatureIds.walletDetail, 'mfp', ['마스터 핑거프린트 입력', 'MFP', '핑거프린트']),
    _sub(FeatureIds.walletDetail, 'mnemonic_backup', ['니모닉 백업', '백업', '니모닉 보기', '시드 백업', '복구 문구']),
    _sub(FeatureIds.walletDetail, 'passphrase', ['패스프레이즈 확인하기', '패스프레이즈', 'passphrase']),
    _sub(FeatureIds.walletDetail, 'xpub', ['확장 공개키', 'xpub', 'zpub', '공개키']),
    _sub(FeatureIds.walletDetail, 'bsms', ['지갑 백업 데이터 보기', 'BSMS', '디스크립터 내보내기']),
    _sub(FeatureIds.walletDetail, 'target', ['목표 수량', '목표', '저축 목표']),
    _sub(FeatureIds.walletDetail, 'resync', ['지갑 재동기화', '재동기화', '다시 불러오기', '잔액 오류']),
    _sub(FeatureIds.walletDetail, 'delete', ['지갑 삭제하기', '삭제', '지우기']),
  ];
}
