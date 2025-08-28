import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/settings/electrum_server_view_model.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/repository/realm/wallet_preferences_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/routes/route_observer.dart';
import 'package:coconut_wallet/screens/donation/lightning_donation_info_screen.dart';
import 'package:coconut_wallet/screens/donation/onchain_donation_info_screen.dart';
import 'package:coconut_wallet/screens/donation/select_donation_amount_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add_input_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_home_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_list_screen.dart';
import 'package:coconut_wallet/screens/send/refactor/send_screen.dart';
import 'package:coconut_wallet/screens/send/refactor/utxo_selection_screen.dart';
import 'package:coconut_wallet/screens/send/send_amount_screen.dart';
import 'package:coconut_wallet/screens/settings/block_explorer_screen.dart';
import 'package:coconut_wallet/screens/settings/coconut_crew_screen.dart';
import 'package:coconut_wallet/screens/settings/electrum_server_screen.dart';
import 'package:coconut_wallet/screens/settings/log_viewer_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/address_list_screen.dart';
import 'package:coconut_wallet/screens/review/negative_feedback_screen.dart';
import 'package:coconut_wallet/screens/review/positive_feedback_screen.dart';
import 'package:coconut_wallet/screens/send/broadcasting_complete_screen.dart';
import 'package:coconut_wallet/screens/send/broadcasting_screen.dart';
import 'package:coconut_wallet/screens/send/send_address_screen.dart';
import 'package:coconut_wallet/screens/send/send_confirm_screen.dart';
import 'package:coconut_wallet/screens/send/send_fee_selection_screen.dart';
import 'package:coconut_wallet/screens/settings/app_info_screen.dart';
import 'package:coconut_wallet/screens/settings/bip39_list_screen.dart';
import 'package:coconut_wallet/screens/send/signed_psbt_scanner_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/address_search_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_detail_screen.dart';
import 'package:coconut_wallet/screens/send/unsigned_transaction_qr_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_detail_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_list_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_tag_crud_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add_scanner_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_receive_address_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info_screen.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/screens/onboarding/start_screen.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/analytics_service.dart';

enum AppEntryFlow { splash, main, pinCheck }

class CoconutWalletApp extends StatefulWidget {
  static late String kMempoolHost;
  static late String kFaucetHost;
  static late String kDonationAddress;
  static late NetworkType kNetworkType;
  static late bool kIsFirebaseAnalyticsUsed;

  const CoconutWalletApp({super.key});

  @override
  State<CoconutWalletApp> createState() => _CoconutWalletAppState();
}

class _CoconutWalletAppState extends State<CoconutWalletApp> {
  /// 0 = splash, 1 = main, 2 = pin check
  AppEntryFlow _appEntryFlow = AppEntryFlow.splash;

  final RealmManager _realmManager = RealmManager();

  /// startSplash 완료 콜백
  void _completeSplash(AppEntryFlow appEntryFlow) {
    setState(() {
      _appEntryFlow = appEntryFlow;
    });
  }

  @override
  Widget build(BuildContext context) {
    CoconutTheme.setTheme(Brightness.dark);
    return MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => VisibilityProvider()),
          ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),

          Provider.value(value: _realmManager),

          Provider<AnalyticsService>(
            create: (context) => AnalyticsService(
              CoconutWalletApp.kIsFirebaseAnalyticsUsed ? FirebaseAnalytics.instance : null,
              !CoconutWalletApp.kIsFirebaseAnalyticsUsed,
            ),
          ),

          // Repository 등록 - Provider보다 먼저 등록해야 함
          Provider<WalletRepository>(
            create: (context) => WalletRepository(context.read<RealmManager>()),
          ),
          Provider<AddressRepository>(
            create: (context) => AddressRepository(context.read<RealmManager>()),
          ),
          Provider<TransactionRepository>(
            create: (context) => TransactionRepository(context.read<RealmManager>()),
          ),
          Provider<UtxoRepository>(
            create: (context) => UtxoRepository(context.read<RealmManager>()),
          ),
          Provider<SubscriptionRepository>(
            create: (context) => SubscriptionRepository(context.read<RealmManager>()),
          ),
          Provider<WalletPreferencesRepository>(
            create: (context) => WalletPreferencesRepository(context.read<RealmManager>()),
          ),

          ChangeNotifierProvider(
              create: (_) => PreferenceProvider(context.read<WalletPreferencesRepository>())),

          ChangeNotifierProvider(
            create: (context) => PreferenceProvider(context.read<WalletPreferencesRepository>()),
          ),

          ChangeNotifierProvider<PriceProvider>(
            create: (context) => PriceProvider(
              context.read<ConnectivityProvider>(),
              context.read<PreferenceProvider>(),
            ),
          ),

          ChangeNotifierProvider(
              create: (context) => UtxoTagProvider(
                    context.read<UtxoRepository>(),
                  )),
          ChangeNotifierProvider(
              create: (context) => TransactionProvider(
                    context.read<TransactionRepository>(),
                  )),

          /// main 에서만 사용하는 모델
          if (_appEntryFlow == AppEntryFlow.main) ...{
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
                  context.read<PreferenceProvider>().getElectrumServer(),
                  CoconutWalletApp.kNetworkType,
                  context.read<ConnectivityProvider>(),
                  walletProvider.walletLoadStateNotifier,
                  walletProvider.walletItemListNotifier,
                  CoconutWalletApp.kIsFirebaseAnalyticsUsed
                      ? context.read<AnalyticsService>()
                      : null,
                );
              },
            ),
          },
        ],
        child: TranslationProvider(
          child: CupertinoApp(
            navigatorObservers: [
              routeObserver,
              if (CoconutWalletApp.kIsFirebaseAnalyticsUsed)
                FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance)
            ],
            localizationsDelegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
              DefaultCupertinoLocalizations.delegate,
            ],
            debugShowCheckedModeBanner: false,
            theme: const CupertinoThemeData(
              // 테마 설정
              brightness: Brightness.dark,
              primaryColor: CoconutColors.primary,
              // 기본 색상
              scaffoldBackgroundColor: CoconutColors.black,
              textTheme: CupertinoTextThemeData(
                // 텍스트 테마 설정
                textStyle: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  color: CupertinoColors.white, // 기본 텍스트 색상
                ),
                navTitleTextStyle: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white, // AppBar 제목 텍스트 색상
                ),
                primaryColor: CupertinoColors.white, // 기본 주요 텍스트 색상
                actionTextStyle: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: CupertinoColors.white,
                ),
              ),
              barBackgroundColor: CoconutColors.black, // AppBar 배경 색상
            ),
            color: CoconutColors.black,
            home: _appEntryFlow == AppEntryFlow.splash
                ? StartScreen(onComplete: _completeSplash)
                : _appEntryFlow == AppEntryFlow.main
                    ? const AppGuard(
                        child: WalletHomeScreen(),
                      )
                    : CustomLoadingOverlay(
                        child: PinCheckScreen(
                          appEntrance: true,
                          onComplete: () {
                            setState(() {
                              _appEntryFlow = AppEntryFlow.main;
                            });
                          },
                        ),
                      ),
            routes: {
              '/wallet-list': (context) => const WalletListScreen(),
              '/wallet-add-scanner': (context) => buildScreenWithArguments(
                    context,
                    (args) => CustomLoadingOverlay(
                      child: WalletAddScannerScreen(
                        importSource: args['walletImportSource'],
                      ),
                    ),
                  ),
              '/wallet-add-input': (context) => const CustomLoadingOverlay(
                    child: WalletAddInputScreen(),
                  ),
              '/app-info': (context) => const AppInfoScreen(),
              '/receive-address': (context) => buildScreenWithArguments(
                    context,
                    (args) => ReceiveAddressScreen(
                      id: args['id'],
                    ),
                  ),
              '/wallet-detail': (context) => buildScreenWithArguments(
                    context,
                    (args) => WalletDetailScreen(
                      id: args['id'],
                      entryPoint: args['entryPoint'],
                    ),
                  ),
              '/wallet-info': (context) => buildScreenWithArguments(
                    context,
                    (args) => CustomLoadingOverlay(
                        child: WalletInfoScreen(
                            id: args['id'],
                            isMultisig: args['isMultisig'],
                            entryPoint: args['entryPoint'])),
                  ),
              '/address-list': (context) => buildScreenWithArguments(
                    context,
                    (args) => AddressListScreen(id: args['id']),
                  ),
              '/address-search': (context) => buildScreenWithArguments(
                    context,
                    (args) => AddressSearchScreen(id: args['id']),
                  ),
              '/transaction-detail': (context) => buildScreenWithArguments(
                    context,
                    (args) => TransactionDetailScreen(id: args['id'], txHash: args['txHash']),
                  ),
              '/transaction-fee-bumping': (context) => buildScreenWithArguments(
                    context,
                    (args) => TransactionFeeBumpingScreen(
                      transaction: args['transaction'],
                      feeBumpingType: args['feeBumpingType'],
                      walletId: args['walletId'],
                      walletName: args['walletName'],
                    ),
                  ),
              '/unsigned-transaction-qr': (context) => buildScreenWithArguments(
                    context,
                    (args) => UnsignedTransactionQrScreen(walletName: args['walletName']),
                  ),
              '/signed-psbt-scanner': (context) => const SignedPsbtScannerScreen(),
              '/broadcasting': (context) => const CustomLoadingOverlay(child: BroadcastingScreen()),
              '/broadcasting-complete': (context) => buildScreenWithArguments(
                    context,
                    (args) => CustomLoadingOverlay(
                        child: BroadcastingCompleteScreen(
                            id: args['id'],
                            txHash: args['txHash'],
                            isDonation: args['isDonation'])),
                  ),
              '/send': (context) => buildScreenWithArguments(
                    context,
                    (args) => SendScreen(
                      walletId: args['walletId'],
                      sendEntryPoint: args['sendEntryPoint'],
                    ),
                  ),
              '/send-address': (context) => buildScreenWithArguments(
                    context,
                    (args) => CustomLoadingOverlay(child: SendAddressScreen(id: args['id'])),
                  ),
              '/send-amount': (context) => const SendAmountScreen(),
              '/fee-selection': (context) => const SendFeeSelectionScreen(),
              '/refactor-utxo-selection': (context) => CustomLoadingOverlay(
                    child: buildScreenWithArguments(
                      context,
                      (args) => UtxoSelectionScreen(
                          selectedUtxoList: args['selectedUtxoList'],
                          walletId: args['walletId'],
                          currentUnit: args['currentUnit']),
                    ),
                  ),
              '/send-confirm': (context) => buildScreenWithArguments(
                    context,
                    (args) => CustomLoadingOverlay(
                        child: SendConfirmScreen(currentUnit: args['currentUnit'])),
                  ),
              '/utxo-list': (context) => buildScreenWithArguments(
                    context,
                    (args) => CustomLoadingOverlay(
                      child: UtxoListScreen(id: args['id']),
                    ),
                  ),
              '/positive-feedback': (context) => const PositiveFeedbackScreen(),
              '/negative-feedback': (context) => const NegativeFeedbackScreen(),
              '/mnemonic-word-list': (context) => const Bip39ListScreen(),
              '/utxo-tag': (context) =>
                  buildScreenWithArguments(context, (args) => UtxoTagCrudScreen(id: args['id'])),
              '/select-donation-amount': (context) => buildScreenWithArguments(
                  context,
                  (args) =>
                      SelectDonationAmountScreen(walletListLength: args['wallet-list-length'])),
              '/onchain-donation-info': (context) => buildScreenWithArguments(
                  context,
                  (args) => OnchainDonationInfoScreen(
                        donationAmount: args['donation-amount'],
                      )),
              '/lightning-donation-info': (context) => buildScreenWithArguments(context,
                  (args) => LightningDonationInfoScreen(donationAmount: args['donation-amount'])),
              '/utxo-detail': (context) => buildScreenWithArguments(
                    context,
                    (args) => CustomLoadingOverlay(
                      child: UtxoDetailScreen(
                        utxo: args['utxo'],
                        id: args['id'],
                      ),
                    ),
                  ),
              '/coconut-crew': (context) => const CoconutCrewScreen(),
              '/electrum-server': (context) => ChangeNotifierProvider<ElectrumServerViewModel>(
                    create: (context) => ElectrumServerViewModel(
                        Provider.of<NodeProvider>(context, listen: false),
                        Provider.of<PreferenceProvider>(context, listen: false)),
                    child: const ElectrumServerScreen(),
                  ),
              '/block-explorer': (context) => const BlockExplorerScreen(),
              '/log-viewer': (context) => const LogViewerScreen(),
            },
          ),
        ));
  }

  T buildScreenWithArguments<T>(BuildContext context, T Function(Map<String, dynamic>) builder) {
    final Map<String, dynamic> args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
    return builder(args);
  }
}
