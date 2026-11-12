import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutPopup, CoconutToast;
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/ark/ark_refresh_due.dart';
import 'package:coconut_wallet/model/ark/ark_vtxo.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ark/ark_unlock_flow.dart';
import 'package:coconut_wallet/screens/ark/vtxo_refresh_flow.dart';
import 'package:coconut_wallet/screens/ark/vtxo_refresh_result_view.dart';
import 'package:coconut_wallet/screens/ark/vtxo_list_header.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_overview_filter_widgets.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_tween_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/common/clipper/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/features/ark/vtxo_list_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class VtxoListScreen extends StatefulWidget {
  const VtxoListScreen({super.key, required this.id, this.startRefresh = false});

  final int id;
  final bool startRefresh;

  @override
  State<VtxoListScreen> createState() => _VtxoListScreenState();
}

class _VtxoListScreenState extends State<VtxoListScreen> {
  late final ArkProvider _arkProvider;
  late BitcoinUnit _unit;
  bool _isSelecting = false;
  VtxoRefreshPhase? _refreshPhase;
  int _refreshedCount = 0;
  String? _refreshFeeText;
  bool _isRefreshing = false;
  bool _isEstimatingFee = false;
  int? _estimatedRefreshFee;
  int _feeEstimateRevision = 0;
  final Set<String> _refreshCandidateIds = {};
  final Set<String> _selectedIds = {};
  final GlobalKey _tooltipIconKey = GlobalKey();
  Offset _tooltipIconPosition = Offset.zero;
  Size _tooltipIconSize = Size.zero;
  bool _isTooltipVisible = false;
  bool _showRefreshDueOnly = false;
  final ScrollController _scrollController = ScrollController();
  bool _isSnappingHeader = false;

  static const double _headerCollapseExtent = 94;

  @override
  void initState() {
    super.initState();
    _arkProvider = context.read<ArkProvider>();
    _unit = context.read<PreferenceProvider>().currentUnit;
    if (widget.startRefresh) WidgetsBinding.instance.addPostFrameCallback((_) => _startSelecting());
  }

  Future<bool> _ensureOpen() => openArkWalletForSession(context, widget.id, userInitiated: true);

  Future<void> _sync() async {
    if (!await _ensureOpen() || !mounted) return;
    await _arkProvider.syncNow(widget.id);
  }

  Future<void> _startSelecting() async {
    final tip = context.read<NodeProvider>().currentBlockNotifier.value?.height;
    final due =
        tip == null
            ? const <String>[]
            : [
              for (final vtxo in _arkProvider.snapshot(widget.id)?.vtxos ?? const <ArkVtxo>[])
                if (!vtxo.isLocked &&
                    !_arkProvider.isRefreshingVtxo(vtxo.id) &&
                    vtxo.expiryHeight - tip <= ArkRefreshDue.noticeBlocks)
                  vtxo.id,
            ];
    if (due.isEmpty) {
      CoconutToast.showToast(context: context, text: t.ark.vtxo.none_due);
      return;
    }
    setState(() {
      _isSelecting = true;
      _refreshCandidateIds
        ..clear()
        ..addAll(due);
      _selectedIds
        ..clear()
        ..addAll(due);
    });
    if (!await _ensureOpen() || !mounted) {
      if (mounted) _exitSelecting();
      return;
    }
    await _estimateSelectedFee();
  }

  /// 지갑 상세 배너에서 바로 갱신으로 들어왔으면 목록을 거치지 않고 지갑 상세로 돌아감
  void _exitSelecting() {
    if (widget.startRefresh) {
      Navigator.pop(context);
      return;
    }
    _stopSelecting();
  }

  void _stopSelecting() => setState(() {
    _feeEstimateRevision++;
    _isSelecting = false;
    _isEstimatingFee = false;
    _estimatedRefreshFee = null;
    _refreshCandidateIds.clear();
    _selectedIds.clear();
  });

  Future<void> _estimateSelectedFee() async {
    final revision = ++_feeEstimateRevision;
    final ids = _selectedIds.toList();
    if (ids.isEmpty) {
      if (mounted) {
        setState(() {
          _isEstimatingFee = false;
          _estimatedRefreshFee = null;
        });
      }
      return;
    }
    setState(() {
      _isEstimatingFee = true;
      _estimatedRefreshFee = null;
    });
    try {
      final fee = await _arkProvider.estimateRefreshFee(widget.id, ids);
      if (!mounted || revision != _feeEstimateRevision) return;
      setState(() {
        _isEstimatingFee = false;
        _estimatedRefreshFee = fee;
      });
    } catch (_) {
      if (!mounted || revision != _feeEstimateRevision) return;
      setState(() {
        _isEstimatingFee = false;
        _estimatedRefreshFee = null;
      });
    }
  }

  Future<void> _confirmRefresh() async {
    final ids = _selectedIds.toList();
    final scheduled = await refreshVtxosWithConfirmation(
      context,
      walletId: widget.id,
      ids: ids,
      unit: _unit,
      showsToast: false,
      onConfirmed: (fee) {
        if (!mounted) return;
        setState(() {
          _refreshPhase = VtxoRefreshPhase.requesting;
          _refreshedCount = ids.length;
          _refreshFeeText = _unit.displayBitcoinAmount(fee, withUnit: true);
        });
      },
      onFailed: (_) {
        if (mounted && _refreshPhase != null) setState(() => _refreshPhase = VtxoRefreshPhase.failed);
      },
    );
    if (scheduled && mounted) setState(() => _refreshPhase = VtxoRefreshPhase.requested);
  }

  void _closeRefreshResult() {
    if (widget.startRefresh) {
      Navigator.pop(context);
      return;
    }
    setState(() => _refreshPhase = null);
    _stopSelecting();
  }

  void _retryRefresh() {
    setState(() => _refreshPhase = null);
    _confirmRefresh();
  }

  void _toggleTooltip() {
    final box = _tooltipIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() {
      _tooltipIconPosition = box.localToGlobal(Offset.zero);
      _tooltipIconSize = box.size;
      _isTooltipVisible = !_isTooltipVisible;
    });
  }

  void _openVtxo(ArkVtxo vtxo) {
    Navigator.pushNamed(context, AppRouteNames.vtxoDetail, arguments: VtxoDetailRouteArgs(id: widget.id, vtxo: vtxo));
  }

  void _onVtxoPressed(ArkVtxo vtxo) {
    if (!_isSelecting) {
      _openVtxo(vtxo);
      return;
    }
    if (vtxo.isLocked) return;
    setState(() {
      if (!_selectedIds.remove(vtxo.id)) _selectedIds.add(vtxo.id);
    });
    unawaited(_estimateSelectedFee());
  }

  bool _handleScrollEnd(ScrollEndNotification notification) {
    if (_isSelecting || !_scrollController.hasClients || _isSnappingHeader || notification.depth != 0) return false;
    final offset = _scrollController.offset;
    if (offset <= 0 || offset >= _headerCollapseExtent) return false;
    final target = offset < _headerCollapseExtent * 0.7 ? 0.0 : _headerCollapseExtent;
    _isSnappingHeader = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_scrollController.hasClients) {
        _isSnappingHeader = false;
        return;
      }
      HapticFeedback.selectionClick();
      try {
        await _scrollController.animateTo(
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ArkProvider>(
      builder: (context, arkProvider, _) {
        final snapshot = arkProvider.snapshot(widget.id);
        final vtxos = [...?snapshot?.vtxos]..sort((a, b) => a.expiryHeight.compareTo(b.expiryHeight));
        final selectedTotal = vtxos
            .where((vtxo) => _selectedIds.contains(vtxo.id))
            .fold<int>(0, (total, vtxo) => total + vtxo.amountSats);
        final isOpen = arkProvider.isOpen(widget.id);
        final isBusy = arkProvider.isOpening(widget.id) || arkProvider.isSyncing(widget.id);
        if (_refreshPhase case final phase?) {
          return PopScope(
            canPop: phase != VtxoRefreshPhase.requesting,
            child: Scaffold(
              backgroundColor: context.coconutColors.background,
              body: SafeArea(
                child: VtxoRefreshResultView(
                  phase: phase,
                  count: _refreshedCount,
                  feeText: _refreshFeeText,
                  onDone: _closeRefreshResult,
                  onRetry: _retryRefresh,
                ),
              ),
            ),
          );
        }
        return GestureDetector(
          onTap: () => setState(() => _isTooltipVisible = false),
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: context.coconutColors.background,
                appBar:
                    _isSelecting
                        ? CoconutAppBar.build(
                          context: context,
                          title: t.ark.vtxo.select_title,
                          isCloseButton: true,
                          onBackPressed: _exitSelecting,
                        )
                        : null,
                body: Stack(
                  children: [
                    ValueListenableBuilder<BlockTimestamp?>(
                      valueListenable: context.read<NodeProvider>().currentBlockNotifier,
                      builder: (context, tip, _) {
                        final refreshDueVtxos =
                            tip == null
                                ? const <ArkVtxo>[]
                                : vtxos
                                    .where(
                                      (vtxo) =>
                                          !vtxo.isLocked &&
                                          vtxo.expiryHeight - tip.height <= ArkRefreshDue.noticeBlocks,
                                    )
                                    .toList();
                        final visibleVtxos =
                            _isSelecting
                                ? vtxos.where((vtxo) => _refreshCandidateIds.contains(vtxo.id)).toList()
                                : _showRefreshDueOnly
                                ? refreshDueVtxos
                                : vtxos;
                        final hasRefreshCandidates = refreshDueVtxos.isNotEmpty;
                        final listBottomPadding = _isSelecting ? 160.0 : MediaQuery.paddingOf(context).bottom + 70;
                        return NotificationListener<ScrollEndNotification>(
                          onNotification: _handleScrollEnd,
                          child: CustomScrollView(
                            key: ValueKey(_isSelecting),
                            controller: _isSelecting ? null : _scrollController,
                            physics: const AlwaysScrollableScrollPhysics(),
                            slivers: [
                              if (!_isSelecting)
                                SliverPersistentHeader(
                                  pinned: true,
                                  delegate: VtxoListHeaderDelegate(
                                    topPadding: MediaQuery.paddingOf(context).top,
                                    totalSats: arkProvider.totalSats(widget.id),
                                    unit: _unit,
                                    onBackPressed: () => Navigator.pop(context),
                                    onUnitPressed: () => setState(() => _unit = _unit.next),
                                    infoButton: _buildInfoButton(context),
                                    refreshButton: _buildRefreshButton(
                                      context,
                                      canRefresh: hasRefreshCandidates && !_isRefreshing,
                                      onRefresh: _startSelecting,
                                    ),
                                    filterBar: _buildFilterBar(
                                      context,
                                      totalCount: vtxos.length,
                                      refreshDueCount: refreshDueVtxos.length,
                                    ),
                                  ),
                                ),
                              CupertinoSliverRefreshControl(
                                onRefresh: _sync,
                                refreshTriggerPullDistance: 80,
                                builder: (_, _, _, _, _) => const SizedBox.shrink(),
                              ),
                              if (_isSelecting)
                                SliverToBoxAdapter(
                                  child: _buildRefreshSummary(
                                    selectedTotal: selectedTotal,
                                    selectedCount: _selectedIds.length,
                                  ),
                                ),
                              if (!isOpen)
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                    child: _LockedNotice(isBusy: isBusy, onUnlock: _ensureOpen),
                                  ),
                                ),
                              if (_isSelecting) SliverToBoxAdapter(child: _buildRefreshListTitle()),
                              if (_isRefreshing)
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(16, 0, 16, listBottomPadding),
                                  sliver: const SliverToBoxAdapter(child: VtxoListSkeleton()),
                                )
                              else if (visibleVtxos.isEmpty)
                                SliverFillRemaining(
                                  hasScrollBody: false,
                                  child: Center(
                                    child: Text(
                                      _showRefreshDueOnly
                                          ? t.ark.vtxo.none_due
                                          : snapshot == null && isOpen
                                          ? t.ark.vtxo.syncing
                                          : t.ark.vtxo.empty,
                                      style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                                    ),
                                  ),
                                )
                              else
                                SliverPadding(
                                  padding: EdgeInsets.fromLTRB(16, 0, 16, listBottomPadding),
                                  sliver: SliverList.builder(
                                    itemCount: visibleVtxos.length,
                                    itemBuilder: (context, index) {
                                      final vtxo = visibleVtxos[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8),
                                        child: VtxoListRow(
                                          vtxo: vtxo,
                                          unit: _unit,
                                          tip: tip,
                                          isSelecting: _isSelecting,
                                          isSelected: _selectedIds.contains(vtxo.id),
                                          onPressed: () => _onVtxoPressed(vtxo),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (_isSelecting && _refreshCandidateIds.isNotEmpty)
                      FixedBottomTweenButton(
                        leftButtonRatio: 0.35,
                        leftText: t.cancel,
                        rightText:
                            _isRefreshing ? t.ark.vtxo.refreshing : t.ark.vtxo.refresh_n(count: _selectedIds.length),
                        leftButtonClicked: _isRefreshing ? () {} : _exitSelecting,
                        rightButtonClicked: _confirmRefresh,
                        isRightButtonActive: !_isRefreshing && _selectedIds.isNotEmpty,
                      ),
                  ],
                ),
              ),
              if (_isTooltipVisible) _buildTooltip(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoButton(BuildContext context) => CoconutAppBarActionButton(
    key: _tooltipIconKey,
    onPressed: _toggleTooltip,
    icon: SvgPicture.asset(
      CommonStateIconPath.circleInfo,
      width: 24,
      height: 24,
      colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
    ),
  );

  Widget _buildFilterBar(BuildContext context, {required int totalCount, required int refreshDueCount}) {
    final colors = context.coconutColors;
    return ColoredBox(
      color: colors.background,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            AnimatedUtxoFilterChip(
              label: t.all,
              count: totalCount,
              isSelected: !_showRefreshDueOnly,
              onTap: () => setState(() => _showRefreshDueOnly = false),
            ),
            CoconutLayout.spacing_100w,
            AnimatedUtxoFilterChip(
              label: t.ark.vtxo.refresh_due,
              count: refreshDueCount,
              isSelected: _showRefreshDueOnly,
              onTap: () => setState(() => _showRefreshDueOnly = true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRefreshButton(BuildContext context, {required bool canRefresh, required VoidCallback onRefresh}) {
    final colors = context.coconutColors;
    return ShrinkAnimationButton(
      onPressed: onRefresh,
      isActive: canRefresh,
      defaultColor: colors.surface,
      disabledColor: colors.surface,
      pressedOverlayColor: colors.surfacePressOverlay,
      borderRadius: CoconutStyles.radius_150,
      child: Opacity(
        opacity: canRefresh ? 1 : 0.4,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                CommonActionIconPath.arrowReload,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
              ),
              const SizedBox(width: 4),
              Text(t.ark.vtxo.menu_refresh, style: CoconutTypography.body3_12_Bold.setColor(colors.primaryText)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshSummary({required int selectedTotal, required int selectedCount}) {
    final colors = context.coconutColors;
    final feeText =
        _isEstimatingFee
            ? t.ark.vtxo.estimating_fee
            : _estimatedRefreshFee == null
            ? '-'
            : _unit.displayBitcoinAmount(_estimatedRefreshFee!, withUnit: true);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(CoconutStyles.radius_300)),
        child: Column(
          children: [
            _buildSummaryRow(
              label: t.ark.vtxo.selected_summary(count: selectedCount),
              value: _unit.displayBitcoinAmount(selectedTotal, withUnit: true),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, thickness: 1, color: colors.divider),
            ),
            _buildSummaryRow(label: t.ark.vtxo.estimated_fee, value: feeText, isMuted: _isEstimatingFee),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow({required String label, required String value, bool isMuted = false}) {
    final colors = context.coconutColors;
    return Row(
      children: [
        Expanded(child: Text(label, style: CoconutTypography.body2_14.setColor(colors.secondaryText))),
        const SizedBox(width: 16),
        Text(
          value,
          style: CoconutTypography.body2_14_NumberBold.setColor(isMuted ? colors.secondaryText : colors.primaryText),
        ),
      ],
    );
  }

  Widget _buildTooltip(BuildContext context) {
    final colors = context.coconutColors;
    final anchor = _tooltipIconPosition & _tooltipIconSize;
    return Positioned(
      top: _tooltipIconPosition.dy + _tooltipIconSize.height - 10,
      right: RightTriangleBubbleClipper.rightOffsetForAnchor(
        viewportWidth: MediaQuery.sizeOf(context).width,
        anchor: anchor,
      ),
      child: GestureDetector(
        onTap: () => setState(() => _isTooltipVisible = false),
        child: ClipPath(
          clipper: RightTriangleBubbleClipper(),
          child: Container(
            width: MediaQuery.sizeOf(context).width * 0.68,
            padding: const EdgeInsets.only(top: 28, left: 16, right: 16, bottom: 12),
            color: colors.popoverBackground,
            child: Text(
              t.ark.vtxo.list_tooltip,
              style: CoconutTypography.body3_12.copyWith(color: colors.popoverText, height: 1.3),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshListTitle() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
    child: Text(
      t.ark.vtxo.refresh_candidates,
      style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
    ),
  );
}

class _LockedNotice extends StatelessWidget {
  const _LockedNotice({required this.isBusy, required this.onUnlock});

  final bool isBusy;
  final Future<bool> Function() onUnlock;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          SvgPicture.asset(
            CommonSecurityIconPath.lock,
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.ark.vtxo.locked_title, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
                const SizedBox(height: 4),
                Text(t.ark.vtxo.locked_description, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
              ],
            ),
          ),
          TextButton(onPressed: isBusy ? null : onUnlock, child: Text(t.ark.send.unlock)),
        ],
      ),
    );
  }
}
