import 'package:coconut_wallet/appGuard.dart';
import 'package:coconut_wallet/model/manager/wallet_data_manager.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/screens/address_list_screen.dart';
import 'package:coconut_wallet/screens/receive_address_screen.dart';
import 'package:coconut_wallet/screens/review/negative_feedback_screen.dart';
import 'package:coconut_wallet/screens/review/positive_feedback_screen.dart';
import 'package:coconut_wallet/screens/send/broadcasting_complete_screen.dart';
import 'package:coconut_wallet/screens/send/broadcasting_screen.dart';
import 'package:coconut_wallet/screens/send/send_address_screen.dart';
import 'package:coconut_wallet/screens/send/send_amount_screen.dart';
import 'package:coconut_wallet/screens/send/send_confirm_screen.dart';
import 'package:coconut_wallet/screens/send/send_fee_selection_screen.dart';
import 'package:coconut_wallet/screens/send/send_utxo_selection_screen.dart';
import 'package:coconut_wallet/screens/settings/app_info_screen.dart';
import 'package:coconut_wallet/screens/settings/bip39_list_screen.dart';
import 'package:coconut_wallet/screens/signed_psbt_scanner_screen.dart';
import 'package:coconut_wallet/screens/transaction_detail_screen.dart';
import 'package:coconut_wallet/screens/unsigned_transaction_qr_screen.dart';
import 'package:coconut_wallet/screens/utxo_detail_screen.dart';
import 'package:coconut_wallet/screens/utxo_list_screen.dart';
import 'package:coconut_wallet/screens/utxo_tag_screen.dart';
import 'package:coconut_wallet/screens/wallet_add_scanner_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail_screen.dart';
import 'package:coconut_wallet/screens/wallet_list_screen.dart';
import 'package:coconut_wallet/screens/wallet_multisig_screen.dart';
import 'package:coconut_wallet/screens/wallet_setting_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/providers/app_sub_state_model.dart';
import 'package:coconut_wallet/screens/pin_check_screen.dart';
import 'package:coconut_wallet/screens/start_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:provider/provider.dart';

enum AccessFlow { splash, main, pinCheck }

class PowWalletApp extends StatefulWidget {
  static late String kElectrumHost;
  static late int kElectrumPort;
  static late bool kElectrumIsSSL;
  static late String kMempoolHost;
  static late String kFaucetHost;
  const PowWalletApp({super.key});

  @override
  State<PowWalletApp> createState() => _PowWalletAppState();
}

class _PowWalletAppState extends State<PowWalletApp> {
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
        /// splash, main, pinCheck 에서 공통으로 사용하는 모델
        ChangeNotifierProvider(create: (_) => AppSubStateModel()),

        ChangeNotifierProvider(create: (_) => UpbitConnectModel()),

        /// main 에서만 사용하는 모델
        if (_screenStatus == AccessFlow.main) ...{
          ChangeNotifierProxyProvider<AppSubStateModel, AppStateModel>(
            create: (_) {
              return AppStateModel(
                  Provider.of<AppSubStateModel>(_, listen: false),
                  WalletDataManager());
            },
            update: (_, subStateModel, appStateModel) =>
                appStateModel!..updateWithSubState(subStateModel),
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
                ? const AppGuard(child: WalletListScreen())
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
          '/wallet-list': (context) =>
              const AppGuard(child: WalletListScreen()),
          '/wallet-add-scanner': (context) =>
              const CustomLoadingOverlay(child: WalletAddScannerScreen()),
          '/app-info': (context) => const AppInfoScreen(),
          '/wallet-detail': (context) => buildScreenWithArguments(
                context,
                (args) => WalletDetailScreen(
                    id: args['id'], syncResult: args['syncResult']),
              ),
          '/wallet-multisig': (context) => buildScreenWithArguments(
                context,
                (args) => WalletMultisigScreen(id: args['id']),
              ),
          '/wallet-setting': (context) => buildScreenWithArguments(
                context,
                (args) => WalletSettingScreen(id: args['id']),
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
          '/receive-address': (context) => buildScreenWithArguments(
                context,
                (args) => ReceiveAddressScreen(id: args['id']),
              ),
          '/unsigned-transaction-qr': (context) => buildScreenWithArguments(
                context,
                (args) => UnsignedTransactionQrScreen(id: args['id']),
              ),
          '/signed-psbt-scanner': (context) => buildScreenWithArguments(
                context,
                (args) => SignedPsbtScannerScreen(id: args['id']),
              ),
          '/broadcasting': (context) => buildScreenWithArguments(
                context,
                (args) => CustomLoadingOverlay(
                    child: BroadcastingScreen(id: args['id'])),
              ),
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
          '/send-amount': (context) => buildScreenWithArguments(
                context,
                (args) => CustomLoadingOverlay(
                    child: SendAmountScreen(
                        id: args['id'], recipient: args['recipient'])),
              ),
          '/fee-selection': (context) => buildScreenWithArguments(
                context,
                (args) => CustomLoadingOverlay(
                    child: SendFeeSelectionScreen(
                        id: args['id'], sendInfo: args['sendInfo'])),
              ),
          '/utxo-selection': (context) => buildScreenWithArguments(
                context,
                (args) => CustomLoadingOverlay(
                    child: SendUtxoSelectionScreen(
                        id: args['id'], sendInfo: args['sendInfo'])),
              ),
          '/send-confirm': (context) => buildScreenWithArguments(
                context,
                (args) => CustomLoadingOverlay(
                    child: SendConfirmScreen(
                        id: args['id'], sendInfo: args['fullSendInfo'])),
              ),
          '/utxo-list': (context) => buildScreenWithArguments(
                context,
                (args) =>
                    CustomLoadingOverlay(child: UtxoListScreen(id: args['id'])),
              ),
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
