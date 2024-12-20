import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/model/utxo.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/button/small_action_button.dart';
import 'package:coconut_wallet/widgets/label_value.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class UtxoDetailScreen extends StatefulWidget {
  final UTXO utxo;

  const UtxoDetailScreen({
    super.key,
    required this.utxo,
  });

  @override
  State<UtxoDetailScreen> createState() => _UtxoDetailScreenState();
}

class _UtxoDetailScreenState extends State<UtxoDetailScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: MyColors.black,
        appBar: CustomAppBar.build(
          title: '',
          context: context,
          hasRightIcon: false,
          isBottom: true,
        ),
        body: SafeArea(
            child: SingleChildScrollView(
                child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(children: [
                      Center(
                          child: RichText(
                              text: TextSpan(
                                  text: satoshiToBitcoinString(
                                      widget.utxo.amount),
                                  style: Styles.h1Number,
                                  children: const <TextSpan>[
                            TextSpan(text: ' BTC', style: Styles.unit)
                          ]))),
                      Center(
                          child: Selector<UpbitConnectModel, int?>(
                        selector: (context, model) => model.bitcoinPriceKrw,
                        builder: (context, bitcoinPriceKrw, child) {
                          return Text(
                            bitcoinPriceKrw != null
                                ? '₩ ${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(widget.utxo.amount, bitcoinPriceKrw).toDouble())}'
                                : '',
                            style: Styles.balance2,
                          );
                        },
                      )),
                      const SizedBox(height: 20),
                      InfoRow(
                          label: '블록 번호',
                          value: Text(
                            widget.utxo.blockHeight,
                            style: Styles.body1Number,
                          )),
                      _divider,
                      InfoRow(
                          label: '일시',
                          value: Text(
                            DateTimeUtil.formatDatetime(widget.utxo.timestamp),
                            style: Styles.body1Number,
                          )),
                      _divider,
                      InfoRow(
                          label: '보유 주소',
                          subLabel: widget.utxo.derivationPath,
                          value: Text(
                            widget.utxo.to,
                            style: Styles.body1Number,
                          )),
                      _divider,
                      InfoRow(
                          label: '트랜잭션 ID',
                          value: Text(
                            widget.utxo.txHash,
                            style: Styles.body1Number,
                          )),
                      _divider,
                      const SizedBox(
                        height: 40,
                      ),
                      SmallActionButton(
                        text: '멤풀에서 보기',
                        borderRadius: BorderRadius.circular(12),
                        backgroundColor: MyColors.transparentWhite_20,
                        onPressed: () {
                          Logger.log(widget.utxo.to);
                          launchUrl(Uri.parse(
                              "${PowWalletApp.kMempoolHost}/address/${widget.utxo.to}"));
                        },
                        textStyle: const TextStyle(
                            color: MyColors.white, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(
                        height: 40,
                      ),
                    ])))));
  }
}

const _divider = Divider(color: MyColors.transparentWhite_15);

class InfoRow extends StatelessWidget {
  final String label;
  final Widget value;
  final String? subLabel;

  const InfoRow(
      {super.key, required this.label, required this.value, this.subLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Label(text: label),
            if (subLabel != null)
              Expanded(
                  child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(subLabel!,
                          style: Styles.label.merge(TextStyle(
                              fontFamily: CustomFonts.number.getFontFamily)))))
          ]),
          const SizedBox(height: 8),
          value
        ],
      ),
    );
  }
}
