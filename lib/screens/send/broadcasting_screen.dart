import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/broadcasting_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/alert_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/card/information_item_card.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

class BroadcastingScreen extends StatefulWidget {
  const BroadcastingScreen({super.key});

  @override
  State<BroadcastingScreen> createState() => _BroadcastingScreenState();
}

class _BroadcastingScreenState extends State<BroadcastingScreen> {
  late BroadcastingViewModel _viewModel;

  void broadcast() async {
    setOverlayLoading(true);
    PSBT psbt = PSBT.parse(_viewModel.signedTransaction);
    Transaction signedTx =
        psbt.getSignedTransaction(_viewModel.walletAddressType);

    try {
      Result<String, CoconutError> result =
          await _viewModel.broadcast(signedTx);

      setOverlayLoading(false);

      if (result.isFailure) {
        vibrateMedium();
        if (!mounted) return;
        showAlertDialog(
            context: context, content: "전송 실패\n${result.error?.message}");
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
              '/wallet-detail'), // '/wallet-detail' 경로를 남기고 그 외의 경로 제거
          arguments: {
            'id': _viewModel.walletId,
            'txId': result.value,
          },
        );
      }
    } catch (_) {
      Logger.log(">>>>> broadcast error: $_");
      setOverlayLoading(false);
      String message = '[전송 실패]\n${_.toString()}';
      if (_.toString().contains('min relay fee not met')) {
        message = '[전송 실패]\n수수료율을 높여서\n다시 시도해주세요.';
      }
      if (!mounted) return;
      showAlertDialog(context: context, content: message);
      vibrateMedium();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider3<ConnectivityProvider, WalletProvider,
        UpbitConnectModel, BroadcastingViewModel>(
      create: (_) => _viewModel,
      update: (_, connectivityProvider, walletProvider, upbitConnectModel,
          viewModel) {
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
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          backgroundColor: MyColors.black,
          appBar: CustomAppBar.buildWithNext(
              title: '최종 확인',
              context: context,
              isActive: viewModel.isInitDone,
              onNextPressed: () {
                if (viewModel.isNetworkOn == false) {
                  CustomToast.showWarningToast(
                      context: context, text: ErrorCodes.networkError.message);
                  return;
                }

                if (viewModel.isInitDone) {
                  broadcast();
                }
              }),
          body: SafeArea(
            child: SingleChildScrollView(
              child: Container(
                width: MediaQuery.of(context).size.width,
                padding: Paddings.container,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      height: 40,
                    ),
                    const Text(
                      "아래 정보로 송금할게요",
                      style: Styles.h3,
                    ),
                    Container(
                        margin: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text.rich(
                            TextSpan(
                                text: viewModel.amount != null
                                    ? satoshiToBitcoinString(viewModel
                                                .sendingAmountWhenAddressIsMyChange !=
                                            null
                                        ? viewModel.sendingAmountWhenAddressIsMyChange!
                                        : viewModel.amount!)
                                    : "",
                                children: const <TextSpan>[
                                  TextSpan(text: ' BTC', style: Styles.unit)
                                ]),
                            style: Styles.balance1,
                          ),
                        )),
                    Selector<BroadcastingViewModel, int?>(
                      selector: (context, model) => model.amountValueInKrw,
                      builder: (context, amountValueInKrw, child) {
                        if (amountValueInKrw != null) {
                          return Text(
                              addCommasToIntegerPart(
                                  amountValueInKrw.toDouble()),
                              style: Styles.label.merge(TextStyle(
                                  fontFamily:
                                      CustomFonts.number.getFontFamily)));
                        } else {
                          return const SizedBox();
                        }
                      },
                    ),
                    const SizedBox(
                      height: 40,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28.0),
                            color: MyColors.transparentWhite_06,
                          ),
                          child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                children: [
                                  InformationItemCard(
                                      label: '보낼 주소',
                                      value: viewModel.address ?? "",
                                      isNumber: true),
                                  const Divider(
                                      color: MyColors.transparentWhite_12,
                                      height: 1),
                                  InformationItemCard(
                                      label: '예상 수수료',
                                      value: viewModel.fee != null
                                          ? "${satoshiToBitcoinString(viewModel.fee!)} BTC"
                                          : '',
                                      isNumber: true),
                                  const Divider(
                                      color: MyColors.transparentWhite_12,
                                      height: 1),
                                  InformationItemCard(
                                      label: '총 소요 수량',
                                      value: viewModel.totalAmount != null
                                          ? "${satoshiToBitcoinString(viewModel.totalAmount!)} BTC"
                                          : '',
                                      isNumber: true),
                                ],
                              ))),
                    ),
                    if (viewModel.isSendingToMyAddress) ...[
                      const SizedBox(
                        height: 20,
                      ),
                      const Text(
                        "내 지갑으로 보내는 트랜잭션입니다.",
                        textAlign: TextAlign.center,
                        style: Styles.caption,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _viewModel = BroadcastingViewModel(
        Provider.of<SendInfoProvider>(context, listen: false),
        Provider.of<WalletProvider>(context, listen: false),
        Provider.of<UtxoTagProvider>(context, listen: false),
        Provider.of<ConnectivityProvider>(context, listen: false).isNetworkOn,
        Provider.of<UpbitConnectModel>(context, listen: false).bitcoinPriceKrw);

    WidgetsBinding.instance.addPostFrameCallback((duration) {
      setOverlayLoading(true);

      try {
        _viewModel.setTxInfo();
      } catch (e) {
        vibrateMedium();
        showAlertDialog(context: context, content: "트랜잭션 파싱 실패: $e");
      }

      setOverlayLoading(false);
    });
  }

  void setOverlayLoading(bool value) {
    if (value) {
      context.loaderOverlay.show();
    } else {
      context.loaderOverlay.hide();
    }
  }
}
