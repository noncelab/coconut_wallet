import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/model/app/error/app_error.dart';
import 'package:coconut_wallet/model/app/send/send_info.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/send_utxo_selection_view_model.dart';
import 'package:coconut_wallet/screens/send/fee_selection_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/card/send_utxo_selection_selectable_item_card.dart';
import 'package:coconut_wallet/widgets/card/send_utxo_selection_header_item_card.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/custom_dropdown.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/selector/custom_tag_horizontal_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

enum ErrorState {
  insufficientBalance('잔액이 부족하여 수수료를 낼 수 없어요'),
  failedToFetchRecommendedFee(
      '추천 수수료를 조회하지 못했어요.\n\'변경\'버튼을 눌러서 수수료를 직접 입력해 주세요.'),
  insufficientUtxo('UTXO 합계가 모자라요');

  final String displayMessage;

  const ErrorState(this.displayMessage);
}

enum RecommendedFeeFetchStatus { fetching, succeed, failed }

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
  static const allLabelName = '전체';
  SendUtxoSelectionViewModel? _viewModel;
  late final ScrollController _scrollController;

  final GlobalKey _filterDropdownButtonKey = GlobalKey();
  final GlobalKey _scrolledFilterDropdownButtonKey = GlobalKey();
  final GlobalKey _headerTopContainerKey = GlobalKey();
  // final bool _positionedTopWidgetVisible = false; // 스크롤시 상단에 붙어있는 위젯
  bool _afterScrolledHeaderContainerVisible = false;
  bool _isFilterDropdownVisible = false; // 필터 드롭다운(확장형)
  bool _isScrolledFilterDropdownVisible = false; // 필터 드롭다운(축소형)
  late Offset _filterDropdownButtonPosition;
  late Offset _scrolledFilterDropdownButtonPosition;

  Size _headerTopContainerSize = const Size(0, 0);

  @override
  void initState() {
    try {
      super.initState();
      _scrollController = ScrollController();

      _scrollController.addListener(() {
        double threshold = _headerTopContainerSize.height + 24;
        double offset = _scrollController.offset;
        if (_isFilterDropdownVisible || _isScrolledFilterDropdownVisible) {
          _removeFilterDropdown();
        }
        setState(() {
          _afterScrolledHeaderContainerVisible = offset >= threshold;
        });
      });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        _viewModel?.initUtxoTagScreenTagData();

        RenderBox filterDropdownButtonRenderBox =
            _filterDropdownButtonKey.currentContext?.findRenderObject()
                as RenderBox;
        RenderBox scrolledFilterDropdownButtonRenderBox =
            _scrolledFilterDropdownButtonKey.currentContext?.findRenderObject()
                as RenderBox;
        RenderBox headerTopContainerRenderBox =
            _headerTopContainerKey.currentContext?.findRenderObject()
                as RenderBox;

        _filterDropdownButtonPosition =
            filterDropdownButtonRenderBox.localToGlobal(Offset.zero);
        _scrolledFilterDropdownButtonPosition =
            scrolledFilterDropdownButtonRenderBox.localToGlobal(Offset.zero);
        _headerTopContainerSize = headerTopContainerRenderBox.size;

        await _viewModel?.setRecommendedFees();
        if (_viewModel?.recommendedFeeFetchStatus ==
            RecommendedFeeFetchStatus.succeed) {
          _viewModel?.updateFeeRate(_viewModel?.satsPerVb ?? 0);
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider<UpbitConnectModel,
        SendUtxoSelectionViewModel>(
      create: (_) => SendUtxoSelectionViewModel(
        Provider.of<AppStateModel>(_, listen: false),
        Provider.of<UpbitConnectModel>(_, listen: false),
        widget.id,
        widget.sendInfo,
      ),
      update: (_, upbitConnectModel, viewModel) {
        return viewModel!..updateUpbitConnectModel(upbitConnectModel);
      },
      child: Consumer<SendUtxoSelectionViewModel>(
        builder: (context, viewModel, child) {
          _viewModel ??= viewModel;
          if (viewModel.isErrorInUpdateFeeInfoEstimateFee) {
            WidgetsBinding.instance.addPostFrameCallback((duration) {
              CustomToast.showWarningToast(
                  context: context,
                  text: ErrorCodes.withMessage(
                          ErrorCodes.feeEstimationError, viewModel.errorString)
                      .message);
            });
          }
          return Scaffold(
            appBar: CustomAppBar.buildWithNext(
                backgroundColor: MyColors.black,
                title: 'UTXO 고르기',
                context: context,
                nextButtonTitle: '완료',
                isActive: viewModel.estimatedFee != null &&
                    viewModel.errorState == null,
                onNextPressed: () => _goNext(viewModel)),
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
                                child: SendUtxoSelectionHeaderItemCard(
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
                                  onTapFeeButton: () =>
                                      _onTapFeeButton(viewModel),
                                  isMaxMode: viewModel.isMaxMode,
                                  customFeeSelected:
                                      viewModel.customFeeSelected,
                                  sendAmount: viewModel.sendAmount,
                                  bitcoinPriceKrw: viewModel
                                      .upbitConnectModel.bitcoinPriceKrw,
                                  estimatedFee: viewModel.estimatedFee,
                                  satsPerVb: viewModel.satsPerVb,
                                  change: viewModel.change,
                                ),
                              ),
                              _totalUtxoAmountWidget(
                                Text(
                                  key: _filterDropdownButtonKey,
                                  _getCurrentFilter(
                                      viewModel.selectedUtxoOrder),
                                  style: Styles.caption2.merge(
                                    const TextStyle(
                                      color: MyColors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                viewModel,
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
                                  _afterScrolledHeaderContainerVisible = false;
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
                                  child: SendUtxoSelectionSelectableItemCard(
                                    key: ValueKey(utxo.transactionHash),
                                    utxo: utxo,
                                    isSelected: viewModel.selectedUtxoList
                                        .contains(utxo),
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
                              _getCurrentFilter(viewModel.selectedUtxoOrder),
                              style: Styles.caption2.merge(
                                const TextStyle(
                                  color: MyColors.white,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            viewModel,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_isFilterDropdownVisible &&
                      viewModel.confirmedUtxoList.isNotEmpty) ...{
                    Positioned(
                      top: _filterDropdownButtonPosition.dy -
                          _scrollController.offset -
                          MediaQuery.of(context).padding.top -
                          20,
                      left: 16,
                      child: _filterDropDownWidget(
                          viewModel.selectedUtxoOrder.text),
                    ),
                  },
                  if (_isScrolledFilterDropdownVisible &&
                      viewModel.confirmedUtxoList.isNotEmpty) ...{
                    Positioned(
                      top: _scrolledFilterDropdownButtonPosition.dy -
                          MediaQuery.of(context).padding.top -
                          65,
                      left: 16,
                      child: _filterDropDownWidget(
                          viewModel.selectedUtxoOrder.text),
                    ),
                  }
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _goNext(SendUtxoSelectionViewModel viewModel) {
    _removeFilterDropdown();
    if (viewModel.appStateModel.isNetworkOn != true) {
      CustomToast.showWarningToast(
          context: context, text: ErrorCodes.networkError.message);
      return;
    }

    List<String> usedUtxoIds =
        viewModel.selectedUtxoList.map((e) => e.utxoId).toList();

    bool isIncludeTag = usedUtxoIds.any(
        (txHashIndex) => viewModel.utxoTagMap[txHashIndex]?.isNotEmpty == true);

    if (isIncludeTag) {
      CustomDialogs.showCustomAlertDialog(
        context,
        title: '태그 적용',
        message: '기존 UTXO의 태그를 새 UTXO에도 적용하시겠어요?',
        onConfirm: () {
          Navigator.of(context).pop();
          viewModel.appStateModel.recordUsedUtxoIdListWhenSend(usedUtxoIds);
          viewModel.appStateModel.allowTagToMove();
          _moveToSendConfirm(viewModel);
        },
        onCancel: () {
          Navigator.of(context).pop();
          viewModel.appStateModel.recordUsedUtxoIdListWhenSend(usedUtxoIds);
          _moveToSendConfirm(viewModel);
        },
        confirmButtonText: '적용하기',
        confirmButtonColor: MyColors.primary,
        cancelButtonText: '아니오',
      );
    } else {
      _moveToSendConfirm(viewModel);
    }
  }

  void _applyOrder(UtxoOrderEnum orderEnum) async {
    if (orderEnum == _viewModel?.selectedUtxoOrder) return;
    //_scrollController.jumpTo(0);
    _viewModel?.setSelectedUtxoOrder(orderEnum);
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {
        UTXO.sortUTXO(_viewModel?.confirmedUtxoList ?? [], orderEnum);
        _viewModel?.addDisplayUtxoList();
      });
    }
  }

  void _deselectAll(SendUtxoSelectionViewModel viewModel) {
    _removeFilterDropdown();
    viewModel.clearUtxoList();
    if (!viewModel.isMaxMode) {
      viewModel.transaction = Transaction.fromUtxoList([],
          widget.sendInfo.address,
          UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount),
          viewModel.satsPerVb ?? 1,
          viewModel.walletBase!);
    }
  }

  /// 필터 드롭다운 위젯
  Widget _filterDropDownWidget(String selectedUtxoOrder) {
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
            _isFilterDropdownVisible = _isScrolledFilterDropdownVisible = false;
          });
        },
        selectedButton: selectedUtxoOrder,
      ),
    );
  }

  String _getCurrentFilter(UtxoOrderEnum selectedUtxoOrder) {
    if (selectedUtxoOrder == UtxoOrderEnum.byTimestampDesc) {
      return '최신순';
    } else if (selectedUtxoOrder == UtxoOrderEnum.byTimestampAsc) {
      return '오래된 순';
    } else if (selectedUtxoOrder == UtxoOrderEnum.byAmountDesc) {
      return '큰 금액순';
    } else {
      return '작은 금액순';
    }
  }

  void _moveToSendConfirm(SendUtxoSelectionViewModel viewModel) {
    Navigator.pushNamed(context, '/send-confirm', arguments: {
      'id': widget.id,
      'fullSendInfo': FullSendInfo(
          address: widget.sendInfo.address,
          amount: UnitUtil.satoshiToBitcoin(viewModel.sendAmount),
          satsPerVb: viewModel.satsPerVb!,
          estimatedFee: viewModel.estimatedFee!,
          isMaxMode: viewModel.isMaxMode,
          transaction: viewModel.transaction)
    });
  }

  void _onTapFeeButton(SendUtxoSelectionViewModel viewModel) async {
    if (viewModel.errorState == null) {
      viewModel.updateFeeInfoEstimateFee();
    }
    Result<int, CoconutError>? minimumFeeRate =
        await viewModel.appStateModel.getMinimumNetworkFeeRate();

    if (!mounted) {
      return;
    }

    Map<String, dynamic>? feeSelectionResult =
        await CommonBottomSheets.showBottomSheet_90(
      context: context,
      child: FeeSelectionScreen(
          feeInfos: viewModel.feeInfos,
          selectedFeeLevel: viewModel.selectedLevel,
          networkMinimumFeeRate: minimumFeeRate?.value,
          customFeeInfo: viewModel.customFeeInfo,
          isRecommendedFeeFetchSuccess: viewModel.recommendedFeeFetchStatus ==
              RecommendedFeeFetchStatus.succeed,
          estimateFee: viewModel.estimateFee),
    );
    if (feeSelectionResult != null) {
      viewModel.onFeeRateChanged(feeSelectionResult);
    }
  }

  void _removeFilterDropdown() {
    setState(() {
      _isFilterDropdownVisible = false;
      _isScrolledFilterDropdownVisible = false;
    });
  }

  void _selectAll(SendUtxoSelectionViewModel viewModel) {
    _removeFilterDropdown();
    viewModel.setSelectedUtxoList(List.from(viewModel.confirmedUtxoList));

    if (!viewModel.isMaxMode) {
      viewModel.transaction = Transaction.fromUtxoList(
          viewModel.selectedUtxoList,
          widget.sendInfo.address,
          UnitUtil.bitcoinToSatoshi(widget.sendInfo.amount),
          viewModel.satsPerVb ?? 1,
          viewModel.walletBase!);
      viewModel.setEstimatedFee(viewModel.satsPerVb ?? 1);
    }
  }

  /// UTXO 선택 상태를 토글하는 함수
  void _toggleSelection(UTXO utxo) {
    _removeFilterDropdown();
    if (_viewModel!.selectedUtxoList.contains(utxo)) {
      if (!_viewModel!.isMaxMode) {
        _viewModel!.transaction!.removeInputWithUtxo(
            utxo, _viewModel!.satsPerVb ?? 1, _viewModel!.walletBase!,
            requiredSignature: _viewModel!.requiredSignature,
            totalSinger: _viewModel!.totalSigner);
      }

      // 모두 선택 시 List.from 으로 전체 리스트, 필터 리스트 구분 될 때
      // 라이브러리 UTXO에 copyWith 구현 필요함
      final keyToRemove = '${utxo.transactionHash}_${utxo.index}';

      _viewModel!.setSelectedUtxoList(_viewModel!.selectedUtxoList
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

      if (_viewModel!.estimatedFee != null &&
          _viewModel!.isSelectedUtxoEnough()) {
        _viewModel!
            .setEstimatedFee(_viewModel!.estimateFee(_viewModel!.satsPerVb!));
      }
    } else {
      if (!_viewModel!.isMaxMode) {
        _viewModel!.transaction!.addInputWithUtxo(
            utxo, _viewModel!.satsPerVb ?? 1, _viewModel!.walletBase!,
            requiredSignature: _viewModel!.requiredSignature,
            totalSinger: _viewModel!.totalSigner);
        _viewModel!.setEstimatedFee(
            _viewModel!.estimateFee(_viewModel!.satsPerVb ?? 1));
      }
      _viewModel!.addSelectedUtxoList(utxo);
    }
  }

  Widget _totalUtxoAmountWidget(
      Widget textKeyWidget, SendUtxoSelectionViewModel viewModel) {
    return Column(
      children: [
        Container(
          width: MediaQuery.sizeOf(context).width,
          decoration: BoxDecoration(
            color: viewModel.errorState == ErrorState.insufficientBalance ||
                    viewModel.errorState == ErrorState.insufficientUtxo
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
                        color: viewModel.errorState ==
                                    ErrorState.insufficientBalance ||
                                viewModel.errorState ==
                                    ErrorState.insufficientUtxo
                            ? MyColors.warningRed
                            : MyColors.white),
                  ),
                ),
                const SizedBox(
                  width: 4,
                ),
                Visibility(
                  visible: viewModel.selectedUtxoList.isNotEmpty,
                  child: Text(
                    '(${viewModel.selectedUtxoList.length}개)',
                    style: Styles.caption.merge(
                      TextStyle(
                          fontFamily: 'Pretendard',
                          color: viewModel.errorState ==
                                      ErrorState.insufficientBalance ||
                                  viewModel.errorState ==
                                      ErrorState.insufficientUtxo
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
                        viewModel.selectedUtxoList.isEmpty
                            ? '0 BTC'
                            : '${satoshiToBitcoinString(viewModel.calculateTotalAmountOfUtxoList(viewModel.selectedUtxoList)).normalizeToFullCharacters()} BTC',
                        style: Styles.body1Number.merge(TextStyle(
                            color: viewModel.errorState ==
                                        ErrorState.insufficientBalance ||
                                    viewModel.errorState ==
                                        ErrorState.insufficientUtxo
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
        if (!_afterScrolledHeaderContainerVisible) ...{
          Visibility(
            visible: viewModel.errorState != null,
            maintainSize: true,
            maintainState: true,
            maintainAnimation: true,
            child: Text(
              viewModel.errorState?.displayMessage ?? '',
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
            height: !_afterScrolledHeaderContainerVisible ? 16 : 0),
        Visibility(
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          maintainSemantics: false,
          maintainInteractivity: false,
          // visible: !_positionedTopWidgetVisible,
          child: Row(children: [
            CupertinoButton(
              onPressed: () {
                setState(
                  () {
                    if (_afterScrolledHeaderContainerVisible
                        ? _isScrolledFilterDropdownVisible
                        : _isFilterDropdownVisible) {
                      _removeFilterDropdown();
                    } else {
                      _scrollController.jumpTo(_scrollController.offset);

                      if (_afterScrolledHeaderContainerVisible) {
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
                  const SizedBox(
                    width: 16,
                  ),
                  CustomUnderlinedButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    text: '모두 해제',
                    onTap: () {
                      _removeFilterDropdown();
                      _deselectAll(viewModel);
                    },
                  ),
                  SvgPicture.asset('assets/svg/row-divider.svg'),
                  CustomUnderlinedButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    text: '모두 선택',
                    onTap: () async {
                      _removeFilterDropdown();
                      _selectAll(viewModel);
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
