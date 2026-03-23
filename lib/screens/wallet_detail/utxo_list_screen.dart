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
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_list_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/common/tag_apply_bottom_sheet.dart';
import 'package:coconut_wallet/utils/amimation_util.dart';
import 'package:coconut_wallet/widgets/button/bottom_action_bar.dart';
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

  const UtxoListScreen({super.key, required this.id});

  @override
  State<UtxoListScreen> createState() => _UtxoListScreenState();
}

class _UtxoListScreenState extends State<UtxoListScreen> {
  // ──────────────────────────────
  // Controllers & Keys
  // ──────────────────────────────
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _appBarKey = GlobalKey();
  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _stickyHeaderKey = GlobalKey();
  final GlobalKey _headerDropdownKey = GlobalKey();
  final GlobalKey _stickyHeaderDropdownKey = GlobalKey();
  final GlobalKey _selectModeHeaderDropdownKey = GlobalKey();
  final GlobalKey _selectModeStickyHeaderDropdownKey = GlobalKey();
  final GlobalKey<_UtxoListState> _utxoListKey = GlobalKey<_UtxoListState>();

  // ──────────────────────────────
  // Layout & Dropdown State
  // ──────────────────────────────
  final ValueNotifier<bool> _stickyHeaderVisible = ValueNotifier(false);
  final ValueNotifier<bool> _firstLoaded = ValueNotifier(false);
  final ValueNotifier<bool> _dropdownVisible = ValueNotifier(false);

  double _topPadding = 0;
  Size _appBarSize = Size.zero;

  Offset _headerDropdownPos = Offset.zero;
  Offset _stickyDropdownPos = Offset.zero;
  Size _headerDropdownSize = Size.zero;
  Size _stickyDropdownSize = Size.zero;

  // ──────────────────────────────
  // App / Business Logic
  // ──────────────────────────────
  late UtxoListViewModel viewModel;
  late BitcoinUnit _currentUnit;
  OverlayEntry? _statusBarTapOverlay;
  bool _isSelectionMode = false;

  // ──────────────────────────────
  // Lifecycle
  // ──────────────────────────────
  @override
  void initState() {
    super.initState();

    _currentUnit = context.read<PreferenceProvider>().currentUnit;

    viewModel = UtxoListViewModel(
      widget.id,
      context.read<WalletProvider>(),
      context.read<TransactionProvider>(),
      context.read<UtxoTagProvider>(),
      context.read<ConnectivityProvider>(),
      context.read<PriceProvider>(),
      context.read<PreferenceProvider>(),
      context.read<NodeProvider>().getWalletStateStream(widget.id),
    );

    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _calculateTopPadding());

    if (Platform.isIOS) _enableStatusBarTapScroll();
  }

  @override
  void dispose() {
    _statusBarTapOverlay?.remove();
    _scrollController.dispose();
    super.dispose();
  }

  // ──────────────────────────────
  // Build
  // ──────────────────────────────
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: viewModel,
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (didPop, _) => _hideDropdown(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _hideDropdown,
          child: Stack(
            children: [
              _buildScaffold(context),
              _buildStickyHeader(context),
              _buildUtxoOrderDropdown(),
              BottomActionBarSlide(isVisible: _isSelectionMode, child: _buildSelectionButtons()),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────
  // Layout Builders
  // ──────────────────────────────
  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: _buildAppBar(context),
      body: Selector<UtxoListViewModel, (bool, bool, List<UtxoState>)>(
        selector: (_, vm) => (vm.isSyncing, vm.isUtxoTagListEmpty, vm.utxoList),
        builder: (context, data, _) {
          final (isSyncing, isEmpty, utxos) = data;
          return Stack(
            children: [
              CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                semanticChildCount: isEmpty ? 1 : utxos.length,
                slivers: [
                  if (isSyncing) const SliverToBoxAdapter(child: LoadingIndicator()),
                  CupertinoSliverRefreshControl(
                    onRefresh: () async => context.read<UtxoListViewModel>().refetchFromDB(),
                  ),
                  SliverToBoxAdapter(child: _buildHeader(context)),
                  UtxoList(
                    key: _utxoListKey,
                    walletId: widget.id,
                    currentUnit: _currentUnit,
                    isSelectionMode: _isSelectionMode,
                    onRemoveDropdown: _hideDropdown,
                    onSettingLockChanged: (v) => setState(() => _isSelectionMode = v),
                    onFirstBuildCompleted: () {
                      if (!mounted) return;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _firstLoaded.value = true;
                      });
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return CoconutAppBar.build(
      entireWidgetKey: _appBarKey,
      title: t.utxo_list,
      context: context,
      backgroundColor: CoconutColors.black,
      actionButtonList: [
        Container(
          alignment: Alignment.center,
          child: CoconutUnderlinedButton(
            text: _isSelectionMode ? t.done : t.select,
            textStyle: CoconutTypography.body2_14.setColor(CoconutColors.onPrimary(CoconutTheme.brightness())),
            onTap: _toggleSelectionMode,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────
  // Header / Sticky Header
  // ──────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _firstLoaded,
      builder: (context, canShowDropdown, _) {
        return Selector<UtxoListViewModel, Tuple5<UtxoOrder, String, String, int, int>>(
          selector:
              (_, vm) => Tuple5(
                vm.activeUtxoOrder,
                vm.utxoTagListKey,
                vm.activeUtxoTagName,
                vm.selectedUtxoList.length,
                vm.selectedUtxoAmountSum,
              ),
          shouldRebuild:
              (a, b) =>
                  a.item1 != b.item1 ||
                  a.item2 != b.item2 ||
                  a.item3 != b.item3 ||
                  a.item4 != b.item4 ||
                  a.item5 != b.item5,
          builder: (context, data, _) {
            final vm = context.read<UtxoListViewModel>();
            final (order, tagKey, tagName, _, _) = (data.item1, data.item2, data.item3, data.item4, data.item5);

            return UtxoListHeader(
              key: ValueKey(tagKey),
              headerGlobalKey: _headerKey,
              dropdownGlobalKey: _headerDropdownKey,
              isLoadComplete: canShowDropdown,
              animatedBalanceData: AnimatedBalanceData(vm.balance, vm.prevBalance),
              activeOption: order.text,
              onTapDropdown: () {
                _dropdownVisible.value = !_dropdownVisible.value;
                _hideStickyHeaderAndUpdateDropdownPosition();
              },
              onPressedUnitToggle: _toggleUnit,
              currentUnit: _currentUnit,
              tagListWidget: UtxoTagListWidget(
                activeUtxoTagName: tagName,
                onTagSelected: (name) => vm.setActiveUtxoTagName(name),
              ),
              orderDropdownButtonKey: _selectModeHeaderDropdownKey,
              orderText: vm.utxoOrder.text,
              selectedUtxoCount: vm.selectedUtxoList.length,
              selectedUtxoAmountSum: vm.selectedUtxoAmountSum,
              onSelectAll: () => _selectAll(tagName),
              onUnselectAll: _deselectAll,
              isSelectionMode: _isSelectionMode,
              dropdownVisibleNotifier: _dropdownVisible,
            );
          },
        );
      },
    );
  }

  Widget _buildStickyHeader(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _firstLoaded,
      builder: (context, enableDropdown, _) {
        return Selector<UtxoListViewModel, Tuple6<UtxoOrder, String, int, AnimatedBalanceData, String, int>>(
          selector:
              (_, vm) => Tuple6(
                vm.activeUtxoOrder,
                vm.utxoTagListKey,
                vm.utxoList.length,
                AnimatedBalanceData(vm.balance, vm.prevBalance),
                vm.activeUtxoTagName,
                vm.selectedUtxoList.length,
              ),
          shouldRebuild:
              (a, b) =>
                  a.item1 != b.item1 ||
                  a.item2 != b.item2 ||
                  a.item3 != b.item3 ||
                  a.item4.current != b.item4.current ||
                  a.item5 != b.item5 ||
                  a.item6 != b.item6,
          builder: (context, data, _) {
            final (order, tagKey, count, balanceData, tagName) = (
              data.item1,
              data.item2,
              data.item3,
              data.item4,
              data.item5,
            );

            return ValueListenableBuilder<bool>(
              valueListenable: _stickyHeaderVisible,
              builder: (context, isVisible, _) {
                return UtxoListStickyHeader(
                  key: ValueKey('sticky_$tagKey'),
                  stickyHeaderGlobalKey: _stickyHeaderKey,
                  dropdownGlobalKey: _stickyHeaderDropdownKey,
                  height: _appBarSize.height,
                  isVisible: isVisible,
                  isLoadComplete: _firstLoaded.value,
                  enableDropdown: enableDropdown,
                  animatedBalanceData: balanceData,
                  totalCount: count,
                  activeOption: order.text,
                  currentUnit: _currentUnit,
                  isSelectionMode: _isSelectionMode,
                  orderDropdownButtonKey: _selectModeStickyHeaderDropdownKey,
                  onTapDropdown: _toggleDropdownSticky,
                  onSelectAll: () => _selectAll(tagName),
                  onUnselectAll: _deselectAll,
                  onPressedUnitToggle: _toggleUnit,
                  removePopup: _hideDropdown,
                  onToggleOrderDropdown: () => _dropdownVisible.value = !_dropdownVisible.value,
                  selectedUtxoCount: viewModel.selectedUtxoList.length,
                  selectedUtxoAmountSum: viewModel.selectedUtxoAmountSum,
                  orderText: viewModel.utxoOrder.text,
                  tagListWidget: UtxoTagListWidget(
                    activeUtxoTagName: tagName,
                    onTagSelected: (name) => viewModel.setActiveUtxoTagName(name),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────
  // Dropdown & Selection
  // ──────────────────────────────
  Widget _buildUtxoOrderDropdown() {
    return ValueListenableBuilder<bool>(
      valueListenable: _dropdownVisible,
      builder: (context, isVisible, _) {
        if (!isVisible) return const SizedBox.shrink();

        final isSticky = _stickyHeaderVisible.value;
        final positionTop =
            isSticky
                ? _stickyDropdownPos.dy + _stickyDropdownSize.height
                : _headerDropdownPos.dy + _headerDropdownSize.height;

        return Selector<UtxoListViewModel, UtxoOrder>(
          selector: (_, vm) => vm.activeUtxoOrder,
          builder: (context, activeOrder, _) {
            return UtxoOrderDropdown(
              isVisible: isVisible,
              positionTop: positionTop,
              activeOption: activeOrder,
              isSelectionMode: _isSelectionMode,
              onOptionSelected: (filter) {
                _hideDropdown();
                context.read<UtxoListViewModel>().updateUtxoFilter(filter);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSelectionButtons() {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;

    return Consumer<UtxoListViewModel>(
      builder: (context, vm, _) {
        final hasLockedUtxo = vm.selectedUtxoList.any((utxo) => utxo.status == UtxoStatus.locked);

        return BottomActionBar(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 40 + bottomPadding,
            bottom: bottomPadding > 0 ? bottomPadding : 16,
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildSelectionActionButton(
                  iconPath: 'assets/svg/send.svg',
                  text: t.send,
                  enabled: !hasLockedUtxo,
                  onTap:
                      () => _handleActionUtxoSelected(() {
                        final currentSelectedUtxos = List<UtxoState>.from(viewModel.selectedUtxoList);
                        final currentHasLocked = currentSelectedUtxos.any((utxo) => utxo.status == UtxoStatus.locked);

                        if (currentHasLocked) {
                          CoconutToast.showToast(
                            context: context,
                            text: t.utxo_list_screen.send_locked_utxo,
                            isVisibleIcon: true,
                          );
                          return;
                        }

                        setState(() {
                          _isSelectionMode = false;
                        });
                        viewModel.deselectTaggedUtxo();
                        _utxoListKey.currentState?._selectedUtxoIds.clear();

                        Navigator.pushNamed(
                          context,
                          '/send',
                          arguments: {
                            'walletId': widget.id,
                            'sendEntryPoint': SendEntryPoint.walletDetail,
                            'selectedUtxoList': currentSelectedUtxos,
                          },
                        );
                      }),
                ),
              ),
              Expanded(
                child: _buildSelectionActionButton(
                  iconPath: 'assets/svg/tag.svg',
                  text: t.utxo_list_screen.tag_apply,
                  onTap: () => _handleActionUtxoSelected(showTagBottomSheet),
                ),
              ),
              Expanded(
                child: _buildSelectionActionButton(
                  iconPath: 'assets/svg/lock_simple.svg',
                  text: t.utxo_list_screen.utxo_locked_button,
                  onTap:
                      () => _handleActionUtxoSelected(() {
                        _utxoListKey.currentState?._updateSelectedUtxos(lock: true);
                      }),
                ),
              ),
              Expanded(
                child: _buildSelectionActionButton(
                  iconPath: 'assets/svg/unlock_simple.svg',
                  text: t.utxo_list_screen.utxo_unlocked_button,
                  onTap:
                      () => _handleActionUtxoSelected(() {
                        _utxoListKey.currentState?._updateSelectedUtxos(lock: false);
                      }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSelectionActionButton({
    required String iconPath,
    required String text,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return BottomActionButton(
      iconPath: iconPath,
      label: text,
      onTap: onTap,
      enabled: enabled,
      buttonLayout: BottomActionButtonLayout.vertical,
      iconSize: 24,
      spacing: 4,
      textStyle: const TextStyle(color: CoconutColors.gray100, fontSize: 12, fontWeight: FontWeight.bold),
    );
  }

  void _handleActionUtxoSelected(VoidCallback action) {
    if (_utxoListKey.currentState?._selectedUtxoIds.isEmpty ?? true) {
      CoconutToast.showToast(context: context, text: t.utxo_list_screen.utxo_select_required, isVisibleIcon: true);
      return;
    }
    action();
  }

  Future<void> showTagBottomSheet() async {
    final selectedUtxoIds = _utxoListKey.currentState?._selectedUtxoIds.toList() ?? [];

    final result = await showModalBottomSheet<TagApplyResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TagApplyBottomSheet(walletId: widget.id, selectedUtxoIds: selectedUtxoIds),
    );

    if (result == null) return;
    if (!mounted) return;

    final mode = result.mode;
    final tagStates = result.tagStates;

    if (mode == UtxoTagApplyEditMode.add ||
        mode == UtxoTagApplyEditMode.update ||
        mode == UtxoTagApplyEditMode.delete) {
      viewModel.refetchFromDB();
      viewModel.deselectTaggedUtxo();
      return;
    }

    if (mode == UtxoTagApplyEditMode.changeAppliedTags) {
      final tagProvider = context.read<UtxoTagProvider>();

      await tagProvider.applyTagsToUtxos(
        walletId: widget.id,
        selectedUtxoIds: selectedUtxoIds,
        tagStates: tagStates,
        getCurrentTagsCallback: (utxoId) => _utxoListKey.currentState?._getCurrentTagsForUtxo(utxoId) ?? [],
      );

      viewModel.refetchFromDB();
      viewModel.deselectTaggedUtxo();

      setState(() {
        _utxoListKey.currentState?._selectedUtxoIds.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        CoconutToast.showToast(
          context: context,
          isVisibleIcon: true,
          iconPath: 'assets/svg/circle-info.svg',
          text: t.utxo_list_screen.utxo_tag_updated,
        );
      }
    }
  }

  // ──────────────────────────────
  // Event Handlers
  // ──────────────────────────────
  void _onScroll() {
    _hideDropdown();
    if (!_scrollController.hasClients) return;
    final shouldShowSticky = _scrollController.offset > _topPadding;
    if (_stickyHeaderVisible.value != shouldShowSticky) {
      _stickyHeaderVisible.value = shouldShowSticky;
      shouldShowSticky ? _showStickyHeaderAndUpdateDropdownPosition() : _hideStickyHeaderAndUpdateDropdownPosition();
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _isSelectionMode ? viewModel.setActiveUtxoTagName(t.all) : _deselectAll();
    });
  }

  void _toggleDropdownSticky() {
    _dropdownVisible.value = !_dropdownVisible.value;
    _scrollController.jumpTo(_scrollController.offset);
    _showStickyHeaderAndUpdateDropdownPosition();
  }

  void _toggleUnit() {
    setState(() {
      _currentUnit = _currentUnit.next;
    });
  }

  void _hideDropdown() => _dropdownVisible.value = false;

  void _showStickyHeaderAndUpdateDropdownPosition() =>
      _updateDropdownPosition(_isSelectionMode ? _selectModeStickyHeaderDropdownKey : _stickyHeaderDropdownKey, true);

  void _hideStickyHeaderAndUpdateDropdownPosition() =>
      _updateDropdownPosition(_isSelectionMode ? _selectModeHeaderDropdownKey : _headerDropdownKey, false);

  void _updateDropdownPosition(GlobalKey key, bool isSticky) {
    final ctx = key.currentContext;
    if (ctx == null) return;

    final renderBox = ctx.findRenderObject() as RenderBox;
    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    if (isSticky) {
      _stickyDropdownPos = position;
      _stickyDropdownSize = size;
    } else {
      _headerDropdownPos = position;
      _headerDropdownSize = size;
    }
  }

  void _calculateTopPadding() {
    final appBarBox = _appBarKey.currentContext?.findRenderObject() as RenderBox?;
    final headerBox = _headerKey.currentContext?.findRenderObject() as RenderBox?;
    final stickyBox = _stickyHeaderKey.currentContext?.findRenderObject() as RenderBox?;

    setState(() {
      _appBarSize = appBarBox?.size ?? Size.zero;
      _topPadding = (headerBox?.size.height ?? 0) - (stickyBox?.size.height ?? 0);
    });
  }

  void _enableStatusBarTapScroll() {
    if (_statusBarTapOverlay != null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _statusBarTapOverlay = OverlayEntry(
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
      Overlay.of(context).insert(_statusBarTapOverlay!);
    });
  }

  void _selectAll(String tagName) {
    _hideDropdown();
    viewModel
      ..setActiveUtxoTagName(tagName)
      ..selectTaggedUtxo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _utxoListKey.currentState?._setSelectedUtxosFromViewModel(viewModel.selectedUtxoList);
    });
    setState(() {});
  }

  void _deselectAll() {
    _hideDropdown();
    viewModel.deselectTaggedUtxo();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _utxoListKey.currentState?._setSelectedUtxosFromViewModel(viewModel.selectedUtxoList);
    });
    setState(() {});
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
  // Displayed Data
  late List<UtxoState> _displayedUtxoList = [];
  final Set<String> _selectedUtxoIds = {};

  // Keys
  final GlobalKey<SliverAnimatedListState> _utxoListKey = GlobalKey<SliverAnimatedListState>();
  final GlobalKey<SliverAnimatedListState> _lockedUtxoListKey = GlobalKey<SliverAnimatedListState>();
  final GlobalKey<SliverAnimatedListState> _changeUtxoListKey = GlobalKey<SliverAnimatedListState>();

  // Animation Durations
  final Duration _duration = const Duration(milliseconds: 1200);
  final Duration _animationDuration = const Duration(milliseconds: 100);

  // State
  bool _isListLoading = false;
  PersistentBottomSheetController? _bottomSheetController;

  @override
  Widget build(BuildContext context) {
    double bottomInset = MediaQuery.of(context).padding.bottom;

    return Selector<UtxoListViewModel, Tuple3<List<UtxoState>, String, UtxoOrder>>(
      selector: (_, vm) => Tuple3(vm.utxoList, vm.activeUtxoTagName, vm.activeUtxoOrder),
      shouldRebuild: (prev, next) => prev.item1 != next.item1 || prev.item2 != next.item2 || prev.item3 != next.item3,
      builder: (_, data, __) {
        final utxoList = data.item1;
        final activeTag = data.item2;

        if (utxoList.isEmpty) return _buildEmptyState();

        if (_isListChanged(_displayedUtxoList, utxoList)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleUtxoListChange(utxoList);
          });
        }

        return SliverPadding(
          padding: EdgeInsets.only(bottom: bottomInset + 70),
          sliver: _buildSliverAnimatedList(utxoList, activeTag),
        );
      },
    );
  }

  // --------------------
  // Sliver & List Building
  // --------------------
  Widget _buildSliverAnimatedList(List<UtxoState> utxoList, String activeTag) {
    Key listKey;
    if (activeTag == t.utxo_detail_screen.utxo_locked) {
      listKey = _lockedUtxoListKey;
    } else if (activeTag == t.change) {
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
        if (!_belongsToTag(utxo, activeTag)) return const SizedBox();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildUtxoItem(utxo, _buildSlideAnimation(animation)),
        );
      },
    );
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

  bool _belongsToTag(UtxoState utxo, String? tagName) {
    if (tagName == null || tagName.isEmpty) return false;

    final matchers = {
      t.all: true,
      t.utxo_detail_screen.utxo_locked: utxo.status == UtxoStatus.locked,
      t.change: utxo.isChange == true,
    };

    return matchers[tagName] ?? (utxo.tags?.any((e) => e.name == tagName) ?? false);
  }

  // --------------------
  // Selection
  // --------------------
  void _setSelectedUtxosFromViewModel(List<UtxoState> selectedList) {
    setState(() {
      _selectedUtxoIds
        ..clear()
        ..addAll(selectedList.map((u) => u.utxoId));
    });
  }

  Future<void> _updateSelectedUtxos({required bool lock}) async {
    if (_selectedUtxoIds.isEmpty) return;

    final viewModel = context.read<UtxoListViewModel>();
    final selectedCount = _selectedUtxoIds.length;

    try {
      final changedCount = await viewModel.setUtxoLockStatus(_selectedUtxoIds.toList(), lock);

      setState(() {
        _selectedUtxoIds.clear();
        widget.onSettingLockChanged?.call(false);
      });

      if (!mounted) return;

      final toastText = _buildLockToastMessage(lock: lock, selectedCount: selectedCount, changedCount: changedCount);

      if (changedCount == 0) {
        CoconutToast.showToast(
          context: context,
          isVisibleIcon: true,
          iconPath: 'assets/svg/triangle-warning.svg',
          text: toastText,
          level: CoconutToastLevel.warning,
        );
      } else {
        CoconutToast.showToast(
          context: context,
          isVisibleIcon: true,
          iconPath: 'assets/svg/circle-info.svg',
          text: toastText,
        );
      }

      _bottomSheetController?.close();
    } catch (e) {
      debugPrint('UTXO 상태 업데이트 실패: $e');
    }
  }

  String _buildLockToastMessage({required bool lock, required int selectedCount, required int changedCount}) {
    if (changedCount == 0) {
      if (selectedCount == 1) {
        return lock ? t.utxo_detail_screen.utxo_already_locked : t.utxo_detail_screen.utxo_already_unlocked;
      }
      return lock ? t.utxo_detail_screen.utxo_all_already_locked : t.utxo_detail_screen.utxo_all_already_unlocked;
    }

    if (changedCount == 1) {
      return lock ? t.utxo_detail_screen.utxo_locked_toast_msg : t.utxo_detail_screen.utxo_unlocked_toast_msg;
    }

    return lock
        ? t.utxo_detail_screen.utxo_locked_count_toast_msg(count: changedCount)
        : t.utxo_detail_screen.utxo_unlocked_count_toast_msg(count: changedCount);
  }

  // --------------------
  // Item Builders
  // --------------------
  Widget _buildUtxoItem(UtxoState utxo, Animation<Offset> offsetAnimation) {
    final viewModel = context.read<UtxoListViewModel>();
    final isSelectionMode = widget.isSelectionMode;
    final isSelected = _selectedUtxoIds.contains(utxo.utxoId);

    return SlideTransition(
      position: offsetAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: UtxoItemCard(
          key: Key(utxo.utxoId),
          currentUnit: widget.currentUnit,
          utxo: utxo,
          isSelected: isSelected,
          isSelectionMode: isSelectionMode,
          onPressed: () {
            if (isSelectionMode) {
              if (utxo.status == UtxoStatus.outgoing || utxo.status == UtxoStatus.incoming) {
                CoconutToast.showToast(context: context, text: t.utxo_list_screen.pending_utxo, isVisibleIcon: true);

                return;
              }
              setState(() {
                if (_selectedUtxoIds.contains(utxo.utxoId)) {
                  _selectedUtxoIds.remove(utxo.utxoId);
                  viewModel.removeSelectUtxo(utxo);
                } else {
                  _selectedUtxoIds.add(utxo.utxoId);
                  viewModel.addSelectUtxo(utxo);
                }
              });
            } else {
              _openDetailPage(utxo, viewModel);
            }
          },
          // 요소 중 하나를 Long Press 하면 선택 모드로 진입
          onLongPress: () {
            if (isSelectionMode) return;
            if (utxo.status == UtxoStatus.outgoing || utxo.status == UtxoStatus.incoming) {
              CoconutToast.showToast(context: context, text: t.utxo_list_screen.pending_utxo, isVisibleIcon: true);
              return;
            }
            setState(() {
              _selectedUtxoIds.add(utxo.utxoId);
              viewModel.addSelectUtxo(utxo);
            });
            widget.onSettingLockChanged?.call(true);
          },
        ),
      ),
    );
  }

  void _openDetailPage(UtxoState utxo, UtxoListViewModel viewModel) async {
    widget.onRemoveDropdown();
    await Navigator.pushNamed(context, '/utxo-detail', arguments: {'utxo': utxo, 'id': widget.walletId});
    viewModel.refetchFromDB();
  }

  Animation<Offset> _buildSlideAnimation(Animation<double> animation) {
    return Tween(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).chain(CurveTween(curve: Curves.easeOutExpo)).animate(animation);
  }

  Widget _buildRemoveUtxoItem(UtxoState utxo, Animation<double> animation) {
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: AnimationUtil.buildSlideOutAnimation(animation),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: UtxoItemCard(
            key: Key(utxo.utxoId),
            currentUnit: widget.currentUnit,
            utxo: utxo,
            onPressed: () async {
              widget.onRemoveDropdown();
              await Navigator.pushNamed(context, '/utxo-detail', arguments: {'utxo': utxo, 'id': widget.walletId});
            },
          ),
        ),
      ),
    );
  }

  // --------------------
  // List Change Handling
  // --------------------
  Future<void> _handleUtxoListChange(List<UtxoState> utxoList) async {
    final isFirstLoad = _displayedUtxoList.isEmpty && utxoList.isNotEmpty;
    if (_isListLoading) return;
    _isListLoading = true;

    final oldMap = {for (var u in _displayedUtxoList) u.utxoId: u};
    final newMap = {for (var u in utxoList) u.utxoId: u};

    final inserted = <int>[];
    final removed = <int>[];

    for (int i = 0; i < utxoList.length; i++) {
      if (!oldMap.containsKey(utxoList[i].utxoId)) inserted.add(i);
    }
    for (int i = 0; i < _displayedUtxoList.length; i++) {
      if (!newMap.containsKey(_displayedUtxoList[i].utxoId)) removed.add(i);
    }

    setState(() => _displayedUtxoList = List.from(utxoList));

    for (var index in removed.reversed) {
      if (index >= _displayedUtxoList.length) continue;
      await Future.delayed(_animationDuration);
      if (!mounted) return;
      _utxoListKey.currentState?.removeItem(
        index,
        (c, anim) => _buildRemoveUtxoItem(_displayedUtxoList[index], anim),
        duration: _duration,
      );
    }

    for (var index in inserted) {
      await Future.delayed(_animationDuration);
      if (!mounted) return;
      _utxoListKey.currentState?.insertItem(index, duration: _duration);
    }

    _isListLoading = false;
    if (isFirstLoad) widget.onFirstBuildCompleted();
  }

  // --------------------
  // Utilities
  // --------------------
  bool _isListChanged(List<UtxoState> oldList, List<UtxoState> newList) {
    if (oldList.length != newList.length) return true;
    if (oldList.isEmpty && newList.isEmpty) return false;

    for (int i = 0; i < oldList.length; i++) if (oldList[i].utxoId != newList[i].utxoId) return true;

    final oldMap = {for (var u in oldList) u.utxoId: u};
    final newMap = {for (var u in newList) u.utxoId: u};

    for (final key in oldMap.keys) {
      if (!newMap.containsKey(key)) return true;
    }

    for (final id in oldMap.keys) {
      final oldU = oldMap[id]!;
      final newU = newMap[id]!;
      if (oldU.status != newU.status) return true;
      if (!_equalTagLists(oldU.tags, newU.tags)) return true;
    }
    return false;
  }

  bool _equalTagLists(List<UtxoTag>? a, List<UtxoTag>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    if (a.isEmpty) return true;
    return Set<UtxoTag>.from(a).containsAll(Set<UtxoTag>.from(b));
  }

  @override
  void didUpdateWidget(covariant UtxoList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSelectionMode != widget.isSelectionMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<String> _getCurrentTagsForUtxo(String utxoId) {
    final utxo = _displayedUtxoList.where((u) => u.utxoId == utxoId).firstOrNull;
    return utxo?.tags?.map((tag) => tag.name).toList() ?? [];
  }
}
