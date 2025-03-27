import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/send/fee_info.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/view_model/send/send_fee_selection_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/common/text_field_bottom_sheet.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/alert_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/card/send_fee_selection_item_card.dart';
import 'package:coconut_wallet/widgets/overlays/custom_toast.dart';
import 'package:coconut_wallet/widgets/tooltip/custom_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

class SendFeeSelectionScreen extends StatefulWidget {
  const SendFeeSelectionScreen({
    super.key,
  });

  @override
  State<SendFeeSelectionScreen> createState() => _SendFeeSelectionScreenState();
}

class _SendFeeSelectionScreenState extends State<SendFeeSelectionScreen> {
  static const maxFeeLimit =
      1000000; // sats, 사용자가 실수로 너무 큰 금액을 수수료로 지불하지 않도록 지정했습니다.
  final networkOffMessage = t.alert.error_send.poor_network;
  final TextEditingController _customFeeController = TextEditingController();
  List<FeeInfoWithLevel> feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];
  int? _minimumSatsPerVb;
  TransactionFeeLevel _selectedLevel = TransactionFeeLevel.halfhour;
  bool _customSelected = false;
  String? _selectedFeeLevel = TransactionFeeLevel.halfhour.text;
  int? _estimatedFee = 0;
  int? _fiatValue = 0;
  FeeInfo? _customFeeInfo;
  bool? _isRecommendedFeeFetchSuccess;
  late SendFeeSelectionViewModel _viewModel;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider3<ConnectivityProvider, WalletProvider,
            UpbitConnectModel, SendFeeSelectionViewModel>(
        create: (_) => _viewModel,
        update: (_, connectivityProvider, walletProvider, upbitConnectModel,
            viewModel) {
          if (viewModel!.isNetworkOn != connectivityProvider.isNetworkOn) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              viewModel.setIsNetworkOn(connectivityProvider.isNetworkOn);
            });
          }
          if (upbitConnectModel.bitcoinPriceKrw != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              viewModel.setBitcoinPriceKrw(upbitConnectModel.bitcoinPriceKrw!);
            });
          }

          return viewModel;
        },
        child: Consumer<SendFeeSelectionViewModel>(
          builder: (context, viewModel, child) {
            if (!viewModel.isNetworkOn) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showAlertAndGoHome(networkOffMessage);
              });
            }

            return Scaffold(
                backgroundColor: MyColors.black,
                appBar: CustomAppBar.buildWithNext(
                    title: t.fee,
                    context: context,
                    isActive: _canGoNext(),
                    onBackPressed: () {
                      Navigator.pop(context);
                    },
                    nextButtonTitle: t.complete,
                    onNextPressed: () {
                      if (_viewModel.isNetworkOn != true) {
                        CustomToast.showWarningToast(
                            context: context,
                            text: ErrorCodes.networkError.message);
                        return;
                      }

                      int satsPerVb = _customSelected
                          ? _customFeeInfo!.satsPerVb!
                          : feeInfos
                              .firstWhere(
                                  (element) => element.level == _selectedLevel)
                              .satsPerVb!;

                      _viewModel.saveFinalSendInfo(_estimatedFee!, satsPerVb);
                      Navigator.pushNamed(context, '/send-confirm');
                    }),
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
                                  color: MyColors.transparentWhite_12,
                                  width: 1)),
                          child: Text(_selectedFeeLevel ?? "",
                              style: Styles.caption),
                        ),
                        Text(
                            _estimatedFee != null
                                ? '${(satoshiToBitcoinString(_estimatedFee!))} ${t.btc}'
                                : '',
                            style: Styles.fee),
                        Selector<UpbitConnectModel, int?>(
                          selector: (context, model) => model.bitcoinPriceKrw,
                          builder: (context, bitcoinPriceKrw, child) {
                            return Text(
                                _fiatValue != null && bitcoinPriceKrw != null
                                    ? '${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(_estimatedFee!, bitcoinPriceKrw).toDouble())} ${CurrencyCode.KRW.code}'
                                    : '',
                                style: Styles.balance2);
                          },
                        ),
                        const SizedBox(height: 32),
                      ])),

                      if (viewModel.isNetworkOn == false)
                        CustomTooltip(
                            richText: RichText(
                                text: TextSpan(
                                    text: ErrorCodes.networkError.message)),
                            showIcon: true,
                            type: TooltipType.warning),
                      if (viewModel.isNetworkOn == true &&
                          _isRecommendedFeeFetchSuccess == false)
                        CustomTooltip(
                            richText: RichText(
                                text:
                                    TextSpan(text: t.tooltip.recommended_fee1)),
                            showIcon: true,
                            type: TooltipType.error),
                      if (_estimatedFee != null &&
                          _estimatedFee! >= maxFeeLimit)
                        CustomTooltip(
                            richText: RichText(
                                text: TextSpan(
                                    text: t.tooltip.recommended_fee2(
                                        bitcoin: UnitUtil.satoshiToBitcoin(
                                            maxFeeLimit)))),
                            showIcon: true,
                            type: TooltipType.warning),
                      if (_estimatedFee != null &&
                          _estimatedFee! != 0 &&
                          !_viewModel.isBalanceEnough(_estimatedFee) &&
                          _estimatedFee! < maxFeeLimit)
                        CustomTooltip(
                            richText: RichText(
                                text: TextSpan(
                                    text: t.errors.insufficient_balance)),
                            showIcon: true,
                            type: TooltipType.warning),
                      Padding(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                          child: Column(
                            children: [
                              ...List.generate(
                                  3,
                                  (index) => FeeSelectionItemCard(
                                      feeInfo: feeInfos[index],
                                      isSelected: _customSelected
                                          ? false
                                          : _selectedLevel ==
                                              feeInfos[index].level,
                                      bitcoinPriceKrw:
                                          viewModel.bitcoinPriceKrw,
                                      onPressed: () {
                                        setState(() {
                                          _selectedLevel =
                                              feeInfos[index].level;
                                          _selectedFeeLevel =
                                              feeInfos[index].level.text;
                                          _estimatedFee =
                                              feeInfos[index].estimatedFee;
                                          _fiatValue =
                                              feeInfos[index].fiatValue;
                                          _customSelected = false;
                                        });
                                      })),
                              CustomUnderlinedButton(
                                padding: Paddings.widgetContainer,
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    builder: (context) => TextFieldBottomSheet(
                                      title: t.input_directly,
                                      placeholder: t.text_field
                                          .enter_fee_as_natural_number,
                                      onComplete: (text) {
                                        _handleCustomFeeInput(text);
                                      },
                                      keyboardType: TextInputType.number,
                                      visibleTextLimit: false,
                                    ),
                                  );
                                },
                                text: t.text_field.enter_fee_directly,
                                fontSize: 14,
                                lineHeight: 21,
                                defaultColor: _customSelected
                                    ? MyColors.white
                                    : MyColors.transparentWhite_70,
                              ),
                            ],
                          )),
                    ],
                  ),
                )));
          },
        ));
  }

  @override
  void initState() {
    super.initState();
    _viewModel = SendFeeSelectionViewModel(
        Provider.of<SendInfoProvider>(context, listen: false),
        Provider.of<WalletProvider>(context, listen: false),
        Provider.of<NodeProvider>(context, listen: false),
        Provider.of<UpbitConnectModel>(context, listen: false).bitcoinPriceKrw,
        Provider.of<ConnectivityProvider>(context, listen: false).isNetworkOn);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_viewModel.isNetworkOn) {
        _startToSetRecommendedFee();
      } else {
        _showAlertAndGoHome(networkOffMessage);
        return;
      }

      // TODO:
      //_model.recordUsedUtxoIdListWhenSend([]);
    });
  }

  bool _canGoNext() {
    int? satsPerVb = _customSelected
        ? _customFeeInfo?.satsPerVb
        : feeInfos
            .firstWhere((element) => element.level == _selectedLevel)
            .satsPerVb;

    return _viewModel.isNetworkOn &&
        (satsPerVb != null && satsPerVb > 0) &&
        _viewModel.isBalanceEnough(_estimatedFee) &&
        _estimatedFee != null &&
        _estimatedFee! < maxFeeLimit;
  }

  void _handleCustomFeeInput(String input) async {
    if (input.isEmpty) {
      return;
    }

    int customSatsPerVb;
    try {
      customSatsPerVb = int.parse(input.trim());
      if (_minimumSatsPerVb != null && customSatsPerVb < _minimumSatsPerVb!) {
        CustomToast.showToast(
            context: context,
            text: t.toast.min_fee(minimum: _minimumSatsPerVb!));
        _customFeeController.clear();
        return;
      }
    } catch (_) {
      _customFeeController.clear();
      return;
    }

    // 이미 입력했던 값이랑 동일한 값인 경우 재계산 하지 않음
    if (_customSelected == true &&
        _customFeeInfo != null &&
        _customFeeInfo?.satsPerVb != null &&
        _customFeeInfo?.satsPerVb! == customSatsPerVb) {
      return;
    }

    context.loaderOverlay.show();

    try {
      int estimatedFee = _viewModel.estimateFee(customSatsPerVb);

      setState(() {
        _customFeeInfo = FeeInfo(satsPerVb: customSatsPerVb);
        _setFeeInfo(_customFeeInfo!, estimatedFee);
      });
    } catch (error) {
      int? estimatedFee = _handleFeeEstimationError(error as Exception);
      if (estimatedFee != null) {
        setState(() {
          _customFeeInfo = FeeInfo(satsPerVb: customSatsPerVb);
          _setFeeInfo(_customFeeInfo!, estimatedFee);
        });
      } else {
        // custom 수수료 조회 실패 알림
        if (mounted) {
          CustomToast.showWarningToast(
              context: context,
              text: ErrorCodes.withMessage(
                      ErrorCodes.feeEstimationError, error.toString())
                  .message);
        }
      }
    }
    _customFeeController.clear();
    if (mounted) {
      context.loaderOverlay.hide();
    }
  }

  int? _handleFeeEstimationError(Exception e) {
    try {
      if (e.toString().contains("Insufficient amount. Estimated fee is")) {
        // get finalFee from error message : 'Insufficient amount. Estimated fee is $finalFee'
        var estimatedFee = int.parse(
            e.toString().split("Insufficient amount. Estimated fee is ")[1]);
        return estimatedFee;
      }

      if (e.toString().contains("Not enough amount for sending. (Fee")) {
        // get finalFee from error message : 'Not enough amount for sending. (Fee : $finalFee)'
        var estimatedFee = int.parse(e
            .toString()
            .split("Not enough amount for sending. (Fee : ")[1]
            .split(")")[0]);
        return estimatedFee;
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  void _setFeeInfo(FeeInfo feeInfo, int estimatedFee) {
    feeInfo.estimatedFee = estimatedFee;
    feeInfo.fiatValue = _viewModel.bitcoinPriceKrw != null
        ? FiatUtil.calculateFiatAmount(
            estimatedFee, _viewModel.bitcoinPriceKrw!)
        : null;

    if (feeInfo is FeeInfoWithLevel && feeInfo.level == _selectedLevel) {
      _estimatedFee = estimatedFee;
      _fiatValue = feeInfo.fiatValue;
      return;
    }

    if (feeInfo is! FeeInfoWithLevel) {
      _selectedFeeLevel = t.input_directly;
      _estimatedFee = estimatedFee;
      _fiatValue = _customFeeInfo?.fiatValue;
      _customSelected = true;
    }
  }

  Future<void> _setRecommendedFees() async {
    var result = await _viewModel.nodeprovider.getRecommendedFees();
    if (result.isFailure) {
      setState(() {
        _isRecommendedFeeFetchSuccess = false;
      });
      return;
    }

    final recommendedFees = result.value;

    feeInfos[0].satsPerVb = recommendedFees.fastestFee;
    feeInfos[1].satsPerVb = recommendedFees.halfHourFee;
    feeInfos[2].satsPerVb = recommendedFees.hourFee;

    setState(() => _minimumSatsPerVb = recommendedFees.minimumFee);

    for (var feeInfo in feeInfos) {
      try {
        int estimatedFee = _viewModel.estimateFee(feeInfo.satsPerVb!);
        setState(() {
          _setFeeInfo(feeInfo, estimatedFee);
        });
      } catch (error) {
        int? estimatedFee = _handleFeeEstimationError(error as Exception);
        if (estimatedFee != null) {
          setState(() {
            _setFeeInfo(feeInfo, estimatedFee);
          });
        } else {
          _isRecommendedFeeFetchSuccess = false;
          // custom 수수료 조회 실패 알림
          WidgetsBinding.instance.addPostFrameCallback((duration) {
            CustomToast.showWarningToast(
                context: context,
                text: ErrorCodes.withMessage(
                        ErrorCodes.feeEstimationError, error.toString())
                    .message);
          });
        }
      }
    }
  }

  void _showAlertAndGoHome(String message) {
    if (context.loaderOverlay.visible) {
      context.loaderOverlay.hide();
    }

    showAlertDialog(
        context: context,
        content: message,
        dismissible: false,
        onClosed: () {
          Navigator.of(context).pop(); // 다이얼로그 닫기

          // 약간의 지연 후 popUntil 호출
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/',
                (Route<dynamic> route) => false,
              );
            }
          });
        });
  }

  Future<void> _startToSetRecommendedFee() async {
    context.loaderOverlay.show();
    await _setRecommendedFees();
    if (mounted) {
      context.loaderOverlay.hide();
    }
  }
}
