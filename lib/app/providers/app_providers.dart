import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/providers/preferences/electrum_server_provider.dart';
import 'package:coconut_wallet/providers/preferences/feature_settings_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_preferences_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

List<SingleChildWidget> buildAppProviders({
  required RealmManager realmManager,
  required bool isMainFlow,
  required bool isFirebaseAnalyticsUsed,
  required NetworkType networkType,
}) {
  return [
    ChangeNotifierProvider(create: (_) => VisibilityProvider()),
    ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    ChangeNotifierProvider(create: (_) => FeatureSettingsProvider()),
    Provider.value(value: realmManager),
    Provider<AnalyticsService>(
      create:
          (context) =>
              AnalyticsService(isFirebaseAnalyticsUsed ? FirebaseAnalytics.instance : null, !isFirebaseAnalyticsUsed),
    ),
    // Repository providers must be registered before dependent providers.
    Provider<AddressRepository>(create: (context) => AddressRepository(context.read<RealmManager>())),
    Provider<TransactionRepository>(create: (context) => TransactionRepository(context.read<RealmManager>())),
    Provider<UtxoRepository>(create: (context) => UtxoRepository(context.read<RealmManager>())),
    Provider<TransactionDraftRepository>(create: (context) => TransactionDraftRepository(context.read<RealmManager>())),
    Provider<WalletRepository>(
      create: (context) => WalletRepository(context.read<RealmManager>(), context.read<TransactionDraftRepository>()),
    ),
    Provider<SubscriptionRepository>(create: (context) => SubscriptionRepository(context.read<RealmManager>())),
    Provider<WalletPreferencesRepository>(
      create: (context) => WalletPreferencesRepository(context.read<RealmManager>()),
    ),
    ChangeNotifierProvider(create: (_) => ElectrumServerProvider()),
    ChangeNotifierProvider(create: (_) => BlockExplorerProvider()),
    ChangeNotifierProvider(
      create:
          (context) => PreferenceProvider(
            context.read<WalletPreferencesRepository>(),
            context.read<ElectrumServerProvider>(),
            context.read<BlockExplorerProvider>(),
            featureSettingsProvider: context.read<FeatureSettingsProvider>(),
          ),
    ),
    ChangeNotifierProvider<PriceProvider>(
      create: (context) => PriceProvider(context.read<ConnectivityProvider>(), context.read<PreferenceProvider>()),
    ),
    ChangeNotifierProvider(create: (context) => UtxoTagProvider(context.read<UtxoRepository>())),
    ChangeNotifierProvider(create: (context) => TransactionProvider(context.read<TransactionRepository>())),
    if (isMainFlow) ...[
      Provider(create: (_) => SendInfoProvider()),
      ChangeNotifierProvider<WalletProvider>(
        create: (context) {
          return WalletProvider(
            Provider.of<AddressRepository>(context, listen: false),
            Provider.of<TransactionRepository>(context, listen: false),
            Provider.of<UtxoRepository>(context, listen: false),
            Provider.of<WalletRepository>(context, listen: false),
            (count) async {
              await context.read<VisibilityProvider>().setWalletCount(count);
            },
            Provider.of<PreferenceProvider>(context, listen: false),
          );
        },
      ),
      ChangeNotifierProvider<NodeProvider>(
        create: (context) {
          final walletProvider = context.read<WalletProvider>();
          return NodeProvider(
            context.read<ElectrumServerProvider>().getElectrumServer(),
            networkType,
            context.read<ConnectivityProvider>(),
            walletProvider.walletLoadStateNotifier,
            walletProvider.walletItemListNotifier,
            isFirebaseAnalyticsUsed ? context.read<AnalyticsService>() : null,
          );
        },
      ),
    ],
  ];
}
