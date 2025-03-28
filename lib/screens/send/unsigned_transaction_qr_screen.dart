import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/animated_qr/animated_qr_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/animated_qr_view.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/tooltip/custom_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UnsignedTransactionQrScreen extends StatefulWidget {
  final String walletName;

  const UnsignedTransactionQrScreen({super.key, required this.walletName});

  @override
  State<UnsignedTransactionQrScreen> createState() =>
      _UnsignedTransactionQrScreenState();
}

class _UnsignedTransactionQrScreenState
    extends State<UnsignedTransactionQrScreen> {
  late final String _psbtBase64;
  late final bool _isMultisig;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      backgroundColor: MyColors.black,
      appBar: CustomAppBar.buildWithNext(
          title: t.send,
          context: context,
          onNextPressed: () {
            Navigator.pushNamed(context, '/signed-psbt-scanner');
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
                CustomTooltip(
                    backgroundColor: MyColors.white.withOpacity(0.9),
                    richText: RichText(
                      text: TextSpan(
                        text: '[1] ',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          height: 1.4,
                          letterSpacing: 0.5,
                          color: MyColors.black,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text: t.tooltip.unsigned_tx_qr.in_vault,
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          TextSpan(
                            text:
                                ' ${t.tooltip.unsigned_tx_qr.select_wallet(name: widget.walletName)} '
                                '\'${_isMultisig ? t.sign_multisig : t.sign}\'',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(
                            text: t.tooltip.unsigned_tx_qr.scan_qr_below,
                            style: const TextStyle(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    showIcon: true,
                    type: TooltipType.info),
                Container(
                    margin: const EdgeInsets.only(top: 40),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: MyColors.white,
                        borderRadius: BorderRadius.circular(8)),
                    child: AnimatedQrView(
                      data: AnimatedQRDataHandler.splitData(_psbtBase64),
                      size: MediaQuery.of(context).size.width * 0.8,
                    )),
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
    final sendInfoProvider =
        Provider.of<SendInfoProvider>(context, listen: false);
    _psbtBase64 = sendInfoProvider.txWaitingForSign!;
    debugPrint(
        'txWaitingForSign = ${sendInfoProvider.txWaitingForSign!.length}');
    debugPrint('txWaitingForSign = ${sendInfoProvider.txWaitingForSign}');
    _isMultisig = sendInfoProvider.isMultisig!;
  }
}
