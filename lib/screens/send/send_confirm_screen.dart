import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/view_model/send/send_confirm_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/alert_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/card/information_item_card.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

class SendConfirmScreen extends StatefulWidget {
  const SendConfirmScreen({super.key});

  @override
  State<SendConfirmScreen> createState() => _SendConfirmScreenState();
}

class _SendConfirmScreenState extends State<SendConfirmScreen> {
  late SendConfirmViewModel _viewModel;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<WalletProvider, UpbitConnectModel,
        SendConfirmViewModel>(
      create: (_) => _viewModel,
      update: (_, walletProvider, upbitConnectModel, viewModel) {
        if (upbitConnectModel.bitcoinPriceKrw != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            viewModel!
                .updateBitcoinPriceKrw(upbitConnectModel.bitcoinPriceKrw!);
          });
        }

        return viewModel!;
      },
      child: Consumer<SendConfirmViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
              backgroundColor: MyColors.black,
              appBar: CustomAppBar.buildWithNext(
                  title: t.send_confirm_screen.title,
                  context: context,
                  isActive: true,
                  onNextPressed: () {
                    context.loaderOverlay.show();
                    viewModel.generateUnsignedPsbt().then((value) {
                      viewModel.setTxWaitingForSign(value);
                      context.loaderOverlay.hide();
                      Navigator.pushNamed(context, '/unsigned-transaction-qr',
                          arguments: {'walletName': viewModel.walletName});
                    }).catchError((error) {
                      context.loaderOverlay.hide();
                      showAlertDialog(
                          context: context,
                          content: t.alert.error_tx
                              .not_created(error: error.toString()));
                    });
                  }),
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Column(children: [
                    Container(
                        margin: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text.rich(
                            TextSpan(
                                text: satoshiToBitcoinString(
                                    UnitUtil.bitcoinToSatoshi(
                                        viewModel.amount)),
                                children: <TextSpan>[
                                  TextSpan(
                                      text: ' ${t.btc}', style: Styles.unit)
                                ]),
                            style: Styles.balance1,
                          ),
                        )),
                    // fiatValue
                    Selector<SendConfirmViewModel, int?>(
                      selector: (context, model) => model.bitcoinPriceKrw,
                      builder: (context, bitcoinPriceKrw, child) {
                        return Container(
                            margin: const EdgeInsets.only(bottom: 40),
                            child: Center(
                                child: Text(
                                    bitcoinPriceKrw != null
                                        ? '${addCommasToIntegerPart(viewModel.amount * bitcoinPriceKrw)} ${CurrencyCode.KRW.code}'
                                        : '',
                                    style: Styles.balance2)));
                      },
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
                                      value: viewModel.addresses,
                                      isNumber: true),
                                  const Divider(
                                      color: MyColors.transparentWhite_12,
                                      height: 1),
                                  InformationItemCard(
                                      label: t.estimated_fee,
                                      value: [
                                        viewModel.estimatedFee != 0
                                            ? '${satoshiToBitcoinString(viewModel.estimatedFee)} ${t.btc}'
                                            : t.calculation_failed
                                      ],
                                      isNumber: true),
                                  const Divider(
                                      color: MyColors.transparentWhite_12,
                                      height: 1),
                                  InformationItemCard(
                                      label: t.total_cost,
                                      value: [
                                        viewModel.estimatedFee != 0
                                            ? '${satoshiToBitcoinString(viewModel.totalUsedAmount)} BTC'
                                            : t.calculation_failed
                                      ],
                                      isNumber: true),
                                ],
                              ))),
                    )
                  ]),
                ),
              ));
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _viewModel = SendConfirmViewModel(
        Provider.of<SendInfoProvider>(context, listen: false),
        Provider.of<WalletProvider>(context, listen: false),
        Provider.of<UpbitConnectModel>(context, listen: false).bitcoinPriceKrw);
  }
}
