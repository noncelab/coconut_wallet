import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/model/send_info.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/alert_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/print_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/infomation_row_item.dart';
import 'package:provider/provider.dart';

class SendConfirmScreen extends StatefulWidget {
  final FullSendInfo sendInfo;
  final int id;

  const SendConfirmScreen(
      {super.key, required this.sendInfo, required this.id});

  @override
  State<SendConfirmScreen> createState() => _SendConfirmScreenState();
}

class _SendConfirmScreenState extends State<SendConfirmScreen> {
  late AppStateModel _model;
  late WalletBase _walletBase;
  @override
  void initState() {
    super.initState();
    _loadWalletInfo();
  }

  void _loadWalletInfo() {
    _model = Provider.of<AppStateModel>(context, listen: false);
    _walletBase = _model.getWalletById(widget.id).walletBase;
  }

  Future<String> generateUnsignedPsbt() async {
    var FullSendInfo(:satsPerVb, :address, :amount) = widget.sendInfo;
    String generatedTx;

    //TODO: SingleSignatureWallet
    final singlesigWallet = _walletBase as SingleSignatureWallet;

    if (widget.sendInfo.isMaxMode) {
      generatedTx =
          await singlesigWallet.generatePsbtWithMaximum(address, satsPerVb);
    } else {
      generatedTx = await singlesigWallet.generatePsbt(
          address, UnitUtil.bitcoinToSatoshi(amount), satsPerVb);
    }

    printLongString(">>>>>> psbt 생성");
    printLongString(generatedTx);
    return generatedTx;
  }

  @override
  Widget build(BuildContext context) {
    var FullSendInfo(
      :address,
      :amount,
      :estimatedFee,
    ) = widget.sendInfo;

    return Scaffold(
        backgroundColor: MyColors.black,
        appBar: CustomAppBar.buildWithNext(
            title: "입력 정보 확인",
            context: context,
            isActive: true,
            onNextPressed: () {
              context.loaderOverlay.show();
              generateUnsignedPsbt().then((value) {
                _model.txWaitingForSign = value;
                context.loaderOverlay.hide();
                Navigator.pushNamed(context, '/unsigned-transaction-qr',
                    arguments: {'id': widget.id});
              }).catchError((error) {
                context.loaderOverlay.hide();
                showAlertDialog(
                    context: context,
                    content: "트랜잭션 생성 실패 ${error.toString()}");
              });
            }),
        body: SafeArea(
          child: Column(children: [
            Container(
                margin: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text.rich(
                    TextSpan(
                        text: satoshiToBitcoinString(
                            UnitUtil.bitcoinToSatoshi(amount)),
                        children: const <TextSpan>[
                          TextSpan(text: ' BTC', style: Styles.unit)
                        ]),
                    style: Styles.balance1,
                  ),
                )),
            // fiatValue
            Selector<UpbitConnectModel, int?>(
              selector: (context, model) => model.bitcoinPriceKrw,
              builder: (context, bitcoinPriceKrw, child) {
                return Container(
                    margin: const EdgeInsets.only(bottom: 40),
                    child: Center(
                        child: Text(
                            bitcoinPriceKrw != null
                                ? '₩${addCommasToIntegerPart(amount * bitcoinPriceKrw)}'
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
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          InformationRowItem(
                              label: '보낼 주소', value: address, isNumber: true),
                          const Divider(
                              color: MyColors.transparentWhite_12, height: 1),
                          InformationRowItem(
                              label: '예상 수수료',
                              value: estimatedFee != null && estimatedFee != 0
                                  ? '${satoshiToBitcoinString(estimatedFee)} BTC'
                                  : '계산 실패',
                              isNumber: true),
                          const Divider(
                              color: MyColors.transparentWhite_12, height: 1),
                          InformationRowItem(
                              label: '총 소요 수량',
                              value: estimatedFee != null && estimatedFee != 0
                                  ? '${satoshiToBitcoinString(UnitUtil.bitcoinToSatoshi(amount) + estimatedFee)} BTC'
                                  : '계산 실패',
                              isNumber: true),
                        ],
                      ))),
            )
          ]),
        ));
  }
}
