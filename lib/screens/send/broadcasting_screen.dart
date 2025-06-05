import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/broadcasting_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/alert_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
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
  bool isSendingDonation = false;
  int? userMessageIndex; // 후원하기에서만 사용

  @override
  void initState() {
    super.initState();
    _viewModel = BroadcastingViewModel(
      Provider.of<SendInfoProvider>(context, listen: false),
      Provider.of<WalletProvider>(context, listen: false),
      Provider.of<UtxoTagProvider>(context, listen: false),
      Provider.of<ConnectivityProvider>(context, listen: false).isNetworkOn,
      Provider.of<UpbitConnectModel>(context, listen: false).bitcoinPriceKrw,
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

  void _setOverlayLoading(bool value) {
    if (value) {
      context.loaderOverlay.show();
    } else {
      context.loaderOverlay.hide();
    }
  }

  void _onChangeUserMessage() {
    if (userMessageIndex == null) return;

    final userMessagesLength = t.donation.user_messages.length;
    debugPrint('userMessageIndex: $userMessageIndex, userMessagesLength: $userMessagesLength');
    setState(() {
      userMessageIndex = (userMessageIndex! + 1) % userMessagesLength;
    });
  }

  void broadcast() async {
    if (context.loaderOverlay.visible) return;
    _setOverlayLoading(true);
    await Future.delayed(const Duration(seconds: 1));

    Psbt psbt = Psbt.parse(_viewModel.signedTransaction);
    Transaction signedTx = psbt.getSignedTransaction(_viewModel.walletAddressType);

    try {
      Result<String> result = await _viewModel.broadcast(signedTx);
      _setOverlayLoading(false);

      if (result.isFailure) {
        vibrateMedium();
        if (!mounted) return;
        showAlertDialog(
            context: context,
            title: t.broadcasting_screen.error_popup_title,
            content: t.alert.error_send.broadcasting_failed(error: result.error.message));
        return;
      }

      if (result.isSuccess) {
        vibrateLight();
        await _viewModel.updateTagsOfUsedUtxos(signedTx.transactionHash);

        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/broadcasting-complete', // 이동할 경로
          ModalRoute.withName('/wallet-detail'), // '/wallet-detail' 경로를 남기고 그 외의 경로 제거
          arguments: {'id': _viewModel.walletId},
        );
      }
    } catch (_) {
      Logger.log(">>>>> broadcast error: $_");
      _setOverlayLoading(false);
      String message = t.alert.error_send.broadcasting_failed(error: _.toString());
      if (_.toString().contains('min relay fee not met')) {
        message = t.alert.error_send.insufficient_fee;
      }
      if (!mounted) return;
      showAlertDialog(context: context, content: message);
      vibrateMedium();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider3<ConnectivityProvider, WalletProvider, UpbitConnectModel,
        BroadcastingViewModel>(
      create: (_) => _viewModel,
      update: (_, connectivityProvider, walletProvider, upbitConnectModel, viewModel) {
        if (viewModel!.isNetworkOn != connectivityProvider.isNetworkOn) {
          viewModel.setIsNetworkOn(connectivityProvider.isNetworkOn);
        }
        if (mounted && upbitConnectModel.bitcoinPriceKrw != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            viewModel.setBitcoinPriceKrw(upbitConnectModel.bitcoinPriceKrw!);
          });
        }

        return viewModel;
      },
      child: Consumer<BroadcastingViewModel>(
        builder: (context, viewModel, child) => Scaffold(
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          backgroundColor: CoconutColors.black,
          appBar: viewModel.isSendingDonation
              ? CoconutAppBar.build(title: t.donation.donate, context: context)
              : CoconutAppBar.buildWithNext(
                  title: t.broadcasting_screen.title,
                  context: context,
                  usePrimaryActiveColor: true,
                  isActive: viewModel.isNetworkOn && viewModel.isInitDone,
                  onNextPressed: () async {
                    if (viewModel.isNetworkOn == false) {
                      CoconutToast.showWarningToast(
                        context: context,
                        text: ErrorCodes.networkError.message,
                      );
                      return;
                    }
                    if (viewModel.feeBumpingType != null && viewModel.hasTransactionConfirmed()) {
                      await TransactionUtil.showTransactionConfirmedDialog(context);
                      return;
                    }
                    if (viewModel.isInitDone) {
                      broadcast();
                    }
                  }),
          body: SafeArea(
            child: Stack(
              children: [
                viewModel.isSendingDonation
                    ? _buildDonationBroadcastInfo(
                        viewModel.amount,
                        viewModel.isInitDone,
                        viewModel.isNetworkOn,
                      )
                    : _buildNormalBroadcastInfo(
                        viewModel.amount,
                        viewModel.fee,
                        viewModel.totalAmount,
                        viewModel.sendingAmountWhenAddressIsMyChange,
                        viewModel.isSendingToMyAddress,
                        viewModel.recipientAddresses,
                      ),
                NetworkErrorTooltip(isNetworkOn: viewModel.isNetworkOn),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDonationBroadcastInfo(int? amount, bool isInitDone, bool isNetworkOn) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CoconutLayout.defaultPadding,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              left: 20,
              top: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    _onChangeUserMessage();
                  },
                  child: Row(
                    children: [
                      Text(
                        t.donation.user_messages[userMessageIndex!],
                        style: CoconutTypography.heading3_21_Bold,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: SvgPicture.asset(
                          'assets/svg/arrow-reload.svg',
                          width: 18,
                          height: 18,
                        ),
                      ),
                    ],
                  ),
                ),
                CoconutLayout.spacing_100h,
                Text(
                  t.donation.user_messages_description_1,
                  style: CoconutTypography.heading4_18_Bold,
                ),
                CoconutLayout.spacing_100h,
                Text(
                  t.donation.user_messages_description_2(
                    amount: addCommasToIntegerPart((amount ?? 0).toDouble()),
                  ),
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
                CoconutToast.showWarningToast(
                  context: context,
                  text: ErrorCodes.networkError.message,
                );
                return;
              }
              if (isInitDone) {
                // CoconutToast.showToast(context: context, text: '브로드캐스트됨');
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
    );
  }

  Widget _buildNormalBroadcastInfo(
    int? amount,
    int? fee,
    int? totalAmount,
    int? sendingAmountWhenAddressIsMyChange,
    bool isSendingToMyAddress,
    List<String> recipientAddresses,
  ) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        width: MediaQuery.of(context).size.width,
        height:
            MediaQuery.sizeOf(context).height - kToolbarHeight - MediaQuery.of(context).padding.top,
        padding: Paddings.container,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            CoconutLayout.spacing_1000h,
            Text(
              t.broadcasting_screen.description,
              style: Styles.h3,
            ),
            CoconutLayout.spacing_400h,
            Center(
              child: Text.rich(
                TextSpan(
                    text: amount != null
                        ? satoshiToBitcoinString(sendingAmountWhenAddressIsMyChange ?? amount)
                        : "",
                    children: <TextSpan>[TextSpan(text: ' ${t.btc}', style: Styles.unit)]),
                style: Styles.balance1,
              ),
            ),
            FiatPrice(
                satoshiAmount: amount ?? 0,
                textStyle: CoconutTypography.body2_14_Number.setColor(CoconutColors.gray400)),
            CoconutLayout.spacing_1000h,
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28.0),
                    color: MyColors.transparentWhite_06,
                  ),
                  child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          InformationItemCard(
                              label: t.receiver,
                              value: recipientAddresses,
                              isNumber: true,
                              crossAxisAlignment: CrossAxisAlignment.start),
                          const Divider(color: MyColors.transparentWhite_12, height: 1),
                          InformationItemCard(
                              label: t.estimated_fee,
                              value: [fee != null ? "${satoshiToBitcoinString(fee)} ${t.btc}" : ''],
                              isNumber: true),
                          const Divider(color: MyColors.transparentWhite_12, height: 1),
                          InformationItemCard(
                              label: t.total_cost,
                              value: [
                                totalAmount != null
                                    ? "${satoshiToBitcoinString(totalAmount)} ${t.btc}"
                                    : ''
                              ],
                              isNumber: true),
                        ],
                      ))),
            ),
            if (isSendingToMyAddress) ...[
              const SizedBox(
                height: 20,
              ),
              Text(
                t.broadcasting_screen.self_sending,
                textAlign: TextAlign.center,
                style: Styles.caption,
              ),
            ],
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
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  CoconutColors.white.withOpacity(0.1),
                  Colors.transparent,
                  CoconutColors.black.withOpacity(0.1),
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
            Lottie.asset(
              assetPath,
              key: lottieKey,
              width: 200,
              height: 200,
              fit: BoxFit.fill,
              repeat: repeat,
            ),
          ],
        ),
      );
    }
    return FloatingWidget(
      delayMilliseconds: delayMilliseconds,
      child: userMessageIndex == 1
          ? Image.asset(
              assetPath,
              width: 200,
              height: 200,
              fit: BoxFit.fill,
            )
          : Lottie.asset(
              assetPath,
              key: lottieKey,
              width: 200,
              height: 200,
              fit: BoxFit.fill,
              repeat: repeat,
            ),
    );
  }
}
