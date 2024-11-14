import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/data/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/model/app_error.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/model/constants.dart';
import 'package:coconut_wallet/model/enums.dart';
import 'package:coconut_wallet/model/send_info.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/alert_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:coconut_wallet/widgets/custom_tooltip.dart';
import 'package:provider/provider.dart';

class SendFeeSelectionScreen extends StatefulWidget {
  final SendInfo sendInfo;
  final int id;

  const SendFeeSelectionScreen(
      {super.key, required this.sendInfo, required this.id});

  @override
  State<SendFeeSelectionScreen> createState() => _SendFeeSelectionScreenState();
}

class _SendFeeSelectionScreenState extends State<SendFeeSelectionScreen> {
  static const maxFeeLimit =
      1000000; // sats, 사용자가 실수로 너무 큰 금액을 수수료로 지불하지 않도록 지정했습니다.
  List<FeeInfoWithLevel> feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];
  int? _minimumSatsPerVb;
  TransactionFeeLevel _selectedLevel = TransactionFeeLevel.halfhour;
  bool _customSelected = false;
  String? _selectedOption = TransactionFeeLevel.halfhour.text;
  int? _estimatedFee = 0;
  int? _fiatValue = 0;

  final TextEditingController _customFeeController = TextEditingController();
  FeeInfo? _customFeeInfo;

  late AppStateModel _model;
  late UpbitConnectModel _upbitConnectModel;
  late SinglesigWalletListItem _singlesigWalletListItem;
  late bool _isMaxMode;
  late bool _userBackFlag;
  late WalletBase _walletBase;
  late SingleSignatureWallet _singlesigWallet;
  late int _confirmedBalance;

  bool? _isNetworkOn;
  bool? _isRecommendedFeeFetchSuccess;

  @override
  void initState() {
    super.initState();
    context.loaderOverlay.show(); // onChangedNetworkStatus 과정 중 hide 됨
    _model = Provider.of<AppStateModel>(context, listen: false);
    _upbitConnectModel = Provider.of<UpbitConnectModel>(context, listen: false);
    _singlesigWalletListItem = _model.getWalletById(widget.id);
    _walletBase = _singlesigWalletListItem.walletBase;

    // TODO: SingleSignatureWallet
    _singlesigWallet = _walletBase as SingleSignatureWallet;
    _confirmedBalance = _singlesigWallet.getBalance();

    _isMaxMode =
        _confirmedBalance == UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount);
    _userBackFlag = false;
  }

  Future<void> onChangedNetworkStatus(
      bool? isNetworkOn, int? confirmedBalance) async {
    if (isNetworkOn == false && !_userBackFlag) {
      context.loaderOverlay.hide();
      showAlertAndGoHome("네트워크 상태가 좋지 않아 처음으로 돌아갑니다.");
      return;
    }

    if (_isNetworkOn == isNetworkOn) return; // 네트워크 상태가 기존과 같으면 할 일이 없음
    context.loaderOverlay.show();
    setState(() {
      _isNetworkOn = isNetworkOn;
    });

    if (isNetworkOn == true) {
      await setRecommendedFees();
      context.loaderOverlay.hide();
    }
  }

  void showAlertAndGoHome(String message) {
    showAlertDialog(
        context: context,
        content: message,
        onClosed: () {
          _userBackFlag = true;
          Navigator.of(context).pop(); // 다이얼로그 닫기

          // 약간의 지연 후 popUntil 호출
          Future.delayed(const Duration(milliseconds: 300), () {
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (Route<dynamic> route) => false,
            );
          });
        });
  }

  Future<void> setRecommendedFees() async {
    var recommendedFees = await fetchRecommendedFees();
    if (recommendedFees == null) {
      setState(() {
        _isRecommendedFeeFetchSuccess = false;
      });
      return;
    }

    feeInfos[0].satsPerVb = recommendedFees.fastestFee;
    feeInfos[1].satsPerVb = recommendedFees.halfHourFee;
    feeInfos[2].satsPerVb = recommendedFees.hourFee;

    setState(() => _minimumSatsPerVb = recommendedFees.minimumFee);

    for (var feeInfo in feeInfos) {
      try {
        int? estimatedFee;
        if (_isMaxMode) {
          estimatedFee = await _singlesigWallet.estimateFeeWithMaximum(
              widget.sendInfo.address, feeInfo.satsPerVb!);
        } else {
          estimatedFee = await _singlesigWallet.estimateFee(
              widget.sendInfo.address,
              UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount),
              feeInfo.satsPerVb!);
        }
        setState(() {
          setFeeInfo(feeInfo, estimatedFee!);
        });
      } catch (error) {
        int? estimatedFee = handleFeeEstimationError(error as Exception);
        if (estimatedFee != null) {
          setState(() {
            setFeeInfo(feeInfo, estimatedFee);
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

  void setFeeInfo(FeeInfo feeInfo, int estimatedFee) {
    feeInfo.estimatedFee = estimatedFee;
    feeInfo.fiatValue = _upbitConnectModel.bitcoinPriceKrw != null
        ? FiatUtil.calculateFiatAmount(
            estimatedFee, _upbitConnectModel.bitcoinPriceKrw!)
        : null;

    if (feeInfo is FeeInfoWithLevel && feeInfo.level == _selectedLevel) {
      _estimatedFee = estimatedFee;
      _fiatValue = feeInfo.fiatValue;
      return;
    }

    if (feeInfo is! FeeInfoWithLevel) {
      _selectedOption = '직접 입력';
      _estimatedFee = estimatedFee;
      _fiatValue = _customFeeInfo?.fiatValue;
      _customSelected = true;
    }
  }

  int? handleFeeEstimationError(Exception e) {
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

  Future<RecommendedFee> getRecommendFee() async {
    String urlString = '${PowWalletApp.kMempoolHost}/api/v1/fees/recommended';
    final url = Uri.parse(urlString);
    final response = await get(url);

    Map<String, dynamic> jsonMap = jsonDecode(response.body);

    return RecommendedFee.fromJson(jsonMap);
  }

  Future<RecommendedFee?> fetchRecommendedFees() async {
    try {
      RecommendedFee recommendedFee = await getRecommendFee();

      /// 포우 월렛은 수수료를 너무 낮게 보내서 1시간 이상 트랜잭션이 펜딩되는 것을 막는 방향으로 구현하자고 결정되었습니다.
      /// 따라서 트랜잭션 전송 시점에, 네트워크 상 최소 수수료 값 미만으로는 수수료를 설정할 수 없게 해야 합니다.
      Result<int, CoconutError>? minimumFeeResult =
          await _model.getMinimumNetworkFeeRate();
      if (minimumFeeResult != null &&
          minimumFeeResult.isSuccess &&
          minimumFeeResult.value != null) {
        return RecommendedFee(
            recommendedFee.fastestFee,
            recommendedFee.halfHourFee,
            recommendedFee.hourFee,
            recommendedFee.economyFee,
            minimumFeeResult.value!);
      }

      //RecommendedFee recommendedFee = RecommendedFee(20, 19, 12, 3, 3);
      return recommendedFee;
    } catch (e) {
      return null;
    }
  }

  bool _enoughBalance() {
    if (_estimatedFee == null) {
      return false;
    }
    if (_estimatedFee == 0) {
      return false;
    }

    if (_isMaxMode) {
      return (_confirmedBalance - _estimatedFee!) > dustLimit;
    }

    return (UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount) +
            _estimatedFee!) <=
        _confirmedBalance;
  }

  bool _canGoNext() {
    int? satsPerVb = _customSelected
        ? _customFeeInfo?.satsPerVb
        : feeInfos
            .firstWhere((element) => element.level == _selectedLevel)
            .satsPerVb;

    return (satsPerVb != null && satsPerVb > 0) &&
        _enoughBalance() &&
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
            text: "현재 최소 수수료는 $_minimumSatsPerVb sats/vb 입니다.");
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
      int? estimatedFee;
      if (_isMaxMode) {
        estimatedFee = await _singlesigWallet.estimateFeeWithMaximum(
            widget.sendInfo.address, customSatsPerVb);
      } else {
        estimatedFee = await _singlesigWallet.estimateFee(
            widget.sendInfo.address,
            UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount),
            customSatsPerVb);
      }

      setState(() {
        _customFeeInfo = FeeInfo(satsPerVb: customSatsPerVb);
        setFeeInfo(_customFeeInfo!, estimatedFee!);
      });
    } catch (error) {
      int? estimatedFee = handleFeeEstimationError(error as Exception);
      if (estimatedFee != null) {
        setState(() {
          _customFeeInfo = FeeInfo(satsPerVb: customSatsPerVb);
          setFeeInfo(_customFeeInfo!, estimatedFee);
        });
      } else {
        // custom 수수료 조회 실패 알림
        CustomToast.showWarningToast(
            context: context,
            text: ErrorCodes.withMessage(
                    ErrorCodes.feeEstimationError, error.toString())
                .message);
      }
    }
    _customFeeController.clear();
    context.loaderOverlay.hide();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: MyColors.black,
        appBar: CustomAppBar.buildWithNext(
            title: "수수료",
            context: context,
            isActive: _canGoNext(),
            onNextPressed: () {
              if (_isNetworkOn != true) {
                CustomToast.showWarningToast(
                    context: context, text: ErrorCodes.networkError.message);
                return;
              }

              int satsPerVb = _customSelected
                  ? _customFeeInfo!.satsPerVb!
                  : feeInfos
                      .firstWhere((element) => element.level == _selectedLevel)
                      .satsPerVb!;

              double amount = _isMaxMode
                  ? UnitUtil.satoshiToBitcoin(
                      _confirmedBalance - _estimatedFee!)
                  : widget.sendInfo.amount;

              Navigator.pushNamed(context, '/send-confirm', arguments: {
                'id': widget.id,
                'fullSendInfo': FullSendInfo(
                  address: widget.sendInfo.address,
                  amount: amount,
                  satsPerVb: satsPerVb,
                  estimatedFee: _estimatedFee,
                  isMaxMode: _isMaxMode,
                )
              });
            }),
        body: Consumer<AppStateModel>(
          builder: (context, state, child) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // TODO: SingleSignatureWallet
              final singlesigWallet = state.getWalletById(widget.id).walletBase
                  as SingleSignatureWallet;
              onChangedNetworkStatus(
                  state.isNetworkOn, singlesigWallet.getBalance());
            });

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
                              color: MyColors.transparentWhite_12, width: 1)),
                      child: Text(_selectedOption ?? "", style: Styles.caption),
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
                      _isRecommendedFeeFetchSuccess == false)
                    CustomTooltip(
                        richText: RichText(
                            text: const TextSpan(
                                text: '추천 수수료를 조회하지 못했어요. 수수료를 직접 입력해 주세요.')),
                        showIcon: true,
                        type: TooltipType.error),
                  if (_estimatedFee != null && _estimatedFee! >= maxFeeLimit)
                    CustomTooltip(
                        richText: RichText(
                            text: TextSpan(
                                text:
                                    '설정하신 수수료가 ${UnitUtil.satoshiToBitcoin(maxFeeLimit)}BTC 이상이에요.')),
                        showIcon: true,
                        type: TooltipType.warning),
                  if (_estimatedFee != null &&
                      _estimatedFee! != 0 &&
                      !_enoughBalance() &&
                      _estimatedFee! < maxFeeLimit)
                    CustomTooltip(
                        richText:
                            RichText(text: const TextSpan(text: '잔액이 부족해요.')),
                        showIcon: true,
                        type: TooltipType.warning),
                  Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
                      child: Column(
                        children: [
                          ...List.generate(
                              3,
                              (index) => FeeSelectionItem(
                                  feeInfo: feeInfos[index],
                                  isSelected: _customSelected
                                      ? false
                                      : _selectedLevel == feeInfos[index].level,
                                  onPressed: () {
                                    setState(() {
                                      _selectedLevel = feeInfos[index].level;
                                      _selectedOption =
                                          feeInfos[index].level.text;
                                      _estimatedFee =
                                          feeInfos[index].estimatedFee;
                                      _fiatValue = feeInfos[index].fiatValue;
                                      _customSelected = false;
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
                                  onPressed: () {
                                    _handleCustomFeeInput(
                                        _customFeeController.text);
                                  });
                            },
                            child: Text(
                              "직접 입력",
                              style: _customSelected
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
        ));
  }
}

class FeeSelectionItem extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isSelected;
  final bool isLoading;
  final FeeInfoWithLevel feeInfo;

  const FeeSelectionItem({
    super.key,
    this.onPressed,
    this.isLoading = false,
    this.isSelected = false,
    required this.feeInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 79,
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? MyColors.white : MyColors.grey,
          ),
          borderRadius: MyBorder.defaultRadius,
          color: MyColors.transparentWhite_06),
      child: CupertinoButton(
        padding: Paddings.widgetContainer,
        onPressed: feeInfo.satsPerVb == null || feeInfo.estimatedFee == null
            ? null
            : onPressed,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  feeInfo.level.text,
                  style: feeInfo.estimatedFee == null
                      ? Styles.body1Bold.merge(
                          const TextStyle(color: MyColors.borderLightgrey),
                        )
                      : Styles.body1,
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: Styles.caption, // 동일한 스타일 적용
                        children: [
                          TextSpan(
                            text: feeInfo.level.expectedTime,
                          ),
                          if (feeInfo.satsPerVb != null)
                            TextSpan(
                              text: " (${feeInfo.satsPerVb} sats/vb)",
                            ),
                        ],
                      ),
                    ),
                  ],
                )
              ],
            ),
            if (feeInfo.estimatedFee != null)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          satoshiToBitcoinString(feeInfo.estimatedFee!),
                          style: Styles.body1Number,
                        ),
                        Text(
                          ' BTC',
                          style: Styles.body2.merge(
                            const TextStyle(
                              color: MyColors.transparentWhite_70,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(
                      height: 5,
                    ),
                    Selector<UpbitConnectModel, int?>(
                      selector: (context, model) => model.bitcoinPriceKrw,
                      builder: (context, bitcoinPriceKrw, child) {
                        return Text(
                          bitcoinPriceKrw != null
                              ? "₩${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(feeInfo.estimatedFee!, bitcoinPriceKrw).toDouble())}"
                              : '',
                          style: Styles.caption,
                        );
                      },
                    ),
                  ],
                ),
              ),
            if (feeInfo.failedEstimation)
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "수수료 조회 실패",
                      style: Styles.warning,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class FeeInfoWithLevel extends FeeInfo {
  final TransactionFeeLevel level;

  FeeInfoWithLevel({
    required this.level,
    super.estimatedFee,
    super.fiatValue,
    super.satsPerVb,
    super.failedEstimation, // 현재 활용 안함
    super.isEstimating, // 현재 활용 안함
  });
}

class FeeInfo {
  int? estimatedFee;
  int? fiatValue;
  int? satsPerVb;
  bool failedEstimation;
  bool isEstimating;

  FeeInfo(
      {this.estimatedFee,
      this.fiatValue,
      this.satsPerVb,
      this.failedEstimation = false,
      this.isEstimating = false});
}
