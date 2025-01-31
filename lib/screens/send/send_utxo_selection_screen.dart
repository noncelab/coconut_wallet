import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/model/app/error/app_error.dart';
import 'package:coconut_wallet/model/app/send/send_info.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/send_utxo_selection_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/fee_selection_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
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

  final GlobalKey _orderDropdownButtonKey = GlobalKey();
  final GlobalKey _scrolledOrderDropdownButtonKey = GlobalKey();
  bool _isStickyHeaderVisible = false; // 스크롤시 상단에 붙어있는 위젯
  bool _isOrderDropdownVisible = false; // 필터 드롭다운(확장형)
  bool _isScrolledOrderDropdownVisible = false; // 필터 드롭다운(축소형)
  late Offset _orderDropdownButtonPosition;
  late Offset _scrolledOrderDropdownButtonPosition;

  final GlobalKey _headerTopContainerKey = GlobalKey();
  Size _headerTopContainerSize = const Size(0, 0);

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
              isActive: viewModel.estimatedFee != null &&
                  viewModel.errorState == null,
              onNextPressed: () => _goNext()),
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
                              child: SendUtxoStickyHeader(
                                errorState: viewModel.errorState,
                                recommendedFeeFetchStatus:
                                    viewModel.recommendedFeeFetchStatus,
                                selectedLevel: viewModel.selectedLevel,
                                updateFeeInfoEstimatedFee: () {
                                  var result =
                                      viewModel.updateFeeInfoEstimateFee();
                                  if (result != true) {
                                    CustomToast.showWarningToast(
                                        context: context,
                                        text: ErrorCodes.withMessage(
                                                ErrorCodes.feeEstimationError,
                                                viewModel.errorString)
                                            .message);
                                  }
                                },
                                onTapFeeButton: () => _onTapFeeButton(),
                                isMaxMode: viewModel.isMaxMode,
                                customFeeSelected: viewModel.customFeeSelected,
                                sendAmount: viewModel.sendAmount,
                                bitcoinPriceKrw:
                                    viewModel.upbitConnectModel.bitcoinPriceKrw,
                                estimatedFee: viewModel.estimatedFee,
                                satsPerVb: viewModel.satsPerVb,
                                change: viewModel.change,
                              ),
                            ),
                            _totalUtxoAmountWidget(
                              Text(
                                key: _orderDropdownButtonKey,
                                _getCurrentOrder(),
                                style: Styles.caption2.merge(
                                  const TextStyle(
                                    color: MyColors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              viewModel.errorState,
                              viewModel.selectedUtxoList.isEmpty,
                              viewModel.selectedUtxoList.length,
                              () => satoshiToBitcoinString(
                                      _viewModel.calculateTotalAmountOfUtxoList(
                                          _viewModel.selectedUtxoList))
                                  .normalizeToFullCharacters(),
                            ),
                          ],
                        ),
                      ),
                      Visibility(
                        visible: !viewModel.isUtxoTagListEmpty,
                        child: Container(
                          margin: const EdgeInsets.only(left: 16, bottom: 12),
                          child: CustomTagHorizontalSelector(
                            tags: viewModel.utxoTagList
                                .map((e) => e.name)
                                .toList(),
                            onSelectedTag: (tagName) {
                              viewModel.setSelectedUtxoTagName(tagName);
                              setState(() {
                                _isStickyHeaderVisible = false;
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
                          itemCount: viewModel.confirmedUtxoList.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 0),
                          itemBuilder: (context, index) {
                            final utxo = viewModel.confirmedUtxoList[index];
                            final utxoHasSelectedTag = viewModel
                                        .selectedUtxoTagName ==
                                    allLabelName ||
                                viewModel.utxoTagMap[utxo.utxoId]?.any((e) =>
                                        e.name ==
                                        viewModel.selectedUtxoTagName) ==
                                    true;

                            if (utxoHasSelectedTag) {
                              if (viewModel.selectedUtxoTagName !=
                                      allLabelName &&
                                  !utxoHasSelectedTag) {
                                return const SizedBox();
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: SelectableUtxoItemCard(
                                  key: ValueKey(utxo.transactionHash),
                                  utxo: utxo,
                                  isSelected:
                                      viewModel.selectedUtxoList.contains(utxo),
                                  utxoTags: viewModel.utxoTagMap[utxo.utxoId],
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
                    ignoring: !_isStickyHeaderVisible,
                    child: Opacity(
                      opacity: _isStickyHeaderVisible ? 1 : 0,
                      child: Container(
                        color: MyColors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        child: _totalUtxoAmountWidget(
                          Text(
                            key: _scrolledOrderDropdownButtonKey,
                            _getCurrentOrder(),
                            style: Styles.caption2.merge(
                              const TextStyle(
                                color: MyColors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          viewModel.errorState,
                          viewModel.selectedUtxoList.isEmpty,
                          viewModel.selectedUtxoList.length,
                          () => satoshiToBitcoinString(
                                  _viewModel.calculateTotalAmountOfUtxoList(
                                      _viewModel.selectedUtxoList))
                              .normalizeToFullCharacters(),
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isOrderDropdownVisible &&
                    viewModel.confirmedUtxoList.isNotEmpty) ...{
                  Positioned(
                    top: _orderDropdownButtonPosition.dy -
                        _scrollController.offset -
                        MediaQuery.of(context).padding.top -
                        20,
                    left: 16,
                    child: _orderDropDownWidget(),
                  ),
                },
                if (_isScrolledOrderDropdownVisible &&
                    viewModel.confirmedUtxoList.isNotEmpty) ...{
                  Positioned(
                    top: _scrolledOrderDropdownButtonPosition.dy -
                        MediaQuery.of(context).padding.top -
                        65,
                    left: 16,
                    child: _orderDropDownWidget(),
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
        if (_isOrderDropdownVisible || _isScrolledOrderDropdownVisible) {
          _removeOrderDropdown();
        }
        setState(() {
          _isStickyHeaderVisible = offset >= threshold;
        });
      });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        RenderBox orderDropdownButtonRenderBox =
            _orderDropdownButtonKey.currentContext?.findRenderObject()
                as RenderBox;
        RenderBox scrolledOrderDropdownButtonRenderBox =
            _scrolledOrderDropdownButtonKey.currentContext?.findRenderObject()
                as RenderBox;
        _orderDropdownButtonPosition =
            orderDropdownButtonRenderBox.localToGlobal(Offset.zero);
        _scrolledOrderDropdownButtonPosition =
            scrolledOrderDropdownButtonRenderBox.localToGlobal(Offset.zero);

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

  void _applyOrder(UtxoOrderEnum orderEnum) async {
    if (orderEnum == _viewModel.selectedUtxoOrder) return;
    //_scrollController.jumpTo(0);
    _viewModel.setSelectedUtxoOrder(orderEnum);
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {
        UTXO.sortUTXO(_viewModel.confirmedUtxoList, orderEnum);
        _viewModel.addDisplayUtxoList();
      });
    }
  }

  void _deselectAll() {
    _removeOrderDropdown();
    _viewModel.clearUtxoList();
    if (!_viewModel.isMaxMode) {
      _viewModel.transaction = Transaction.fromUtxoList([],
          _viewModel.sendInfoProvider.recipientAddress!,
          UnitUtil.bitcoinToSatoshi(_viewModel.sendInfoProvider.amount!),
          _viewModel.satsPerVb ?? 1,
          _viewModel.walletBase!);
    }
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

  String _getCurrentOrder() {
    if (_viewModel.selectedUtxoOrder == UtxoOrderEnum.byTimestampDesc) {
      return '최신순';
    } else if (_viewModel.selectedUtxoOrder == UtxoOrderEnum.byTimestampAsc) {
      return '오래된 순';
    } else if (_viewModel.selectedUtxoOrder == UtxoOrderEnum.byAmountDesc) {
      return '큰 금액순';
    } else {
      return '작은 금액순';
    }
  }

  void _goNext() {
    _removeOrderDropdown();
    var connectivityProvider =
        Provider.of<ConnectivityProvider>(context, listen: false);
    if (connectivityProvider.isNetworkOn != true) {
      CustomToast.showWarningToast(
          context: context, text: ErrorCodes.networkError.message);
      return;
    }

    List<String> usedUtxoIds =
        _viewModel.selectedUtxoList.map((e) => e.utxoId).toList();

    bool isTagIncluded = usedUtxoIds.any((txHashIndex) =>
        _viewModel.utxoTagMap[txHashIndex]?.isNotEmpty == true);

    _viewModel.updateSendInfoProvider();

    if (isTagIncluded) {
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

  void _onTapFeeButton() async {
    if (_viewModel.errorState == null) {
      _viewModel.updateFeeInfoEstimateFee();
    }
    Result<int, CoconutError>? minimumFeeRate =
        await _viewModel.walletProvider.getMinimumNetworkFeeRate();

    if (!mounted) {
      return;
    }

    Map<String, dynamic>? feeSelectionResult =
        await CommonBottomSheets.showBottomSheet_90(
      context: context,
      child: FeeSelectionScreen(
          feeInfos: _viewModel.feeInfos,
          selectedFeeLevel: _viewModel.selectedLevel,
          networkMinimumFeeRate: minimumFeeRate?.value,
          customFeeInfo: _viewModel.customFeeInfo,
          isRecommendedFeeFetchSuccess: _viewModel.recommendedFeeFetchStatus ==
              RecommendedFeeFetchStatus.succeed,
          estimateFee: _viewModel.estimateFee),
    );
    if (feeSelectionResult != null) {
      _viewModel.onFeeRateChanged(feeSelectionResult);
    }
  }

  /// 필터 드롭다운 위젯
  Widget _orderDropDownWidget() {
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
              _applyOrder(UtxoOrderEnum.byAmountDesc);
              break;
            case 1: // 작은 금액순
              _applyOrder(UtxoOrderEnum.byAmountAsc);
              break;
            case 2: // 최신순
              _applyOrder(UtxoOrderEnum.byTimestampDesc);
              break;
            case 3: // 오래된 순
              _applyOrder(UtxoOrderEnum.byTimestampAsc);
              break;
          }
          setState(() {
            _isOrderDropdownVisible = _isScrolledOrderDropdownVisible = false;
          });
        },
        selectedButton: _viewModel.selectedUtxoOrder.text,
      ),
    );
  }

  void _removeOrderDropdown() {
    setState(() {
      _isOrderDropdownVisible = false;
      _isScrolledOrderDropdownVisible = false;
    });
  }

  void _selectAll() {
    _removeOrderDropdown();
    _viewModel.setSelectedUtxoList(List.from(_viewModel.confirmedUtxoList));

    if (!_viewModel.isMaxMode) {
      _viewModel.transaction = Transaction.fromUtxoList(
          _viewModel.selectedUtxoList,
          _viewModel.sendInfoProvider.recipientAddress!,
          UnitUtil.bitcoinToSatoshi(_viewModel.sendInfoProvider.amount!),
          _viewModel.satsPerVb ?? 1,
          _viewModel.walletBase!);
      if (_viewModel.estimatedFee != null &&
          _viewModel.isSelectedUtxoEnough()) {
        _viewModel
            .setEstimatedFee(_viewModel.estimateFee(_viewModel.satsPerVb!));
      }
    }
  }

  /// UTXO 선택 상태를 토글하는 함수
  void _toggleSelection(UTXO utxo) {
    _removeOrderDropdown();
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

  Widget _totalUtxoAmountWidget(
    Widget textKeyWidget,
    ErrorState? errorState,
    bool isSelectedUtxoListEmpty,
    int selectedUtxoListLength,
    Function calculateTotalAmountOfUtxoList,
  ) {
    return Column(
      children: [
        Container(
          width: MediaQuery.sizeOf(context).width,
          decoration: BoxDecoration(
            color: errorState == ErrorState.insufficientBalance ||
                    errorState == ErrorState.insufficientUtxo
                ? MyColors.transparentRed
                : MyColors.transparentWhite_10,
            borderRadius: BorderRadius.circular(24),
          ),
          margin: const EdgeInsets.only(
            top: 10,
          ),
          child: Container(
            padding: const EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: 20,
            ),
            child: Row(
              children: [
                Text(
                  'UTXO 합계',
                  style: Styles.body2Bold.merge(
                    TextStyle(
                        color: errorState == ErrorState.insufficientBalance ||
                                errorState == ErrorState.insufficientUtxo
                            ? MyColors.warningRed
                            : MyColors.white),
                  ),
                ),
                const SizedBox(
                  width: 4,
                ),
                Visibility(
                  visible: !isSelectedUtxoListEmpty,
                  child: Text(
                    '($selectedUtxoListLength개)',
                    style: Styles.caption.merge(
                      TextStyle(
                          fontFamily: 'Pretendard',
                          color: errorState == ErrorState.insufficientBalance ||
                                  errorState == ErrorState.insufficientUtxo
                              ? MyColors.transparentWarningRed
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
                        isSelectedUtxoListEmpty
                            ? '0 BTC'
                            : '${calculateTotalAmountOfUtxoList()} BTC',
                        style: Styles.body1Number.merge(TextStyle(
                            color: errorState ==
                                        ErrorState.insufficientBalance ||
                                    errorState == ErrorState.insufficientUtxo
                                ? MyColors.warningRed
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
        if (!_isStickyHeaderVisible) ...{
          Visibility(
            visible: errorState != null,
            maintainSize: true,
            maintainState: true,
            maintainAnimation: true,
            child: Text(
              errorState?.displayMessage ?? '',
              style: Styles.warning.merge(
                const TextStyle(
                  height: 16 / 12,
                  color: MyColors.warningRed,
                ),
              ),
              textAlign: TextAlign.center,
            ),
          )
        },
        AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeInOut,
            height: !_isStickyHeaderVisible ? 16 : 0),
        Visibility(
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          maintainSemantics: false,
          maintainInteractivity: false,
          child: Row(children: [
            CupertinoButton(
              onPressed: () {
                setState(
                  () {
                    if (_isStickyHeaderVisible
                        ? _isScrolledOrderDropdownVisible
                        : _isOrderDropdownVisible) {
                      _removeOrderDropdown();
                    } else {
                      _scrollController.jumpTo(_scrollController.offset);

                      if (_isStickyHeaderVisible) {
                        _isScrolledOrderDropdownVisible = true;
                      } else {
                        _isOrderDropdownVisible = true;
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
                  const SizedBox(
                    width: 16,
                  ),
                  CustomUnderlinedButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    text: '모두 해제',
                    onTap: () {
                      _removeOrderDropdown();
                      _deselectAll();
                    },
                  ),
                  SvgPicture.asset('assets/svg/row-divider.svg'),
                  CustomUnderlinedButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    text: '모두 선택',
                    onTap: () async {
                      _removeOrderDropdown();
                      _selectAll();
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
}
