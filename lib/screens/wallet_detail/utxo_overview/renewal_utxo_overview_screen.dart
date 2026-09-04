import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup;
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/constants/dust_constants.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_bucket.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_list_view_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/renewal_utxo_list_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_bucket_card_row.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_bucket_scroll_rail.dart';
import 'package:coconut_wallet/screens/common/tag_apply_bottom_sheet.dart';
import 'package:coconut_wallet/screens/settings/utxo_tier_theme_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/common/buttons/bottom_action_bar.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_filter_bar.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_summary_chart.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_tag_chart.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/renewal_utxo_overview_filter_widgets.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/renewal_utxo_overview_header.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_list_screen.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/utils/utxo_amount_format_util.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_refresh_icon.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/features/utxo/dropdown/utxo_filter_dropdown.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

class RenewalUtxoOverviewScreen extends StatefulWidget {
  final int id;
  const RenewalUtxoOverviewScreen({super.key, required this.id});

  @override
  State<RenewalUtxoOverviewScreen> createState() => _RenewalUtxoOverviewScreenState();
}

class _RenewalUtxoOverviewScreenState extends State<RenewalUtxoOverviewScreen> {
  late RenewalUtxoListViewModel viewModel;
  BitcoinUnit _currentUnit = BitcoinUnit.btc;

  late List<UtxoBucket> _buckets;
  late String _utxoDataKey;

  final _headerScrollController = ScrollController();
  ScrollController? _contentScrollController;
  final _activeIndex = ValueNotifier<int>(0);
  final _activeBucketY = ValueNotifier<double>(0);

  final GlobalKey _scrollRailKey = GlobalKey();
  final GlobalKey _listOrderDropdownKey = GlobalKey();
  bool _isListOrderDropdownVisible = false;
  double _listOrderDropdownTop = 0;

  int get _dustThreshold => viewModel.walletType.addressType.dustThreshold;

  bool _isSnappingHeader = false;
  bool _isSwitchingPrimaryTab = false;
  final ValueNotifier<double> _collapseProgress = ValueNotifier<double>(0);

  static const double _filterBarBaseHeight = 58;
  static const double _selectionSummaryRowHeight = 40;
  static const double _filterBarExpandedHeight = _filterBarBaseHeight + _selectionSummaryRowHeight;

  late List<UtxoBucket> _filteredBuckets;
  late List<GlobalKey> _filteredBucketKeys;

  /// 상세 화면 복귀 시 복원할 상태
  String? _restoreUtxoId;
  double? _restoreScrollOffset;
  bool _isRestoringState = false;
  final _restoredStateListenable = ValueNotifier<({int bucket, int card})?>(null);

  List<UtxoBucket> _computeFilteredBuckets() {
    return viewModel.filterBuckets(_buckets, showLocked: viewModel.lockFilterIndex == 1);
  }

  void _updateFilteredBuckets({bool preserveUiState = false}) {
    _filteredBuckets = _computeFilteredBuckets();
    if (preserveUiState && _filteredBucketKeys.length == _filteredBuckets.length) {
      // 키 유지 → 위젯 트리/State 보존
    } else {
      _filteredBucketKeys = List.generate(_filteredBuckets.length, (_) => GlobalKey());
    }
    if (!preserveUiState) {
      _activeIndex.value = 0;
    }
  }

  void _refreshBucketsFromViewModel() {
    _buckets = viewModel.buildBuckets();
    final preserving = _restoreUtxoId != null;
    _updateFilteredBuckets(preserveUiState: preserving);
    _restoreStateAfterReturn();
  }

  void _restoreStateAfterReturn() {
    final utxoId = _restoreUtxoId;
    final scrollOffset = _restoreScrollOffset;
    _restoreUtxoId = null;
    _restoreScrollOffset = null;
    if (utxoId == null) return;
    if (!viewModel.isByAmount || viewModel.viewModeIndex != 0) return;

    _isRestoringState = true;
    final bucketIdx = _filteredBuckets.indexWhere((b) => b.utxos.any((u) => u.utxoId == utxoId));
    if (bucketIdx >= 0) {
      final bucket = _filteredBuckets[bucketIdx];
      final cardIdx = bucket.utxos.indexWhere((u) => u.utxoId == utxoId);
      _activeIndex.value = bucketIdx;
      if (cardIdx >= 0) {
        _restoredStateListenable.value = (bucket: bucketIdx, card: cardIdx);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final controller = _contentScrollController;
        if (controller != null && controller.hasClients) {
          final pos = controller.position;
          final targetOffset =
              scrollOffset != null
                  ? scrollOffset.clamp(pos.minScrollExtent, pos.maxScrollExtent)
                  : _scrollOffsetForBucket(bucketIdx, pos);
          controller.jumpTo(targetOffset);
        }
        setState(() {}); // 스크롤 후 리스트 rebuild 유도
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateBucketY(bucketIdx);
          Future.delayed(const Duration(milliseconds: 350), () {
            if (!mounted) return;
            _updateBucketY(bucketIdx);
            _restoredStateListenable.value = null;
            setState(() => _isRestoringState = false);
          });
        });
      });
    } else {
      _isRestoringState = false;
    }
  }

  double _scrollOffsetForBucket(int bucketIdx, ScrollPosition pos) {
    final filterBarH = _effectiveFilterBarHeight;
    final listStart = UtxoSummaryChart.estimatedHeight + filterBarH;
    final target = listStart + bucketIdx * _itemHeight - (pos.viewportDimension - filterBarH) / 2 + _itemHeight / 2;
    return target.clamp(pos.minScrollExtent, pos.maxScrollExtent);
  }

  @override
  void initState() {
    super.initState();

    viewModel = RenewalUtxoListViewModel(
      widget.id,
      context.read<WalletProvider>(),
      context.read<TransactionProvider>(),
      context.read<UtxoTagProvider>(),
      context.read<ConnectivityProvider>(),
      context.read<PriceProvider>(),
      context.read<PreferenceProvider>(),
      context.read<NodeProvider>().getWalletStateStream(widget.id),
    );

    _buckets = viewModel.buildBuckets();
    _utxoDataKey = viewModel.utxoDataKey;
    _updateFilteredBuckets();

    viewModel.addListener(_onViewModelChanged);
    _headerScrollController.addListener(_handleHeaderScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateActiveBucket();
    });
  }

  double get _effectiveFilterBarHeight =>
      _shouldShowAmountSelectionSummary ? _filterBarExpandedHeight : _filterBarBaseHeight;
  double get _effectiveTagSelectionBarHeight => viewModel.isSelectionMode ? _filterBarBaseHeight : 0;

  bool get _shouldShowAmountSelectionSummary =>
      viewModel.isByAmount && viewModel.viewModeIndex == 1 && viewModel.isSelectionMode;

  void _exitSelectionMode() {
    if (!mounted) return;
    setState(() {
      viewModel.isSelectionMode = false;
      viewModel.selectedUtxoIds.clear();
      viewModel.selectionBarExiting = false;
    });
  }

  int get _selectedTotalSats {
    return viewModel.getUtxoAmountByIds(viewModel.selectedUtxoIds);
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    setState(() {
      final nextDataKey = viewModel.utxoDataKey;
      if (_utxoDataKey == nextDataKey) return;
      _utxoDataKey = nextDataKey;
      _refreshBucketsFromViewModel();
    });
  }

  Future<void> _navigateToUtxoDetail(UtxoState utxo) async {
    _restoreUtxoId = utxo.utxoId;
    _restoreScrollOffset = _contentScrollController?.hasClients == true ? _contentScrollController!.offset : null;

    await Navigator.pushNamed(context, '/utxo-detail', arguments: {'utxo': utxo, 'id': widget.id});
    if (mounted) {
      viewModel.refetchFromDB();
    }
  }

  void _toggleUnit() {
    setState(() => _currentUnit = _currentUnit.next);
  }

  @override
  void dispose() {
    viewModel.removeListener(_onViewModelChanged);
    _contentScrollController?.removeListener(_updateActiveBucket);
    _headerScrollController.removeListener(_handleHeaderScroll);
    _headerScrollController.dispose();
    _activeIndex.dispose();
    _activeBucketY.dispose();
    _collapseProgress.dispose();
    _restoredStateListenable.dispose();
    super.dispose();
  }

  static const double _collapseExtent = 96;

  void _handleHeaderScroll() {
    if (!_headerScrollController.hasClients) return;
    final next = (_headerScrollController.offset / _collapseExtent).clamp(0.0, 1.0);
    if ((next - _collapseProgress.value).abs() > 0.002) {
      _collapseProgress.value = next;
    }
  }

  bool _handleScrollEnd(ScrollEndNotification notification) {
    if (!_headerScrollController.hasClients || _isSnappingHeader || notification.depth != 0) {
      return false;
    }
    final offset = _headerScrollController.offset;
    if (offset <= 0 || offset >= _collapseExtent) return false;
    final target = offset < _collapseExtent * 0.7 ? 0.0 : _collapseExtent;
    _isSnappingHeader = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_headerScrollController.hasClients) {
        _isSnappingHeader = false;
        return;
      }
      HapticFeedback.selectionClick();
      try {
        await _headerScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      } finally {
        _isSnappingHeader = false;
      }
    });
    return false;
  }

  Future<void> _selectPrimaryTab(int index) async {
    final selectOverview = index == 0;
    if (_isSwitchingPrimaryTab || selectOverview == viewModel.isOverviewTab) {
      return;
    }

    _isSwitchingPrimaryTab = true;
    if (mounted) {
      setState(() {
        viewModel.isOverviewTab = selectOverview;
        _isListOrderDropdownVisible = false;
        viewModel.isSelectionMode = false;
        viewModel.selectedUtxoIds.clear();
      });
    }

    await WidgetsBinding.instance.endOfFrame;
    if (mounted && _headerScrollController.hasClients && _headerScrollController.offset > 0) {
      _isSnappingHeader = true;
      final duration = Duration(milliseconds: (280 + _headerScrollController.offset * 0.8).round().clamp(320, 420));
      try {
        await _headerScrollController.animateTo(0, duration: duration, curve: Curves.easeInOutCubic);
      } finally {
        _isSnappingHeader = false;
      }
    }
    _isSwitchingPrimaryTab = false;
  }

  SliverPersistentHeader _buildMorphingHeader() {
    final totalSats = viewModel.utxoList.fold<int>(0, (sum, utxo) => sum + utxo.amount);
    return SliverPersistentHeader(
      pinned: true,
      delegate: RenewalUtxoHeaderDelegate(
        topPadding: MediaQuery.paddingOf(context).top,
        totalBalance: formatUtxoAmountForDisplay(totalSats, _currentUnit, dustThreshold: _dustThreshold),
        fiatPrice: viewModel.fiatPriceString,
        bottomBar:
            viewModel.isOverviewTab
                ? RenewalUtxoGroupingTabBar(isByAmount: viewModel.isByAmount, onSelected: _selectGroupingTab)
                : RenewalUtxoListFilterHeader(
                  viewModel: viewModel,
                  dropdownKey: _listOrderDropdownKey,
                  onTapDropdown: _toggleListOrderDropdown,
                ),
        isOverviewSelected: viewModel.isOverviewTab,
        onBackPressed: () => Navigator.pop(context),
        onTabChanged: _selectPrimaryTab,
        refreshButton: ListenableBuilder(
          listenable: viewModel,
          builder: (context, _) {
            return CoconutAppBarActionButton(
              onPressed: viewModel.isRefreshing || viewModel.isSyncing ? null : viewModel.refresh,
              icon: WalletRefreshIcon(isRefreshing: viewModel.isRefreshing, size: 20),
            );
          },
        ),
      ),
    );
  }

  void _selectGroupingTab(int index) {
    setState(() {
      viewModel.isByAmount = index == 0;
      viewModel.isSelectionMode = false;
      viewModel.selectedUtxoIds.clear();
      viewModel.selectionBarExiting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UtxoListViewModel>.value(
      value: viewModel,
      child: Scaffold(
        backgroundColor: context.coconutColors.background,
        body: Stack(
          children: [
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (event) {
                if (_isListOrderDropdownVisible && !_isInsideListOrderButton(event.position)) {
                  setState(() => _isListOrderDropdownVisible = false);
                }
              },
              child: NotificationListener<ScrollEndNotification>(
                onNotification: _handleScrollEnd,
                child: NestedScrollView(
                  controller: _headerScrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  headerSliverBuilder: (context, innerBoxIsScrolled) => [_buildMorphingHeader()],
                  body: Builder(
                    builder: (innerContext) {
                      _bindContentScrollController(innerContext);
                      return Consumer<UtxoTagProvider>(
                        builder: (context, tagProvider, _) {
                          final utxoTagList = tagProvider.getUtxoTagList(widget.id);
                          if (!viewModel.isOverviewTab) {
                            return _buildUtxoListBody();
                          }
                          return viewModel.isByAmount ? _buildAmountViewBody() : _buildTagViewBody(utxoTagList);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
            if (_isListOrderDropdownVisible)
              UtxoOrderDropdown(
                isVisible: true,
                positionTop: _listOrderDropdownTop,
                activeOption: viewModel.activeUtxoOrder,
                isSelectionMode: false,
                onOptionSelected: (order) {
                  setState(() => _isListOrderDropdownVisible = false);
                  viewModel.updateUtxoFilter(order as UtxoOrder);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildUtxoListBody() {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: viewModel.refresh, refreshTriggerPullDistance: 80),
        UtxoList(
          walletId: widget.id,
          currentUnit: _currentUnit,
          emptyStateText:
              viewModel.activeUtxoTagName == t.utxo_detail_screen.utxo_locked
                  ? t.utxo_overview_screen.no_locked_utxos
                  : viewModel.activeUtxoTagName == t.change
                  ? t.utxo_overview_screen.no_change_utxos
                  : null,
          emptyStateTextStyle: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
          isSelectionMode: false,
          onRemoveDropdown: () {},
          onSettingLockChanged: (_) {},
          onFirstBuildCompleted: () {},
        ),
      ],
    );
  }

  void _toggleListOrderDropdown() {
    if (_isListOrderDropdownVisible) {
      setState(() => _isListOrderDropdownVisible = false);
      return;
    }

    final renderBox = _listOrderDropdownKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final position = renderBox.localToGlobal(Offset.zero);
    setState(() {
      _listOrderDropdownTop = position.dy + renderBox.size.height + 8;
      _isListOrderDropdownVisible = true;
    });
  }

  bool _isInsideListOrderButton(Offset globalPosition) {
    final renderBox = _listOrderDropdownKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return false;
    return (renderBox.localToGlobal(Offset.zero) & renderBox.size).contains(globalPosition);
  }

  void _bindContentScrollController(BuildContext context) {
    final controller = PrimaryScrollController.maybeOf(context);
    if (controller == null || identical(controller, _contentScrollController)) {
      return;
    }
    _contentScrollController?.removeListener(_updateActiveBucket);
    _contentScrollController = controller;
    controller.addListener(_updateActiveBucket);
  }

  Widget _buildAmountViewBody() {
    return Stack(
      children: [
        if (viewModel.viewModeIndex == 0 && _filteredBuckets.length > 1)
          Positioned(
            left: -8,
            top: 0,
            bottom: 0,
            width: 34,
            child: UtxoBucketScrollRail(
              key: _scrollRailKey,
              buckets: _filteredBuckets,
              scrollController: _contentScrollController!,
              activeIndexListenable: _activeIndex,
              activeBucketY: _activeBucketY,
            ),
          ),
        CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            CupertinoSliverRefreshControl(onRefresh: viewModel.refresh, refreshTriggerPullDistance: 80),
            SliverToBoxAdapter(
              child: UtxoSummaryChart(
                buckets: _buckets,
                totalSats: viewModel.utxoList.fold<int>(0, (s, u) => s + u.amount),
                coinCount: viewModel.utxoList.length,
                availableCount: viewModel.utxoList.where((u) => u.status == UtxoStatus.unspent).length,
                availableSats: viewModel.utxoList
                    .where((u) => u.status == UtxoStatus.unspent)
                    .fold<int>(0, (s, u) => s + u.amount),
                lockedCount: viewModel.utxoList.where((u) => u.status == UtxoStatus.locked).length,
                lockedSats: viewModel.utxoList
                    .where((u) => u.status == UtxoStatus.locked)
                    .fold<int>(0, (s, u) => s + u.amount),
                currentUnit: _currentUnit,
                dustThreshold: _dustThreshold,
                onBalanceTap: _toggleUnit,
                onThemeSettingTap: () {
                  CommonBottomSheets.showCustomHeightBottomSheet(
                    context: context,
                    heightRatio: 0.6,
                    child: const UtxoTierThemeBottomSheet(),
                  );
                },
                hasReusedAddresses: _reusedAddresses.isNotEmpty,
                showBalanceHeader: false,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: UtxoAmountStickyFilterBarDelegate(
                height: _effectiveFilterBarHeight,
                selectedCount: viewModel.selectedUtxoIds.length,
                selectedTotalSats: _selectedTotalSats,
                currentUnit: _currentUnit,
                dustThreshold: _dustThreshold,
                viewModeIndex: viewModel.viewModeIndex,
                lockFilterIndex: viewModel.lockFilterIndex,
                isSelectionMode: viewModel.isSelectionMode,
                onViewModeSelected: (index) {
                  setState(() {
                    viewModel.viewModeIndex = index;
                    if (!viewModel.isSelectionMode) return;
                    viewModel.isSelectionMode = false;
                    viewModel.selectedUtxoIds.clear();
                    viewModel.selectionBarExiting = false;
                  });
                },
                onLockFilterSelected: (index) {
                  setState(() {
                    viewModel.lockFilterIndex = index;
                    _updateFilteredBuckets();
                  });
                },
                onExitSelectionMode: _exitSelectionMode,
              ),
            ),
            if (_filteredBuckets.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    viewModel.lockFilterIndex == 0
                        ? t.utxo_overview_screen.no_available_utxos
                        : t.utxo_overview_screen.no_locked_utxos,
                    textAlign: TextAlign.center,
                    style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                  ),
                ),
              )
            else if (viewModel.viewModeIndex == 0)
              SliverPadding(
                padding: const EdgeInsets.only(left: 38),
                sliver: SliverList.builder(
                  itemCount: _filteredBuckets.length,
                  itemBuilder: (context, index) {
                    final bucket = _filteredBuckets[index];
                    return Padding(
                      key: _filteredBucketKeys[index],
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                      child: UtxoBucketCardRow(
                        bucket: bucket,
                        index: index,
                        currentUnit: _currentUnit,
                        dustThreshold: _dustThreshold,
                        activeIndexListenable: _activeIndex,
                        restoredStateListenable: _restoredStateListenable,
                        isSelectionMode: viewModel.isSelectionMode,
                        selectedUtxoIds: viewModel.selectedUtxoIds,
                        reusedAddresses: _reusedAddresses,
                        suspiciousUtxoIds: _suspiciousUtxoIds,
                        onTapUtxo: (u) {
                          if (viewModel.isSelectionMode) {
                            if (u.status == UtxoStatus.outgoing || u.status == UtxoStatus.incoming) {
                              CoconutToast.showToast(
                                context: context,
                                text: t.utxo_list_screen.pending_utxo,
                                isVisibleIcon: false,
                              );
                              return;
                            }
                            setState(() {
                              if (viewModel.selectedUtxoIds.contains(u.utxoId)) {
                                viewModel.selectedUtxoIds.remove(u.utxoId);
                              } else {
                                viewModel.selectedUtxoIds.add(u.utxoId);
                              }
                            });
                          } else {
                            _navigateToUtxoDetail(u);
                          }
                        },
                        onLongPressUtxo: (u) {
                          if (u.status == UtxoStatus.outgoing || u.status == UtxoStatus.incoming) {
                            CoconutToast.showToast(
                              context: context,
                              text: t.utxo_list_screen.pending_utxo,
                              isVisibleIcon: false,
                            );
                            return;
                          }
                          setState(() {
                            viewModel.viewModeIndex = 1;
                            viewModel.isSelectionMode = true;
                            viewModel.selectedUtxoIds.add(u.utxoId);
                          });
                        },
                        setActiveIndex: (index) => _activeIndex.value = index,
                      ),
                    );
                  },
                ),
              )
            else
              _buildGridSliver(_currentUnit),
            SliverToBoxAdapter(child: SizedBox(height: _selectionBarBottomPadding(context))),
          ],
        ),
        BottomActionBarSlide(
          isVisible:
              (viewModel.isSelectionMode && viewModel.selectedUtxoIds.isNotEmpty) || viewModel.selectionBarExiting,
          child: _buildSelectionBottomBar(),
        ),
      ],
    );
  }

  Widget _buildTagViewBody(List<UtxoTag> utxoTagList) {
    return Stack(
      children: [
        _buildTagView(utxoTagList),
        BottomActionBarSlide(
          isVisible:
              (viewModel.isSelectionMode && viewModel.selectedUtxoIds.isNotEmpty) || viewModel.selectionBarExiting,
          child: _buildSelectionBottomBar(),
        ),
      ],
    );
  }

  Widget _buildTagView(List<UtxoTag> utxoTagList) {
    return CustomScrollView(
      clipBehavior: Clip.none,
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: viewModel.refresh, refreshTriggerPullDistance: 80),
        SliverToBoxAdapter(
          child: UtxoTagChart(
            utxoList: viewModel.utxoList,
            utxoTagList: utxoTagList,
            currentUnit: _currentUnit,
            dustThreshold: _dustThreshold,
            onBalanceTap: _toggleUnit,
            showBalanceHeader: false,
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: UtxoTagSelectionBarDelegate(
            height: _effectiveTagSelectionBarHeight,
            selectedCount: viewModel.selectedUtxoIds.length,
            selectedTotalSats: _selectedTotalSats,
            currentUnit: _currentUnit,
            dustThreshold: _dustThreshold,
            isSelectionMode: viewModel.isSelectionMode,
            onExitSelectionMode: () {
              _exitSelectionMode();
            },
          ),
        ),
        SliverToBoxAdapter(
          child: UtxoTagGridSection(
            key: ValueKey(utxoTagList.map((t) => t.id).join(',')),
            utxoList: viewModel.utxoList,
            utxoTagList: utxoTagList,
            currentUnit: _currentUnit,
            dustThreshold: _dustThreshold,
            selectedUtxoIds: viewModel.selectedUtxoIds,
            reusedAddresses: _reusedAddresses,
            suspiciousUtxoIds: _suspiciousUtxoIds,
            isSelectionMode: viewModel.isSelectionMode,
            onUtxoTap: (u) {
              if (viewModel.isSelectionMode) {
                if (u.status == UtxoStatus.outgoing || u.status == UtxoStatus.incoming) {
                  CoconutToast.showToast(context: context, text: t.utxo_list_screen.pending_utxo, isVisibleIcon: false);
                  return;
                }
                setState(() {
                  if (viewModel.selectedUtxoIds.contains(u.utxoId)) {
                    viewModel.selectedUtxoIds.remove(u.utxoId);
                  } else {
                    viewModel.selectedUtxoIds.add(u.utxoId);
                  }
                });
              } else {
                _navigateToUtxoDetail(u);
              }
            },
            onUtxoLongPress: (u) {
              if (u.status == UtxoStatus.outgoing || u.status == UtxoStatus.incoming) {
                CoconutToast.showToast(context: context, text: t.utxo_list_screen.pending_utxo, isVisibleIcon: false);
                return;
              }
              setState(() {
                viewModel.isSelectionMode = true;
                viewModel.selectedUtxoIds.add(u.utxoId);
              });
            },
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: _selectionBarBottomPadding(context))),
      ],
    );
  }

  Widget _buildSelectionBottomBar() {
    final showBar = viewModel.selectedUtxoIds.isNotEmpty || viewModel.selectionBarExiting;
    if (!showBar) return const SizedBox.shrink();

    final lockFilter = viewModel.selectionBarExiting ? viewModel.lastLockFilterForBar : viewModel.lockFilterIndex;
    final isLockedFilter = lockFilter == 1;

    return BottomActionBar(
      child:
          viewModel.isByAmount
              ? (isLockedFilter
                  ? BottomActionButton(
                    iconPath: CommonSecurityIconPath.unlock,
                    label: t.utxo_list_screen.utxo_unlocked_button,
                    onTap: () => _updateSelectedUtxosLock(lock: false),
                    buttonLayout: BottomActionButtonLayout.horizontal,
                    textStyle: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.iconPrimary),
                  )
                  : Builder(
                    builder: (context) {
                      final selectedUtxos =
                          viewModel.utxoList.where((u) => viewModel.selectedUtxoIds.contains(u.utxoId)).toList();
                      final hasLockedUtxo = selectedUtxos.any((u) => u.status == UtxoStatus.locked);
                      return Row(
                        children: [
                          Expanded(
                            child: BottomActionButton(
                              iconPath: FeatureTransactionIconPath.send,
                              label: t.send,
                              onTap: _onSendPressed,
                              enabled: !hasLockedUtxo,
                              buttonLayout: BottomActionButtonLayout.horizontal,
                              textStyle: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: BottomActionButton(
                              iconPath: CommonSecurityIconPath.lock,
                              label: t.utxo_list_screen.utxo_locked_button,
                              onTap: () => _updateSelectedUtxosLock(lock: true),
                              buttonLayout: BottomActionButtonLayout.horizontal,
                              textStyle: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.iconPrimary),
                            ),
                          ),
                        ],
                      );
                    },
                  ))
              : _buildTagViewSelectionButtons(),
    );
  }

  Widget _buildTagViewSelectionButtons() {
    final selectedUtxos = viewModel.utxoList.where((u) => viewModel.selectedUtxoIds.contains(u.utxoId)).toList();
    final hasLockedUtxo = selectedUtxos.any((u) => u.status == UtxoStatus.locked);

    return Row(
      children: [
        Expanded(
          child: BottomActionButton(
            iconPath: FeatureTransactionIconPath.send,
            label: t.send,
            onTap: () {
              if (hasLockedUtxo) {
                CoconutToast.showToast(
                  context: context,
                  text: t.utxo_list_screen.send_locked_utxo,
                  isVisibleIcon: true,
                );
                return;
              }
              _onTagViewSendPressed(selectedUtxos);
            },
            enabled: !hasLockedUtxo,
            buttonLayout: BottomActionButtonLayout.horizontal,
            textStyle: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: BottomActionButton(
            iconPath: FeatureTagIconPath.tag,
            label: t.utxo_list_screen.tag_apply,
            onTap: _showTagApplyBottomSheet,
            buttonLayout: BottomActionButtonLayout.horizontal,
            textStyle: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
          ),
        ),
      ],
    );
  }

  void _onTagViewSendPressed(List<UtxoState> selectedUtxos) {
    if (selectedUtxos.isEmpty) return;
    setState(() {
      viewModel.isSelectionMode = false;
      viewModel.selectedUtxoIds.clear();
    });
    Navigator.pushNamed(
      context,
      '/send',
      arguments: {
        'walletId': widget.id,
        'sendEntryPoint': SendEntryPoint.walletDetail,
        'selectedUtxoList': selectedUtxos,
      },
    );
  }

  List<String> _getCurrentTagsForUtxo(String utxoId) {
    return viewModel.getCurrentTagNames(utxoId);
  }

  Future<void> _showTagApplyBottomSheet() async {
    if (viewModel.selectedUtxoIds.isEmpty) return;

    final selectedUtxoIds = viewModel.selectedUtxoIds.toList();
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
      setState(() {
        viewModel.selectedUtxoIds.clear();
        viewModel.isSelectionMode = false;
      });
      return;
    }

    if (mode == UtxoTagApplyEditMode.changeAppliedTags) {
      final tagProvider = context.read<UtxoTagProvider>();

      await tagProvider.applyTagsToUtxos(
        walletId: widget.id,
        selectedUtxoIds: selectedUtxoIds,
        tagStates: tagStates,
        getCurrentTagsCallback: _getCurrentTagsForUtxo,
      );

      viewModel.refetchFromDB();
      setState(() {
        viewModel.selectedUtxoIds.clear();
        viewModel.isSelectionMode = false;
      });

      if (mounted) {
        CoconutToast.showToast(
          context: context,
          isVisibleIcon: true,
          iconPath: CommonStateIconPath.circleInfo,
          text: t.utxo_list_screen.utxo_tag_updated,
        );
      }
    }
  }

  Future<void> _updateSelectedUtxosLock({required bool lock}) async {
    if (viewModel.selectedUtxoIds.isEmpty) return;
    final ids = viewModel.selectedUtxoIds.toList();
    final selectedCount = ids.length;
    try {
      final changedCount = await viewModel.setUtxoLockStatus(ids, lock);
      if (mounted) {
        setState(() {
          viewModel.selectedUtxoIds.clear();
          viewModel.isSelectionMode = false;
          viewModel.selectionBarExiting = false;
          _refreshBucketsFromViewModel();
        });
      }
      if (!mounted) return;

      // 이 문맥에서는 selectedCount, changedCount가 같은 상태만 존재함
      final toastText = viewModel.buildLockToastMessage(
        lock: lock,
        selectedCount: selectedCount,
        changedCount: changedCount,
      );

      if (changedCount == 0) {
        // 정상 동작에서 이 토스트는 나타나지 않아야함.
        CoconutToast.showToast(
          context: context,
          isVisibleIcon: true,
          iconPath: CommonStateIconPath.triangleWarning,
          text: toastText,
          level: CoconutToastLevel.warning,
        );
      } else {
        CoconutToast.showToast(
          context: context,
          isVisibleIcon: true,
          iconPath: CommonStateIconPath.circleInfo,
          text: toastText,
        );
      }
    } catch (e) {
      debugPrint('UTXO 상태 업데이트 실패: $e');
    }
  }

  void _onSendPressed() {
    if (viewModel.selectedUtxoIds.isEmpty) return;
    final selectedUtxos = viewModel.getUtxosByIds(viewModel.selectedUtxoIds);
    final hasLockedUtxo = selectedUtxos.any((u) => u.status == UtxoStatus.locked);
    if (hasLockedUtxo) {
      CoconutToast.showToast(context: context, text: t.utxo_list_screen.send_locked_utxo, isVisibleIcon: true);
      return;
    }
    setState(() {
      viewModel.isSelectionMode = false;
      viewModel.selectedUtxoIds.clear();
    });
    Navigator.pushNamed(
      context,
      '/send',
      arguments: {
        'walletId': widget.id,
        'sendEntryPoint': SendEntryPoint.walletDetail,
        'selectedUtxoList': selectedUtxos,
      },
    );
  }

  static const double _gridMaxCoinExtent = 100.0;

  Set<String> get _reusedAddresses => viewModel.reusedAddresses;

  Set<String> get _suspiciousUtxoIds => viewModel.suspiciousUtxoIds;

  Widget _buildGridSliver(BitcoinUnit currentUnit) {
    final utxos = _filteredBuckets.expand((b) => b.utxos).toList();
    const mainAxisSpacing = 6.0;
    const crossAxisSpacing = 12.0;
    const padding = 16.0;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(padding, 8, padding, 24),
      sliver: SliverGrid.builder(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: _gridMaxCoinExtent,
          mainAxisSpacing: mainAxisSpacing,
          crossAxisSpacing: crossAxisSpacing,
          childAspectRatio: 0.95,
        ),
        itemCount: utxos.length,
        itemBuilder: (context, index) {
          final utxo = utxos[index];
          final isSelected = viewModel.selectedUtxoIds.contains(utxo.utxoId);
          return LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight;
              return Center(
                child: UtxoCoinCard(
                  utxo: utxo,
                  size: size * 0.9,
                  compact: true,
                  isFocused: true,
                  isSelected: isSelected,
                  isSelectionMode: viewModel.isSelectionMode,
                  currentUnit: currentUnit,
                  dustThreshold: _dustThreshold,
                  isAddressReused: _reusedAddresses.contains(utxo.to),
                  isSuspiciousDust: _suspiciousUtxoIds.contains(utxo.utxoId),
                  onTap: () {
                    if (viewModel.isSelectionMode) {
                      if (utxo.status == UtxoStatus.outgoing || utxo.status == UtxoStatus.incoming) {
                        CoconutToast.showToast(
                          context: context,
                          text: t.utxo_list_screen.pending_utxo,
                          isVisibleIcon: false,
                        );
                        return;
                      }
                      setState(() {
                        if (viewModel.selectedUtxoIds.contains(utxo.utxoId)) {
                          viewModel.selectedUtxoIds.remove(utxo.utxoId);
                        } else {
                          viewModel.selectedUtxoIds.add(utxo.utxoId);
                        }
                      });
                    } else {
                      _navigateToUtxoDetail(utxo);
                    }
                  },
                  onLongPress: () {
                    if (utxo.status == UtxoStatus.outgoing || utxo.status == UtxoStatus.incoming) {
                      CoconutToast.showToast(
                        context: context,
                        text: t.utxo_list_screen.pending_utxo,
                        isVisibleIcon: false,
                      );
                      return;
                    }
                    setState(() {
                      viewModel.isSelectionMode = true;
                      viewModel.selectedUtxoIds.add(utxo.utxoId);
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  static const double _itemHeight = 10 + UtxoBucketCardRow.rowHeight + 10; // padding + row + padding

  static const double _baseBottomPadding = 48;
  static const double _selectionBarTopPadding = 40;
  static const double _selectionBarInnerBottomPadding = 8;
  static double get _selectionBarContentHeight =>
      _selectionBarTopPadding + BottomActionButton.horizontalHeight + _selectionBarInnerBottomPadding;

  double _selectionBarBottomPadding(BuildContext context) {
    final showBar =
        (viewModel.isSelectionMode && viewModel.selectedUtxoIds.isNotEmpty) || viewModel.selectionBarExiting;
    if (!showBar) return _baseBottomPadding;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return _baseBottomPadding + _selectionBarContentHeight + bottomInset * 2;
  }

  void _updateActiveBucket() {
    final controller = _contentScrollController;
    if (!mounted || controller == null || !controller.hasClients || _isRestoringState) {
      return;
    }

    final count = _filteredBuckets.length;
    if (count == 0) return;
    if (count <= 1) {
      if (_activeIndex.value != 0) _activeIndex.value = 0;
      _updateBucketY(0);
      return;
    }

    final pos = controller.position;
    final minExtent = pos.minScrollExtent;
    final maxExtent = pos.maxScrollExtent;
    final pixels = pos.pixels;
    final filterBarH = _effectiveFilterBarHeight;
    final listStart = UtxoSummaryChart.estimatedHeight + filterBarH;
    // 스티키 헤더가 앱바에 붙었을 때(pinned) 리스트 영역은 헤더 아래에서 시작
    final contentCenter =
        pixels >= UtxoSummaryChart.estimatedHeight
            ? pixels + filterBarH + (pos.viewportDimension - filterBarH) / 2
            : pixels + pos.viewportDimension / 2;
    final target =
        pixels <= minExtent + 1
            ? 0
            : pixels >= maxExtent - 1
            ? count - 1
            : ((contentCenter - listStart) / _itemHeight).floor().clamp(0, count - 1);

    if (target != _activeIndex.value) {
      _activeIndex.value = target;
    }
    _updateBucketY(target);
  }

  void _updateBucketY(int index) {
    final bucketCtx = _filteredBucketKeys[index].currentContext;
    if (bucketCtx == null) return;
    final bucketBox = bucketCtx.findRenderObject() as RenderBox?;
    if (bucketBox == null || !bucketBox.hasSize) return;
    final railCtx = _scrollRailKey.currentContext;
    if (railCtx == null) return;
    final railBox = railCtx.findRenderObject() as RenderBox?;
    if (railBox == null || !railBox.hasSize) return;

    final bucketCenterGlobal = bucketBox.localToGlobal(Offset(bucketBox.size.width / 2, bucketBox.size.height / 2));
    final railTopGlobal = railBox.localToGlobal(Offset.zero);
    _activeBucketY.value = bucketCenterGlobal.dy - railTopGlobal.dy;
  }
}
