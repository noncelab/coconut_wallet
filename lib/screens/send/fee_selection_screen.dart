import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/model/app/error/app_error.dart';
import 'package:coconut_wallet/model/app/send/fee_info.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/alert_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/card/send_fee_selection_item_card.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:coconut_wallet/widgets/tooltip/custom_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// [INFO] send_utxo_selection_screen에서 필요한 정보를 전달 받고, 선택된 결과만 반환하는 화면이어서 ConnectivityProvider와 UpbitConnectModel을 사용하지만, 별도 view_model을 추가하지 않았습니다.
class FeeSelectionScreen extends StatefulWidget {
  static const String selectedOptionField = 'selectedOption';
  static const String feeInfoField = 'feeInfo';

  final List<FeeInfoWithLevel> feeInfos;
  final int Function(int satsPerVb) estimateFee;
  final int? networkMinimumFeeRate;
  final TransactionFeeLevel? selectedFeeLevel; // null인 경우 직접 입력한 경우
  final FeeInfo? customFeeInfo; // feeRate을 직접 입력한 경우
  final bool isRecommendedFeeFetchSuccess;

  const FeeSelectionScreen(
      {super.key,
      required this.feeInfos,
      required this.estimateFee,
      required this.networkMinimumFeeRate,
      this.selectedFeeLevel,
      this.customFeeInfo,
      this.isRecommendedFeeFetchSuccess = true});

  @override
  State<FeeSelectionScreen> createState() => _FeeSelectionScreenState();
}

class _FeeSelectionScreenState extends State<FeeSelectionScreen> {
  static const int kMaxFeeLimit = 1000000;
  late int? _estimatedFee;
  bool? _isNetworkOn;
  int? _customSatsPerVb;
  int? _bitcoinPriceKrw;

  TransactionFeeLevel? _selectedFeeLevel;

  final TextEditingController _customFeeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Selector<ConnectivityProvider, bool?>(
        selector: (context, connectivityProvider) =>
            connectivityProvider.isNetworkOn,
        builder: (context, isNetworkOn, child) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _onChangedNetworkStatus(isNetworkOn);
          });
          return Scaffold(
              backgroundColor: MyColors.black,
              appBar: CustomAppBar.buildWithNext(
                  title: "수수료",
                  context: context,
                  isActive: (isNetworkOn ?? false) &&
                      _estimatedFee != null &&
                      _estimatedFee != 0 &&
                      _estimatedFee! < kMaxFeeLimit,
                  onBackPressed: () {
                    Navigator.pop(context);
                  },
                  nextButtonTitle: '완료',
                  onNextPressed: _onDone),
              body: SafeArea(
                  child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Fee 선택 현황
                    Center(
                        child: Column(children: [
                      const SizedBox(height: 32),
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: MyColors.transparentWhite_06,
                            border: Border.all(
                                color: MyColors.transparentWhite_12, width: 1)),
                        child: Text(
                            _selectedFeeLevel == null
                                ? '직접 입력'
                                : _selectedFeeLevel!.text,
                            style: Styles.caption),
                      ),
                      Text(
                          _estimatedFee != null
                              ? '${(satoshiToBitcoinString(_estimatedFee!))} BTC'
                              : '',
                          style: Styles.fee),
                      Selector<UpbitConnectModel, int?>(
                        selector: (context, model) => model.bitcoinPriceKrw,
                        builder: (context, bitcoinPriceKrw, child) {
                          _bitcoinPriceKrw = bitcoinPriceKrw;
                          return Text(
                              fiatValueInKrw != null
                                  ? '${addCommasToIntegerPart(fiatValueInKrw!)} ${CurrencyCode.KRW.code}'
                                  : '',
                              style: Styles.balance2);
                        },
                      ),
                      const SizedBox(height: 32),
                    ])),

                    if (_isNetworkOn == false)
                      CustomTooltip(
                          richText: RichText(
                              text: TextSpan(
                                  text: ErrorCodes.networkError.message)),
                          showIcon: true,
                          type: TooltipType.warning),
                    if (_isNetworkOn == true &&
                        widget.isRecommendedFeeFetchSuccess == false)
                      CustomTooltip(
                          richText: RichText(
                              text: const TextSpan(
                                  text: '추천 수수료를 조회하지 못했어요. 수수료를 직접 입력해 주세요.')),
                          showIcon: true,
                          type: TooltipType.error),
                    if (_estimatedFee != null && _estimatedFee! >= kMaxFeeLimit)
                      CustomTooltip(
                          richText: RichText(
                              text: TextSpan(
                                  text:
                                      '설정하신 수수료가 ${UnitUtil.satoshiToBitcoin(kMaxFeeLimit)}BTC 이상이에요.')),
                          showIcon: true,
                          type: TooltipType.warning),

                    Padding(
                        padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                        child: Column(
                          children: [
                            ...List.generate(
                                3,
                                (index) => FeeSelectionItemCard(
                                    feeInfo: widget.feeInfos[index],
                                    isSelected: _selectedFeeLevel ==
                                        widget.feeInfos[index].level,
                                    bitcoinPriceKrw: _bitcoinPriceKrw,
                                    onPressed: () {
                                      setState(() {
                                        _selectedFeeLevel =
                                            widget.feeInfos[index].level;
                                        _estimatedFee =
                                            widget.feeInfos[index].estimatedFee;
                                        _customSatsPerVb = null;

                                        debugPrint(
                                            'selectedFeeLevel : ${widget.selectedFeeLevel}');
                                      });
                                    })),
                            CustomUnderlinedButton(
                              padding: Paddings.widgetContainer,
                              onTap: () {
                                showTextFieldDialog(
                                  context: context,
                                  content: '수수료를 자연수로 입력해 주세요.',
                                  controller: _customFeeController,
                                  textInputType: TextInputType.number,
                                  onPressed: _onCustomFeeRateInput,
                                );
                              },
                              text: '직접 입력하기',
                              fontSize: 14,
                              lineHeight: 21,
                              defaultColor: _selectedFeeLevel == null
                                  ? MyColors.white
                                  : MyColors.transparentWhite_70,
                            ),
                          ],
                        )),
                  ],
                ),
              )));
        });
  }

  @override
  void initState() {
    super.initState();
    _selectedFeeLevel = widget.selectedFeeLevel;
    if (_selectedFeeLevel == null && widget.customFeeInfo != null) {
      _estimatedFee = widget.customFeeInfo!.estimatedFee ?? 0;
      _customSatsPerVb = widget.customFeeInfo!.satsPerVb;
    } else if (_selectedFeeLevel != null && widget.customFeeInfo == null) {
      _estimatedFee =
          _findFeeInfoWithLevel(_selectedFeeLevel!).estimatedFee ?? 0;
    }
  }

  FeeInfoWithLevel _findFeeInfoWithLevel(
      TransactionFeeLevel transactionFeeLevel) {
    return widget.feeInfos
        .firstWhere((feeInfo) => feeInfo.level == transactionFeeLevel);
  }

  double? get fiatValueInKrw {
    if (_estimatedFee != null && _bitcoinPriceKrw != null) {
      return FiatUtil.calculateFiatAmount(_estimatedFee!, _bitcoinPriceKrw!)
          .toDouble();
    }

    return null;
  }

  Future<void> _onChangedNetworkStatus(bool? isNetworkOn) async {
    debugPrint('isNetworkOn = $isNetworkOn _isNetworkOn = $_isNetworkOn');

    if (_isNetworkOn == isNetworkOn) return; // 네트워크 상태가 기존과 같으면 할 일이 없음

    setState(() {
      _isNetworkOn = isNetworkOn;
    });
  }

  void _onCustomFeeRateInput() async {
    if (_customFeeController.text.isEmpty) {
      return;
    }

    int customSatsPerVb = int.parse(_customFeeController.text);
    if (widget.networkMinimumFeeRate != null &&
        customSatsPerVb < widget.networkMinimumFeeRate!) {
      CustomToast.showToast(
          context: context,
          text: "현재 최소 수수료는 ${widget.networkMinimumFeeRate} sats/vb 입니다.");
      _customFeeController.clear();
      return null;
    }

    try {
      int result = widget.estimateFee(customSatsPerVb);
      _customSatsPerVb = customSatsPerVb;
      if (mounted) {
        setState(() {
          _estimatedFee = result;
          _selectedFeeLevel = null;
        });
      }
    } catch (e) {
      CustomToast.showWarningToast(
          context: context,
          text: ErrorCodes.withMessage(
                  ErrorCodes.feeEstimationError, e.toString())
              .message);
    } finally {
      _customFeeController.clear();
    }
  }

  void _onDone() {
    Map<String, dynamic> returnData = {
      FeeSelectionScreen.selectedOptionField: _selectedFeeLevel,
      FeeSelectionScreen.feeInfoField:
          (_selectedFeeLevel == null && _customSatsPerVb != null)
              ? FeeInfo(
                  estimatedFee: _estimatedFee,
                  fiatValue: fiatValueInKrw?.toInt(),
                  satsPerVb: _customSatsPerVb)
              : _findFeeInfoWithLevel(_selectedFeeLevel!),
    };

    Navigator.pop(context, returnData);
  }
}
