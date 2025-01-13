import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:coconut_wallet/model/app/error/app_error.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/alert_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:coconut_wallet/widgets/infomation_row_item.dart';
import 'package:provider/provider.dart';

class BroadcastingScreen extends StatefulWidget {
  final int id;

  const BroadcastingScreen({super.key, required this.id});

  @override
  State<BroadcastingScreen> createState() => _BroadcastingScreenState();
}

class _BroadcastingScreenState extends State<BroadcastingScreen> {
  String? _address;
  int? _amount;
  int? _fee;
  int? _totalAmount;
  late final AppStateModel _model;
  late WalletBase _walletBase;
  bool _initDone = false;
  bool _isValidSignedTransaction = false;
  int? _sendingAmountWhenAddressIsMyChange; // 내 지갑의 change address로 보내는 경우 잔액
  bool _isSendingToMyAddress = false;
  List<int> outputIndexesToMyAddress = [];

  @override
  void initState() {
    super.initState();
    _model = Provider.of<AppStateModel>(context, listen: false);

    if (_model.signedTransaction == null) {
      throw "[broadcasting_screen] _model.signedTransaction is null";
    }
    if (_model.txWaitingForSign == null) {
      throw "[broadcasting_screen] _model.txWaitingForSign is null";
    }

    final walletBaseItem = _model.getWalletById(widget.id);
    _walletBase = walletBaseItem.walletBase;

    WidgetsBinding.instance.addPostFrameCallback((duration) {
      setOverlayLoading(true);
      setTxInfo();
      setOverlayLoading(false);
    });
  }

  void setTxInfo() async {
    try {
      PSBT signedPsbt = PSBT.parse(_model.signedTransaction!);
      // print("!!! -> ${_model.signedTransaction!}");
      List<PsbtOutput> outputs = signedPsbt.outputs;

      // case1. 다른 사람에게 보내고(B1) 잔액이 있는 경우(A2)
      // case2. 다른 사람에게 보내고(B1) 잔액이 없는 경우
      // case3. 내 지갑의 다른 주소로 보내고(A2) 잔액이 있는 경우(A3)
      // case4. 내 지갑의 다른 주소로 보내고(A2) 잔액이 없는 경우
      // 만약 실수로 내 지갑의 change address로 보내는 경우에는 sendingAmount가 0
      List<PsbtOutput> outputToMyReceivingAddress = [];
      List<PsbtOutput> outputToMyChangeAddress = [];
      List<PsbtOutput> outputsToOther = [];
      for (int i = 0; i < outputs.length; i++) {
        if (outputs[i].derivationPath == null) {
          outputsToOther.add(outputs[i]);
        } else if (outputs[i].isChange) {
          outputToMyChangeAddress.add(outputs[i]);
          outputIndexesToMyAddress.add(i);
        } else {
          outputToMyReceivingAddress.add(outputs[i]);
          outputIndexesToMyAddress.add(i);
        }
      }

      PsbtOutput? output;
      if (outputsToOther.isNotEmpty) {
        setState(() {
          output = outputsToOther[0];
        });
      } else if (outputToMyReceivingAddress.isNotEmpty) {
        setState(() {
          output = outputToMyReceivingAddress[0];
          _isSendingToMyAddress = true;
        });
      } else if (outputToMyChangeAddress.isNotEmpty) {
        // 받는 주소에 내 지갑의 change address를 입력한 경우
        // 원래 이 경우 output.sendingAmount = 0, 보낼 주소가 표기되지 않았었지만, 버그처럼 보이는 문제 때문에 대응합니다.
        // (주의!!) coconut_lib에서 output 배열에 sendingOutput을 먼저 담으므로 항상 첫번째 것을 사용하면 전액 보내기일 때와 아닐 때 모두 커버 됨
        // 하지만 coconut_lib에 종속적이므로 coconut_lib에 변경 발생 시 대응 필요
        setState(() {
          output = outputToMyChangeAddress[0];
          _sendingAmountWhenAddressIsMyChange = output!.amount;
          _isSendingToMyAddress = true;
        });
      }

      setState(() {
        _address = output?.getAddress() ?? '';
        _amount = signedPsbt.sendingAmount;

        _fee = signedPsbt.fee;
        _initDone = true;
        _totalAmount = signedPsbt.sendingAmount + signedPsbt.fee;

        _isValidSignedTransaction = true;
      });
    } catch (e) {
      vibrateMedium();
      showAlertDialog(context: context, content: "트랜잭션 파싱 실패: $e");
    }
  }

  void broadcast() async {
    setOverlayLoading(true);
    PSBT psbt = PSBT.parse(_model.signedTransaction!);
    Transaction signedTx = psbt.getSignedTransaction(_walletBase.addressType);

    try {
      Result<String, CoconutError> result = await _model.broadcast(signedTx);

      setOverlayLoading(false);

      if (result.isFailure) {
        vibrateMedium();
        showAlertDialog(
            context: context, content: "전송 실패\n${result.error?.message}");
        return;
      }

      if (result.isSuccess) {
        vibrateLight();
        _model.clearAllRelatedSending();
        List<String> newUtxoIds = _model.tagsMoveAllowed
            ? outputIndexesToMyAddress
                .map((index) => makeUtxoId(signedTx.transactionHash, index))
                .toList()
            : [];
        await _model.updateTagsOfUsedUtxos(widget.id, newUtxoIds);

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/broadcasting-complete', // 이동할 경로
          ModalRoute.withName('/wallet-detail'), // '/home' 경로를 남기고 그 외의 경로 제거
          arguments: {
            'id': widget.id,
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
      showAlertDialog(context: context, content: message);
      vibrateMedium();
    }
  }

  void setOverlayLoading(bool value) {
    if (value) {
      context.loaderOverlay.show();
    } else {
      context.loaderOverlay.hide();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      backgroundColor: MyColors.black,
      appBar: CustomAppBar.buildWithNext(
          title: '최종 확인',
          context: context,
          isActive: _isValidSignedTransaction,
          onNextPressed: () {
            if (_model.isNetworkOn == false) {
              CustomToast.showWarningToast(
                  context: context, text: ErrorCodes.networkError.message);
              return;
            }

            if (_initDone) {
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
                            text: _amount != null
                                ? satoshiToBitcoinString(
                                    _sendingAmountWhenAddressIsMyChange != null
                                        ? _sendingAmountWhenAddressIsMyChange!
                                        : _amount!)
                                : "",
                            children: const <TextSpan>[
                              TextSpan(text: ' BTC', style: Styles.unit)
                            ]),
                        style: Styles.balance1,
                      ),
                    )),
                Selector<UpbitConnectModel, int?>(
                  selector: (context, model) => model.bitcoinPriceKrw,
                  builder: (context, bitcoinPriceKrw, child) {
                    if (bitcoinPriceKrw != null && _amount != null) {
                      String bitcoinPriceKrwString = addCommasToIntegerPart(
                          FiatUtil.calculateFiatAmount(
                                  _sendingAmountWhenAddressIsMyChange != null
                                      ? _sendingAmountWhenAddressIsMyChange!
                                      : _amount!,
                                  bitcoinPriceKrw)
                              .toDouble());
                      return Text(
                          "$bitcoinPriceKrwString ${CurrencyCode.KRW.code}",
                          style: Styles.label.merge(TextStyle(
                              fontFamily: CustomFonts.number.getFontFamily)));
                    } else {
                      return Container();
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
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              InformationRowItem(
                                  label: '보낼 주소',
                                  value: _address ?? "",
                                  isNumber: true),
                              const Divider(
                                  color: MyColors.transparentWhite_12,
                                  height: 1),
                              InformationRowItem(
                                  label: '예상 수수료',
                                  value: _fee != null
                                      ? "${satoshiToBitcoinString(_fee!)} BTC"
                                      : '',
                                  isNumber: true),
                              const Divider(
                                  color: MyColors.transparentWhite_12,
                                  height: 1),
                              InformationRowItem(
                                  label: '총 소요 수량',
                                  value: _totalAmount != null
                                      ? "${satoshiToBitcoinString(_totalAmount!)} BTC"
                                      : '',
                                  isNumber: true),
                            ],
                          ))),
                ),
                if (_isSendingToMyAddress) ...[
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
    );
  }
}
