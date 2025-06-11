import 'package:coconut_design_system/coconut_design_system.dart';
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
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/text_field_filter_util.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/card/send_fee_selection_item_card.dart';
import 'package:coconut_wallet/widgets/contents/fiat_price.dart';
import 'package:coconut_wallet/widgets/overlays/coconut_loading_overlay.dart';
import 'package:coconut_wallet/widgets/overlays/network_error_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SendFeeSelectionScreen extends StatefulWidget {
  const SendFeeSelectionScreen({
    super.key,
  });

  @override
  State<SendFeeSelectionScreen> createState() => _SendFeeSelectionScreenState();
}

class _SendFeeSelectionScreenState extends State<SendFeeSelectionScreen> {
  static const maxFeeLimit = 1000000; // sats, 사용자가 실수로 너무 큰 금액을 수수료로 지불하지 않도록 지정했습니다.
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
  FeeInfo? _customFeeInfo;
  bool? _isRecommendedFeeFetchSuccess;
  bool _isLoading = false;
  late SendFeeSelectionViewModel _viewModel;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider3<ConnectivityProvider, WalletProvider, UpbitConnectModel,
        SendFeeSelectionViewModel>(
      create: (_) => _viewModel,
      update: (_, connectivityProvider, walletProvider, upbitConnectModel, viewModel) {
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
          return Scaffold(
            backgroundColor: CoconutColors.black,
            appBar: CoconutAppBar.buildWithNext(
                title: t.fee,
                context: context,
                isActive: _canGoNext(),
                onBackPressed: () {
                  Navigator.pop(context);
                },
                usePrimaryActiveColor: true,
                nextButtonTitle: t.complete,
                onNextPressed: () {
                  double finalFeeRate = _customSelected
                      ? _customFeeInfo!.satsPerVb!
                      : feeInfos
                          .firstWhere((element) => element.level == _selectedLevel)
                          .satsPerVb!;

                  _viewModel.saveFinalSendInfo(_estimatedFee!, finalFeeRate);
                  Navigator.pushNamed(context, '/send-confirm');
                }),
            body: SafeArea(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.sizeOf(context).height -
                          kToolbarHeight -
                          MediaQuery.of(context).padding.top,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          // Fee 선택 현황
                          Center(
                              child: Column(children: [
                            const SizedBox(height: 32),
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: MyColors.transparentWhite_06,
                                  border:
                                      Border.all(color: MyColors.transparentWhite_12, width: 1)),
                              child: Text(_selectedFeeLevel ?? "", style: Styles.caption),
                            ),
                            Text(
                                _estimatedFee != null
                                    ? '${(satoshiToBitcoinString(_estimatedFee!))} ${t.btc}'
                                    : '',
                                style: Styles.fee),
                            FiatPrice(
                                satoshiAmount: _estimatedFee ?? 0,
                                textStyle: CoconutTypography.body2_14_Number
                                    .setColor(CoconutColors.gray400)),
                            const SizedBox(height: 32),
                          ])),

                          if (viewModel.isNetworkOn == true &&
                              _isRecommendedFeeFetchSuccess == false)
                            _buildFixedTooltip(
                                tooltipState: CoconutTooltipState.error,
                                richText:
                                    RichText(text: TextSpan(text: t.tooltip.recommended_fee1))),
                          if (_estimatedFee != null && _estimatedFee! >= maxFeeLimit)
                            _buildFixedTooltip(
                              tooltipState: CoconutTooltipState.warning,
                              richText: RichText(
                                  text: TextSpan(
                                      text: t.tooltip.recommended_fee2(
                                          bitcoin: UnitUtil.satoshiToBitcoin(maxFeeLimit)))),
                            ),
                          if (_estimatedFee != null &&
                              _estimatedFee! != 0 &&
                              !_viewModel.isBalanceEnough(_estimatedFee) &&
                              _estimatedFee! < maxFeeLimit)
                            _buildFixedTooltip(
                              tooltipState: CoconutTooltipState.warning,
                              richText:
                                  RichText(text: TextSpan(text: t.errors.insufficient_balance)),
                            ),
                          Padding(
                              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                              child: Column(
                                children: [
                                  ...List.generate(
                                      3,
                                      (index) => FeeSelectionItemCard(
                                          feeInfo: feeInfos[index],
                                          isSelected: _customSelected
                                              ? false
                                              : _selectedLevel == feeInfos[index].level,
                                          onPressed: () {
                                            setState(() {
                                              _selectedLevel = feeInfos[index].level;
                                              _selectedFeeLevel = feeInfos[index].level.text;
                                              _estimatedFee = feeInfos[index].estimatedFee;
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
                                          placeholder:
                                              t.text_field.enter_fee_with_two_decimal_places,
                                          onComplete: (text) {
                                            _handleCustomFeeInput(text);
                                          },
                                          keyboardType:
                                              const TextInputType.numberWithOptions(decimal: true),
                                          visibleTextLimit: false,
                                          formatInput: (text) {
                                            String finalText = filterDecimalInput(text, 2);
                                            return finalText;
                                          },
                                          maxLength: 10,
                                        ),
                                      );
                                    },
                                    text: t.text_field.enter_fee_directly,
                                    fontSize: 14,
                                    lineHeight: 21,
                                    defaultColor: CoconutColors.gray200,
                                  ),
                                ],
                              )),
                        ],
                      ),
                    ),
                  ),
                  NetworkErrorTooltip(isNetworkOn: viewModel.isNetworkOn),
                  if (_isLoading) const CoconutLoadingOverlay(),
                ],
              ),
            ),
          );
        },
      ),
    );
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
      }
    });
  }

  bool _canGoNext() {
    double? finalFeeRate = _customSelected
        ? _customFeeInfo?.satsPerVb
        : feeInfos.firstWhere((element) => element.level == _selectedLevel).satsPerVb;

    return _viewModel.isNetworkOn &&
        (finalFeeRate != null && finalFeeRate > 0) &&
        _viewModel.isBalanceEnough(_estimatedFee) &&
        _estimatedFee != null &&
        _estimatedFee! < maxFeeLimit &&
        !_isLoading;
  }

  void _handleCustomFeeInput(String input) async {
    if (input.isEmpty) {
      return;
    }

    double customSatsPerVb;
    try {
      customSatsPerVb = double.parse(input.trim());
    } catch (_) {
      _customFeeController.clear();
      return;
    }

    if (_minimumSatsPerVb != null && customSatsPerVb < _minimumSatsPerVb!) {
      CoconutToast.showToast(
        isVisibleIcon: true,
        context: context,
        text: t.toast.min_fee(minimum: _minimumSatsPerVb!),
      );
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

    setState(() {
      _isLoading = true;
    });

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
          CoconutToast.showWarningToast(
              context: context,
              text:
                  ErrorCodes.withMessage(ErrorCodes.feeEstimationError, error.toString()).message);
        }
      }
    }
    _customFeeController.clear();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  int? _handleFeeEstimationError(Exception e) {
    try {
      if (e.toString().contains("Insufficient amount. Estimated fee is")) {
        // get finalFee from error message : 'Insufficient amount. Estimated fee is $finalFee'
        var estimatedFee =
            int.parse(e.toString().split("Insufficient amount. Estimated fee is ")[1]);
        return estimatedFee;
      }

      if (e.toString().contains("Not enough amount for sending. (Fee")) {
        // get finalFee from error message : 'Not enough amount for sending. (Fee : $finalFee)'
        var estimatedFee = int.parse(
            e.toString().split("Not enough amount for sending. (Fee : ")[1].split(")")[0]);
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
        ? FiatUtil.calculateFiatAmount(estimatedFee, _viewModel.bitcoinPriceKrw!)
        : null;

    if (feeInfo is FeeInfoWithLevel && feeInfo.level == _selectedLevel) {
      _estimatedFee = estimatedFee;
      return;
    }

    if (feeInfo is! FeeInfoWithLevel) {
      _selectedFeeLevel = t.input_directly;
      _estimatedFee = estimatedFee;
      _customSelected = true;
    }
  }

  Future<void> _setRecommendedFees() async {
    final recommendedFeesResult = await _viewModel.nodeprovider.getRecommendedFees();
    if (recommendedFeesResult.isFailure) {
      setState(() {
        _isRecommendedFeeFetchSuccess = false;
      });
      return;
    }

    final RecommendedFee recommendedFees = recommendedFeesResult.value;

    feeInfos[0].satsPerVb = recommendedFees.fastestFee.toDouble();
    feeInfos[1].satsPerVb = recommendedFees.halfHourFee.toDouble();
    feeInfos[2].satsPerVb = recommendedFees.hourFee.toDouble();

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
            CoconutToast.showWarningToast(
                context: context,
                text: ErrorCodes.withMessage(ErrorCodes.feeEstimationError, error.toString())
                    .message);
          });
        }
      }
    }
  }

  Future<void> _startToSetRecommendedFee() async {
    setState(() {
      _isLoading = true;
    });
    await _setRecommendedFees();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildFixedTooltip(
      {required RichText richText, CoconutTooltipState tooltipState = CoconutTooltipState.info}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: CoconutLayout.defaultPadding),
      child: CoconutToolTip(
        richText: richText,
        showIcon: true,
        tooltipType: CoconutTooltipType.fixed,
        tooltipState: tooltipState,
      ),
    );
  }
}
