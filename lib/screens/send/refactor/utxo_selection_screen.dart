import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/refactor/utxo_selection_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/card/locked_utxo_item_card.dart';
import 'package:coconut_wallet/widgets/card/selectable_utxo_item_card.dart';
import 'package:coconut_wallet/widgets/overlays/error_tooltip.dart';
import 'package:coconut_wallet/widgets/selector/custom_tag_horizontal_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/widgets/header/selected_utxo_amount_header.dart';

class UtxoSelectionScreen extends StatefulWidget {
  final List<UtxoState> selectedUtxoList;
  final int walletId;
  final BitcoinUnit currentUnit;
  final ScrollController? scrollController;
  final bool showSkipButton;
  final bool isSplitMode;

  const UtxoSelectionScreen({
    super.key,
    required this.currentUnit,
    required this.selectedUtxoList,
    required this.walletId,
    this.scrollController,
    this.showSkipButton = false,
    this.isSplitMode = false,
  });

  @override
  State<UtxoSelectionScreen> createState() => _UtxoSelectionScreenState();
}

class _UtxoSelectionScreenState extends State<UtxoSelectionScreen> {
  final String allLabelName = t.all;
  late final ScrollController _scrollController;
  late final bool _hasScrollController;
  late UtxoSelectionViewModel _viewModel;

  final List<UtxoOrder> _utxoOrderOptions = [
    UtxoOrder.byAmountDesc,
    UtxoOrder.byAmountAsc,
    UtxoOrder.byTimestampDesc,
    UtxoOrder.byTimestampAsc,
  ];

  final GlobalKey _orderDropdownButtonKey = GlobalKey();
  final GlobalKey _dropdownLayerKey = GlobalKey();
  bool _isOrderDropdownVisible = false; // 필터 드롭다운
  double _dropdownTop = 0;
  double? _dropdownLeft;
  double? _dropdownRight;

  @override
  Widget build(BuildContext context) {
    String titleText = widget.isSplitMode ? t.select_utxo : t.utxo_selection_screen.title;
    return ChangeNotifierProxyProvider<ConnectivityProvider, UtxoSelectionViewModel>(
      create: (_) => _viewModel,
      update: (_, connectivityProvider, viewModel) {
        if (connectivityProvider.isInternetOn != viewModel!.isNetworkOn) {
          viewModel.setIsNetworkOn(connectivityProvider.isInternetOn);

          WidgetsBinding.instance.addPostFrameCallback((_) {
            // 네트워크 알림 툴팁이 생성되면 위젯이 밀리기 때문에 드롭다운 버튼 위치를 다시 계산
            _updateOrderDropdownButtonPosition();
          });
        }
        return viewModel;
      },
      child: Consumer<UtxoSelectionViewModel>(
        builder:
            (context, viewModel, child) => Stack(
              children: [
                GestureDetector(
                  onTap: () => _removeUtxoOrderDropdown(),
                  child: Scaffold(
                    backgroundColor: CoconutColors.black,
                    appBar: CoconutAppBar.build(
                      backgroundColor: CoconutColors.black,
                      customTitle: Text(
                        titleText,
                        style:
                            widget.isSplitMode
                                ? CoconutTypography.body2_14_Bold.setColor(CoconutColors.white)
                                : CoconutTypography.body2_14.setColor(CoconutColors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                      context: context,
                      actionButtonList: [
                        if (widget.showSkipButton)
                          CoconutUnderlinedButton(
                            text: t.utxo_selection_screen.skip,
                            textStyle: CoconutTypography.body2_14,
                            onTap: () {
                              _viewModel.deselectAllUtxo();
                              Navigator.pop(context, _viewModel.selectedUtxoList);
                            },
                          ),
                      ],
                      onBackPressed: () => Navigator.pop(context),
                      isBottom: true,
                    ),
                    body: SafeArea(
                      child: Stack(
                        key: _dropdownLayerKey,
                        children: [
                          Column(
                            children: [
                              Visibility(
                                visible: !viewModel.isNetworkOn,
                                maintainSize: false,
                                maintainAnimation: false,
                                maintainState: false,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
                                  child: ErrorTooltip(
                                    isShown: !viewModel.isNetworkOn,
                                    errorMessage: t.errors.network_error,
                                  ),
                                ),
                              ),
                              if (!widget.isSplitMode)
                                SelectedUtxoAmountHeader(
                                  orderDropdownButtonKey: _orderDropdownButtonKey,
                                  orderText: _viewModel.utxoOrder.text,
                                  selectedUtxoCount: viewModel.selectedUtxoList.length,
                                  selectedUtxoAmountSum: viewModel.selectedUtxoAmountSum,
                                  currentUnit: widget.currentUnit,
                                  onSelectAll: _selectAll,
                                  onUnselectAll: _deselectAll,
                                  onToggleOrderDropdown: () {
                                    setState(() {
                                      _isOrderDropdownVisible = !_isOrderDropdownVisible;
                                    });
                                  },
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(right: 16.0, bottom: 12.0, top: 4.0),
                                  child: Align(
                                    alignment: Alignment.centerRight,
                                    child: GestureDetector(
                                      key: _orderDropdownButtonKey,
                                      onTap: () {
                                        setState(() {
                                          _isOrderDropdownVisible = !_isOrderDropdownVisible;
                                        });
                                      },
                                      behavior: HitTestBehavior.opaque,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _viewModel.utxoOrder.text,
                                            style: CoconutTypography.caption_10.setColor(CoconutColors.gray400),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(Icons.keyboard_arrow_down, color: CoconutColors.gray400, size: 16),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              _buildUtxoTagList(viewModel),
                              Expanded(
                                child:
                                    viewModel.isInitialized
                                        ? Stack(
                                          children: [
                                            Container(color: CoconutColors.black, child: _buildUtxoList(viewModel)),
                                            FixedBottomButton(
                                              onButtonClicked: () {
                                                vibrateLight();
                                                Navigator.pop(context, _viewModel.selectedUtxoList);
                                              },
                                              text: t.done,
                                              isActive: _viewModel.hasSelectionChanged,
                                              showGradient: true,
                                              horizontalPadding: 16,
                                              backgroundColor: CoconutColors.white,
                                            ),
                                          ],
                                        )
                                        : const Center(child: CircularProgressIndicator()),
                              ),
                            ],
                          ),
                          _buildUtxoOrderDropdown(viewModel),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  @override
  void dispose() {
    if (_hasScrollController) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    try {
      super.initState();
      _hasScrollController = widget.scrollController == null;
      _scrollController = widget.scrollController ?? ScrollController();

      _viewModel = UtxoSelectionViewModel(
        Provider.of<WalletProvider>(context, listen: false),
        Provider.of<UtxoTagProvider>(context, listen: false),
        Provider.of<PriceProvider>(context, listen: false),
        Provider.of<PreferenceProvider>(context, listen: false),
        Provider.of<ConnectivityProvider>(context, listen: false).isInternetOn,
        widget.walletId,
      )..isSplitMode = widget.isSplitMode;

      _scrollController.addListener(() {
        if (_isOrderDropdownVisible) {
          _removeUtxoOrderDropdown();
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (mounted) {
          _viewModel.initialize(widget.selectedUtxoList);
          if (widget.isSplitMode) {
            _viewModel.changeUtxoOrder(UtxoOrder.byAmountDesc);
          }
        }

        _updateOrderDropdownButtonPosition();
      });
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return CoconutPopup(
              languageCode: context.read<PreferenceProvider>().language,
              title: t.alert.error_occurs,
              description: t.alert.contact_admin(error: e.toString()),
              onTapRight: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop();
              },
              rightButtonText: t.OK,
            );
          },
        );
      });
    }
  }

  void _removeUtxoOrderDropdown() {
    setState(() {
      _isOrderDropdownVisible = false;
    });
  }

  void _updateOrderDropdownButtonPosition() {
    final buttonContext = _orderDropdownButtonKey.currentContext;
    final dropdownLayerContext = _dropdownLayerKey.currentContext;
    if (buttonContext == null || dropdownLayerContext == null) return;

    final buttonRenderBox = buttonContext.findRenderObject();
    final dropdownLayerRenderBox = dropdownLayerContext.findRenderObject();
    if (buttonRenderBox is! RenderBox || dropdownLayerRenderBox is! RenderBox) return;

    final topLeft = buttonRenderBox.localToGlobal(Offset.zero, ancestor: dropdownLayerRenderBox);

    _dropdownTop = topLeft.dy + buttonRenderBox.size.height + 4;
    final layerWidth = dropdownLayerRenderBox.size.width;
    final buttonRight = topLeft.dx + buttonRenderBox.size.width;

    if (topLeft.dx > layerWidth / 2) {
      _dropdownRight = layerWidth - buttonRight;
      _dropdownLeft = null;
    } else {
      _dropdownLeft = topLeft.dx;
      _dropdownRight = null;
    }
  }

  void _selectAll() {
    _removeUtxoOrderDropdown();
    _viewModel.selectTaggedUtxo(_viewModel.selectedUtxoTagName);
  }

  void _deselectAll() {
    _removeUtxoOrderDropdown();
    _viewModel.deselectTaggedUtxo();
  }

  void _toggleSelection(UtxoState utxo) {
    _removeUtxoOrderDropdown();
    _viewModel.toggleUtxoSelection(utxo);
  }

  Widget _utxoOrderDropdownMenu() {
    return Material(
      borderRadius: BorderRadius.circular(16),
      child: CoconutPulldownMenu(
        entries: _utxoOrderOptions.map((order) => CoconutPulldownMenuItem(title: order.text)).toList(),
        dividerColor: CoconutColors.black,
        onSelected: (index, selectedText) async {
          bool isChanged = _viewModel.utxoOrder != _utxoOrderOptions[index];
          setState(() {
            _isOrderDropdownVisible = false;
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
    switch (_viewModel.utxoOrder) {
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

  Widget _buildUtxoOrderDropdown(UtxoSelectionViewModel viewModel) {
    if (_isOrderDropdownVisible && viewModel.confirmedUtxoList.isNotEmpty) {
      return Positioned(top: _dropdownTop, left: _dropdownLeft, right: _dropdownRight, child: _utxoOrderDropdownMenu());
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
          },
        ),
      ),
    );
  }

  Widget _buildUtxoList(UtxoSelectionViewModel viewModel) {
    final filteredUtxoList = viewModel.filteredUtxoList;

    return ListView.separated(
      key: ValueKey(viewModel.selectedUtxoTagName),
      controller: _scrollController,
      padding: const EdgeInsets.only(top: 0, bottom: 100, left: 16, right: 16),
      itemCount: filteredUtxoList.length,
      separatorBuilder: (context, index) => const SizedBox(height: 0),
      itemBuilder: (context, index) {
        final utxo = filteredUtxoList[index];

        if (utxo.isLocked) {
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: LockedUtxoItemCard(
              key: ValueKey(utxo.utxoId),
              utxo: utxo,
              utxoTags: viewModel.utxoTagMap[utxo.utxoId],
              currentUnit: widget.currentUnit,
            ),
          );
        }

        final bool isDisabledForSplit = widget.isSplitMode && utxo.amount < 1000;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: IgnorePointer(
            ignoring: isDisabledForSplit,
            child: Opacity(
              opacity: isDisabledForSplit ? 0.4 : 1.0,
              child: SelectableUtxoItemCard(
                key: ValueKey(utxo.utxoId),
                currentUnit: widget.currentUnit,
                utxo: utxo,
                isSelectable: true,
                isSelected: viewModel.selectedUtxoIdSet.contains(utxo.utxoId),
                utxoTags: viewModel.utxoTagMap[utxo.utxoId],
                onSelected: _toggleSelection,
              ),
            ),
          ),
        );
      },
    );
  }
}
