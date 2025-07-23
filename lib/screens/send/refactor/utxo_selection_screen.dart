import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/refactor/utxo_selection_view_model.dart';
import 'package:coconut_wallet/providers/view_model/send/send_utxo_selection_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/card/locked_utxo_item_card.dart';
import 'package:coconut_wallet/widgets/card/selectable_utxo_item_card.dart';
import 'package:coconut_wallet/widgets/card/utxo_item_card.dart';
import 'package:coconut_wallet/widgets/custom_dialogs.dart';
import 'package:coconut_wallet/widgets/overlays/network_error_tooltip.dart';
import 'package:coconut_wallet/widgets/selector/custom_tag_horizontal_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class UtxoSelectionScreen extends StatefulWidget {
  final List<UtxoState> selectedUtxoList;
  final int walletId;
  final BitcoinUnit currentUnit;

  const UtxoSelectionScreen({
    super.key,
    required this.currentUnit,
    required this.selectedUtxoList,
    required this.walletId,
  });

  @override
  State<UtxoSelectionScreen> createState() => _UtxoSelectionScreenState();
}

class _UtxoSelectionScreenState extends State<UtxoSelectionScreen> {
  final String allLabelName = t.all;
  final ScrollController _scrollController = ScrollController();
  late UtxoSelectionViewModel _viewModel;

  final List<UtxoOrder> _utxoOrderOptions = [
    UtxoOrder.byAmountDesc,
    UtxoOrder.byAmountAsc,
    UtxoOrder.byTimestampDesc,
    UtxoOrder.byTimestampAsc,
  ];
  late UtxoOrder _selectedUtxoOrder;

  final GlobalKey _orderDropdownButtonKey = GlobalKey();
  final GlobalKey _scrolledOrderDropdownButtonKey = GlobalKey();
  bool _isStickyHeaderVisible = false; // 스크롤시 상단에 붙어있는 위젯
  bool _isOrderDropdownVisible = false; // 필터 드롭다운(확장형)
  bool _isScrolledOrderDropdownVisible = false; // 필터 드롭다운(축소형)
  late Offset _orderDropdownButtonPosition;
  late Offset _scrolledOrderDropdownButtonPosition;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider<ConnectivityProvider, UtxoSelectionViewModel>(
      create: (_) => _viewModel,
      update: (_, connectivityProvider, viewModel) {
        if (connectivityProvider.isNetworkOn != viewModel!.isNetworkOn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            viewModel.setIsNetworkOn(connectivityProvider.isNetworkOn);
          });
        }
        return viewModel;
      },
      child: Consumer<UtxoSelectionViewModel>(
        builder: (context, viewModel, child) => Scaffold(
          appBar: CoconutAppBar.build(
            backgroundColor: CoconutColors.black,
            title: t.utxo_selection_screen.title,
            context: context,
            onBackPressed: () => Navigator.pop(context),
          ),
          body: Column(
            children: [
              Visibility(
                visible: !viewModel.isNetworkOn,
                maintainSize: false,
                maintainAnimation: false,
                maintainState: false,
                child: NetworkErrorTooltip(
                  isNetworkOn: viewModel.isNetworkOn,
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        children: [
                          _buildSendInfoHeader(
                            viewModel,
                          ),
                          _buildUtxoTagList(viewModel),
                          _buildUtxoList(viewModel),
                          CoconutLayout.spacing_400h,
                          const SizedBox(height: 50)
                        ],
                      ),
                    ),
                    _buildStickyHeader(viewModel),
                    _buildUtxoOrderDropdown(viewModel),
                    FixedBottomButton(
                      buttonHeight: 50,
                      onButtonClicked: () {
                        vibrateLight();
                        Navigator.pop(context, _viewModel.selectedUtxoList);
                      },
                      text: t.complete,
                      isActive: _viewModel.hasSelectionChanged,
                      showGradient: true,
                      gradientPadding:
                          const EdgeInsets.only(left: 16, right: 16, bottom: 40, top: 110),
                      horizontalPadding: 16,
                      backgroundColor: CoconutColors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      _viewModel = UtxoSelectionViewModel(
          Provider.of<WalletProvider>(context, listen: false),
          Provider.of<UtxoTagProvider>(context, listen: false),
          Provider.of<PriceProvider>(context, listen: false),
          Provider.of<ConnectivityProvider>(context, listen: false).isNetworkOn,
          widget.walletId,
          widget.selectedUtxoList,
          _selectedUtxoOrder);

      _scrollController.addListener(() {
        double threshold = /*_headerTopContainerSize.height +*/ 24;
        double offset = _scrollController.offset;
        if ((_isOrderDropdownVisible || _isScrolledOrderDropdownVisible) && offset > 0) {
          _removeUtxoOrderDropdown();
        }
        setState(() {
          _isStickyHeaderVisible = offset >= threshold;
        });
      });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        RenderBox orderDropdownButtonRenderBox =
            _orderDropdownButtonKey.currentContext?.findRenderObject() as RenderBox;
        RenderBox scrolledOrderDropdownButtonRenderBox =
            _scrolledOrderDropdownButtonKey.currentContext?.findRenderObject() as RenderBox;
        _orderDropdownButtonPosition = orderDropdownButtonRenderBox.localToGlobal(Offset.zero);
        _scrolledOrderDropdownButtonPosition =
            scrolledOrderDropdownButtonRenderBox.localToGlobal(Offset.zero);
      });
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        CustomDialogs.showCustomAlertDialog(
          context,
          title: t.alert.error_occurs,
          message: t.alert.contact_admin(error: e.toString()),
          onConfirm: () {
            Navigator.of(context).pop();
            Navigator.of(context).pop();
          },
        );
      });
    }
  }

  void _deselectAll() {
    _removeUtxoOrderDropdown();
    _viewModel.deselectAllUtxo();
  }

  void _removeUtxoOrderDropdown() {
    setState(() {
      _isOrderDropdownVisible = false;
      _isScrolledOrderDropdownVisible = false;
    });
  }

  void _selectAll() {
    _removeUtxoOrderDropdown();
    _viewModel.selectAllUtxo();
  }

  void _toggleSelection(UtxoState utxo) {
    _removeUtxoOrderDropdown();
    _viewModel.toggleUtxoSelection(utxo);
  }

  Widget _buildTotalUtxoAmount(Widget textKeyWidget, ErrorState? errorState,
      int selectedUtxoListLength, int totalSelectedUtxoAmount) {
    String utxoSumText = widget.currentUnit
        .displayBitcoinAmount(totalSelectedUtxoAmount, defaultWhenZero: '0', shouldCheckZero: true);
    String unitText = widget.currentUnit.symbol;

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
                            : CoconutColors.white),
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
                        "$utxoSumText $unitText",
                        style: Styles.body1Number.merge(TextStyle(
                            color: errorState == ErrorState.insufficientBalance ||
                                    errorState == ErrorState.insufficientUtxo
                                ? MyColors.warningRed
                                : CoconutColors.white,
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
                      _removeUtxoOrderDropdown();
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
                    colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
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
                    text: t.unselect_all,
                    isEnable: true,
                    onTap: () {
                      _removeUtxoOrderDropdown();
                      _deselectAll();
                    },
                  ),
                  SvgPicture.asset('assets/svg/row-divider.svg'),
                  CustomUnderlinedButton(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    text: t.select_all,
                    isEnable: true,
                    onTap: () async {
                      _removeUtxoOrderDropdown();
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

  Widget _utxoOrderDropdownMenu() {
    return Material(
      borderRadius: BorderRadius.circular(16),
      child: CoconutPulldownMenu(
        entries:
            _utxoOrderOptions.map((order) => CoconutPulldownMenuItem(title: order.text)).toList(),
        shadowColor: CoconutColors.gray800,
        dividerColor: CoconutColors.gray800,
        onSelected: (index, selectedText) async {
          bool isChanged = _selectedUtxoOrder != _utxoOrderOptions[index];
          setState(() {
            if (isChanged) {
              _selectedUtxoOrder = _utxoOrderOptions[index];
            }
            _isOrderDropdownVisible = _isScrolledOrderDropdownVisible = false;
          });

          if (!isChanged) return;
          await Future.delayed(const Duration(milliseconds: 100));
          if (mounted) {
            _viewModel.changeUtxoOrder(_utxoOrderOptions[index]);
          }
        },
        selectedIndex: _getIndexBySelectedFilter(),
      ),
    );
  }

  int _getIndexBySelectedFilter() {
    switch (_selectedUtxoOrder) {
      case UtxoOrder.byAmountDesc:
        return 0;
      case UtxoOrder.byAmountAsc:
        return 1;
      case UtxoOrder.byTimestampDesc:
        return 2;
      case UtxoOrder.byTimestampAsc:
        return 3;
    }
  }

  Widget _buildStickyHeader(UtxoSelectionViewModel viewModel) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !_isStickyHeaderVisible,
        child: Opacity(
          opacity: _isStickyHeaderVisible ? 1 : 0,
          child: Container(
            color: CoconutColors.black,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child: _buildTotalUtxoAmount(
              Text(
                key: _scrolledOrderDropdownButtonKey,
                _selectedUtxoOrder.text,
                style: Styles.caption2.merge(
                  const TextStyle(
                    color: CoconutColors.white,
                    fontSize: 12,
                  ),
                ),
              ),
              null,
              viewModel.selectedUtxoList.length,
              viewModel.selectedUtxoAmountSum,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUtxoOrderDropdown(UtxoSelectionViewModel viewModel) {
    if (_isOrderDropdownVisible && viewModel.confirmedUtxoList.isNotEmpty) {
      return Positioned(
        top: _orderDropdownButtonPosition.dy -
            _scrollController.offset -
            MediaQuery.of(context).padding.top,
        left: 16,
        child: _utxoOrderDropdownMenu(),
      );
    }

    if (_isScrolledOrderDropdownVisible && viewModel.confirmedUtxoList.isNotEmpty) {
      return Positioned(
        top: _scrolledOrderDropdownButtonPosition.dy - MediaQuery.of(context).padding.top - 55,
        left: 16,
        child: _utxoOrderDropdownMenu(),
      );
    }
    return Container();
  }

  Widget _buildUtxoTagList(UtxoSelectionViewModel viewModel) {
    return Visibility(
      visible: !viewModel.isUtxoTagListEmpty,
      child: Container(
        margin: const EdgeInsets.only(left: 4, bottom: 12),
        child: CustomTagHorizontalSelector(
          tags: viewModel.utxoTagList.map((e) => e.name).toList(),
          showDefaultTags: false,
          selectedName: viewModel.selectedUtxoTagName,
          onSelectedTag: (tagName) {
            viewModel.setSelectedUtxoTagName(tagName);
            setState(() {
              _isStickyHeaderVisible = false;
            });
          },
        ),
      ),
    );
  }

  Widget _buildUtxoList(UtxoSelectionViewModel viewModel) {
    return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.only(top: 0, bottom: 30, left: 16, right: 16),
        itemCount: viewModel.confirmedUtxoList.length,
        separatorBuilder: (context, index) => const SizedBox(height: 0),
        itemBuilder: (context, index) {
          final utxo = viewModel.confirmedUtxoList[index];
          final utxoHasSelectedTag = viewModel.selectedUtxoTagName == allLabelName ||
              viewModel.utxoTagMap[utxo.utxoId]
                      ?.any((e) => e.name == viewModel.selectedUtxoTagName) ==
                  true;

          if (utxoHasSelectedTag) {
            if (viewModel.selectedUtxoTagName != allLabelName && !utxoHasSelectedTag) {
              return const SizedBox();
            }

            if (utxo.isLocked) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                child: LockedUtxoItemCard(
                  key: ValueKey(utxo.transactionHash),
                  utxo: utxo,
                  utxoTags: viewModel.utxoTagMap[utxo.utxoId],
                  currentUnit: widget.currentUnit,
                ),
              );
            }
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              child: SelectableUtxoItemCard(
                key: ValueKey(utxo.transactionHash),
                currentUnit: widget.currentUnit,
                utxo: utxo,
                isSelectable: true,
                isSelected: viewModel.selectedUtxoList.contains(utxo),
                utxoTags: viewModel.utxoTagMap[utxo.utxoId],
                onSelected: _toggleSelection,
              ),
            );
          } else {
            return const SizedBox();
          }
        });
  }

  Widget _buildSendInfoHeader(UtxoSelectionViewModel viewModel) {
    return Container(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12,
      ),
      alignment: Alignment.center,
      color: CoconutColors.black,
      child: _buildTotalUtxoAmount(
        Text(
          key: _orderDropdownButtonKey,
          _selectedUtxoOrder.text,
          style: Styles.caption2.merge(
            const TextStyle(
              color: CoconutColors.white,
              fontSize: 12,
            ),
          ),
        ),
        null,
        viewModel.selectedUtxoList.length,
        viewModel.selectedUtxoAmountSum,
      ),
    );
  }
}
