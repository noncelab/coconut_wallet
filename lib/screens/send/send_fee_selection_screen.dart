import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/fee_info.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/utils/recommended_fee_util.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:coconut_wallet/model/app_error.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
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

  const SendFeeSelectionScreen({
    super.key,
    required this.sendInfo,
    required this.id,
  });

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
  String? _selectedFeeLevel = TransactionFeeLevel.halfhour.text;
  int? _estimatedFee = 0;
  int? _fiatValue = 0;

  final TextEditingController _customFeeController = TextEditingController();
  FeeInfo? _customFeeInfo;

  late AppStateModel _model;
  late UpbitConnectModel _upbitConnectModel;
  late bool _isMaxMode;
  late bool _userBackFlag;
  late WalletBase _walletBase;
  late int _confirmedBalance;

  bool? _isNetworkOn;
  bool? _isRecommendedFeeFetchSuccess;

  bool _isMultisig = false;

  @override
  void initState() {
    super.initState();
    _model = Provider.of<AppStateModel>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _model.recordUsedUtxoIdListWhenSend([]);
    });

    _upbitConnectModel = Provider.of<UpbitConnectModel>(context, listen: false);

    final walletBaseItem = _model.getWalletById(widget.id);
    if (walletBaseItem.walletType == WalletType.multiSignature) {
      final multisigListItem = walletBaseItem as MultisigWalletListItem;
      _walletBase = multisigListItem.walletBase;

      final multisigWallet = _walletBase as MultisignatureWallet;
      _confirmedBalance = multisigWallet.getBalance();
      _isMultisig = true;
    } else {
      final singlesigListItem = walletBaseItem as SinglesigWalletListItem;
      _walletBase = singlesigListItem.walletBase;

      final singlesigWallet = _walletBase as SingleSignatureWallet;
      _confirmedBalance = singlesigWallet.getBalance();
    }

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
    debugPrint('isNetworkOn = $isNetworkOn _isNetworkOn = $_isNetworkOn');

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
    var recommendedFees = await fetchRecommendedFees(_model);
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
          final walletBaseItem = _model.getWalletById(widget.id);
          if (walletBaseItem.walletType == WalletType.multiSignature) {
            final multisigListItem = walletBaseItem as MultisigWalletListItem;
            _walletBase = multisigListItem.walletBase;

            final multisigWallet = _walletBase as MultisignatureWallet;
            _confirmedBalance = multisigWallet.getBalance();
          } else {
            final singlesigListItem = walletBaseItem as SinglesigWalletListItem;
            _walletBase = singlesigListItem.walletBase;

            final singlesigWallet = _walletBase as SingleSignatureWallet;
            _confirmedBalance = singlesigWallet.getBalance();
          }

          estimatedFee = await estimateFeeWithMaximum(widget.sendInfo.address,
              feeInfo.satsPerVb!, _isMultisig, _walletBase);
        } else {
          estimatedFee = await estimateFee(
              widget.sendInfo.address,
              widget.sendInfo.amount,
              feeInfo.satsPerVb!,
              _isMultisig,
              _walletBase);
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
      _selectedFeeLevel = '직접 입력';
      _estimatedFee = estimatedFee;
      _fiatValue = _customFeeInfo?.fiatValue;
      _customSelected = true;
    }
  }

  bool enoughBalance() {
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

  bool canGoNext() {
    int? satsPerVb = _customSelected
        ? _customFeeInfo?.satsPerVb
        : feeInfos
            .firstWhere((element) => element.level == _selectedLevel)
            .satsPerVb;

    return (satsPerVb != null && satsPerVb > 0) &&
        enoughBalance() &&
        _estimatedFee != null &&
        _estimatedFee! < maxFeeLimit;
  }

  void handleCustomFeeInput(String input) async {
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
        estimatedFee = await estimateFeeWithMaximum(
            widget.sendInfo.address, customSatsPerVb, _isMultisig, _walletBase);
      } else {
        estimatedFee = await estimateFee(widget.sendInfo.address,
            widget.sendInfo.amount, customSatsPerVb, _isMultisig, _walletBase);
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
            isActive: canGoNext(),
            onBackPressed: () {
              Navigator.pop(context);
            },
            nextButtonTitle: '완료',
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
              final walletBase = state.getWalletById(widget.id);
              if (walletBase.walletType == WalletType.multiSignature) {
                final multisigWallet = state.getWalletById(widget.id).walletBase
                    as MultisignatureWallet;
                onChangedNetworkStatus(
                    state.isNetworkOn, multisigWallet.getBalance());
              } else {
                final singlesigWallet = state
                    .getWalletById(widget.id)
                    .walletBase as SingleSignatureWallet;
                onChangedNetworkStatus(
                    state.isNetworkOn, singlesigWallet.getBalance());
              }
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
                      child:
                          Text(_selectedFeeLevel ?? "", style: Styles.caption),
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
                                ? '${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(_estimatedFee!, bitcoinPriceKrw).toDouble())} ${CurrencyCode.KRW.code}'
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
                      !enoughBalance() &&
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
                                      _selectedFeeLevel =
                                          feeInfos[index].level.text;
                                      _estimatedFee =
                                          feeInfos[index].estimatedFee;
                                      _fiatValue = feeInfos[index].fiatValue;
                                      _customSelected = false;
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
                                  onPressed: () {
                                    handleCustomFeeInput(
                                        _customFeeController.text);
                                  });
                            },
                            text: '직접 입력하기',
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
            ));
          },
        ));
  }
}

Future<int?> estimateFeeWithMaximum(String address, int satsPerVb,
    bool isMultisig, WalletBase walletBase) async {
  if (isMultisig) {
    return await (walletBase as MultisignatureWallet)
        .estimateFeeWithMaximum(address, satsPerVb);
  } else {
    return await (walletBase as SingleSignatureWallet)
        .estimateFeeWithMaximum(address, satsPerVb);
  }
}

Future<int?> estimateFee(String address, double amount, int satsPerVb,
    bool isMultisig, WalletBase walletBase) async {
  if (isMultisig) {
    return await (walletBase as MultisignatureWallet)
        .estimateFee(address, UnitUtil.bitcoinToSatoshi(amount), satsPerVb);
  } else {
    return await (walletBase as SingleSignatureWallet)
        .estimateFee(address, UnitUtil.bitcoinToSatoshi(amount), satsPerVb);
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
                          style: Styles.body2Number.merge(
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
                              ? "${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(feeInfo.estimatedFee!, bitcoinPriceKrw).toDouble())} ${CurrencyCode.KRW.code}"
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
