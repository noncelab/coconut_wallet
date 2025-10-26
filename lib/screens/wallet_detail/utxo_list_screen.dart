import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_list_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/amimation_util.dart';
import 'package:coconut_wallet/widgets/card/utxo_item_card.dart';
import 'package:coconut_wallet/widgets/header/utxo_list_header.dart';
import 'package:coconut_wallet/widgets/header/utxo_list_sticky_header.dart';
import 'package:coconut_wallet/widgets/dropdown/utxo_filter_dropdown.dart';
import 'package:coconut_wallet/widgets/header/utxo_tag_list_widget.dart';
import 'package:coconut_wallet/widgets/loading_indicator/loading_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

class UtxoListScreen extends StatefulWidget {
  final int id; // wallet id
  final List<UtxoState> selectedUtxoList;

  const UtxoListScreen({super.key, required this.id, List<UtxoState>? selectedUtxoList})
    : selectedUtxoList = selectedUtxoList ?? const [];

  @override
  State<UtxoListScreen> createState() => _UtxoListScreenState();
}

class _UtxoListScreenState extends State<UtxoListScreen> {
  // Scroll & Layout
  final ScrollController _scrollController = ScrollController();
  double _topPadding = 0;
  Size _appBarSize = Size.zero;

  // Global Keys
  final GlobalKey _appBarKey = GlobalKey();
  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _stickyHeaderKey = GlobalKey();
  final GlobalKey _headerDropdownKey = GlobalKey();
  final GlobalKey _stickyHeaderDropdownKey = GlobalKey();
  final GlobalKey _selectModeHeaderDropdownKey = GlobalKey();
  final GlobalKey _selectModeStickyHeaderDropdownKey = GlobalKey();

  final GlobalKey<_UtxoListState> utxoListKey = GlobalKey<_UtxoListState>();

  // Dropdown & Header 상태
  final ValueNotifier<bool> _stickyHeaderVisibleNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _firstLoadedNotifier = ValueNotifier(false);
  final ValueNotifier<bool> _dropdownVisibleNotifier = ValueNotifier(false);

  // Dropdown 위치 & 크기
  Offset _headerDropdownPosition = Offset.zero;
  Offset _stickyHeaderDropdownPosition = Offset.zero;
  Size _headerDropdownSize = Size.zero;
  Size _stickyHeaderDropdownSize = Size.zero;

  // 기타
  OverlayEntry? _statusBarTapOverlayEntry; // iOS status bar tap scroll
  late BitcoinUnit _currentUnit;
  bool _isSelectionMode = false;

  late UtxoListViewModel viewModel;

  // 선택된 UTXO 초기값
  final List<UtxoState> selectedUtxoList = [];

  OverlayEntry? _orderDropdownOverlay;

  @override
  void initState() {
    super.initState();
    _currentUnit = context.read<PreferenceProvider>().currentUnit;

    viewModel = UtxoListViewModel(
      widget.id,
      Provider.of<WalletProvider>(context, listen: false),
      Provider.of<TransactionProvider>(context, listen: false),
      Provider.of<UtxoTagProvider>(context, listen: false),
      Provider.of<ConnectivityProvider>(context, listen: false),
      Provider.of<PriceProvider>(context, listen: false),
      Provider.of<PreferenceProvider>(context, listen: false),
      Provider.of<NodeProvider>(context, listen: false).getWalletStateStream(widget.id),
      widget.selectedUtxoList,
    );

    _scrollController.addListener(() {
      if (_dropdownVisibleNotifier.value) {
        _removeUtxoOrderDropdown();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateTopPadding();
      _scrollController.addListener(_onScroll);
    });

    if (Platform.isIOS) _enableStatusBarTapScroll();
  }

  void _calculateTopPadding() {
    final appBarBox = _appBarKey.currentContext?.findRenderObject() as RenderBox?;
    final headerBox = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    final stickyBox = _stickyHeaderKey.currentContext?.findRenderObject() as RenderBox?;

    _appBarSize = appBarBox?.size ?? Size.zero;
    final topHeaderHeight = headerBox?.size.height ?? 0;
    final stickyHeight = stickyBox?.size.height ?? 0;

    setState(() => _topPadding = topHeaderHeight - stickyHeight);
  }

  void _onScroll() {
    _hideDropdown();
    if (_scrollController.offset > _topPadding) {
      _showStickyHeaderAndUpdateDropdownPosition();
    } else {
      _hideStickyHeaderAndUpdateDropdownPosition();
    }
  }

  @override
  void dispose() {
    _statusBarTapOverlayEntry?.remove();
    _scrollController.dispose();
    super.dispose();
  }

  UtxoListViewModel _createViewModel() {
    return UtxoListViewModel(
      widget.id,
      Provider.of<WalletProvider>(context, listen: false),
      Provider.of<TransactionProvider>(context, listen: false),
      Provider.of<UtxoTagProvider>(context, listen: false),
      Provider.of<ConnectivityProvider>(context, listen: false),
      Provider.of<PriceProvider>(context, listen: false),
      Provider.of<PreferenceProvider>(context, listen: false),
      Provider.of<NodeProvider>(context, listen: false).getWalletStateStream(widget.id),
      widget.selectedUtxoList,
    );
  }

  void _toggleUnit() {
    setState(() {
      _currentUnit = _currentUnit == BitcoinUnit.btc ? BitcoinUnit.sats : BitcoinUnit.btc;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<WalletProvider, UtxoTagProvider, UtxoListViewModel>(
      create: (_) => _createViewModel(),
      update: (_, walletProvider, utxoTagProvider, viewModel) {
        viewModel ??= _createViewModel();
        return viewModel..updateProvider();
      },
      child: Builder(
        builder:
            (context) => PopScope(
              canPop: true,
              onPopInvokedWithResult: (didPop, _) => _hideDropdown(),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _hideDropdown,
                child: Stack(
                  children: [
                    _buildScaffold(context, utxoListKey),
                    _buildStickyHeader(context),
                    _buildUtxoOrderDropdown(_isSelectionMode),
                    if (_isSelectionMode) _buildSelectionButtons(utxoListKey),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, GlobalKey<_UtxoListState> utxoListKey) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: CoconutAppBar.build(
        entireWidgetKey: _appBarKey,
        title: t.utxo_list,
        context: context,
        backgroundColor: CoconutColors.black,
        actionButtonList: [
          CoconutUnderlinedButton(
            text: _isSelectionMode ? t.complete : t.select,
            textStyle: const TextStyle(color: CoconutColors.white, fontSize: 16, fontWeight: FontWeight.bold),
            onTap: () {
              setState(() {
                _isSelectionMode = !_isSelectionMode;
                if (_isSelectionMode) {
                  viewModel.setSelectedUtxoTagName(t.all);
                } else {
                  _deselectAll();
                }
              });
            },
          ),
        ],
      ),
      body: Selector<UtxoListViewModel, Tuple3<bool, bool, List<UtxoState>>>(
        selector: (_, vm) => Tuple3(vm.isSyncing, vm.isUtxoTagListEmpty, vm.utxoList),
        builder: (context, data, child) {
          final isSyncing = data.item1;
          final isUtxoTagListEmpty = data.item2;
          final utxoList = data.item3;

          return Stack(
            children: [
              CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                controller: _scrollController,
                semanticChildCount: isUtxoTagListEmpty ? 1 : utxoList.length,
                slivers: [
                  if (isSyncing) const SliverToBoxAdapter(child: LoadingIndicator()),
                  CupertinoSliverRefreshControl(
                    onRefresh: () async => context.read<UtxoListViewModel>().refetchFromDB(),
                  ),
                  SliverToBoxAdapter(child: _buildHeader(context)),
                  UtxoList(
                    key: utxoListKey,
                    walletId: widget.id,
                    currentUnit: _currentUnit,
                    isSelectionMode: _isSelectionMode,
                    onRemoveDropdown: _hideDropdown,
                    onFirstBuildCompleted: () {
                      if (!mounted) return;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _firstLoadedNotifier.value = true;
                      });
                    },
                    onSettingLockChanged: (value) => setState(() => _isSelectionMode = value),
                  ),
                ],
              ),
              _buildBottomGradient(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomGradient() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: 150,
      child: IgnorePointer(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, CoconutColors.black],
              stops: [0.0, 0.75],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUtxoOrderDropdown(bool isSelectionMode) {
    return ValueListenableBuilder<bool>(
      valueListenable: _dropdownVisibleNotifier,
      builder: (context, isVisible, child) {
        if (!isVisible) return const SizedBox.shrink();

        final isSticky = _stickyHeaderVisibleNotifier.value;
        final positionTop =
            isSticky
                ? _stickyHeaderDropdownPosition.dy + _stickyHeaderDropdownSize.height
                : _headerDropdownPosition.dy + _headerDropdownSize.height;

        return Selector<UtxoListViewModel, UtxoOrder>(
          selector: (_, viewModel) => viewModel.selectedUtxoOrder,
          builder: (context, selectedOrder, child) {
            return UtxoOrderDropdown(
              isVisible: isVisible,
              positionTop: positionTop,
              selectedOption: selectedOrder,
              isSelectionMode: isSelectionMode,
              onOptionSelected: (filter) {
                if (isSelectionMode) {
                  _hideDropdown();
                } else {
                  _dropdownVisibleNotifier.value = false;
                }
                context.read<UtxoListViewModel>().updateUtxoFilter(filter);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSelectionButtons(GlobalKey<_UtxoListState> utxoListKey) {
    final buttons = [
      {'text': t.utxo_detail_screen.utxo_unlocked, 'lock': false},
      {'text': t.utxo_detail_screen.utxo_locked, 'lock': true},
    ];

    return Positioned(
      left: 16,
      right: 16,
      bottom: 50,
      child: Row(
        children: List.generate(buttons.length * 2 - 1, (index) {
          if (index.isOdd) return const SizedBox(width: 16);

          final buttonIndex = index ~/ 2;
          final button = buttons[buttonIndex];
          final isLocked = button['lock'] as bool;
          final text = button['text'] as String;

          return Expanded(
            child: CoconutButton(
              onPressed: () {
                final state = utxoListKey.currentState;
                if (state == null) {
                  debugPrint('⚠️ UtxoList state not found!');
                  return;
                }

                debugPrint('selected count: ${state._selectedUtxoIds.length}');
                state._updateSelectedUtxos(lock: isLocked);
              },
              backgroundColor: CoconutColors.white,
              buttonType: CoconutButtonType.filled,
              text: text,
              foregroundColor: CoconutColors.black,
            ),
          );
        }),
      ),
    );
  }

  void _hideDropdown() => _dropdownVisibleNotifier.value = false;

  void _hideStickyHeaderAndUpdateDropdownPosition() {
    _stickyHeaderVisibleNotifier.value = false;
    if (_isSelectionMode) {
      _updateDropdownPosition(_selectModeHeaderDropdownKey, isSticky: false);
    } else {
      _updateDropdownPosition(_headerDropdownKey, isSticky: false);
    }
  }

  void _showStickyHeaderAndUpdateDropdownPosition() {
    _stickyHeaderVisibleNotifier.value = true;
    if (_isSelectionMode) {
      _updateDropdownPosition(_selectModeStickyHeaderDropdownKey, isSticky: true);
    } else {
      _updateDropdownPosition(_stickyHeaderDropdownKey, isSticky: true);
    }
  }

  void _updateDropdownPosition(GlobalKey key, {required bool isSticky}) {
    if (key.currentContext == null) return;
    final renderBox = key.currentContext!.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    setState(() {
      if (isSticky) {
        _stickyHeaderDropdownPosition = position;
        _stickyHeaderDropdownSize = size;
      } else {
        _headerDropdownPosition = position;
        _headerDropdownSize = size;
      }
    });
  }

  Widget _buildHeader(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _firstLoadedNotifier,
      builder: (context, canShowDropdown, child) {
        return Selector<UtxoListViewModel, Tuple4<UtxoOrder, String, String, int>>(
          selector:
              (_, viewModel) => Tuple4(
                viewModel.selectedUtxoOrder,
                viewModel.utxoTagListKey,
                viewModel.selectedUtxoTagName,
                viewModel.selectedUtxoList.length,
              ),
          shouldRebuild: (previous, next) {
            final result =
                previous.item1 != next.item1 ||
                previous.item2 != next.item2 ||
                previous.item3 != next.item3 ||
                previous.item4 != next.item4;
            debugPrint('result: $result');
            return result;
          },
          builder: (context, data, child) {
            final viewModel = context.read<UtxoListViewModel>();
            final selectedOrder = data.item1;
            final tagListKey = data.item2;
            final selectedTagName = data.item3;

            return UtxoListHeader(
              key: ValueKey(tagListKey),
              headerGlobalKey: _headerKey,
              dropdownGlobalKey: _headerDropdownKey,
              isLoadComplete: canShowDropdown,
              isBalanceHidden: _isSelectionMode,
              animatedBalanceData: AnimatedBalanceData(
                context.read<UtxoListViewModel>().balance,
                context.read<UtxoListViewModel>().prevBalance,
              ),
              selectedOption: selectedOrder.text,
              onTapDropdown: () {
                _dropdownVisibleNotifier.value = !_dropdownVisibleNotifier.value;
                _hideStickyHeaderAndUpdateDropdownPosition();
              },
              onPressedUnitToggle: _toggleUnit,
              currentUnit: _currentUnit,
              tagListWidget: UtxoTagListWidget(
                selectedUtxoTagName: selectedTagName,
                onTagSelected: (tagName) {
                  final viewModel = context.read<UtxoListViewModel>();

                  viewModel.setSelectedUtxoTagName(tagName);
                },
                isSelectionMode: _isSelectionMode,
              ),
              orderDropdownButtonKey: _selectModeHeaderDropdownKey,
              orderText: viewModel.utxoOrder.text,
              selectedUtxoCount: viewModel.selectedUtxoList.length,
              selectedUtxoAmountSum: viewModel.selectedUtxoAmountSum,
              onSelectAll: () => _selectAll(selectedTagName),
              onUnselectAll: _deselectAll,
              isSelectionMode: _isSelectionMode,
              dropdownVisibleNotifier: _dropdownVisibleNotifier,
            );
          },
        );
      },
    );
  }

  void _removeUtxoOrderDropdown() {
    _orderDropdownOverlay?.remove();
    _orderDropdownOverlay = null;
  }

  Widget _buildStickyHeader(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _firstLoadedNotifier,
      builder: (context, enableDropdown, _) {
        return Selector<UtxoListViewModel, Tuple5<UtxoOrder, String, int, AnimatedBalanceData, String>>(
          selector:
              (_, viewModel) => Tuple5(
                viewModel.selectedUtxoOrder,
                viewModel.utxoTagListKey,
                viewModel.selectedUtxoList.length,
                AnimatedBalanceData(viewModel.balance, viewModel.prevBalance),
                viewModel.selectedUtxoTagName,
              ),
          shouldRebuild: (previous, next) {
            final result =
                previous.item1 != next.item1 || // order 변경
                previous.item2 != next.item2 || // 태그 리스트 변경
                previous.item3 != next.item3 || // 총 개수 변경
                previous.item4.current != next.item4.current || // 잔액 변경
                previous.item5 != next.item5; // 선택된 태그 변경

            return result;
          },
          builder: (context, data, child) {
            final selectedOrder = data.item1;
            final tagListKey = data.item2;
            final totalCount = data.item3;
            final animatedBalanceData = data.item4;
            final selectedTagName = data.item5;

            return ValueListenableBuilder<bool>(
              valueListenable: _stickyHeaderVisibleNotifier,
              builder: (context, isStickyHeaderVisible, _) {
                return UtxoListStickyHeader(
                  key: ValueKey('sticky_$tagListKey'),
                  stickyHeaderGlobalKey: _stickyHeaderKey,
                  dropdownGlobalKey: _stickyHeaderDropdownKey,
                  height: _appBarSize.height,
                  isVisible: isStickyHeaderVisible,
                  isLoadComplete: _firstLoadedNotifier.value,
                  enableDropdown: enableDropdown,
                  animatedBalanceData: animatedBalanceData,
                  totalCount: totalCount,
                  selectedOption: selectedOrder.text,
                  onTapDropdown: () {
                    _dropdownVisibleNotifier.value = !_dropdownVisibleNotifier.value;
                    _scrollController.jumpTo(_scrollController.offset);
                    _showStickyHeaderAndUpdateDropdownPosition();
                  },
                  removePopup: () {
                    _hideDropdown();
                  },
                  currentUnit: _currentUnit,
                  isSelectionMode: _isSelectionMode,
                  orderDropdownButtonKey: _selectModeStickyHeaderDropdownKey,
                  onSelectAll: () => _selectAll(selectedTagName),
                  onUnselectAll: _deselectAll,
                  onToggleOrderDropdown: () {
                    setState(() {
                      _dropdownVisibleNotifier.value = !_dropdownVisibleNotifier.value;
                    });
                  },
                  selectedUtxoCount: viewModel.selectedUtxoList.length,
                  selectedUtxoAmountSum: viewModel.selectedUtxoAmountSum,
                  orderText: viewModel.utxoOrder.text,
                );
              },
            );
          },
        );
      },
    );
  }

  void _enableStatusBarTapScroll() {
    if (_statusBarTapOverlayEntry != null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _statusBarTapOverlayEntry = OverlayEntry(
        builder:
            (context) => Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).padding.top,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap:
                    () => _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    ),
              ),
            ),
      );
      Overlay.of(context).insert(_statusBarTapOverlayEntry!);
    });
  }

  void _selectAll(selectedTagName) {
    _removeUtxoOrderDropdown();
    viewModel.setSelectedUtxoTagName(selectedTagName);
    viewModel.selectTaggedUtxo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      utxoListKey.currentState?._setSelectedUtxosFromViewModel(viewModel.selectedUtxoList);
    });
    setState(() {});
    debugPrint('selectedUtxoList.length: ${viewModel.selectedUtxoList.length}');
  }

  void _deselectAll() {
    _removeUtxoOrderDropdown();
    viewModel.deselectTaggedUtxo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      utxoListKey.currentState?._setSelectedUtxosFromViewModel(viewModel.selectedUtxoList);
    });
    setState(() {});
    debugPrint('selectedUtxoList.length: ${viewModel.selectedUtxoList.length}');
  }
}

class UtxoList extends StatefulWidget {
  const UtxoList({
    super.key,
    required this.walletId,
    required this.currentUnit,
    required this.onRemoveDropdown,
    required this.onFirstBuildCompleted,
    required this.isSelectionMode,
    this.onSettingLockChanged,
  });

  final int walletId;
  final BitcoinUnit currentUnit;
  final Function onRemoveDropdown;
  final VoidCallback onFirstBuildCompleted;
  final bool isSelectionMode;
  final ValueChanged<bool>? onSettingLockChanged;

  @override
  State<UtxoList> createState() => _UtxoListState();
}

class _UtxoListState extends State<UtxoList> {
  late List<UtxoState> _displayedUtxoList = [];
  final GlobalKey<SliverAnimatedListState> _utxoListKey = GlobalKey<SliverAnimatedListState>();
  final GlobalKey<SliverAnimatedListState> _lockedUtxoListKey = GlobalKey<SliverAnimatedListState>();
  final GlobalKey<SliverAnimatedListState> _changeUtxoListKey = GlobalKey<SliverAnimatedListState>();

  final Duration _duration = const Duration(milliseconds: 1200);
  final Duration _animationDuration = const Duration(milliseconds: 100);
  bool _isListLoading = false;
  final Set<String> _selectedUtxoIds = {};
  PersistentBottomSheetController? _bottomSheetController;

  @override
  Widget build(BuildContext context) {
    return Selector<UtxoListViewModel, Tuple3<List<UtxoState>, String, UtxoOrder>>(
      selector: (_, vm) => Tuple3(vm.utxoList, vm.selectedUtxoTagName, vm.selectedUtxoOrder),
      shouldRebuild: (prev, next) => prev.item1 != next.item1 || prev.item2 != next.item2 || prev.item3 != next.item3,
      builder: (_, data, __) {
        final utxoList = data.item1;
        final selectedUtxoTagName = data.item2;

        if (utxoList.isEmpty) return _buildEmptyState();

        if (_isListChanged(_displayedUtxoList, utxoList)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleUtxoListChange(utxoList);
          });
        }

        return SliverPadding(
          padding: const EdgeInsets.only(bottom: 100),
          sliver: _buildSliverAnimatedList(utxoList, selectedUtxoTagName),
        );
      },
    );
  }

  Widget _buildSliverAnimatedList(List<UtxoState> utxoList, String selectedUtxoTagName) {
    Key listKey;
    if (selectedUtxoTagName == t.utxo_detail_screen.utxo_locked) {
      listKey = _lockedUtxoListKey;
    } else if (selectedUtxoTagName == t.change) {
      listKey = _changeUtxoListKey;
    } else {
      listKey = _utxoListKey;
    }

    return SliverAnimatedList(
      key: listKey,
      initialItemCount: _displayedUtxoList.length,
      itemBuilder: (context, index, animation) {
        if (index >= utxoList.length) return const SizedBox();
        final utxo = utxoList[index];
        final belongsToTag = _belongsToTag(utxo, selectedUtxoTagName);

        if (!belongsToTag) {
          return const SizedBox();
        }

        return Padding(
          padding: const EdgeInsets.only(
            bottom: 8.0, // 아이템 아래 간격
          ),
          child: _buildUtxoItem(utxo, animation, index == utxoList.length - 1),
        );
      },
    );
  }

  bool _belongsToTag(UtxoState utxo, String? tagName) {
    if (tagName == null || tagName.isEmpty) return false;

    final matchers = {
      t.all: true,
      t.utxo_detail_screen.utxo_locked: utxo.status == UtxoStatus.locked,
      t.change: utxo.isChange == true,
    };

    if (matchers.containsKey(tagName)) {
      return matchers[tagName] == true;
    }

    return utxo.tags?.any((e) => e.name == tagName) ?? false;
  }

  Widget _buildEmptyState() {
    widget.onFirstBuildCompleted();

    return SliverFillRemaining(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Align(alignment: Alignment.topCenter, child: Text(t.utxo_not_found, style: CoconutTypography.body1_16)),
      ),
    );
  }

  void _setSelectedUtxosFromViewModel(List<UtxoState> selectedList) {
    setState(() {
      _selectedUtxoIds
        ..clear()
        ..addAll(selectedList.map((u) => u.utxoId));
    });
  }

  Animation<Offset> _buildSlideAnimation(Animation<double> animation) {
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.easeOutExpo;

    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    return animation.drive(tween);
  }

  Future<void> _handleUtxoListChange(List<UtxoState> utxoList) async {
    final isFirstLoad = _displayedUtxoList.isEmpty && utxoList.isNotEmpty;

    if (_isListLoading) return;
    _isListLoading = true;

    final oldUtxoMap = {for (var utxo in _displayedUtxoList) utxo.utxoId: utxo};
    final newUtxoMap = {for (var utxo in utxoList) utxo.utxoId: utxo};

    final List<int> insertedIndexes = [];
    final List<int> removedIndexes = [];

    for (int i = 0; i < utxoList.length; i++) {
      if (!oldUtxoMap.containsKey(utxoList[i].utxoId)) {
        insertedIndexes.add(i);
      }
    }

    for (int i = 0; i < _displayedUtxoList.length; i++) {
      if (!newUtxoMap.containsKey(_displayedUtxoList[i].utxoId)) {
        removedIndexes.add(i);
      }
    }

    setState(() {
      _displayedUtxoList = List.from(utxoList);
    });

    // 삭제된 인덱스 역순으로 삭제
    for (var index in removedIndexes.reversed) {
      if (index >= _displayedUtxoList.length) continue;
      final removedItem = _displayedUtxoList[index];
      await Future.delayed(_animationDuration);

      _utxoListKey.currentState?.removeItem(
        index,
        (context, animation) => _buildRemoveUtxoItem(removedItem, animation),
        duration: _duration,
      );
    }

    // 삽입된 인덱스 순서대로 추가
    for (var index in insertedIndexes) {
      await Future.delayed(_animationDuration);
      _utxoListKey.currentState?.insertItem(index, duration: _duration);
    }

    _isListLoading = false;
    if (isFirstLoad) {
      widget.onFirstBuildCompleted();
    }
  }

  Widget _buildRemoveUtxoItem(UtxoState utxo, Animation<double> animation) {
    var offsetAnimation = AnimationUtil.buildSlideOutAnimation(animation);

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: offsetAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: UtxoItemCard(
            key: Key(utxo.utxoId),
            currentUnit: widget.currentUnit,
            onPressed: () async {
              widget.onRemoveDropdown();

              await Navigator.pushNamed(context, '/utxo-detail', arguments: {'utxo': utxo, 'id': widget.walletId});
            },
            utxo: utxo,
          ),
        ),
      ),
    );
  }

  Widget _buildUtxoItem(UtxoState utxo, Animation<double> animation, bool isLastItem) {
    var offsetAnimation = _buildSlideAnimation(animation);
    final viewModel = context.read<UtxoListViewModel>();
    final bool isSelectionMode = widget.isSelectionMode;

    bool isSelected = _selectedUtxoIds.contains(utxo.utxoId);

    return Column(
      children: [
        SlideTransition(
          position: offsetAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: UtxoItemCard(
              key: Key(utxo.utxoId),
              currentUnit: widget.currentUnit,
              utxo: utxo,
              onPressed: () {
                if (isSelectionMode) {
                  setState(() {
                    if (_selectedUtxoIds.contains(utxo.utxoId)) {
                      _selectedUtxoIds.remove(utxo.utxoId);
                    } else {
                      _selectedUtxoIds.add(utxo.utxoId);
                    }
                  });
                } else {
                  _openDetailPage(utxo, viewModel);
                }
              },
              isSelected: isSelected,
              isSelectionMode: isSelectionMode,
            ),
          ),
        ),
      ],
    );
  }

  void _openDetailPage(UtxoState utxo, UtxoListViewModel viewModel) async {
    widget.onRemoveDropdown();

    await Navigator.pushNamed(context, '/utxo-detail', arguments: {'utxo': utxo, 'id': widget.walletId});
    // 돌아오면 DB 리프레시
    viewModel.refetchFromDB();
  }

  bool _isListChanged(List<UtxoState> oldList, List<UtxoState> newList) {
    // 길이 비교
    if (oldList.length != newList.length) return true;
    if (oldList.isEmpty && newList.isEmpty) return false;

    // 순서 비교 (정렬 변경 감지)
    for (int i = 0; i < oldList.length; i++) {
      if (oldList[i].utxoId != newList[i].utxoId) return true;
    }

    // UTXO ID를 키로 하는 맵 생성
    final oldMap = {for (var utxo in oldList) utxo.utxoId: utxo};
    final newMap = {for (var utxo in newList) utxo.utxoId: utxo};

    // UTXO 추가/삭제 확인
    if (!oldMap.keys.toSet().containsAll(newMap.keys) || !newMap.keys.toSet().containsAll(oldMap.keys)) {
      return true;
    }

    // 각 UTXO의 상태와 태그 변경 확인
    for (final utxoId in oldMap.keys) {
      final oldUtxo = oldMap[utxoId]!;
      final newUtxo = newMap[utxoId]!;

      // 상태 변경 확인
      if (oldUtxo.status != newUtxo.status) return true;

      // 태그 변경 확인
      if (!_equalTagLists(oldUtxo.tags, newUtxo.tags)) return true;
    }

    return false;
  }

  // tags 리스트를 비교하는 유틸 함수
  bool _equalTagLists(List<UtxoTag>? a, List<UtxoTag>? b) {
    // null 체크
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;

    // 길이 체크
    if (a.length != b.length) return false;
    if (a.isEmpty) return true; // 둘 다 비어있음

    // Set으로 변환해서 더 안전하게 비교
    final setA = Set<UtxoTag>.from(a);
    final setB = Set<UtxoTag>.from(b);

    // 길이가 같아야 하고, 모든 요소가 포함되어야 함
    return setA.length == setB.length && setA.containsAll(setB);
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// lock=true -> 잠금, lock=false -> 잠금 해제
  Future<void> _updateSelectedUtxos({required bool lock}) async {
    if (_selectedUtxoIds.isEmpty) return;
    final viewModel = context.read<UtxoListViewModel>();

    try {
      final newStatus = lock ? UtxoStatus.locked : UtxoStatus.unspent;

      // 선택된 모든 UTXO를 한 번에 업데이트
      await viewModel.updateSelectedUtxosStatus(_selectedUtxoIds.toList(), newStatus);

      setState(() {
        _selectedUtxoIds.clear();
        widget.onSettingLockChanged?.call(false);
      });

      // 잠금/잠금 해제 토스트 메시지
      CoconutToast.showToast(
        context: context,
        isVisibleIcon: true,
        iconPath: 'assets/svg/circle-info.svg',
        text: lock ? t.utxo_detail_screen.utxo_locked_toast_msg : t.utxo_detail_screen.utxo_unlocked_toast_msg,
      );

      _bottomSheetController?.close();
    } catch (e) {
      debugPrint('UTXO 상태 업데이트 실패: $e');
    }
  }

  @override
  void didUpdateWidget(covariant UtxoList oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.isSelectionMode != widget.isSelectionMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          setState(() {});
        }
      });
    }
  }
}
