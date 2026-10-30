import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup,
        CoconutUnderlinedButton;
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_filter.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_overview_view_model.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/utils/amimation_util.dart';
import 'package:coconut_wallet/widgets/features/utxo/card/utxo_list_item_card.dart';
import 'package:flutter/material.dart';

class UtxoList extends StatefulWidget {
  const UtxoList({
    super.key,
    required this.walletId,
    required this.currentUnit,
    required this.onRemoveDropdown,
    required this.onFirstBuildCompleted,
    required this.isSelectionMode,
    this.onSettingLockChanged,
    this.emptyStateText,
    this.emptyStateTextStyle,
    required this.viewModel,
  });

  final int walletId;
  final BitcoinUnit currentUnit;
  final Function onRemoveDropdown;
  final VoidCallback onFirstBuildCompleted;
  final bool isSelectionMode;
  final ValueChanged<bool>? onSettingLockChanged;
  final String? emptyStateText;
  final TextStyle? emptyStateTextStyle;
  final UtxoOverviewViewModel viewModel;

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

  @override
  Widget build(BuildContext context) {
    double bottomInset = MediaQuery.of(context).padding.bottom;

    final viewModel = widget.viewModel;
    return ListenableBuilder(
      listenable: viewModel,
      builder: (_, __) => _buildList(viewModel.utxoList, viewModel.activeUtxoFilter, bottomInset),
    );
  }

  Widget _buildList(List<UtxoState> utxoList, UtxoFilter activeFilter, double bottomInset) {
    if (utxoList.isEmpty || !utxoList.any(activeFilter.matches)) {
      return _buildEmptyState();
    }

    if (_isListChanged(_displayedUtxoList, utxoList)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleUtxoListChange(utxoList);
      });
    }

    return SliverPadding(
      padding: EdgeInsets.only(bottom: bottomInset + 70),
      sliver: _buildSliverAnimatedList(utxoList, activeFilter),
    );
  }

  // --------------------
  // Sliver & List Building
  // --------------------
  Widget _buildSliverAnimatedList(List<UtxoState> utxoList, UtxoFilter activeFilter) {
    return SliverAnimatedList(
      key: _listKeyFor(activeFilter),
      initialItemCount: _displayedUtxoList.length,
      itemBuilder: (context, index, animation) {
        if (index >= utxoList.length) return const SizedBox();

        final utxo = utxoList[index];
        if (!activeFilter.matches(utxo)) return const SizedBox();

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: _buildUtxoItem(utxo, _buildSlideAnimation(animation)),
        );
      },
    );
  }

  GlobalKey<SliverAnimatedListState> _listKeyFor(UtxoFilter filter) {
    if (filter == UtxoFilter.locked) return _lockedUtxoListKey;
    if (filter == UtxoFilter.change) return _changeUtxoListKey;
    return _utxoListKey;
  }

  Widget _buildEmptyState() {
    widget.onFirstBuildCompleted();
    return SliverFillRemaining(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(
            widget.emptyStateText ?? t.utxo_not_found,
            style: widget.emptyStateTextStyle ?? CoconutTypography.body1_16.setColor(context.coconutColors.primaryText),
          ),
        ),
      ),
    );
  }

  // --------------------
  // Selection
  // --------------------
  // --------------------
  // Item Builders
  // --------------------
  Widget _buildUtxoItem(UtxoState utxo, Animation<Offset> offsetAnimation) {
    final isSelectionMode = widget.isSelectionMode;
    final isSelected = _selectedUtxoIds.contains(utxo.utxoId);

    return SlideTransition(
      position: offsetAnimation,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: UtxoListItemCard(
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
                  _removeSelectUtxo(utxo);
                } else {
                  _selectedUtxoIds.add(utxo.utxoId);
                  _addSelectUtxo(utxo);
                }
              });
            } else {
              _openDetailPage(utxo);
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
              _addSelectUtxo(utxo);
            });
            widget.onSettingLockChanged?.call(true);
          },
        ),
      ),
    );
  }

  void _addSelectUtxo(UtxoState utxo) {
    widget.viewModel.addSelectUtxo(utxo);
  }

  void _removeSelectUtxo(UtxoState utxo) {
    widget.viewModel.removeSelectUtxo(utxo);
  }

  void _refetchFromDB() {
    widget.viewModel.refetchFromDB();
  }

  void _openDetailPage(UtxoState utxo) async {
    widget.onRemoveDropdown();
    await Navigator.pushNamed(
      context,
      AppRouteNames.utxoDetail,
      arguments: UtxoDetailRouteArgs(utxo: utxo, id: widget.walletId),
    );
    _refetchFromDB();
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
          child: UtxoListItemCard(
            key: Key(utxo.utxoId),
            currentUnit: widget.currentUnit,
            utxo: utxo,
            onPressed: () async {
              widget.onRemoveDropdown();
              await Navigator.pushNamed(
                context,
                AppRouteNames.utxoDetail,
                arguments: UtxoDetailRouteArgs(utxo: utxo, id: widget.walletId),
              );
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
      _listKeyFor(widget.viewModel.activeUtxoFilter).currentState?.removeItem(
        index,
        (c, anim) => _buildRemoveUtxoItem(_displayedUtxoList[index], anim),
        duration: _duration,
      );
    }

    for (var index in inserted) {
      await Future.delayed(_animationDuration);
      if (!mounted) return;
      _listKeyFor(widget.viewModel.activeUtxoFilter).currentState?.insertItem(index, duration: _duration);
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

    for (int i = 0; i < oldList.length; i++) {
      if (oldList[i].utxoId != newList[i].utxoId) return true;
    }

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
}
