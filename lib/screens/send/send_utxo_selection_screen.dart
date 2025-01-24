import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/model/app/error/app_error.dart';
import 'package:coconut_wallet/model/app/send/fee_info.dart';
import 'package:coconut_wallet/model/app/send/send_info.dart';
import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/send_utxo_selection_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/fee_selection_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/recommended_fee_util.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/card/selectable_utxo_item_card.dart';
import 'package:coconut_wallet/widgets/card/send_utxo_sticky_header.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:coconut_wallet/widgets/dropdown/custom_dropdown.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/selector/custom_tag_horizontal_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

enum RecommendedFeeFetchStatus { fetching, succeed, failed }

class SendUtxoSelectionScreen extends StatefulWidget {
  const SendUtxoSelectionScreen({
    super.key,
  });

  @override
  State<SendUtxoSelectionScreen> createState() =>
      _SendUtxoSelectionScreenState();
}

class _SendUtxoSelectionScreenState extends State<SendUtxoSelectionScreen> {
  final String allLabelName = '전체';

  late SendUtxoSelectionViewModel _viewModel;
  late final ScrollController _scrollController;

  // 선택된 태그
  late String _selectedUtxoTagName = allLabelName;

  final GlobalKey _filterDropdownButtonKey = GlobalKey();
  final GlobalKey _scrolledFilterDropdownButtonKey = GlobalKey();
  bool _positionedTopWidgetVisible = false; // 스크롤시 상단에 붙어있는 위젯
  bool _isFilterDropdownVisible = false; // 필터 드롭다운(확장형)
  bool _isScrolledFilterDropdownVisible = false; // 필터 드롭다운(축소형)
  late Offset _filterDropdownButtonPosition;
  late Offset _scrolledFilterDropdownButtonPosition;

  final GlobalKey _headerTopContainerKey = GlobalKey();
  Size _headerTopContainerSize = const Size(0, 0);

  UtxoOrderEnum _selectedFilter = UtxoOrderEnum.byAmountDesc;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Consumer<SendUtxoSelectionViewModel>(
        builder: (context, viewModel, child) => Scaffold(
          appBar: CustomAppBar.buildWithNext(
              backgroundColor: MyColors.black,
              title: 'UTXO 고르기',
              context: context,
              nextButtonTitle: '완료',
              isActive: _viewModel.estimatedFee != null &&
                  _viewModel.errorState == null,
              onNextPressed: goNext),
          body: ConstrainedBox(
            constraints:
                BoxConstraints(minHeight: MediaQuery.sizeOf(context).height),
            child: Stack(
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '보낼 수량',
                                        style: Styles.body2Bold,
                                      ),
                                      const Spacer(),
                                      Visibility(
                                        visible: _viewModel.isMaxMode,
                                        child: Container(
                                          padding:
                                              const EdgeInsets.only(bottom: 2),
                                          margin: const EdgeInsets.only(
                                              right: 4, bottom: 16),
                                          height: 24,
                                          width: 34,
                                          decoration: BoxDecoration(
                                            color: MyColors.defaultBackground,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '최대',
                                              style: Styles.caption2.copyWith(
                                                color: MyColors.white,
                                                letterSpacing: 0.1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${satoshiToBitcoinString(_viewModel.sendAmount).normalizeToFullCharacters()} BTC',
                                            style: Styles.body2Number,
                                          ),
                                          Selector<UpbitConnectModel, int?>(
                                            selector: (context, model) =>
                                                model.bitcoinPriceKrw,
                                            builder: (context, bitcoinPriceKrw,
                                                child) {
                                              return Text(
                                                  bitcoinPriceKrw != null
                                                      ? '${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(UnitUtil.bitcoinToSatoshi(_viewModel.sendInfoProvider.amount!), bitcoinPriceKrw).toDouble())} ${CurrencyCode.KRW.code}'
                                                      : '',
                                                  style: Styles.caption);
                                            },
                                          )
                                        ],
                                      ),
                                    ],
                                  ),
                                  _divider(
                                      padding: const EdgeInsets.only(
                                    top: 12,
                                    bottom: 16,
                                  )),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '수수료',
                                        style:
                                            _viewModel.recommendedFeeFetchStatus ==
                                                        RecommendedFeeFetchStatus
                                                            .failed &&
                                                    !_viewModel
                                                        .customFeeSelected
                                                ? Styles.body2Bold.merge(
                                                    const TextStyle(
                                                      color: MyColors
                                                          .transparentWhite_40,
                                                    ),
                                                  )
                                                : Styles.body2Bold,
                                      ),
                                      CustomUnderlinedButton(
                                          text: '변경',
                                          padding: const EdgeInsets.only(
                                            left: 8,
                                            top: 4,
                                            bottom: 8,
                                            right: 8,
                                          ),
                                          isEnable: _viewModel
                                                  .recommendedFeeFetchStatus !=
                                              RecommendedFeeFetchStatus
                                                  .fetching,
                                          onTap: () async {
                                            if (_viewModel.errorState == null) {
                                              _viewModel
                                                  .updateFeeInfoEstimateFee();
                                            }
                                            Result<int, CoconutError>?
                                                minimumFeeRate =
                                                await _viewModel.walletProvider
                                                    .getMinimumNetworkFeeRate();
                                            Map<String, dynamic>?
                                                feeSelectionResult =
                                                await CommonBottomSheets
                                                    .showBottomSheet_90(
                                              context: context,
                                              child: FeeSelectionScreen(
                                                  feeInfos: _viewModel.feeInfos,
                                                  selectedFeeLevel:
                                                      _viewModel.selectedLevel,
                                                  networkMinimumFeeRate:
                                                      minimumFeeRate?.value,
                                                  customFeeInfo:
                                                      _viewModel.customFeeInfo,
                                                  isRecommendedFeeFetchSuccess:
                                                      _viewModel
                                                              .recommendedFeeFetchStatus ==
                                                          RecommendedFeeFetchStatus
                                                              .succeed,
                                                  estimateFee:
                                                      _viewModel.estimateFee),
                                            );
                                            if (feeSelectionResult != null) {
                                              _viewModel.onFeeRateChanged(
                                                  feeSelectionResult);
                                            }
                                          }),
                                      Expanded(
                                          child: _viewModel
                                                          .recommendedFeeFetchStatus ==
                                                      RecommendedFeeFetchStatus
                                                          .failed &&
                                                  !_viewModel.customFeeSelected
                                              ? Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      '- ',
                                                      style: Styles.body2Bold
                                                          .merge(const TextStyle(
                                                              color: MyColors
                                                                  .transparentWhite_40)),
                                                    ),
                                                    Text(
                                                      'BTC',
                                                      style: Styles.body2Number
                                                          .merge(
                                                        const TextStyle(
                                                          color: MyColors
                                                              .transparentWhite_40,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : _viewModel.recommendedFeeFetchStatus ==
                                                          RecommendedFeeFetchStatus
                                                              .succeed ||
                                                      _viewModel
                                                          .customFeeSelected
                                                  ? Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      children: [
                                                        Text(
                                                          '${satoshiToBitcoinString(_viewModel.estimatedFee ?? 0).toString()} BTC',
                                                          style: Styles
                                                              .body2Number,
                                                        ),
                                                        if (_viewModel
                                                                .satsPerVb !=
                                                            null) ...{
                                                          Text(
                                                            '${_viewModel.selectedLevel?.expectedTime ?? ''} (${_viewModel.satsPerVb} sats/vb)',
                                                            style:
                                                                Styles.caption,
                                                          ),
                                                        },
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
                                                            color:
                                                                MyColors.white,
                                                            strokeWidth: 2,
                                                          ),
                                                        ),
                                                      ],
                                                    )),
                                    ],
                                  ),
                                  _divider(
                                    padding: const EdgeInsets.only(
                                      top: 10,
                                      bottom: 16,
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '잔돈',
                                        style: _viewModel.change != null
                                            ? (_viewModel.change! >= 0
                                                ? Styles.body2Bold
                                                : Styles.body2Bold.merge(
                                                    const TextStyle(
                                                        color: MyColors
                                                            .warningRed)))
                                            : Styles.body2Bold.merge(
                                                const TextStyle(
                                                  color: MyColors
                                                      .transparentWhite_40,
                                                ),
                                              ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              _viewModel.change != null
                                                  ? '${satoshiToBitcoinString(_viewModel.change!)} BTC'
                                                  : '- BTC',
                                              style: _viewModel.change != null
                                                  ? (_viewModel.change! >= 0
                                                      ? Styles.body2Number
                                                      : Styles.body2Number.merge(
                                                          const TextStyle(
                                                              color: MyColors
                                                                  .warningRed)))
                                                  : Styles.body2Number
                                                      .merge(const TextStyle(
                                                      color: MyColors
                                                          .transparentWhite_40,
                                                    )),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            SendUtxoStickyHeader(errorState: viewModel.errorState, recommendedFeeFetchStatus: viewModel.recommendedFeeFetchStatus, updateFeeInfoEstimatedFee: viewModel.updateFeeInfoEstimatedFee, onTapFeeButton: onTapFeeButton, isMaxMode: isMaxMode, customFeeSelected: customFeeSelected, sendAmount: sendAmount, bitcoinPriceKrw: bitcoinPriceKrw, estimatedFee: estimatedFee, satsPerVb: satsPerVb, change: change)
                          ],
                        ),
                      ),
                      Visibility(
                        visible: _viewModel.utxoTagList.isNotEmpty,
                        child: Container(
                          margin: const EdgeInsets.only(left: 16, bottom: 12),
                          child: CustomTagHorizontalSelector(
                            tags: _viewModel.utxoTagList
                                .map((e) => e.name)
                                .toList(),
                            onSelectedTag: (tagName) {
                              setState(() {
                                _selectedUtxoTagName = tagName;
                              });
                            },
                          ),
                        ),
                      ),
                      ListView.separated(
                          physics: const NeverScrollableScrollPhysics(),
                          shrinkWrap: true,
                          padding: const EdgeInsets.only(
                              top: 0, bottom: 30, left: 16, right: 16),
                          itemCount: _viewModel.confirmedUtxoList.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 0),
                          itemBuilder: (context, index) {
                            final utxo = _viewModel.confirmedUtxoList[index];
                            final utxoHasSelectedTag = _selectedUtxoTagName ==
                                    allLabelName ||
                                _viewModel.utxoTagMap[utxo.utxoId]?.any((e) =>
                                        e.name == _selectedUtxoTagName) ==
                                    true;

                            if (utxoHasSelectedTag) {
                              if (_selectedUtxoTagName != allLabelName &&
                                  !utxoHasSelectedTag) {
                                return const SizedBox();
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: SelectableUtxoItemCard(
                                  key: ValueKey(utxo.transactionHash),
                                  utxo: utxo,
                                  isSelected: _viewModel.selectedUtxoList
                                      .contains(utxo),
                                  utxoTags: _viewModel.utxoTagMap[utxo.utxoId],
                                  onSelected: _toggleSelection,
                                ),
                              );
                            } else {
                              return const SizedBox();
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
                    ignoring: !_positionedTopWidgetVisible,
                    child: Opacity(
                      opacity: _positionedTopWidgetVisible ? 1 : 0,
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
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isFilterDropdownVisible &&
                    _viewModel.confirmedUtxoList.isNotEmpty) ...{
                  Positioned(
                    top: _filterDropdownButtonPosition.dy -
                        _scrollController.offset -
                        MediaQuery.of(context).padding.top -
                        20,
                    left: 16,
                    child: _filterDropDownWidget(),
                  ),
                },
                if (_isScrolledFilterDropdownVisible &&
                    _viewModel.confirmedUtxoList.isNotEmpty) ...{
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
        ),
      ),
    );
  }

  Transaction createTransaction(
      bool isMaxMode, int feeRate, WalletBase walletBase) {
    if (isMaxMode) {
      return Transaction.forSweep(
          _viewModel.sendInfoProvider.recipientAddress!, feeRate, walletBase);
    }

    try {
      return Transaction.forPayment(
          _viewModel.sendInfoProvider.recipientAddress!,
          UnitUtil.bitcoinToSatoshi(_viewModel.sendInfoProvider.amount!),
          feeRate,
          walletBase);
    } catch (e) {
      if (e.toString().contains('Not enough amount for sending. (Fee')) {
        return Transaction.forSweep(
            _viewModel.sendInfoProvider.recipientAddress!, feeRate, walletBase);
      }

      rethrow;
    }
  }

  void deselectAll() {
    _removeFilterDropdown();
    _viewModel.clearUtxoList();
    if (!_viewModel.isMaxMode) {
      _viewModel.transaction = Transaction.fromUtxoList([],
          _viewModel.sendInfoProvider.recipientAddress!,
          UnitUtil.bitcoinToSatoshi(_viewModel.sendInfoProvider.amount!),
          _viewModel.satsPerVb ?? 1,
          _viewModel.walletBase!);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void goNext() {
    _removeFilterDropdown();
    var connectivityProvider =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (connectivityProvider.isNetworkOn != true) {
      CustomToast.showWarningToast(
          context: context, text: ErrorCodes.networkError.message);
      return;
    }

    List<String> usedUtxoIds =
        _viewModel.selectedUtxoList.map((e) => e.utxoId).toList();

    bool isIncludeTag = usedUtxoIds.any((txHashIndex) =>
        _viewModel.utxoTagMap[txHashIndex]?.isNotEmpty == true);

    if (isIncludeTag) {
      CustomDialogs.showCustomAlertDialog(
        context,
        title: '태그 적용',
        message: '기존 UTXO의 태그를 새 UTXO에도 적용하시겠어요?',
        onConfirm: () {
          Navigator.of(context).pop();
          _viewModel.tagProvider
              .recordUsedUtxoIdListWhenSend(usedUtxoIds, true);
          _moveToSendConfirm();
        },
        onCancel: () {
          Navigator.of(context).pop();
          _viewModel.tagProvider
              .recordUsedUtxoIdListWhenSend(usedUtxoIds, false);
          _moveToSendConfirm();
        },
        confirmButtonText: '적용하기',
        confirmButtonColor: MyColors.primary,
        cancelButtonText: '아니오',
      );
    } else {
      _moveToSendConfirm();
    }
  }

  @override
  void initState() {
    try {
      super.initState();
      _viewModel = SendUtxoSelectionViewModel(
        Provider.of<WalletProvider>(context, listen: false),
        Provider.of<UtxoTagProvider>(context, listen: false),
        Provider.of<SendInfoProvider>(context, listen: false),
        Provider.of<UpbitConnectModel>(context, listen: false),
      );

      _scrollController = ScrollController();

      _scrollController.addListener(() {
        double threshold = _headerTopContainerSize.height + 24;
        double offset = _scrollController.offset;
        if (_isFilterDropdownVisible || _isScrolledFilterDropdownVisible) {
          _removeFilterDropdown();
        }
        setState(() {
          _positionedTopWidgetVisible = offset >= threshold;
        });
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

        await _viewModel.setRecommendedFees();
        if (_viewModel.recommendedFeeFetchStatus ==
            RecommendedFeeFetchStatus.succeed) {
          _viewModel.updateFeeRate(_viewModel.satsPerVb!);
        }
      });
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        CustomDialogs.showCustomAlertDialog(
          context,
          title: '오류 발생',
          message: '관리자에게 문의하세요. ${e.toString()}',
          onConfirm: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        );
      });
    }
  }

  void selectAll() {
    _removeFilterDropdown();
    _viewModel.setSelectedUtxoList(List.from(_viewModel.confirmedUtxoList));

    if (!_viewModel.isMaxMode) {
      _viewModel.transaction = Transaction.fromUtxoList(
          _viewModel.selectedUtxoList,
          _viewModel.sendInfoProvider.recipientAddress!,
          UnitUtil.bitcoinToSatoshi(_viewModel.sendInfoProvider.amount!),
          _viewModel.satsPerVb ?? 1,
          _viewModel.walletBase!);
      _viewModel
          .setEstimatedFee(_viewModel.estimateFee(_viewModel.satsPerVb ?? 1));
    }
  }

  void _applyFilter(UtxoOrderEnum orderEnum) async {
    if (orderEnum == _selectedFilter) return;
    //_scrollController.jumpTo(0);
    setState(() {
      _selectedFilter = orderEnum;
      //_viewModel.selectedUtxoList.clear();
    });
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {
        UTXO.sortUTXO(_viewModel.confirmedUtxoList, orderEnum);
        _viewModel.addDisplayUtxoList();
      });
    }
  }

  int _calculateTotalAmountOfUtxoList(List<UTXO> utxos) {
    return utxos.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);
  }

  Widget _divider(
          {EdgeInsets padding = const EdgeInsets.symmetric(vertical: 12)}) =>
      Container(
        padding: padding,
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
        buttons: [
          UtxoOrderEnum.byAmountDesc.text,
          UtxoOrderEnum.byAmountAsc.text,
          UtxoOrderEnum.byTimestampDesc.text,
          UtxoOrderEnum.byTimestampAsc.text,
        ],
        dividerColor: Colors.black,
        onTapButton: (index) {
          switch (index) {
            case 0: // 큰 금액순
              _applyFilter(UtxoOrderEnum.byAmountDesc);
              break;
            case 1: // 작은 금액순
              _applyFilter(UtxoOrderEnum.byAmountAsc);
              break;
            case 2: // 최신순
              _applyFilter(UtxoOrderEnum.byTimestampDesc);
              break;
            case 3: // 오래된 순
              _applyFilter(UtxoOrderEnum.byTimestampAsc);
              break;
          }
          setState(() {
            _isFilterDropdownVisible = _isScrolledFilterDropdownVisible = false;
          });
        },
        selectedButton: _selectedFilter.text,
      ),
    );
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

  void _moveToSendConfirm() {
    Navigator.pushNamed(context, '/send-confirm', arguments: {
      'id': _viewModel.sendInfoProvider.walletId,
      'fullSendInfo': FullSendInfo(
          address: _viewModel.sendInfoProvider.recipientAddress!,
          amount: UnitUtil.satoshiToBitcoin(_viewModel.sendAmount),
          satsPerVb: _viewModel.satsPerVb!,
          estimatedFee: _viewModel.estimatedFee!,
          isMaxMode: _viewModel.isMaxMode,
          transaction: _viewModel.transaction)
    });
  }

  void _removeFilterDropdown() {
    setState(() {
      _isFilterDropdownVisible = false;
      _isScrolledFilterDropdownVisible = false;
    });
  }

  /// UTXO 선택 상태를 토글하는 함수
  void _toggleSelection(UTXO utxo) {
    _removeFilterDropdown();
    setState(() {
      if (_viewModel.selectedUtxoList.contains(utxo)) {
        if (!_viewModel.isMaxMode) {
          _viewModel.transaction!.removeInputWithUtxo(
              utxo, _viewModel.satsPerVb ?? 1, _viewModel.walletBase!,
              requiredSignature: _viewModel.requiredSignature,
              totalSinger: _viewModel.totalSigner);
        }

        // 모두 선택 시 List.from 으로 전체 리스트, 필터 리스트 구분 될 때
        // 라이브러리 UTXO에 copyWith 구현 필요함
        final keyToRemove = '${utxo.transactionHash}_${utxo.index}';

        _viewModel.setSelectedUtxoList(_viewModel.selectedUtxoList
            .fold<Map<String, UTXO>>({}, (map, utxo) {
              final key = '${utxo.transactionHash}_${utxo.index}';
              if (key != keyToRemove) {
                // 제거할 키가 아니면 추가
                map[key] = utxo;
              }
              return map;
            })
            .values
            .toList());

        if (_viewModel.estimatedFee != null &&
            _viewModel.isSelectedUtxoEnough()) {
          _viewModel
              .setEstimatedFee(_viewModel.estimateFee(_viewModel.satsPerVb!));
        }
      } else {
        if (!_viewModel.isMaxMode) {
          _viewModel.transaction!.addInputWithUtxo(
              utxo, _viewModel.satsPerVb ?? 1, _viewModel.walletBase!,
              requiredSignature: _viewModel.requiredSignature,
              totalSinger: _viewModel.totalSigner);
          _viewModel.setEstimatedFee(
              _viewModel.estimateFee(_viewModel.satsPerVb ?? 1));
        }
        _viewModel.selectedUtxoList.add(utxo);
      }
    });
  }
}
