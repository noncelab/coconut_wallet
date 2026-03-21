import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
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
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_bucket_card_row.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_bucket_scroll_rail.dart';
import 'package:coconut_wallet/screens/common/tag_apply_bottom_sheet.dart';
import 'package:coconut_wallet/screens/settings/utxo_tier_theme_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/button/bottom_action_bar.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_filter_bar.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_summary_chart.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_tag_chart.dart';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UtxoOverviewScreen extends StatefulWidget {
  final int id; // wallet id
  const UtxoOverviewScreen({super.key, required this.id});

  @override
  State<UtxoOverviewScreen> createState() => _UtxoOverviewScreenState();
}

class _UtxoOverviewScreenState extends State<UtxoOverviewScreen> {
  late UtxoListViewModel viewModel;
  BitcoinUnit _currentUnit = BitcoinUnit.btc;

  late List<UtxoBucket> _buckets;

  final _scrollController = ScrollController();
  final _activeIndex = ValueNotifier<int>(0);
  final _activeBucketY = ValueNotifier<double>(0);

  final GlobalKey _appBarKey = GlobalKey();
  final GlobalKey _scrollRailKey = GlobalKey();

  bool _isByAmount = true;
  int _lockFilterIndex = 0; // 0: 사용 가능, 1: 사용 잠김
  int _viewModeIndex = 0; // 0: 리스트(카드/코인), 1: 그리드
  bool _isSelectionMode = false;
  final Set<String> _selectedUtxoIds = {};
  bool _selectionBarExiting = false;
  final int _lastLockFilterForBar = 0;

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
    final showAvailable = _lockFilterIndex == 0;
    return _buckets
        .map(
          (b) => UtxoBucket(
            label: b.label,
            minSats: b.minSats,
            maxSats: b.maxSats,
            utxos: b.utxos.where((u) => showAvailable ? !u.isLocked : u.isLocked).toList(),
          ),
        )
        .where((b) => b.utxos.isNotEmpty)
        .toList();
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
    _buckets = bucketize(viewModel.utxoList);
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
    if (!_isByAmount || _viewModeIndex != 0) return;

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
        if (_scrollController.hasClients) {
          final pos = _scrollController.position;
          final targetOffset =
              scrollOffset != null
                  ? scrollOffset.clamp(pos.minScrollExtent, pos.maxScrollExtent)
                  : _scrollOffsetForBucket(bucketIdx, pos);
          _scrollController.jumpTo(targetOffset);
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

    _buckets = bucketize(viewModel.utxoList);
    _updateFilteredBuckets();

    viewModel.addListener(_onViewModelChanged);
    _scrollController.addListener(_updateActiveBucket);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateActiveBucket();
    });
  }

  double get _effectiveFilterBarHeight =>
      _shouldShowAmountSelectionSummary ? _filterBarExpandedHeight : _filterBarBaseHeight;
  double get _effectiveTagSelectionBarHeight => _isSelectionMode ? _filterBarBaseHeight : 0;

  bool get _shouldShowAmountSelectionSummary => _isByAmount && _viewModeIndex == 1 && _isSelectionMode;

  void _exitSelectionMode() {
    if (!mounted) return;
    setState(() {
      _isSelectionMode = false;
      _selectedUtxoIds.clear();
      _selectionBarExiting = false;
    });
  }

  int get _selectedTotalSats {
    return viewModel.utxoList
        .where((u) => _selectedUtxoIds.contains(u.utxoId))
        .fold<int>(0, (sum, u) => sum + u.amount);
  }

  void _onViewModelChanged() {
    if (mounted) setState(() => _refreshBucketsFromViewModel());
  }

  Future<void> _navigateToUtxoDetail(UtxoState utxo) async {
    _restoreUtxoId = utxo.utxoId;
    _restoreScrollOffset = _scrollController.hasClients ? _scrollController.offset : null;

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
    _scrollController.removeListener(_updateActiveBucket);
    _scrollController.dispose();
    _activeIndex.dispose();
    _activeBucketY.dispose();
    _restoredStateListenable.dispose();
    super.dispose();
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return CoconutAppBar.build(
      context: context,
      entireWidgetKey: _appBarKey,
      backgroundColor: CoconutColors.black,
      customTitle: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 260),
        child: CoconutSegmentedControl(
          labels: [t.utxo_overview_screen.by_amount, t.utxo_overview_screen.by_tag],
          isSelected: [_isByAmount, !_isByAmount],
          onPressed: (index) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _isByAmount = index == 0;
                  _isSelectionMode = false;
                  _selectedUtxoIds.clear();
                  _selectionBarExiting = false;
                });
              }
            });
          },
          labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
      ),
      titlePadding: const EdgeInsets.symmetric(horizontal: 16),
      onBackPressed: () => Navigator.pop(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: _buildAppBar(context),
      body: Consumer<UtxoTagProvider>(
        builder: (context, tagProvider, _) {
          final utxoTagList = tagProvider.getUtxoTagList(widget.id);
          return _isByAmount ? _buildAmountViewBody() : _buildTagViewBody(utxoTagList);
        },
      ),
    );
  }

  Widget _buildAmountViewBody() {
    return Stack(
      children: [
        if (_viewModeIndex == 0 && _filteredBuckets.length > 1)
          Positioned(
            left: -8,
            top: 0,
            bottom: 0,
            width: 34,
            child: UtxoBucketScrollRail(
              key: _scrollRailKey,
              buckets: _filteredBuckets,
              scrollController: _scrollController,
              activeIndexListenable: _activeIndex,
              activeBucketY: _activeBucketY,
            ),
          ),
        CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
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
                onBalanceTap: _toggleUnit,
                onThemeSettingTap: () {
                  CommonBottomSheets.showCustomHeightBottomSheet(
                    context: context,
                    heightRatio: 0.6,
                    child: const UtxoTierThemeBottomSheet(),
                  );
                },
                hasReusedAddresses: _reusedAddresses.isNotEmpty,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: UtxoAmountStickyFilterBarDelegate(
                height: _effectiveFilterBarHeight,
                selectedCount: _selectedUtxoIds.length,
                selectedTotalSats: _selectedTotalSats,
                currentUnit: _currentUnit,
                viewModeIndex: _viewModeIndex,
                lockFilterIndex: _lockFilterIndex,
                isSelectionMode: _isSelectionMode,
                onViewModeSelected: (index) {
                  setState(() {
                    _viewModeIndex = index;
                    if (!_isSelectionMode) return;
                    _isSelectionMode = false;
                    _selectedUtxoIds.clear();
                    _selectionBarExiting = false;
                  });
                },
                onLockFilterSelected: (index) {
                  setState(() {
                    _lockFilterIndex = index;
                    _updateFilteredBuckets();
                  });
                },
                onExitSelectionMode: _exitSelectionMode,
              ),
            ),
            if (_viewModeIndex == 0)
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
                        activeIndexListenable: _activeIndex,
                        restoredStateListenable: _restoredStateListenable,
                        isSelectionMode: _isSelectionMode,
                        selectedUtxoIds: _selectedUtxoIds,
                        reusedAddresses: _reusedAddresses,
                        onTapUtxo: (u) {
                          if (_isSelectionMode) {
                            if (u.status == UtxoStatus.outgoing || u.status == UtxoStatus.incoming) {
                              CoconutToast.showToast(
                                context: context,
                                text: t.utxo_list_screen.pending_utxo,
                                isVisibleIcon: false,
                              );
                              return;
                            }
                            setState(() {
                              if (_selectedUtxoIds.contains(u.utxoId)) {
                                _selectedUtxoIds.remove(u.utxoId);
                              } else {
                                _selectedUtxoIds.add(u.utxoId);
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
                            _viewModeIndex = 1;
                            _isSelectionMode = true;
                            _selectedUtxoIds.add(u.utxoId);
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
          isVisible: (_isSelectionMode && _selectedUtxoIds.isNotEmpty) || _selectionBarExiting,
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
          isVisible: (_isSelectionMode && _selectedUtxoIds.isNotEmpty) || _selectionBarExiting,
          child: _buildSelectionBottomBar(),
        ),
      ],
    );
  }

  Widget _buildTagView(List<UtxoTag> utxoTagList) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: UtxoTagChart(
            utxoList: viewModel.utxoList,
            utxoTagList: utxoTagList,
            currentUnit: _currentUnit,
            onBalanceTap: _toggleUnit,
          ),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: UtxoTagSelectionBarDelegate(
            height: _effectiveTagSelectionBarHeight,
            selectedCount: _selectedUtxoIds.length,
            selectedTotalSats: _selectedTotalSats,
            currentUnit: _currentUnit,
            isSelectionMode: _isSelectionMode,
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
            selectedUtxoIds: _selectedUtxoIds,
            reusedAddresses: _reusedAddresses,
            isSelectionMode: _isSelectionMode,
            onUtxoTap: (u) {
              if (_isSelectionMode) {
                if (u.status == UtxoStatus.outgoing || u.status == UtxoStatus.incoming) {
                  CoconutToast.showToast(context: context, text: t.utxo_list_screen.pending_utxo, isVisibleIcon: false);
                  return;
                }
                setState(() {
                  if (_selectedUtxoIds.contains(u.utxoId)) {
                    _selectedUtxoIds.remove(u.utxoId);
                  } else {
                    _selectedUtxoIds.add(u.utxoId);
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
                _isSelectionMode = true;
                _selectedUtxoIds.add(u.utxoId);
              });
            },
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: _selectionBarBottomPadding(context))),
      ],
    );
  }

  Widget _buildSelectionBottomBar() {
    final showBar = _selectedUtxoIds.isNotEmpty || _selectionBarExiting;
    if (!showBar) return const SizedBox.shrink();

    final lockFilter = _selectionBarExiting ? _lastLockFilterForBar : _lockFilterIndex;
    final isLockedFilter = lockFilter == 1;
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return BottomActionBar(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: _selectionBarTopPadding + bottomInset,
        bottom: _selectionBarInnerBottomPadding + bottomInset,
      ),
      child:
          _isByAmount
              ? (isLockedFilter
                  ? BottomActionButton(
                    iconPath: 'assets/svg/unlock_simple.svg',
                    label: t.utxo_list_screen.utxo_unlocked_button,
                    onTap: () => _updateSelectedUtxosLock(lock: false),
                    buttonLayout: BottomActionButtonLayout.horizontal,
                    textStyle: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white),
                  )
                  : Builder(
                    builder: (context) {
                      final selectedUtxos =
                          viewModel.utxoList.where((u) => _selectedUtxoIds.contains(u.utxoId)).toList();
                      final hasLockedUtxo = selectedUtxos.any((u) => u.status == UtxoStatus.locked);
                      return Row(
                        children: [
                          Expanded(
                            child: Opacity(
                              opacity: hasLockedUtxo ? 0.5 : 1,
                              child: BottomActionButton(
                                iconPath: 'assets/svg/send.svg',
                                label: t.send,
                                onTap: _onSendPressed,
                                buttonLayout: BottomActionButtonLayout.horizontal,
                                textStyle: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: BottomActionButton(
                              iconPath: 'assets/svg/lock_simple.svg',
                              label: t.utxo_list_screen.utxo_locked_button,
                              onTap: () => _updateSelectedUtxosLock(lock: true),
                              buttonLayout: BottomActionButtonLayout.horizontal,
                              textStyle: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white),
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
    final selectedUtxos = viewModel.utxoList.where((u) => _selectedUtxoIds.contains(u.utxoId)).toList();
    final hasLockedUtxo = selectedUtxos.any((u) => u.status == UtxoStatus.locked);

    return Row(
      children: [
        Expanded(
          child: Opacity(
            opacity: hasLockedUtxo ? 0.5 : 1,
            child: BottomActionButton(
              iconPath: 'assets/svg/send.svg',
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
              buttonLayout: BottomActionButtonLayout.horizontal,
              textStyle: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: BottomActionButton(
            iconPath: 'assets/svg/tag.svg',
            label: t.utxo_list_screen.tag_apply,
            onTap: _showTagApplyBottomSheet,
            buttonLayout: BottomActionButtonLayout.horizontal,
            textStyle: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white),
          ),
        ),
      ],
    );
  }

  void _onTagViewSendPressed(List<UtxoState> selectedUtxos) {
    if (selectedUtxos.isEmpty) return;
    setState(() {
      _isSelectionMode = false;
      _selectedUtxoIds.clear();
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
    final utxo = viewModel.utxoList.where((u) => u.utxoId == utxoId).firstOrNull;
    return utxo?.tags?.map((tag) => tag.name).toList() ?? [];
  }

  Future<void> _showTagApplyBottomSheet() async {
    if (_selectedUtxoIds.isEmpty) return;

    final selectedUtxoIds = _selectedUtxoIds.toList();
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
        _selectedUtxoIds.clear();
        _isSelectionMode = false;
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
        _selectedUtxoIds.clear();
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

  Future<void> _updateSelectedUtxosLock({required bool lock}) async {
    if (_selectedUtxoIds.isEmpty) return;
    final ids = _selectedUtxoIds.toList();
    try {
      final updatedCount = await viewModel.setUtxoLockStatus(ids, lock);
      if (mounted) {
        setState(() {
          _selectedUtxoIds.clear();
          _isSelectionMode = false;
          _selectionBarExiting = false;
          _refreshBucketsFromViewModel();
        });
      }
      if (updatedCount > 0 && mounted) {
        CoconutToast.showToast(
          context: context,
          isVisibleIcon: true,
          iconPath: 'assets/svg/circle-info.svg',
          text: lock ? t.utxo_detail_screen.utxo_locked_toast_msg : t.utxo_detail_screen.utxo_unlocked_toast_msg,
        );
      }
    } catch (e) {
      debugPrint('UTXO 상태 업데이트 실패: $e');
    }
  }

  void _onSendPressed() {
    if (_selectedUtxoIds.isEmpty) return;
    final selectedUtxos = viewModel.utxoList.where((u) => _selectedUtxoIds.contains(u.utxoId)).toList();
    final hasLockedUtxo = selectedUtxos.any((u) => u.status == UtxoStatus.locked);
    if (hasLockedUtxo) {
      CoconutToast.showToast(context: context, text: t.utxo_list_screen.send_locked_utxo, isVisibleIcon: true);
      return;
    }
    setState(() {
      _isSelectionMode = false;
      _selectedUtxoIds.clear();
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

  Set<String> get _reusedAddresses {
    final addressCounts = <String, int>{};
    for (final u in viewModel.utxoList) {
      addressCounts[u.to] = (addressCounts[u.to] ?? 0) + 1;
    }
    return addressCounts.entries.where((e) => e.value > 1).map((e) => e.key).toSet();
  }

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
          final isSelected = _selectedUtxoIds.contains(utxo.utxoId);
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
                  isSelectionMode: _isSelectionMode,
                  currentUnit: currentUnit,
                  isAddressReused: _reusedAddresses.contains(utxo.to),
                  onTap: () {
                    if (_isSelectionMode) {
                      if (utxo.status == UtxoStatus.outgoing || utxo.status == UtxoStatus.incoming) {
                        CoconutToast.showToast(
                          context: context,
                          text: t.utxo_list_screen.pending_utxo,
                          isVisibleIcon: false,
                        );
                        return;
                      }
                      setState(() {
                        if (_selectedUtxoIds.contains(utxo.utxoId)) {
                          _selectedUtxoIds.remove(utxo.utxoId);
                        } else {
                          _selectedUtxoIds.add(utxo.utxoId);
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
                      _isSelectionMode = true;
                      _selectedUtxoIds.add(utxo.utxoId);
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
    final showBar = (_isSelectionMode && _selectedUtxoIds.isNotEmpty) || _selectionBarExiting;
    if (!showBar) return _baseBottomPadding;
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return _baseBottomPadding + _selectionBarContentHeight + bottomInset * 2;
  }

  void _updateActiveBucket() {
    if (!mounted || !_scrollController.hasClients || _isRestoringState) return;

    final count = _filteredBuckets.length;
    if (count == 0) return;
    if (count <= 1) {
      if (_activeIndex.value != 0) _activeIndex.value = 0;
      _updateBucketY(0);
      return;
    }

    final pos = _scrollController.position;
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
