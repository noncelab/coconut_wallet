import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/broadcasting_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/alert_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/card/information_item_card.dart';
import 'package:coconut_wallet/widgets/contents/fiat_price.dart';
import 'package:coconut_wallet/widgets/floating_widget.dart';
import 'package:coconut_wallet/widgets/overlays/network_error_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

class BroadcastingScreen extends StatefulWidget {
  const BroadcastingScreen({super.key});

  @override
  State<BroadcastingScreen> createState() => _BroadcastingScreenState();
}

class _BroadcastingScreenState extends State<BroadcastingScreen> {
  late BroadcastingViewModel _viewModel;
  late BitcoinUnit _currentUnit;

  String get confirmText => _currentUnit.displayBitcoinAmount(_viewModel.amount);

  String get estimatedFeeText =>
      _currentUnit.displayBitcoinAmount(_viewModel.fee, defaultWhenNull: t.calculation_failed);

  String get totalCostText =>
      _currentUnit.displayBitcoinAmount(_viewModel.totalAmount, defaultWhenNull: t.calculation_failed);

  String get unitText => _currentUnit.symbol;
  int? userMessageIndex; // 후원하기에서만 사용

  void _setOverlayLoading(bool value) {
    if (value) {
      context.loaderOverlay.show();
    } else {
      context.loaderOverlay.hide();
    }
  }

  void _onChangeUserMessage() {
    if (userMessageIndex == null) return;

    final int userMessagesLength = t.donation.user_messages.length;
    debugPrint('userMessageIndex: $userMessageIndex, userMessagesLength: $userMessagesLength');
    setState(() {
      userMessageIndex = (userMessageIndex! + 1) % userMessagesLength;
    });
  }

  void broadcast() async {
    if (context.loaderOverlay.visible) return;
    _setOverlayLoading(true);
    await Future.delayed(const Duration(seconds: 1));

    Transaction signedTx;
    if (_viewModel.isPsbt()) {
      signedTx = Psbt.parse(_viewModel.signedTransaction).getSignedTransaction(_viewModel.walletAddressType);
    } else {
      String hexTransaction = _viewModel.decodeTransactionToHex();
      signedTx = Transaction.parse(hexTransaction);
    }

    try {
      Result<String> result = await _viewModel.broadcast(signedTx);
      _setOverlayLoading(false);

      if (result.isFailure) {
        vibrateMedium();
        if (!mounted) return;
        showAlertDialog(
          context: context,
          title: t.broadcasting_screen.error_popup_title,
          content: t.alert.error_send.broadcasting_failed(error: result.error.message),
        );
        return;
      }

      if (result.isSuccess) {
        vibrateLight();
        await _viewModel.updateTagsOfUsedUtxos(signedTx.transactionHash);

        if (!mounted) return;

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/broadcasting-complete', // 이동할 경로
          ModalRoute.withName(
            _viewModel.sendEntryPoint == SendEntryPoint.walletDetail
                ? "/wallet-detail" // '/wallet-detail' 경로를 남기고 그 외의 경로 제거, '/'는 HomeScreen 까지
                : "/",
          ),
          arguments: {
            'id': _viewModel.walletId,
            'txHash': signedTx.transactionHash,
            'isDonation': _viewModel.isSendingDonation,
          },
        );
      }
    } catch (e) {
      Logger.log(">>>>> broadcast error: $e");
      _setOverlayLoading(false);
      String message = t.alert.error_send.broadcasting_failed(error: e.toString());
      if (e.toString().contains('min relay fee not met')) {
        message = t.alert.error_send.insufficient_fee;
      }
      if (!mounted) return;
      showAlertDialog(context: context, content: message);
      vibrateMedium();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<ConnectivityProvider, WalletProvider, BroadcastingViewModel>(
      create: (_) => _viewModel,
      update: (_, connectivityProvider, walletProvider, viewModel) {
        if (viewModel!.isNetworkOn != connectivityProvider.isNetworkOn) {
          viewModel.setIsNetworkOn(connectivityProvider.isNetworkOn);
        }

        return viewModel;
      },
      child: Consumer<BroadcastingViewModel>(
        builder:
            (context, viewModel, child) => Scaffold(
              floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
              backgroundColor: CoconutColors.black,
              appBar: CoconutAppBar.build(
                title: viewModel.isSendingDonation ? t.donation.donate : t.broadcasting_screen.title,
                context: context,
              ),
              body: SafeArea(
                child: Stack(
                  children: [
                    viewModel.isSendingDonation
                        ? _buildDonationBroadcastInfo(viewModel.amount, viewModel.isInitDone, viewModel.isNetworkOn)
                        : _buildNormalBroadcastInfo(
                          viewModel.amount,
                          viewModel.fee,
                          viewModel.totalAmount,
                          viewModel.sendingAmountWhenAddressIsMyChange,
                          viewModel.isSendingToMyAddress,
                          viewModel.recipientAddresses,
                          viewModel.isNetworkOn,
                        ),
                    if (!viewModel.isSendingDonation)
                      FixedBottomButton(
                        showGradient: false,
                        isActive: viewModel.isNetworkOn && viewModel.isInitDone,
                        onButtonClicked: () async {
                          if (viewModel.isNetworkOn == false) {
                            CoconutToast.showWarningToast(context: context, text: ErrorCodes.networkError.message);
                            return;
                          }
                          if (viewModel.feeBumpingType != null && viewModel.hasTransactionConfirmed()) {
                            await TransactionUtil.showTransactionConfirmedDialog(context);
                            return;
                          }
                          if (viewModel.isInitDone) {
                            broadcast();
                          }
                        },
                        text: t.broadcasting_screen.btn_submit,
                      ),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentUnit = context.read<PreferenceProvider>().currentUnit;
    _viewModel = BroadcastingViewModel(
      Provider.of<SendInfoProvider>(context, listen: false),
      Provider.of<WalletProvider>(context, listen: false),
      Provider.of<UtxoTagProvider>(context, listen: false),
      Provider.of<ConnectivityProvider>(context, listen: false).isNetworkOn,
      Provider.of<NodeProvider>(context, listen: false),
      Provider.of<TransactionProvider>(context, listen: false),
    );

    if (_viewModel.isSendingDonation) {
      userMessageIndex = 0;
    }
    WidgetsBinding.instance.addPostFrameCallback((duration) {
      _setOverlayLoading(true);

      try {
        _viewModel.setTxInfo();
      } catch (e) {
        vibrateMedium();
        showAlertDialog(context: context, content: t.alert.error_tx.not_parsed(error: e));
      }

      _setOverlayLoading(false);
    });
  }

  Widget _buildDonationBroadcastInfo(int? amount, bool isInitDone, bool isNetworkOn) {
    return Column(
      children: [
        if (!isNetworkOn) NetworkErrorTooltip(isNetworkOn: isNetworkOn),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 20, top: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () {
                        _onChangeUserMessage();
                      },
                      child: Row(
                        children: [
                          Text(t.donation.user_messages[userMessageIndex!], style: CoconutTypography.heading3_21_Bold),
                          Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: SvgPicture.asset('assets/svg/arrow-reload.svg', width: 18, height: 18),
                          ),
                        ],
                      ),
                    ),
                    CoconutLayout.spacing_100h,
                    Text(t.donation.user_messages_description_1, style: CoconutTypography.heading4_18_Bold),
                    CoconutLayout.spacing_100h,
                    Text(
                      t.donation.user_messages_description_2(amount: (amount ?? 0).toThousandsSeparatedString()),
                      style: CoconutTypography.heading4_18_Bold,
                    ),
                  ],
                ),
              ),
              CoconutLayout.spacing_200h,
              _buildThanksImage(),
              CoconutLayout.spacing_800h,
              CoconutButton(
                width: MediaQuery.sizeOf(context).width,
                onPressed: () {
                  if (isNetworkOn == false) {
                    CoconutToast.showWarningToast(context: context, text: ErrorCodes.networkError.message);
                    return;
                  }
                  if (isInitDone) {
                    broadcast();
                  }
                },
                // 버튼 보이지 않을 때: 수수료 조회에 실패, 잔액이 충분한 지갑이 없음
                // 비활성화 상태로 보일 때: 지갑 동기화 진행 중, 수수료 조회 중,
                // 활성화 상태로 보일 때: 모든 지갑 동기화 완료, 지갑별 수수료 조회 성공
                isActive: isNetworkOn && isInitDone,
                text: t.donation.donate_confirm,
                backgroundColor: CoconutColors.gray100,
                pressedBackgroundColor: CoconutColors.gray500,
                disabledBackgroundColor: CoconutColors.gray800,
                disabledForegroundColor: CoconutColors.gray700,
                height: 50,
                foregroundColor: CoconutColors.black,
                pressedTextColor: CoconutColors.black,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNormalBroadcastInfo(
    int? amount,
    int? fee,
    int? totalAmount,
    int? sendingAmountWhenAddressIsMyChange,
    bool isSendingToMyAddress,
    List<String> recipientAddresses,
    bool isNetworkOn,
  ) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 10,
        right: 10,
        bottom: FixedBottomButton.fixedBottomButtonDefaultBottomPadding,
      ),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            if (!isNetworkOn) NetworkErrorTooltip(isNetworkOn: isNetworkOn),
            CoconutLayout.spacing_1000h,
            Text(t.broadcasting_screen.description, style: Styles.h3, textAlign: TextAlign.center),
            CoconutLayout.spacing_400h,
            GestureDetector(
              onTap: _toggleUnit,
              child: Column(
                children: [
                  Center(
                    child: Text.rich(
                      TextSpan(
                        text: confirmText,
                        children: <TextSpan>[TextSpan(text: ' $unitText', style: Styles.unit)],
                      ),
                      style: Styles.balance1,
                      textAlign: TextAlign.center,
                      textScaler: const TextScaler.linear(1.0),
                    ),
                  ),
                  FiatPrice(
                    satoshiAmount: amount ?? 0,
                    textStyle: CoconutTypography.body2_14_Number.setColor(CoconutColors.gray400),
                  ),
                ],
              ),
            ),
            CoconutLayout.spacing_1000h,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28.0),
                  color: MyColors.transparentWhite_06,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      InformationItemCard(
                        label: t.receiver,
                        value: recipientAddresses,
                        isNumber: true,
                        crossAxisAlignment: CrossAxisAlignment.start,
                      ),
                      const Divider(color: MyColors.transparentWhite_12, height: 1),
                      InformationItemCard(
                        label: t.estimated_fee,
                        value: ["$estimatedFeeText $unitText"],
                        isNumber: true,
                      ),
                      const Divider(color: MyColors.transparentWhite_12, height: 1),
                      InformationItemCard(label: t.total_cost, value: ["$totalCostText $unitText"], isNumber: true),
                    ],
                  ),
                ),
              ),
            ),
            if (isSendingToMyAddress) ...[
              const SizedBox(height: 20),
              Text(t.broadcasting_screen.self_sending, textAlign: TextAlign.center, style: Styles.caption),
            ],
            // FixedBottomButton 크기에 맞게 스크롤이 가능하도록 설정
            CoconutLayout.spacing_600h,
            const SizedBox(height: FixedBottomButton.fixedBottomButtonDefaultHeight),
          ],
        ),
      ),
    );
  }

  Widget _buildThanksImage() {
    final String assetPath;
    int? delayMilliseconds;
    bool repeat = false;

    switch (userMessageIndex) {
      case 0:
        assetPath = 'assets/lottie/two-hands-making-heart.json';
        repeat = true;
        break;
      case 1:
        assetPath = 'assets/images/hand-with-laid-heart.png';
        repeat = true;
        break;
      case 2:
        assetPath = 'assets/lottie/giving-coin.json';
        delayMilliseconds = 1000;
        repeat = false;
        break;
      case 3:
        assetPath = 'assets/lottie/hand-with-floating-heart.json';
        repeat = true;
        break;
      case 4:
        assetPath = 'assets/lottie/tripple-hearts.json';
        repeat = true;
        break;
      case 5:
        assetPath = 'assets/lottie/giving-heart.json';
        delayMilliseconds = 1000;
        repeat = false;
        break;
      case 6:
        assetPath = 'assets/lottie/upside-down-hands.json';
        delayMilliseconds = 1000;
        repeat = false;
        break;
      default:
        assetPath = 'assets/lottie/two-hands-heart.json';
    }

    final Key lottieKey = ValueKey(userMessageIndex);
    if (userMessageIndex == 6) {
      return FloatingWidget(
        delayMilliseconds: delayMilliseconds,
        child: Stack(
          children: [
            ShaderMask(
              shaderCallback:
                  (bounds) => LinearGradient(
                    colors: [
                      CoconutColors.white.withValues(alpha: 0.1),
                      Colors.transparent,
                      CoconutColors.black.withValues(alpha: 0.1),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ).createShader(bounds),
              blendMode: BlendMode.srcATop,
              child: Lottie.asset(
                'assets/lottie/spinning-heart.json',
                key: ValueKey(userMessageIndex! * 2),
                width: 200,
                height: 200,
                fit: BoxFit.fill,
                repeat: true,
              ),
            ),
            Lottie.asset(assetPath, key: lottieKey, width: 200, height: 200, fit: BoxFit.fill, repeat: repeat),
          ],
        ),
      );
    }
    return FloatingWidget(
      delayMilliseconds: delayMilliseconds,
      child:
          userMessageIndex == 1
              ? Image.asset(assetPath, width: 200, height: 200, fit: BoxFit.fill)
              : Lottie.asset(assetPath, key: lottieKey, width: 200, height: 200, fit: BoxFit.fill, repeat: repeat),
    );
  }

  void _toggleUnit() {
    setState(() {
      _currentUnit = _currentUnit == BitcoinUnit.btc ? BitcoinUnit.sats : BitcoinUnit.btc;
    });
  }
}
