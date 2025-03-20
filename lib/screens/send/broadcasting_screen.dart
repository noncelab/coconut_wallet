import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart'; // FIXME: remove model import
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
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/card/information_item_card.dart';
import 'package:coconut_wallet/widgets/overlays/custom_toast.dart';
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
    if (context.loaderOverlay.visible) return;
    _setOverlayLoading(true);
    await Future.delayed(const Duration(seconds: 1));

    Psbt psbt = Psbt.parse(_viewModel.signedTransaction);
    Transaction signedTx =
        psbt.getSignedTransaction(_viewModel.walletAddressType);

    try {
      Result<String> result = await _viewModel.broadcast(signedTx);
      _setOverlayLoading(false);

      if (result.isFailure) {
        vibrateMedium();
        if (!mounted) return;
        showAlertDialog(
            context: context,
            content: t.alert.error_send
                .broadcasting_failed(error: result.error.message));
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
          arguments: {'id': _viewModel.walletId},
        );
      }
    } catch (_) {
      Logger.log(">>>>> broadcast error: $_");
      _setOverlayLoading(false);
      String message =
          t.alert.error_send.broadcasting_failed(error: _.toString());
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
              title: t.broadcasting_screen.title,
              context: context,
              isActive: viewModel.isInitDone,
              onNextPressed: () async {
                if (viewModel.isNetworkOn == false) {
                  CustomToast.showWarningToast(
                      context: context, text: ErrorCodes.networkError.message);
                  return;
                }
                if (viewModel.feeBumpingType != null &&
                    viewModel.hasTransactionConfirmed()) {
                  await TransactionUtil.showTransactionConfirmedDialog(context);
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
                    Text(
                      t.broadcasting_screen.description,
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
                                children: <TextSpan>[
                                  TextSpan(
                                      text: ' ${t.btc}', style: Styles.unit)
                                ]),
                            style: Styles.balance1,
                          ),
                        )),
                    Selector<BroadcastingViewModel, int?>(
                      selector: (context, model) => model.amountValueInKrw,
                      builder: (context, amountValueInKrw, child) {
                        if (amountValueInKrw != null) {
                          return Text(
                              '${addCommasToIntegerPart(amountValueInKrw.toDouble())} ${CurrencyCode.KRW.code}',
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
                                      label: t.receiver,
                                      value: viewModel.recipientAddresses,
                                      isNumber: true,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start),
                                  const Divider(
                                      color: MyColors.transparentWhite_12,
                                      height: 1),
                                  InformationItemCard(
                                      label: t.estimated_fee,
                                      value: [
                                        viewModel.fee != null
                                            ? "${satoshiToBitcoinString(viewModel.fee!)} ${t.btc}"
                                            : ''
                                      ],
                                      isNumber: true),
                                  const Divider(
                                      color: MyColors.transparentWhite_12,
                                      height: 1),
                                  InformationItemCard(
                                      label: t.total_cost,
                                      value: [
                                        viewModel.totalAmount != null
                                            ? "${satoshiToBitcoinString(viewModel.totalAmount!)} ${t.btc}"
                                            : ''
                                      ],
                                      isNumber: true),
                                ],
                              ))),
                    ),
                    if (viewModel.isSendingToMyAddress) ...[
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
      Provider.of<UpbitConnectModel>(context, listen: false).bitcoinPriceKrw,
      Provider.of<NodeProvider>(context, listen: false),
      Provider.of<TransactionProvider>(context, listen: false),
    );
    WidgetsBinding.instance.addPostFrameCallback((duration) {
      _setOverlayLoading(true);

      try {
        _viewModel.setTxInfo();
      } catch (e) {
        vibrateMedium();
        showAlertDialog(
            context: context, content: t.alert.error_tx.not_parsed(error: e));
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
}
