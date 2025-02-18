import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
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
import 'package:coconut_wallet/widgets/dropdown/utxo_filter_dropdown.dart';
import 'package:coconut_wallet/widgets/overlays/custom_toast.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/selector/custom_tag_horizontal_selector.dart';
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
  final String allLabelName = t.all;
  final ScrollController _scrollController = ScrollController();

  late SendUtxoSelectionViewModel _viewModel;

  final List<UtxoOrderEnum> _utxoOrderOptions = [
    UtxoOrderEnum.byAmountDesc,
    UtxoOrderEnum.byAmountAsc,
    UtxoOrderEnum.byTimestampDesc,
    UtxoOrderEnum.byTimestampAsc,
  ];
  late UtxoOrderEnum _selectedUtxoOrder;

  final GlobalKey _orderDropdownButtonKey = GlobalKey();
  final GlobalKey _scrolledOrderDropdownButtonKey = GlobalKey();
  bool _isStickyHeaderVisible = false; // 스크롤시 상단에 붙어있는 위젯
  bool _isOrderDropdownVisible = false; // 필터 드롭다운(확장형)
  // bool _isScrolledOrderDropdownVisible = false; // 필터 드롭다운(축소형)
  late Offset _orderDropdownButtonPosition;
  // late Offset _scrolledOrderDropdownButtonPosition;
  final GlobalKey _headerTopContainerKey = GlobalKey();
  Size _headerTopContainerSize = const Size(0, 0);

  @override
  Widget build(BuildContext context) {
    // try-catch: initState _viewModel 생성 실패로 lateError 발생 할 수 있음
    try {
      return ChangeNotifierProxyProvider2<UpbitConnectModel,
          ConnectivityProvider, SendUtxoSelectionViewModel>(
        create: (_) => _viewModel,
        update: (_, upbitConnectModel, connectivityProvider, viewModel) {
          if (upbitConnectModel.bitcoinPriceKrw != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              viewModel!
                  .updateBitcoinPriceKrw(upbitConnectModel.bitcoinPriceKrw!);
            });
          }
          return viewModel!;
        },
        child: Consumer<SendUtxoSelectionViewModel>(
          builder: (context, viewModel, child) => Scaffold(
            appBar: CustomAppBar.buildWithNext(
                backgroundColor: MyColors.black,
                title: t.select_utxo,
                context: context,
                nextButtonTitle: t.complete,
                isActive: viewModel.estimatedFee != null &&
                    viewModel.estimatedFee != 0 &&
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
                                    onTapFeeButton: () =>
                                        _onTapFeeChangeButton(),
                                    isMaxMode: viewModel.isMaxMode,
                                    customFeeSelected:
                                        viewModel.customFeeSelected,
                                    sendAmount: viewModel.sendAmount,
                                    bitcoinPriceKrw: viewModel.bitcoinPriceKrw,
                                    estimatedFee: viewModel.estimatedFee,
                                    satsPerVb: viewModel.satsPerVb,
                                    change: viewModel.change,
                                  )),
                              _totalUtxoAmountWidget(
                                _orderDropdownButtonKey,
                                viewModel.errorState,
                                viewModel.selectedUtxoList.length,
                                viewModel.selectedUtxoAmountSum,
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
                      ignoring: !_isStickyHeaderVisible,
                      child: Opacity(
                        opacity: _isStickyHeaderVisible ? 1 : 0,
                        child: Container(
                          color: MyColors.black,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: _totalUtxoAmountWidget(
                            _scrolledOrderDropdownButtonKey,
                            viewModel.errorState,
                            viewModel.selectedUtxoList.length,
                            viewModel.selectedUtxoAmountSum,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_isOrderDropdownVisible &&
                      viewModel.confirmedUtxoList.isNotEmpty) ...{
                    UtxoFilterDropdown(
                      isVisible: _isOrderDropdownVisible,
                      positionTop: _orderDropdownButtonPosition.dy -
                          _scrollController.offset -
                          MediaQuery.of(context).padding.top -
                          (_isStickyHeaderVisible ? 20 : 16),
                      positionLeft: 16,
                      selectedFilter: _selectedUtxoOrder,
                      onSelected: (filter) async {
                        final isChanged = _selectedUtxoOrder != filter;
                        if (isChanged) {
                          _selectedUtxoOrder = filter;
                          _isOrderDropdownVisible = false;
                        }

                        if (!isChanged) return;
                        await Future.delayed(const Duration(milliseconds: 100));
                        if (mounted) {
                          _viewModel.changeUtxoOrder(filter);
                        }
                      },
                    ),
                  },
                ],
              ),
            ),
          ),
        ),
      );
    } catch (_) {
      return Container();
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
      _selectedUtxoOrder = _utxoOrderOptions[0];
      _viewModel = SendUtxoSelectionViewModel(
          Provider.of<WalletProvider>(context, listen: false),
          Provider.of<UtxoTagProvider>(context, listen: false),
          Provider.of<SendInfoProvider>(context, listen: false),
          Provider.of<ConnectivityProvider>(context, listen: false),
          Provider.of<UpbitConnectModel>(context, listen: false)
              .bitcoinPriceKrw,
          _selectedUtxoOrder);

      _scrollController.addListener(() {
        double threshold = _headerTopContainerSize.height + 24;
        double offset = _scrollController.offset;
        if (_isOrderDropdownVisible) {
          _setVisibleUtxoOrderDropdown(false);
        }
        setState(() {
          _isStickyHeaderVisible = offset >= threshold;
        });
      });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        RenderBox orderDropdownButtonRenderBox =
            _orderDropdownButtonKey.currentContext?.findRenderObject()
                as RenderBox;

        _orderDropdownButtonPosition =
            orderDropdownButtonRenderBox.localToGlobal(Offset.zero);

        RenderBox headerTopContainerRenderBox =
            _headerTopContainerKey.currentContext?.findRenderObject()
                as RenderBox;

        _headerTopContainerSize = headerTopContainerRenderBox.size;
      });
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        CustomDialogs.showCustomDialog(
          context,
          title: t.alert.error_occurs,
          description: t.alert.contact_admin(error: e.toString()),
          rightButtonColor: MyColors.white,
          onTapRight: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        );
      });
    }
  }

  void _deselectAll() {
    _setVisibleUtxoOrderDropdown(false);
    _viewModel.deselectAllUtxo();
  }

  void _goNext() {
    try {
      _viewModel.checkGoingNextAvailable();
    } catch (e) {
      CustomToast.showWarningToast(context: context, text: e.toString());
      return;
    }

    _setVisibleUtxoOrderDropdown(false);

    if (_viewModel.hasTaggedUtxo()) {
      CustomDialogs.showCustomDialog(
        context,
        title: t.alert.tag_apply.title,
        description: t.alert.tag_apply.description,
        rightButtonColor: CoconutColors.primary,
        rightButtonText: t.alert.tag_apply.btn_apply,
        leftButtonText: t.no,
        onTapLeft: () {
          Navigator.of(context).pop();
          _viewModel.saveUsedUtxoIdsWhenTagged(isTagsMoveAllowed: false);
          _moveToSendConfirm();
        },
        onTapRight: () {
          Navigator.of(context).pop();
          _viewModel.saveUsedUtxoIdsWhenTagged(isTagsMoveAllowed: true);
          _moveToSendConfirm();
        },
      );
    } else {
      _moveToSendConfirm();
    }
  }

  void _moveToSendConfirm() {
    Navigator.pushNamed(context, '/send-confirm');
  }

  void _onTapFeeChangeButton() async {
    Result<int, CoconutError>? minimumFeeRate =
        await _viewModel.getMinimumFeeRateFromNetwork();

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

  void _setVisibleUtxoOrderDropdown(bool visible) {
    setState(() {
      _isOrderDropdownVisible = visible;
    });
  }

  void _selectAll() {
    _setVisibleUtxoOrderDropdown(false);
    _viewModel.selectAllUtxo();
  }

  void _toggleSelection(UTXO utxo) {
    _setVisibleUtxoOrderDropdown(false);
    _viewModel.toggleUtxoSelection(utxo);
  }

  Widget _totalUtxoAmountWidget(GlobalKey dropdownKey, ErrorState? errorState,
      int selectedUtxoListLength, int totalSelectedUtxoAmount) {
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
                  t.utxo_total,
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
                  visible: selectedUtxoListLength != 0,
                  child: Text(
                    t.utxo_count(count: selectedUtxoListLength),
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
                        selectedUtxoListLength == 0
                            ? '0 ${t.btc}'
                            : '${satoshiToBitcoinString(totalSelectedUtxoAmount).normalizeToFullCharacters()} ${t.btc}',
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
            CoconutPulldown(
              key: dropdownKey,
              title: _selectedUtxoOrder.text,
              isOpen: _isOrderDropdownVisible,
              fontSize: 12,
              onChanged: (value) {
                if (value) {
                  _scrollController.jumpTo(_scrollController.offset);
                }
                _setVisibleUtxoOrderDropdown(value);
              },
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
                    text: t.unselect_all,
                    onTap: () {
                      _setVisibleUtxoOrderDropdown(false);
                      _deselectAll();
                    },
                  ),
                  SvgPicture.asset('assets/svg/row-divider.svg'),
                  CustomUnderlinedButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    text: t.select_all,
                    onTap: () async {
                      _setVisibleUtxoOrderDropdown(false);
                      _selectAll();
                    },
                  )
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }
}
