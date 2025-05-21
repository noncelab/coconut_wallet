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
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/screens/home/wallet_add_input_screen.dart';
import 'package:coconut_wallet/screens/send/send_amount_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/address_list_screen.dart';
import 'package:coconut_wallet/screens/review/negative_feedback_screen.dart';
import 'package:coconut_wallet/screens/review/positive_feedback_screen.dart';
import 'package:coconut_wallet/screens/send/broadcasting_complete_screen.dart';
import 'package:coconut_wallet/screens/send/broadcasting_screen.dart';
import 'package:coconut_wallet/screens/send/send_address_screen.dart';
import 'package:coconut_wallet/screens/send/send_confirm_screen.dart';
import 'package:coconut_wallet/screens/send/send_fee_selection_screen.dart';
import 'package:coconut_wallet/screens/send/send_utxo_selection_screen.dart';
import 'package:coconut_wallet/screens/settings/app_info_screen.dart';
import 'package:coconut_wallet/screens/settings/bip39_list_screen.dart';
import 'package:coconut_wallet/screens/send/signed_psbt_scanner_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_detail_screen.dart';
import 'package:coconut_wallet/screens/send/unsigned_transaction_qr_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_detail_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_list_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_tag_crud_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add_scanner_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_list_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/screens/onboarding/start_screen.dart';

import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';

enum AppEntryFlow { splash, main, pinCheck }

class CoconutWalletApp extends StatefulWidget {
  static late String kElectrumHost;
  static late int kElectrumPort;
  static late bool kElectrumIsSSL;
  static late String kMempoolHost;
  static late String kApiHost;
  static late NetworkType kNetworkType;
  const CoconutWalletApp({super.key});

  @override
  State<CoconutWalletApp> createState() => _CoconutWalletAppState();
}

class _CoconutWalletAppState extends State<CoconutWalletApp> {
  /// 0 = splash, 1 = main, 2 = pin check
  AppEntryFlow _appEntryFlow = AppEntryFlow.splash;

  final RealmManager _realmManager = RealmManager();
  final SharedPrefsRepository _sharedPrefs = SharedPrefsRepository();

  @override
  void initState() {
    super.initState();
    _initializeRealmManager();
  }

  // RealmManager 초기화 메서드
  Future<void> _initializeRealmManager() async {
    // SharedPreferences에서 PIN 설정 여부 확인
    final isSetPin = _sharedPrefs.getBool(SharedPrefKeys.kIsSetPin);
    await _realmManager.init(isSetPin);
  }

  /// startSplash 완료 콜백
  void _completeSplash(AppEntryFlow appEntryFlow) {
    setState(() {
      _appEntryFlow = appEntryFlow;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => UpbitConnectModel()),
        ChangeNotifierProvider(create: (_) => VisibilityProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),

        Provider.value(value: _realmManager),

        // Repository 등록 - Provider보다 먼저 등록해야 함
        ProxyProvider<RealmManager, WalletRepository>(
          create: (context) => WalletRepository(context.read<RealmManager>()),
          update: (context, realmManager, previous) => previous ?? WalletRepository(realmManager),
        ),
        ProxyProvider<RealmManager, AddressRepository>(
          create: (context) => AddressRepository(context.read<RealmManager>()),
          update: (context, realmManager, previous) => previous ?? AddressRepository(realmManager),
        ),
        ProxyProvider<RealmManager, TransactionRepository>(
          create: (context) => TransactionRepository(context.read<RealmManager>()),
          update: (context, realmManager, previous) =>
              previous ?? TransactionRepository(realmManager),
        ),
        ProxyProvider<RealmManager, UtxoRepository>(
          create: (context) => UtxoRepository(context.read<RealmManager>()),
          update: (context, realmManager, previous) => previous ?? UtxoRepository(realmManager),
        ),
        ProxyProvider<RealmManager, SubscriptionRepository>(
          create: (context) => SubscriptionRepository(context.read<RealmManager>()),
          update: (context, realmManager, previous) =>
              previous ?? SubscriptionRepository(realmManager),
        ),

        ChangeNotifierProvider(
            create: (context) => UtxoTagProvider(
                  context.read<UtxoRepository>(),
                )),
        ChangeNotifierProvider(
            create: (context) => TransactionProvider(
                  context.read<TransactionRepository>(),
                )),

        // NodeProvider
        ProxyProvider5<AddressRepository, TransactionRepository, UtxoRepository,
            SubscriptionRepository, WalletRepository, NodeProvider>(
          create: (context) => NodeProvider(
              CoconutWalletApp.kElectrumHost,
              CoconutWalletApp.kElectrumPort,
              CoconutWalletApp.kElectrumIsSSL,
              CoconutWalletApp.kNetworkType),
          update: (context, addressRepository, transactionRepository, utxoRepository,
                  subscribeRepository, walletRepository, previous) =>
              previous ??
              NodeProvider(
                CoconutWalletApp.kElectrumHost,
                CoconutWalletApp.kElectrumPort,
                CoconutWalletApp.kElectrumIsSSL,
                CoconutWalletApp.kNetworkType,
              ),
        ),

        /// main 에서만 사용하는 모델
        if (_appEntryFlow == AppEntryFlow.main) ...{
          ChangeNotifierProvider(create: (_) => PreferenceProvider()),
          Provider(create: (_) => SendInfoProvider()),
          ChangeNotifierProxyProvider3<ConnectivityProvider, VisibilityProvider, AuthProvider,
              WalletProvider>(
            create: (_) {
              return WalletProvider(
                  Provider.of<RealmManager>(_, listen: false),
                  Provider.of<AddressRepository>(_, listen: false),
                  Provider.of<TransactionRepository>(_, listen: false),
                  Provider.of<UtxoRepository>(_, listen: false),
                  Provider.of<WalletRepository>(_, listen: false),
                  Provider.of<ConnectivityProvider>(_, listen: false).isNetworkOn,
                  Provider.of<VisibilityProvider>(_, listen: false).setWalletCount,
                  Provider.of<AuthProvider>(_, listen: false).isSetPin,
                  Provider.of<NodeProvider>(_, listen: false));
            },
            update:
                (context, connectivityProvider, visiblityProvider, authProvider, walletProvider) {
              try {
                // TODO: 바뀌었을 때만 호출되도록. walletProvider 내부에서 addLitsener()
                walletProvider!.setIsNetworkOn(connectivityProvider.isNetworkOn);

                return walletProvider;
              } catch (e) {
                if (walletProvider == null) {
                  rethrow;
                }

                return walletProvider;
              }
            },
          ),
        },
      ],
      child: CupertinoApp(
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],
        debugShowCheckedModeBanner: false,
        theme: const CupertinoThemeData(
          // 테마 설정
          brightness: Brightness.dark,
          primaryColor: CoconutColors.primary, // 기본 색상
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
                    child: WalletListScreen(),
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
          '/wallet-detail': (context) => buildScreenWithArguments(
                context,
                (args) => WalletDetailScreen(id: args['id']),
              ),
          '/wallet-info': (context) => buildScreenWithArguments(
                context,
                (args) => CustomLoadingOverlay(
                    child: WalletInfoScreen(id: args['id'], isMultisig: args['isMultisig'])),
              ),
          '/address-list': (context) => buildScreenWithArguments(
                context,
                (args) => AddressListScreen(id: args['id']),
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
                (args) => CustomLoadingOverlay(child: BroadcastingCompleteScreen(id: args['id'])),
              ),
          '/send-address': (context) => buildScreenWithArguments(
                context,
                (args) => CustomLoadingOverlay(child: SendAddressScreen(id: args['id'])),
              ),
          '/send-amount': (context) => const SendAmountScreen(),
          '/fee-selection': (context) => const SendFeeSelectionScreen(),
          '/utxo-selection': (context) => const CustomLoadingOverlay(
                child: SendUtxoSelectionScreen(),
              ),
          '/send-confirm': (context) => const CustomLoadingOverlay(child: SendConfirmScreen()),
          '/utxo-list': (context) => buildScreenWithArguments(
                context,
                (args) => CustomLoadingOverlay(
                  child: UtxoListScreen(id: args['id']),
                ),
              ),
          '/utxo-detail': (context) => buildScreenWithArguments(
                context,
                (args) => CustomLoadingOverlay(
                  child: UtxoDetailScreen(
                    utxo: args['utxo'],
                    id: args['id'],
                  ),
                ),
              ),
          '/positive-feedback': (context) => const PositiveFeedbackScreen(),
          '/negative-feedback': (context) => const NegativeFeedbackScreen(),
          '/mnemonic-word-list': (context) => const Bip39ListScreen(),
          '/utxo-tag': (context) =>
              buildScreenWithArguments(context, (args) => UtxoTagCrudScreen(id: args['id'])),
        },
      ),
    );
  }

  T buildScreenWithArguments<T>(BuildContext context, T Function(Map<String, dynamic>) builder) {
    final Map<String, dynamic> args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
    return builder(args);
  }
}
