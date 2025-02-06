import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/wallet_data_manager.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
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
import 'package:coconut_wallet/screens/wallet_detail/utxo_detail_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_tag_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add_scanner_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_list_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/screens/onboarding/start_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:provider/provider.dart';

enum AccessFlow { splash, main, pinCheck }

class CoconutWalletApp extends StatefulWidget {
  static late String kElectrumHost;
  static late int kElectrumPort;
  static late bool kElectrumIsSSL;
  static late String kMempoolHost;
  static late String kFaucetHost;
  const CoconutWalletApp({super.key});

  @override
  State<CoconutWalletApp> createState() => _CoconutWalletAppState();
}

class _CoconutWalletAppState extends State<CoconutWalletApp> {
  /// 0 = splash, 1 = main, 2 = pin check
  AccessFlow _screenStatus = AccessFlow.splash;

  /// startSplash 완료 콜백
  void _completeSplash(AccessFlow status) {
    setState(() {
      _screenStatus = status;
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

        ChangeNotifierProvider(create: (_) => UtxoTagProvider()),
        ChangeNotifierProvider(create: (_) => TransactionProvider()),

        /// main 에서만 사용하는 모델
        if (_screenStatus == AccessFlow.main) ...{
          ChangeNotifierProvider(create: (_) => PreferenceProvider()),
          Provider(create: (_) => SendInfoProvider()),
          ChangeNotifierProxyProvider3<ConnectivityProvider, VisibilityProvider,
              AuthProvider, WalletProvider>(
            create: (_) {
              return WalletProvider(
                  WalletDataManager(),
                  Provider.of<ConnectivityProvider>(_, listen: false)
                      .isNetworkOn,
                  Provider.of<VisibilityProvider>(_, listen: false)
                      .setWalletCount,
                  Provider.of<AuthProvider>(_, listen: false).isSetPin);
            },
            update: (context, connectivityProvider, visiblityProvider,
                authProvider, walletProvider) {
              try {
                walletProvider!
                    .setIsNetworkOn(connectivityProvider.isNetworkOn);

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
          primaryColor: MyColors.primary, // 기본 색상
          scaffoldBackgroundColor: MyColors.black,
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
          barBackgroundColor: MyColors.black, // AppBar 배경 색상
        ),
        color: MyColors.black,
        home: _screenStatus == AccessFlow.splash
            ? StartScreen(onComplete: _completeSplash)
            : _screenStatus == AccessFlow.main
                ? const AppGuard(
                    child: WalletListScreen(),
                  )
                : CustomLoadingOverlay(
                    child: PinCheckScreen(
                      appEntrance: true,
                      onComplete: () {
                        setState(() {
                          _screenStatus = AccessFlow.main;
                        });
                      },
                    ),
                  ),
        routes: {
          '/wallet-add-scanner': (context) =>
              const CustomLoadingOverlay(child: WalletAddScannerScreen()),
          '/app-info': (context) => const AppInfoScreen(),
          '/wallet-detail': (context) => buildScreenWithArguments(
                context,
                (args) => WalletDetailScreen(id: args['id']),
              ),
          '/wallet-info': (context) => buildScreenWithArguments(
                context,
                (args) => WalletInfoScreen(
                    id: args['id'], isMultisig: args['isMultisig']),
              ),
          '/address-list': (context) => buildScreenWithArguments(
                context,
                (args) => AddressListScreen(id: args['id']),
              ),
          '/transaction-detail': (context) => buildScreenWithArguments(
                context,
                (args) => TransactionDetailScreen(
                    id: args['id'], txHash: args['txHash']),
              ),
          '/unsigned-transaction-qr': (context) => buildScreenWithArguments(
                context,
                (args) =>
                    UnsignedTransactionQrScreen(walletName: args['walletName']),
              ),
          '/signed-psbt-scanner': (context) => const SignedPsbtScannerScreen(),
          '/broadcasting': (context) =>
              const CustomLoadingOverlay(child: BroadcastingScreen()),
          '/broadcasting-complete': (context) => buildScreenWithArguments(
                context,
                (args) => CustomLoadingOverlay(
                    child: BroadcastingCompleteScreen(
                        id: args['id'], txId: args['txId'])),
              ),
          '/send-address': (context) => buildScreenWithArguments(
                context,
                (args) => CustomLoadingOverlay(
                    child: SendAddressScreen(id: args['id'])),
              ),
          '/send-amount': (context) => const SendAmountScreen(),
          '/fee-selection': (context) => const CustomLoadingOverlay(
                child: SendFeeSelectionScreen(),
              ),
          '/utxo-selection': (context) => const CustomLoadingOverlay(
                child: SendUtxoSelectionScreen(),
              ),
          '/send-confirm': (context) =>
              const CustomLoadingOverlay(child: SendConfirmScreen()),
          '/utxo-detail': (context) => buildScreenWithArguments(
                context,
                (args) => CustomLoadingOverlay(
                  child: UtxoDetailScreen(
                    utxo: args['utxo'],
                    id: args['id'],
                    isChange: args['isChange'],
                  ),
                ),
              ),
          '/positive-feedback': (context) => const PositiveFeedbackScreen(),
          '/negative-feedback': (context) => const NegativeFeedbackScreen(),
          '/mnemonic-word-list': (context) => const Bip39ListScreen(),
          '/utxo-tag': (context) => buildScreenWithArguments(
              context, (args) => UtxoTagScreen(id: args['id'])),
        },
      ),
    );
  }

  T buildScreenWithArguments<T>(
      BuildContext context, T Function(Map<String, dynamic>) builder) {
    final Map<String, dynamic> args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>;
    return builder(args);
  }
}
