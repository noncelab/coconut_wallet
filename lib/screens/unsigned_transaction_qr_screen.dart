import 'package:coconut_wallet/widgets/animatedQR/animated_qr_data_handler.dart';
import 'package:coconut_wallet/widgets/animatedQR/animated_qr_view.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/custom_tooltip.dart';
import 'package:provider/provider.dart';

class UnsignedTransactionQrScreen extends StatefulWidget {
  final int id;

  const UnsignedTransactionQrScreen({super.key, required this.id});

  @override
  State<UnsignedTransactionQrScreen> createState() =>
      _UnsignedTransactionQrScreenState();
}

class _UnsignedTransactionQrScreenState
    extends State<UnsignedTransactionQrScreen> {
  late final String _psbtBase64;
  late String _name;

  @override
  void initState() {
    super.initState();
    final model = Provider.of<AppStateModel>(context, listen: false);
    if (model.txWaitingForSign == null) {
      throw "[unsigned_transaction_qr_screen] model.txWaitingForSign is null";
    }
    _psbtBase64 = model.txWaitingForSign!;

    _name = model.getWalletById(widget.id).name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      backgroundColor: MyColors.black,
      appBar: CustomAppBar.buildWithNext(
          title: '보내기',
          context: context,
          onNextPressed: () {
            Navigator.pushNamed(context, '/signed-psbt-scanner',
                arguments: {'id': widget.id});
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
                        text: '[1]',
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          height: 1.4,
                          letterSpacing: 0.5,
                          color: MyColors.black,
                        ),
                        children: <TextSpan>[
                          const TextSpan(
                            text: ' 볼트에서',
                            style: TextStyle(
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          TextSpan(
                            text: ' $_name 선택, \'서명하기\'',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(
                            text: '로 이동하여 아래 QR 코드를 스캔해 주세요.',
                            style: TextStyle(
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
}
