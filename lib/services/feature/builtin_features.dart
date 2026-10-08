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
import 'package:coconut_wallet/services/home/wallet_widget_definitions.dart';
import 'package:coconut_wallet/screens/home/wallet_stack_list_screen.dart';
import 'package:coconut_wallet/screens/settings/tools/glossary_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart' show kEntryPointWalletHome;
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
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

FeatureItem _sub(
  String parentId,
  String id, {
  required String Function() label,
  required String Function() search,
  List<String> keywords = const [],
}) {
  return FeatureItem(
    id: '$parentId.$id',
    label: label,
    keywords: keywords,
    localizedKeywords: () => _keywords(search()),
    parentId: parentId,
  );
}

/// 번역 파일의 쉼표로 구분한 검색어
List<String> _keywords(String text) => [
  for (final keyword in text.split(','))
    if (keyword.trim().isNotEmpty) keyword.trim(),
];

Future<void> _openWalletAdd(BuildContext context, WalletAddDialogMode mode) {
  context.read<AnalyticsService>().logWalletAddButtonClicked(entrySource: WalletAddEntrySource.feature);
  return WalletAddDialog.show(context, mode);
}

Future<void> _push(BuildContext context, String route, [Object? arguments]) {
  return Navigator.pushNamed(context, route, arguments: arguments);
}

/// 언어를 바꾸면 [t]가 새 번역으로 바뀌므로, 라벨은 부를 때마다 지금 번역에서 읽는다.
TranslationsFeatureRegistryKo get _labels => t.feature_registry;
TranslationsFeatureSearchKo get _search => t.feature_search;
TranslationsFeatureSubLabelsKo get _subLabels => t.feature_sub_labels;

List<FeatureItem> builtinFeatures() {
  return [
    FeatureItem(
      id: FeatureIds.appSettings,
      category: FeatureCategory.settings,
      label: () => _labels.app_settings,
      iconPath: FeatureSettingsIconPath.settings,
      localizedKeywords: () => _keywords(_search.app_settings),
      launch:
          (context, _) => Navigator.of(context).push(
            CupertinoPageRoute(
              settings: const RouteSettings(name: '/app-settings'),
              builder: (_) => const AppSettingsScreen(),
            ),
          ),
    ),
    _sub(
      FeatureIds.appSettings,
      'pin',
      label: () => _subLabels.app_settings_pin,
      search: () => _search.app_settings_pin,
      keywords: const ['PIN'],
    ),
    _sub(
      FeatureIds.appSettings,
      'biometrics',
      label: () => _subLabels.app_settings_biometrics,
      search: () => _search.app_settings_biometrics,
      keywords: const ['Face ID'],
    ),
    _sub(
      FeatureIds.appSettings,
      'pin_change',
      label: () => _subLabels.app_settings_pin_change,
      search: () => _search.app_settings_pin_change,
    ),
    _sub(
      FeatureIds.appSettings,
      'unit',
      label: () => _subLabels.app_settings_unit,
      search: () => _search.app_settings_unit,
      keywords: const ['BTC', 'sats', 'BIP177'],
    ),
    _sub(
      FeatureIds.appSettings,
      'fiat',
      label: () => _subLabels.app_settings_fiat,
      search: () => _search.app_settings_fiat,
      keywords: const ['KRW', 'USD', 'JPY', 'EUR'],
    ),
    _sub(
      FeatureIds.appSettings,
      'language',
      label: () => _subLabels.app_settings_language,
      search: () => _search.app_settings_language,
      keywords: const ['한국어', 'English', '日本語', 'Español', 'Deutsch'],
    ),
    _sub(
      FeatureIds.appSettings,
      'theme',
      label: () => _subLabels.app_settings_theme,
      search: () => _search.app_settings_theme,
    ),
    _sub(
      FeatureIds.appSettings,
      'utxo_selection',
      label: () => _subLabels.app_settings_utxo_selection,
      search: () => _search.app_settings_utxo_selection,
    ),
    _sub(
      FeatureIds.appSettings,
      'electrum',
      label: () => _subLabels.app_settings_electrum,
      search: () => _search.app_settings_electrum,
      keywords: const ['Electrum', 'SSL'],
    ),
    _sub(
      FeatureIds.appSettings,
      'explorer',
      label: () => _subLabels.app_settings_explorer,
      search: () => _search.app_settings_explorer,
      keywords: const ['mempool'],
    ),
    _sub(
      FeatureIds.appSettings,
      'log_viewer',
      label: () => _subLabels.app_settings_log_viewer,
      search: () => _search.app_settings_log_viewer,
    ),
    _sub(
      FeatureIds.appSettings,
      'app_info',
      label: () => _subLabels.app_settings_app_info,
      search: () => _search.app_settings_app_info,
    ),
    FeatureItem(
      id: FeatureIds.walletAddWatchOnly,
      category: FeatureCategory.wallet,
      label: () => _labels.wallet_add_watch_only,
      shortLabel: () => _labels.wallet_add_watch_only_short,
      iconPath: FeatureWalletIconPath.walletAddWatchOnly,
      localizedKeywords: () => _keywords(_search.wallet_add_watch_only),
      shortcutEligible: true,
      launch: (context, _) => _openWalletAdd(context, WalletAddDialogMode.watchOnlySource),
    ),
    _sub(
      FeatureIds.walletAddWatchOnly,
      'devices',
      label: () => _subLabels.wallet_add_watch_only_devices,
      search: () => _search.wallet_add_watch_only_devices,
      keywords: const [
        'Coconut Vault',
        'Keystone',
        'SeedSigner',
        'Jade',
        'Coldcard',
        'Krux',
        'Passport',
        'Trezor',
        'BitBox',
      ],
    ),
    _sub(
      FeatureIds.walletAddWatchOnly,
      'manual',
      label: () => _subLabels.wallet_add_watch_only_manual,
      search: () => _search.wallet_add_watch_only_manual,
      keywords: const ['xpub', 'zpub'],
    ),
    FeatureItem(
      id: FeatureIds.walletAddHot,
      category: FeatureCategory.wallet,
      label: () => _labels.wallet_add_hot,
      shortLabel: () => _labels.wallet_add_hot_short,
      iconPath: FeatureShortcutIconPath.walletAddHot,
      localizedKeywords: () => _keywords(_search.wallet_add_hot),
      shortcutEligible: true,
      launch: (context, _) => _openWalletAdd(context, WalletAddDialogMode.hotWalletAction),
    ),
    _sub(
      FeatureIds.walletAddHot,
      'create',
      label: () => _subLabels.wallet_add_hot_create,
      search: () => _search.wallet_add_hot_create,
    ),
    _sub(
      FeatureIds.walletAddHot,
      'restore',
      label: () => _subLabels.wallet_add_hot_restore,
      search: () => _search.wallet_add_hot_restore,
      keywords: const ['SeedQR'],
    ),
    FeatureItem(
      id: FeatureIds.myWallets,
      category: FeatureCategory.wallet,
      label: () => _labels.my_wallets,
      iconPath: FeatureShortcutIconPath.myWallets,
      shortcutEligible: true,
      launch: (context, _) => WalletStackListScreen.open(context, kind: WalletStackKind.all, title: _labels.my_wallets),
    ),
    FeatureItem(
      id: FeatureIds.transactionDraft,
      category: FeatureCategory.transactions,
      label: () => _labels.transaction_draft,
      shortLabel: () => _labels.transaction_draft_short,
      iconPath: FeatureShortcutIconPath.transactionDraft,
      shortcutEligible: true,
      launch: (context, _) => _push(context, AppRouteNames.transactionDraft, const TransactionDraftRouteArgs()),
    ),
    _sub(
      FeatureIds.transactionDraft,
      'signed',
      label: () => _subLabels.transaction_draft_signed,
      search: () => _search.transaction_draft_signed,
    ),
    _sub(
      FeatureIds.transactionDraft,
      'unsigned',
      label: () => _subLabels.transaction_draft_unsigned,
      search: () => _search.transaction_draft_unsigned,
    ),
    FeatureItem(
      id: FeatureIds.calculator,
      category: FeatureCategory.tools,
      label: () => _labels.calculator,
      iconPath: FeatureShortcutIconPath.calculator,
      keywords: const ['P2P'],
      localizedKeywords: () => _keywords(_search.calculator),
      shortcutEligible: true,
      launch: (context, _) => _push(context, AppRouteNames.p2pCalculator),
    ),
    FeatureItem(
      id: FeatureIds.labelManagement,
      category: FeatureCategory.tools,
      label: () => _labels.label_management,
      shortLabel: () => _labels.label_management_short,
      iconPath: FeatureShortcutIconPath.labelManagement,
      shortcutEligible: true,
      keywords: const ['BIP329'],
      localizedKeywords: () => _keywords(_search.label_management),
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
      label: () => _labels.mnemonic_word_list,
      shortLabel: () => _labels.mnemonic_word_list_short,
      iconPath: FeatureShortcutIconPath.mnemonicWordList,
      shortcutEligible: true,
      keywords: const ['BIP39'],
      localizedKeywords: () => _keywords(_search.mnemonic_word_list),
      launch: (context, _) => _push(context, AppRouteNames.mnemonicWordList),
    ),
    FeatureItem(
      id: FeatureIds.glossary,
      category: FeatureCategory.tools,
      label: () => _labels.glossary,
      iconPath: FeatureShortcutIconPath.glossary,
      shortcutEligible: true,
      localizedKeywords: () => _keywords(_search.glossary),
      launch:
          (context, _) => Navigator.of(context).push(
            CupertinoPageRoute(
              settings: const RouteSettings(name: AnalyticsScreenNames.glossary),
              builder: (_) => const GlossaryScreen(),
            ),
          ),
    ),
    FeatureItem(
      id: FeatureIds.hodlInsights,
      category: FeatureCategory.tools,
      label: () => _labels.hodl_insights,
      shortLabel: () => _labels.hodl_insights_short,
      iconPath: FeatureWalletIconPath.pie,
      shortcutEligible: true,
      localizedKeywords: () => _keywords(_search.hodl_insights),
      launch: (context, _) => HodlInsightsScreen.open(context),
    ),
    FeatureItem(
      id: FeatureIds.tutorial,
      category: FeatureCategory.tools,
      label: () => _labels.tutorial,
      iconPath: FeatureShortcutIconPath.tutorial,
      localizedKeywords: () => _keywords(_search.tutorial),
      launch:
          (context, _) =>
              launchURL(context, TUTORIAL_URL, destination: ExternalLinkDestination.tutorial, openInApp: true),
    ),
    FeatureItem(
      id: FeatureIds.openStore,
      label: () => _labels.open_store,
      shortLabel: () => _labels.open_store_short,
      iconPath: BrandIconPath.coconutPlanet,
      keywords: const ['CCOS'],
      localizedKeywords: () => _keywords(_search.open_store),
      launch: (context, _) => openCoconutOpenStoreIntroScreen(context),
    ),
    FeatureItem(
      id: FeatureIds.walletDetail,
      category: FeatureCategory.wallet,
      label: () => _labels.wallet_detail,
      iconPath: FeatureShortcutIconPath.walletDetail,
      localizedKeywords: () => _keywords(_search.wallet_detail),
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
      label: () => _labels.receive,
      iconPath: FeatureTransactionIconPath.receivePlane,
      keywords: const ['QR', 'BIP21'],
      localizedKeywords: () => _keywords(_search.receive),
      context: FeatureContext.wallet,
      shortcutEligible: true,
      launch:
          (context, wallet) => _push(context, AppRouteNames.receiveAddress, ReceiveAddressRouteArgs(id: wallet!.id)),
    ),
    FeatureItem(
      id: FeatureIds.send,
      category: FeatureCategory.transactions,
      label: () => _labels.send,
      iconPath: FeatureShortcutIconPath.send,
      localizedKeywords: () => _keywords(_search.send),
      context: FeatureContext.wallet,
      shortcutEligible: true,
      launch:
          (context, wallet) =>
              _push(context, AppRouteNames.send, SendRouteArgs(id: wallet!.id, sendEntryPoint: SendEntryPoint.home)),
    ),
    FeatureItem(
      id: FeatureIds.transactions,
      category: FeatureCategory.transactions,
      label: () => _labels.transactions,
      iconPath: FeatureShortcutIconPath.transactions,
      keywords: const ['txid', 'RBF', 'CPFP'],
      localizedKeywords: () => _keywords(_search.transactions),
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
      label: () => _labels.utxo_overview,
      iconPath: FeatureShortcutIconPath.utxos,
      keywords: const ['UTXO'],
      localizedKeywords: () => _keywords(_search.utxo_overview),
      context: FeatureContext.wallet,
      shortcutEligible: true,
      launch: (context, wallet) => _push(context, AppRouteNames.utxoOverview, UtxoOverviewRouteArgs(id: wallet!.id)),
    ),
    FeatureItem(
      id: FeatureIds.utxoOrganizer,
      category: FeatureCategory.utxo,
      label: () => _labels.utxo_organizer,
      shortLabel: () => _labels.utxo_organizer_short,
      iconPath: FeatureUtxoIconPath.mergeUtxos,
      keywords: const ['dust'],
      localizedKeywords: () => _keywords(_search.utxo_organizer),
      context: FeatureContext.wallet,
      shortcutEligible: true,
      launch: (context, wallet) => _push(context, AppRouteNames.utxoOrganizer, UtxoOrganizerRouteArgs(id: wallet!.id)),
    ),
    FeatureItem(
      id: FeatureIds.addresses,
      category: FeatureCategory.wallet,
      label: () => _labels.addresses,
      iconPath: FeatureWalletIconPath.bc1,
      localizedKeywords: () => _keywords(_search.addresses),
      context: FeatureContext.wallet,
      shortcutEligible: true,
      launch: (context, wallet) => _push(context, AppRouteNames.addressList, AddressListRouteArgs(id: wallet!.id)),
    ),
    _sub(
      FeatureIds.addresses,
      'search',
      label: () => _subLabels.addresses_search,
      search: () => _search.addresses_search,
    ),
    _sub(
      FeatureIds.addresses,
      'unused',
      label: () => _subLabels.addresses_unused,
      search: () => _search.addresses_unused,
    ),
    _sub(
      FeatureIds.addresses,
      'watched',
      label: () => _subLabels.addresses_watched,
      search: () => _search.addresses_watched,
    ),
    FeatureItem(
      id: FeatureIds.utxoTags,
      category: FeatureCategory.utxo,
      label: () => _labels.utxo_tags,
      iconPath: FeatureTagIconPath.tag,
      localizedKeywords: () => _keywords(_search.utxo_tags),
      context: FeatureContext.wallet,
      shortcutEligible: true,
      launch: (context, wallet) => _push(context, AppRouteNames.utxoTag, UtxoTagCrudRouteArgs(id: wallet!.id)),
    ),
    _sub(
      FeatureIds.walletDetail,
      'rename',
      label: () => _subLabels.wallet_detail_rename,
      search: () => _search.wallet_detail_rename,
    ),
    _sub(
      FeatureIds.walletDetail,
      'mfp',
      label: () => _subLabels.wallet_detail_mfp,
      search: () => _search.wallet_detail_mfp,
      keywords: const ['MFP'],
    ),
    _sub(
      FeatureIds.walletDetail,
      'mnemonic_backup',
      label: () => _subLabels.wallet_detail_mnemonic_backup,
      search: () => _search.wallet_detail_mnemonic_backup,
    ),
    _sub(
      FeatureIds.walletDetail,
      'passphrase',
      label: () => _subLabels.wallet_detail_passphrase,
      search: () => _search.wallet_detail_passphrase,
    ),
    _sub(
      FeatureIds.walletDetail,
      'xpub',
      label: () => _subLabels.wallet_detail_xpub,
      search: () => _search.wallet_detail_xpub,
      keywords: const ['xpub', 'zpub'],
    ),
    _sub(
      FeatureIds.walletDetail,
      'bsms',
      label: () => _subLabels.wallet_detail_bsms,
      search: () => _search.wallet_detail_bsms,
      keywords: const ['BSMS'],
    ),
    _sub(
      FeatureIds.walletDetail,
      'target',
      label: () => _subLabels.wallet_detail_target,
      search: () => _search.wallet_detail_target,
    ),
    _sub(
      FeatureIds.walletDetail,
      'resync',
      label: () => _subLabels.wallet_detail_resync,
      search: () => _search.wallet_detail_resync,
    ),
    _sub(
      FeatureIds.walletDetail,
      'delete',
      label: () => _subLabels.wallet_detail_delete,
      search: () => _search.wallet_detail_delete,
    ),
  ];
}
