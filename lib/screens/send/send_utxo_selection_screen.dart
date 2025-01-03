import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/app_error.dart';
import 'package:coconut_wallet/model/data/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/data/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/data/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/data/wallet_type.dart';
import 'package:coconut_wallet/model/enums.dart';
import 'package:coconut_wallet/model/send_info.dart';
import 'package:coconut_wallet/model/utxo.dart' as model;
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/screens/send/send_fee_selection_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/cconut_wallet_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/bottom_sheet.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/custom_dropdown.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class SendUtxoSelectionScreen extends StatefulWidget {
  final int id;
  final SendInfo sendInfo;

  const SendUtxoSelectionScreen({
    super.key,
    required this.id,
    required this.sendInfo,
  });

  @override
  State<SendUtxoSelectionScreen> createState() =>
      _SendUtxoSelectionScreenState();
}

class _SendUtxoSelectionScreenState extends State<SendUtxoSelectionScreen> {
  late AppStateModel _model;
  late WalletListItemBase _walletBaseItem;
  late WalletBase _walletBase;
  late WalletFeature _walletFeature;
  late WalletType _walletType;

  late UpbitConnectModel _upbitConnectModel;

  static String changeField = 'change';
  static String accountIndexField = 'accountIndex';
  late final ScrollController _scrollController;
  late List<model.UTXO> _utxoList;
  late List<model.UTXO> _selectedUtxoList;

  final GlobalKey _filterDropdownButtonKey = GlobalKey();
  final GlobalKey _scrolledFilterDropdownButtonKey = GlobalKey();
  final bool _positionedTopWidgetVisible = false; // 스크롤시 상단에 붙어있는 위젯
  bool _isFilterDropdownVisible = false; // 필터 드롭다운(확장형)
  bool _isScrolledFilterDropdownVisible = false; // 필터 드롭다운(축소형)
  late Offset _filterDropdownButtonPosition;
  late Offset _scrolledFilterDropdownButtonPosition;

  final GlobalKey _headerTopContainerKey = GlobalKey();
  Size _headerTopContainerSize = const Size(0, 0);
  bool _afterScrolledHeaderContainerVisible = false;

  late double _totalUtxoAmountWidgetPaddingLeft;
  late double _totalUtxoAmountWidgetPaddingRight;
  late double _totalUtxoAmountWidgetPaddingTop;
  late double _totalUtxoAmountWidgetPaddingBottom;

  late int _confirmedBalance;
  late bool _isMaxMode;
  bool _isMultisig = false;
  TransactionFeeLevel _selectedLevel = TransactionFeeLevel.halfhour;
  RecommendedFee? recommendedFees;
  bool _customSelected = false;
  FeeInfo? _customFeeInfo;
  String _selectedOption = TransactionFeeLevel.halfhour.text;
  int? _estimatedFee = 0;
  int? _fiatValue = 0;
  int? _satsPerVb = 0;
  List<FeeInfoWithLevel> feeInfos = [
    FeeInfoWithLevel(level: TransactionFeeLevel.fastest),
    FeeInfoWithLevel(level: TransactionFeeLevel.halfhour),
    FeeInfoWithLevel(level: TransactionFeeLevel.hour),
  ];

  bool _isRecommendedFeeFetchSuccess = false;

  int? _isEnableToGetChange;

  bool _isLoadingMore = false;
  bool _isLastData = false;
  final int _takeLength = 15; // 스크롤시 가져올 데이터 수(페이징)
  UtxoOrderEnum _selectedFilter = UtxoOrderEnum.byTimestampDesc;

  @override
  void initState() {
    super.initState();
    _model = Provider.of<AppStateModel>(context, listen: false);
    _upbitConnectModel = Provider.of<UpbitConnectModel>(context, listen: false);

    _scrollController = ScrollController();

    _walletBaseItem = _model.getWalletById(widget.id);
    _walletFeature = getWalletFeatureByWalletType(_walletBaseItem);

    _walletType = _walletBaseItem.walletType;
    if (_model.walletInitState == WalletInitState.finished) {
      _utxoList = _getUtxoList();
      _selectedUtxoList = [];
    } else {
      _utxoList = _selectedUtxoList = [];
    }

    if (_walletType == WalletType.multiSignature) {
      final multisigListItem = _walletBaseItem as MultisigWalletListItem;
      _walletBase = multisigListItem.walletBase;

      final multisigWallet = _walletBase as MultisignatureWallet;
      _confirmedBalance = multisigWallet.getBalance();
      _isMultisig = true;
    } else {
      final singlesigListItem = _walletBaseItem as SinglesigWalletListItem;
      _walletBase = singlesigListItem.walletBase;

      final singlesigWallet = _walletBase as SingleSignatureWallet;
      _confirmedBalance = singlesigWallet.getBalance();
    }

    _isMaxMode =
        _confirmedBalance == UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount);

    _customSelected = false;

    _totalUtxoAmountWidgetPaddingLeft = _totalUtxoAmountWidgetPaddingRight =
        _totalUtxoAmountWidgetPaddingTop = 24;
    _totalUtxoAmountWidgetPaddingBottom = 20;

    _scrollController.addListener(() {
      double threshold = _headerTopContainerSize.height + 20;
      double offset = _scrollController.offset;
      if (_isFilterDropdownVisible || _isScrolledFilterDropdownVisible) {
        _removeFilterDropdown();
      }
      setState(() {
        _afterScrolledHeaderContainerVisible = offset >= threshold;

        // 부드럽게 패딩 값 계산
        double progress = (offset / threshold).clamp(0.0, 1.0);

        if (_afterScrolledHeaderContainerVisible) {
          _totalUtxoAmountWidgetPaddingLeft =
              _totalUtxoAmountWidgetPaddingRight =
                  _totalUtxoAmountWidgetPaddingTop = 17;
          _totalUtxoAmountWidgetPaddingBottom = 15;
        } else {
          _totalUtxoAmountWidgetPaddingLeft =
              _totalUtxoAmountWidgetPaddingRight =
                  _totalUtxoAmountWidgetPaddingTop = 24 - (7 * progress);
          _totalUtxoAmountWidgetPaddingBottom = 20 - (5 * progress);
        }
      });
      if (_scrollController.position.extentAfter < 100) {
        _loadMoreData();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      RenderBox filterDropdownButtonRenderBox =
          _filterDropdownButtonKey.currentContext?.findRenderObject()
              as RenderBox;
      RenderBox scrolledFilterDropdownButtonRenderBox =
          _scrolledFilterDropdownButtonKey.currentContext?.findRenderObject()
              as RenderBox;
      _filterDropdownButtonPosition =
          filterDropdownButtonRenderBox.localToGlobal(Offset.zero);
      _scrolledFilterDropdownButtonPosition =
          scrolledFilterDropdownButtonRenderBox.localToGlobal(Offset.zero);

      RenderBox headerTopContainerRenderBox =
          _headerTopContainerKey.currentContext?.findRenderObject()
              as RenderBox;
      _headerTopContainerSize = headerTopContainerRenderBox.size;

      recommendedFees = await fetchRecommendedFees(_model);
      await setRecommendedFees(TransactionFeeLevel.halfhour);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  Future<void> setRecommendedFees(TransactionFeeLevel? transactionFeeLevel,
      {int? estimatedFee}) async {
    if (recommendedFees == null) {
      setState(() {
        _isRecommendedFeeFetchSuccess = false;
      });
      return;
    }
    int index;
    if (transactionFeeLevel == null) {
      index = 3;
    } else {
      switch (transactionFeeLevel) {
        case TransactionFeeLevel.fastest:
          index = 0;
        case TransactionFeeLevel.halfhour:
          index = 1;
        case TransactionFeeLevel.hour:
          index = 2;
          break;
      }
    }
    feeInfos[0].satsPerVb = recommendedFees!.fastestFee;
    feeInfos[1].satsPerVb = recommendedFees!.halfHourFee;
    feeInfos[2].satsPerVb = recommendedFees!.hourFee;

    if (index != 3) {
      /// halfHour가 default
      setState(() {
        _selectedLevel = feeInfos[index].level;
        _selectedOption = feeInfos[index].level.text;
        _estimatedFee = feeInfos[index].estimatedFee;
        _fiatValue = feeInfos[index].fiatValue;
        _satsPerVb = feeInfos[index].satsPerVb;
      });
    }

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
          _isRecommendedFeeFetchSuccess = true;
        });
      } catch (error) {
        int? estimatedFee = handleFeeEstimationError(error as Exception);
        if (estimatedFee != null) {
          setState(() {
            setFeeInfo(feeInfo, estimatedFee);
            _isRecommendedFeeFetchSuccess = true;
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

      if (index == 3) {
        /// 직접 입력했을 때
        setState(() {
          _selectedOption = '직접 입력';
          _estimatedFee = estimatedFee;
          _fiatValue = _customFeeInfo?.fiatValue;
          _customSelected = true;
          _satsPerVb = 0;
        });
      }
    }
  }

  /// UTXO 선택 상태를 토글하는 함수
  void _toggleSelection(model.UTXO utxo) {
    _removeFilterDropdown();
    setState(() {
      if (_selectedUtxoList.contains(utxo)) {
        _selectedUtxoList.remove(utxo);
      } else {
        _selectedUtxoList.add(utxo);
      }

      /// 잔돈 계산
      if (_estimatedFee != null) {
        if (_selectedUtxoList.isEmpty) {
          _isEnableToGetChange = 0;
          return;
        }
        _isEnableToGetChange = _getSelectedUtxoTotalSatoshi() -
            (UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount) +
                _estimatedFee!);
      } else {
        _isEnableToGetChange = 0;
      }
    });
  }

  bool _isSelectedUtxoEnough() {
    if (_isMaxMode) {
      return _getSelectedUtxoTotalSatoshi() >=
              UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount) -
                  (_estimatedFee ?? 0) &&
          _selectedUtxoList.isNotEmpty;
    }
    return _getSelectedUtxoTotalSatoshi() >=
            UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount) +
                (_estimatedFee ?? 0) &&
        _selectedUtxoList.isNotEmpty;
  }

  void _applyFilter(UtxoOrderEnum orderEnum) {
    if (orderEnum == _selectedFilter) return;
    _scrollController.jumpTo(0);

    setState(() {
      _selectedFilter = orderEnum;
      _selectedUtxoList.clear();
      _utxoList.clear();
      _utxoList = _getUtxoList(orderEnum: _selectedFilter);
    });
  }

  List<model.UTXO> _getUtxoList(
      {UtxoOrderEnum orderEnum = UtxoOrderEnum.byTimestampDesc,
      int cursor = 0}) {
    return getUtxoListWithHoldingAddress(
      _walletFeature.getUtxoList(
          order: orderEnum, cursor: cursor, count: _takeLength),
      _walletBaseItem,
      accountIndexField,
      changeField,
      _walletType,
    );
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    await Future.delayed(const Duration(milliseconds: 1000));

    List<model.UTXO> newList =
        _getUtxoList(orderEnum: _selectedFilter, cursor: _utxoList.length);

    setState(() {
      _utxoList.addAll(newList);
      if (newList.length < _takeLength) {
        _isLastData = true;
      }
    });

    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Widget _divider() => Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: const Divider(
          height: 1,
          color: MyColors.transparentWhite_10,
        ),
      );

  /// 필터 드롭다운 위젯
  Widget _filterDropDownWidget() {
    return Material(
      borderRadius: BorderRadius.circular(16),
      child: CustomDropdown(
        buttons: const [
          '최신순',
          '오래된 순',
          '큰 금액순',
          '작은 금액순',
        ],
        dividerColor: Colors.black,
        onTapButton: (index) {
          switch (index) {
            case 0: // 최신순
              _applyFilter(UtxoOrderEnum.byTimestampDesc);
              break;
            case 1: // 오래된 순
              _applyFilter(UtxoOrderEnum.byTimestampAsc);
              break;
            case 2: // 큰 금액순
              _applyFilter(UtxoOrderEnum.byAmountDesc);
              break;
            case 3: // 작은 금액순
              _applyFilter(UtxoOrderEnum.byAmountAsc);
              break;
          }
          setState(() {
            _isFilterDropdownVisible = _isScrolledFilterDropdownVisible = false;
          });
        },
      ),
    );
  }

  Widget _totalUtxoAmountWidget(Widget textKeyWidget,
      {bool isAfterScrolled = false}) {
    return Column(
      children: [
        Container(
          width: MediaQuery.sizeOf(context).width,
          decoration: BoxDecoration(
            color: _isRecommendedFeeFetchSuccess &&
                    _estimatedFee != null &&
                    _selectedUtxoList.isNotEmpty
                ? _isSelectedUtxoEnough()
                    ? MyColors.transparentWhite_10
                    : MyColors.transparentRed
                : MyColors.transparentWhite_10,
            borderRadius: BorderRadius.circular(24),
          ),
          margin: const EdgeInsets.only(
            top: 10,
          ),
          child: AnimatedPadding(
            padding: EdgeInsets.only(
              left: _totalUtxoAmountWidgetPaddingLeft,
              right: _totalUtxoAmountWidgetPaddingRight,
              top: _totalUtxoAmountWidgetPaddingTop,
              bottom: _totalUtxoAmountWidgetPaddingBottom,
            ),
            duration: const Duration(milliseconds: 10),
            child: Row(
              children: [
                Text(
                  'UTXO 합계',
                  style: Styles.body2Bold.merge(
                    TextStyle(
                      color: _selectedUtxoList.isEmpty
                          ? MyColors.white
                          : _isRecommendedFeeFetchSuccess &&
                                  _estimatedFee != null
                              ? _isSelectedUtxoEnough()
                                  ? MyColors.white
                                  : MyColors.warningRed
                              : MyColors.white,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 4,
                ),
                Visibility(
                  visible: _selectedUtxoList.isNotEmpty,
                  child: Text(
                    '(${_selectedUtxoList.length}개)',
                    style: Styles.caption.merge(
                      TextStyle(
                          fontFamily: 'Pretendard',
                          color: _isRecommendedFeeFetchSuccess &&
                                  _estimatedFee != null
                              ? _isSelectedUtxoEnough()
                                  ? MyColors.transparentWhite_70
                                  : MyColors.transparentWarningRed
                              : MyColors.transparentWhite_70),
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        // Transaction.estimatedFee,
                        _selectedUtxoList.isEmpty
                            ? '0 BTC'
                            : '${satoshiToBitcoinString(_getSelectedUtxoTotalSatoshi()).normalizeToFullCharacters()} BTC',
                        style: Styles.body2Number.merge(TextStyle(
                            color: _isRecommendedFeeFetchSuccess &&
                                    _estimatedFee != null &&
                                    _selectedUtxoList.isNotEmpty
                                ? _isSelectedUtxoEnough()
                                    ? MyColors.white
                                    : MyColors.warningRed
                                : MyColors.white,
                            fontWeight: FontWeight.w700,
                            height: 16.8 / 14)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(
          height: 8,
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          child: !_afterScrolledHeaderContainerVisible
              ? Visibility(
                  visible: _selectedUtxoList.isEmpty ||
                      _getSelectedUtxoTotalSatoshi() <
                          UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount) +
                              (_estimatedFee ?? 0),
                  maintainSize: true,
                  maintainState: true,
                  maintainAnimation: true,
                  child: _selectedUtxoList.isEmpty
                      ? Text(
                          '아래 목록에서 UTXO를 선택해 주세요',
                          style: Styles.warning.merge(
                            const TextStyle(
                              color: MyColors.white,
                              height: 16 / 12,
                            ),
                          ),
                        )
                      : _getSelectedUtxoTotalSatoshi() <
                              UnitUtil.bitcoinToSatoshi(
                                      widget.sendInfo.amount) +
                                  (_estimatedFee ?? 0)
                          ? Text(
                              'UTXO 합계가 모자라요',
                              style: Styles.warning.merge(
                                const TextStyle(
                                  height: 16 / 12,
                                ),
                              ),
                            )
                          : Text(
                              '',
                              style: Styles.warning.merge(
                                const TextStyle(
                                  height: 16 / 12,
                                ),
                              ),
                            ),
                )
              : Container(),
        ),
        Visibility(
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          maintainSemantics: false,
          maintainInteractivity: false,
          visible: !_positionedTopWidgetVisible,
          child: Row(children: [
            CupertinoButton(
              onPressed: () {
                setState(
                  () {
                    if (isAfterScrolled
                        ? _isScrolledFilterDropdownVisible
                        : _isFilterDropdownVisible) {
                      _removeFilterDropdown();
                    } else {
                      if (isAfterScrolled) {
                        _isScrolledFilterDropdownVisible = true;
                      } else {
                        _isFilterDropdownVisible = true;
                      }
                    }
                  },
                );
              },
              minSize: 0,
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  textKeyWidget,
                  const SizedBox(
                    width: 4,
                  ),
                  SvgPicture.asset(
                    'assets/svg/arrow-down.svg',
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CustomUnderlinedButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    text: '모두 해제',
                    onTap: () {
                      _removeFilterDropdown();
                      setState(() {
                        _selectedUtxoList = [];
                      });
                    },
                  ),
                  SvgPicture.asset('assets/svg/row-divider.svg'),
                  CustomUnderlinedButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    text: '모두 선택',
                    onTap: () {
                      _removeFilterDropdown();
                      setState(() {
                        _selectedUtxoList = List.from(_utxoList);
                      });
                    },
                  )
                ],
              ),
            )
          ]),
        ),
      ],
    );
  }

  void _removeFilterDropdown() {
    setState(() {
      _isFilterDropdownVisible = false;
      _isScrolledFilterDropdownVisible = false;
    });
  }

  int _getSelectedUtxoTotalSatoshi() {
    if (_selectedUtxoList.isEmpty) return 0;
    return _selectedUtxoList
        .map((utxo) => utxo.amount)
        .reduce((value, element) => value + element);
  }

  String _getCurrentFilter() {
    if (_selectedFilter == UtxoOrderEnum.byTimestampDesc) {
      return '최신순';
    } else if (_selectedFilter == UtxoOrderEnum.byTimestampAsc) {
      return '오래된 순';
    } else if (_selectedFilter == UtxoOrderEnum.byAmountDesc) {
      return '큰 금액순';
    } else {
      return '작은 금액순';
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        _removeFilterDropdown();
      },
      child: Scaffold(
        appBar: CustomAppBar.buildWithNext(
          backgroundColor: MyColors.black,
          title: 'UTXO 고르기',
          context: context,
          nextButtonTitle: '완료',
          isActive: _isRecommendedFeeFetchSuccess && _estimatedFee != null
              ? _isSelectedUtxoEnough()
                  ? true
                  : false
              : false,
          onNextPressed: () {
            _removeFilterDropdown();
          },
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 10,
                      bottom: 10,
                    ),
                    alignment: Alignment.center,
                    color: MyColors.black,
                    child: Column(
                      children: [
                        Container(
                          key: _headerTopContainerKey,
                          width: MediaQuery.sizeOf(context).width,
                          decoration: BoxDecoration(
                            color: MyColors.transparentWhite_10,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.only(
                            left: 24,
                            right: 24,
                            top: 24,
                            bottom: 20,
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '보낼 수량',
                                    style: Styles.body2Bold,
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '${satoshiToBitcoinString(
                                            _isMaxMode
                                                ? UnitUtil.bitcoinToSatoshi(
                                                      widget.sendInfo.amount,
                                                    ) -
                                                    (_estimatedFee ?? 0)
                                                : UnitUtil.bitcoinToSatoshi(
                                                    widget.sendInfo.amount,
                                                  ),
                                          ).normalizeToFullCharacters()} BTC',
                                          style: Styles.body2Number,
                                        ),
                                        Selector<UpbitConnectModel, int?>(
                                          selector: (context, model) =>
                                              model.bitcoinPriceKrw,
                                          builder: (context, bitcoinPriceKrw,
                                              child) {
                                            return Text(
                                              bitcoinPriceKrw != null
                                                  ? '₩ ${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount), bitcoinPriceKrw).toDouble())}'
                                                  : '',
                                              style: Styles.balance2,
                                            );
                                          },
                                        )
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              _divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '수수료',
                                    style: Styles.body2Bold,
                                  ),
                                  CustomUnderlinedButton(
                                      text: '변경',
                                      isEnable: _isRecommendedFeeFetchSuccess,
                                      onTap: () async {
                                        Map<String, dynamic>? result =
                                            await MyBottomSheet
                                                .showBottomSheet_90(
                                                    context: context,
                                                    child:
                                                        SendFeeSelectionScreen(
                                                      id: widget.id,
                                                      sendInfo: widget.sendInfo,
                                                      isFromUtxoSelection: true,
                                                    ));
                                        if (result != null) {
                                          if (result['transactionFeeLevel'] !=
                                              null) {
                                            /// 선택 입력
                                            await setRecommendedFees(
                                              result['transactionFeeLevel'],
                                            );
                                          } else {
                                            /// 직접 입력
                                            await setRecommendedFees(
                                              result['transactionFeeLevel'],
                                              estimatedFee:
                                                  result['estimatedFee'],
                                            );
                                          }
                                        }
                                      }),
                                  Expanded(
                                      child: _isRecommendedFeeFetchSuccess
                                          ? Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(
                                                  '${satoshiToBitcoinString(_estimatedFee ?? 0).toString()} BTC',
                                                  style: Styles.body2Number,
                                                ),
                                                if (_satsPerVb != 0) ...{
                                                  Text(
                                                    '${_selectedLevel.expectedTime} ($_satsPerVb sats/vb)',
                                                    style: Styles.caption,
                                                  ),
                                                }
                                              ],
                                            )
                                          : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              children: [
                                                SizedBox(
                                                  width: 15,
                                                  height: 15,
                                                  child:
                                                      CircularProgressIndicator(
                                                    color: MyColors.white,
                                                    strokeWidth: 2,
                                                  ),
                                                ),
                                              ],
                                            )),
                                ],
                              ),
                              _divider(),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '잔돈',
                                    style: _isEnableToGetChange != null &&
                                            _isEnableToGetChange! > 0
                                        ? Styles.body2Bold
                                        : Styles.body2Bold.merge(
                                            const TextStyle(
                                              color:
                                                  MyColors.transparentWhite_40,
                                            ),
                                          ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          // Transaction.estimatedFee,
                                          _isEnableToGetChange != null &&
                                                  _isEnableToGetChange! > 0
                                              ? '${satoshiToBitcoinString(_isEnableToGetChange!)} BTC'
                                              : '- BTC',
                                          style: _isEnableToGetChange != null &&
                                                  _isEnableToGetChange! > 0
                                              ? Styles.body2Bold
                                              : Styles.body2Bold.merge(
                                                  const TextStyle(
                                                    color: MyColors
                                                        .transparentWhite_40,
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        _totalUtxoAmountWidget(
                          Text(
                            key: _filterDropdownButtonKey,
                            _getCurrentFilter(),
                            style: Styles.caption2.merge(
                              const TextStyle(
                                color: MyColors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          isAfterScrolled: false,
                        ),
                      ],
                    ),
                  ),
                  ListView.separated(
                      physics: const NeverScrollableScrollPhysics(),
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(
                          top: 0, bottom: 30, left: 16, right: 16),
                      itemCount: _utxoList.length + 1,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        if (index < _utxoList.length) {
                          return UtxoSelectableCard(
                            utxo: _utxoList[index],
                            isSelected:
                                _selectedUtxoList.contains(_utxoList[index]),
                            onSelected: _toggleSelection,
                          );
                        } else {
                          return _isLoadingMore && !_isLastData
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: MyColors.white,
                                  ),
                                )
                              : const SizedBox();
                        }
                      }),
                ],
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_afterScrolledHeaderContainerVisible,
                child: Opacity(
                  opacity: _afterScrolledHeaderContainerVisible ? 1 : 0,
                  child: Container(
                    color: MyColors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    child: _totalUtxoAmountWidget(
                      Text(
                        key: _scrolledFilterDropdownButtonKey,
                        _getCurrentFilter(),
                        style: Styles.caption2.merge(
                          const TextStyle(
                            color: MyColors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      isAfterScrolled: true,
                    ),
                  ),
                ),
              ),
            ),
            if (_isFilterDropdownVisible && _utxoList.isNotEmpty) ...{
              Positioned(
                top: _filterDropdownButtonPosition.dy -
                    _scrollController.offset -
                    MediaQuery.of(context).padding.top -
                    20,
                left: 16,
                child: _filterDropDownWidget(),
              ),
            },
            if (_isScrolledFilterDropdownVisible && _utxoList.isNotEmpty) ...{
              Positioned(
                top: _scrolledFilterDropdownButtonPosition.dy -
                    MediaQuery.of(context).padding.top -
                    65,
                left: 16,
                child: _filterDropDownWidget(),
              ),
            }
          ],
        ),
      ),
    );
  }
}

class UtxoSelectableCard extends StatefulWidget {
  final model.UTXO utxo;
  final bool isSelected;
  final Function(model.UTXO) onSelected;

  const UtxoSelectableCard({
    super.key,
    required this.utxo,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  State<UtxoSelectableCard> createState() => _UtxoSelectableCardState();
}

class _UtxoSelectableCardState extends State<UtxoSelectableCard> {
  late bool _isPressing;
  late List<String> dateString;

  @override
  void initState() {
    super.initState();
    _isPressing = false;
    dateString = DateTimeUtil.formatDatetime(widget.utxo.timestamp).split('|');
    dateString[0] = dateString[0].replaceAll('.', '/');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        setState(() {
          _isPressing = true;
        });
      },
      onTapCancel: () {
        setState(() {
          _isPressing = false;
        });
      },
      onTap: () {
        setState(() {
          _isPressing = false;
        });
        widget.onSelected(widget.utxo);
      },
      child: Container(
        decoration: BoxDecoration(
          color: _isPressing ? MyColors.transparentWhite_10 : MyColors.black,
          borderRadius: BorderRadius.circular(
            20,
          ),
          border: Border.all(
            width: 1,
            color: widget.isSelected ? MyColors.primary : MyColors.borderGrey,
          ),
        ),
        padding: const EdgeInsets.only(
          top: 23,
          bottom: 22,
          left: 18,
          right: 23,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  satoshiToBitcoinString(widget.utxo.amount),
                  style: Styles.h2Number,
                ),
                const SizedBox(
                  height: 8,
                ),
                Row(
                  children: [
                    Text(
                      dateString[0],
                      style: Styles.caption,
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: MyColors.transparentWhite_40,
                      width: 1,
                      height: 10,
                    ),
                    Text(
                      dateString[1],
                      style: Styles.caption,
                    ),
                  ],
                )
              ],
            ),
            SvgPicture.asset(
              'assets/svg/circle-check.svg',
              colorFilter: ColorFilter.mode(
                  widget.isSelected
                      ? MyColors.primary
                      : MyColors.transparentWhite_40,
                  BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }
}
