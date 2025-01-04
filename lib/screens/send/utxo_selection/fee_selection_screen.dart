import 'package:coconut_wallet/model/app_error.dart';
import 'package:coconut_wallet/model/enums.dart';
import 'package:coconut_wallet/model/fee_info.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/screens/send/send_fee_selection_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/alert_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/custom_tooltip.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FeeSelectionScreen extends StatefulWidget {
  final List<FeeInfoWithLevel> feeInfos;
  final Future<int?> Function(
          String satsPerVb, TextEditingController customFeeController)
      onCustomSelected;
  final TransactionFeeLevel? selectedFeeLevel; // null인 경우 직접 입력한 경우
  final int? estimatedFeeOfCustomFeeRate; // feeRate을 직접 입력한 경우의 예상 수수료
  final bool isRecommendedFeeFetchSuccess;

  const FeeSelectionScreen(
      {super.key,
      required this.feeInfos,
      required this.onCustomSelected,
      this.selectedFeeLevel,
      this.estimatedFeeOfCustomFeeRate,
      this.isRecommendedFeeFetchSuccess = true});

  @override
  State<FeeSelectionScreen> createState() => _FeeSelectionScreenState();
}

class _FeeSelectionScreenState extends State<FeeSelectionScreen> {
  String? _selectedOption = TransactionFeeLevel.halfhour.text;
  int? _estimatedFee = 0;
  int? _fiatValue = 0;
  bool? _isNetworkOn;

  TransactionFeeLevel? _selectedFeeLevel;

  final TextEditingController _customFeeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedFeeLevel = widget.selectedFeeLevel;
    if (_selectedFeeLevel == null &&
        widget.estimatedFeeOfCustomFeeRate != null) {
      _estimatedFee = widget.estimatedFeeOfCustomFeeRate;
      _selectedOption = '직접 입력';
    } else if (_selectedFeeLevel != null) {
      _estimatedFee = getEstimatedFeeByLevel(_selectedFeeLevel!);
      _selectedOption = getSelectedOptionTextByLevel(_selectedFeeLevel!);
    }
  }

  int getEstimatedFeeByLevel(TransactionFeeLevel transactionFeeLevel) {
    int index;
    if (transactionFeeLevel == TransactionFeeLevel.fastest) {
      index = 0;
    } else if (transactionFeeLevel == TransactionFeeLevel.halfhour) {
      index = 1;
    } else {
      index = 2;
    }

    return widget.feeInfos[index].estimatedFee ?? 0;
  }

  String getSelectedOptionTextByLevel(TransactionFeeLevel transactionFeeLevel) {
    int index;
    if (transactionFeeLevel == TransactionFeeLevel.fastest) {
      index = 0;
    } else if (transactionFeeLevel == TransactionFeeLevel.halfhour) {
      index = 1;
    } else {
      index = 2;
    }

    return widget.feeInfos[index].level.text;
  }

  Future<void> onChangedNetworkStatus(bool? isNetworkOn) async {
    debugPrint('isNetworkOn = $isNetworkOn _isNetworkOn = $_isNetworkOn');

    if (_isNetworkOn == isNetworkOn) return; // 네트워크 상태가 기존과 같으면 할 일이 없음

    setState(() {
      _isNetworkOn = isNetworkOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Selector<AppStateModel, bool?>(
        selector: (context, model) => model.isNetworkOn,
        builder: (context, isNetworkOn, child) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onChangedNetworkStatus(isNetworkOn);
          });
          return Scaffold(
            backgroundColor: MyColors.black,
            appBar: CustomAppBar.buildWithNext(
                title: "수수료",
                context: context,
                isActive: (isNetworkOn ?? false) &&
                    _estimatedFee != null &&
                    _estimatedFee != 0,
                onBackPressed: () {
                  Navigator.pop(context);
                },
                nextButtonTitle: '완료',
                onNextPressed: () {
                  Map<String, dynamic> returnData = {
                    'selectedFeeLevel': _selectedFeeLevel,
                    'estimatedFee': _estimatedFee,
                  };
                  Navigator.pop(context, returnData);
                }),
            body: Consumer<AppStateModel>(
              builder: (context, state, child) {
                return SafeArea(
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
                                  color: MyColors.transparentWhite_12,
                                  width: 1)),
                          child: Text(_selectedOption ?? "",
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
                            return Text(
                                _fiatValue != null && bitcoinPriceKrw != null
                                    ? '₩${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(_estimatedFee!, bitcoinPriceKrw).toDouble())}'
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
                                    text:
                                        '추천 수수료를 조회하지 못했어요. 수수료를 직접 입력해 주세요.')),
                            showIcon: true,
                            type: TooltipType.error),

                      Padding(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                          child: Column(
                            children: [
                              ...List.generate(
                                  3,
                                  (index) => FeeSelectionItem(
                                      feeInfo: widget.feeInfos[index],
                                      isSelected: _selectedFeeLevel == null
                                          ? false
                                          : _selectedFeeLevel ==
                                              widget.feeInfos[index].level,
                                      onPressed: () {
                                        setState(() {
                                          _selectedFeeLevel =
                                              widget.feeInfos[index].level;
                                          _selectedOption =
                                              widget.feeInfos[index].level.text;
                                          _estimatedFee = widget
                                              .feeInfos[index].estimatedFee;
                                          _fiatValue =
                                              widget.feeInfos[index].fiatValue;

                                          debugPrint(
                                              'selectedFeeLevel : ${widget.selectedFeeLevel}');
                                        });
                                      })),
                              CupertinoButton(
                                padding: Paddings.widgetContainer,
                                onPressed: () {
                                  showTextFieldDialog(
                                    context: context,
                                    content: '수수료를 자연수로 입력해 주세요.',
                                    controller: _customFeeController,
                                    textInputType: TextInputType.number,
                                    onPressed: () async {
                                      ///TODO: TEST
                                      int? result =
                                          await widget.onCustomSelected(
                                        _customFeeController.text,
                                        _customFeeController,
                                      );
                                      if (result != null && mounted) {
                                        setState(() {
                                          _estimatedFee = result;
                                          _selectedOption = '직접 입력';
                                          _selectedFeeLevel = null;
                                        });
                                      }
                                    },
                                  );
                                },
                                child: Text(
                                  "직접 입력",
                                  style: _selectedFeeLevel == null
                                      ? Styles.body2
                                      : Styles.body2.merge(const TextStyle(
                                          color: MyColors.transparentWhite_70)),
                                ),
                              ),
                            ],
                          )),
                    ],
                  ),
                ));
              },
            ),
          );
        });
  }
}
