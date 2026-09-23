import 'dart:io';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/constants/icon_path.dart';

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
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/amimation_util.dart';
import 'package:coconut_wallet/widgets/common/loading/loading_indicator.dart';
import 'package:coconut_wallet/widgets/features/transaction/card/transaction_item_card.dart';
import 'package:coconut_wallet/widgets/features/wallet/header/transaction_list_header.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_refresh_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

class TransactionListScreen extends StatefulWidget {
  final int id;
  final String entryPoint;

  const TransactionListScreen({super.key, required this.id, required this.entryPoint});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  static const _minimumRefreshIndicatorDuration = Duration(milliseconds: 700);
  bool _isPullToRefreshing = false;
  bool _isSnappingHeader = false;
  late BitcoinUnit _currentUnit;
  late WalletDetailViewModel _viewModel;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => _viewModel,
      child: PopScope(
        canPop: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque, // 빈 영역도 감지 가능
          child: Stack(
            children: [
              Scaffold(
                backgroundColor: context.coconutColors.background,
                body: NotificationListener<ScrollEndNotification>(
                  onNotification: _handleScrollEnd,
                  child: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: _scrollController,
                    slivers: [
                      Selector<WalletDetailViewModel, Tuple5<AnimatedBalanceData, String, int, int, bool>>(
                        selector:
                            (_, viewModel) => Tuple5(
                              AnimatedBalanceData(viewModel.balance, viewModel.prevBalance),
                              viewModel.fiatPriceString,
                              viewModel.sendingAmount,
                              viewModel.receivingAmount,
                              viewModel.isWalletSyncing,
                            ),
                        builder: (_, data, __) {
                          return SliverPersistentHeader(
                            pinned: true,
                            delegate: _TransactionListHeaderDelegate(
                              topPadding: MediaQuery.paddingOf(context).top,
                              animatedBalanceData: data.item1,
                              currentUnit: _currentUnit,
                              fiatPrice: data.item2,
                              sendingAmount: data.item3,
                              receivingAmount: data.item4,
                              isRefreshing: _isPullToRefreshing || data.item5,
                              onPressedUnitToggle: _toggleUnit,
                              onBackPressed: () => Navigator.pop(context),
                              refreshButton: WalletRefreshIndicator(isRefreshing: _isPullToRefreshing),
                            ),
                          );
                        },
                      ),
                      Selector<WalletDetailViewModel, bool>(
                        selector: (_, viewModel) => viewModel.isWalletSyncing,
                        builder:
                            (_, isWalletSyncing, _) =>
                                isWalletSyncing
                                    ? const SliverToBoxAdapter(child: SizedBox.shrink())
                                    : CupertinoSliverRefreshControl(
                                      onRefresh: _onRefresh,
                                      refreshTriggerPullDistance: 80,
                                      refreshIndicatorExtent: 0,
                                      builder: (_, _, _, _, _) => const SizedBox.shrink(),
                                    ),
                      ),
                      _buildTxListLabel(),
                      TransactionList(currentUnit: _currentUnit, walldtId: widget.id),

                      SliverToBoxAdapter(child: SizedBox(height: 35 + MediaQuery.of(context).padding.bottom)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onRefresh() async {
    if (_isPullToRefreshing) return;

    setState(() => _isPullToRefreshing = true);
    final stopwatch = Stopwatch()..start();
    try {
      if (!_checkStateAndShowToast()) {
        return;
      }
      await _viewModel.refreshWallet();
    } finally {
      final remaining = _minimumRefreshIndicatorDuration - stopwatch.elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
      if (mounted) setState(() => _isPullToRefreshing = false);
    }
  }

  Widget _buildTxListLabel() {
    return SliverToBoxAdapter(
      child: Selector<WalletDetailViewModel, Tuple2<int, bool>>(
        selector: (_, viewModel) => Tuple2(viewModel.txList.length, viewModel.isWalletSyncing),
        builder: (_, data, __) {
          final txCount = data.item1;
          final isWalletSyncing = data.item2;

          return Padding(
            key: _txListLabelWidgetKey,
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 12.0),
            child: SizedBox(
              height: 32,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              t.tx_list,
                              style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
                            ),
                          ),
                        ),
                        CoconutLayout.spacing_100w,
                        if (txCount > 0)
                          Text(
                            t.total_item_count(count: txCount),
                            style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                          ),
                      ],
                    ),
                  ),

                  if (isWalletSyncing)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: InlineLoadingIndicator(
                            padding: EdgeInsets.zero,
                            color: context.coconutColors.primary,
                            radius: 8,
                          ),
                        ),
                        CoconutLayout.spacing_100w,
                        Text(
                          t.status_updating,
                          style: CoconutTypography.body3_12_Bold.setColor(context.coconutColors.primary),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 스크롤 시 sticky header 렌더링을 위한 상태 변수들
  final ScrollController _scrollController = ScrollController();
  OverlayEntry? _statusBarTapOverlayEntry;

  final GlobalKey _txListLabelWidgetKey = GlobalKey();

  double get _headerCollapseExtent {
    final pendingCount = (_viewModel.sendingAmount != 0 ? 1 : 0) + (_viewModel.receivingAmount != 0 ? 1 : 0);
    return _TransactionListHeaderDelegate.expandedBodyExtent(pendingCount);
  }

  bool _handleScrollEnd(ScrollEndNotification notification) {
    if (!_scrollController.hasClients || _isSnappingHeader || notification.depth != 0) return false;

    final collapseExtent = _headerCollapseExtent;
    final offset = _scrollController.offset;
    if (offset <= 0 || offset >= collapseExtent) return false;

    final target = offset < collapseExtent * 0.7 ? 0.0 : collapseExtent;
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
  void initState() {
    super.initState();
    _currentUnit = context.read<PreferenceProvider>().currentUnit;
    _viewModel = WalletDetailViewModel(
      widget.id,
      Provider.of<WalletProvider>(context, listen: false),
      Provider.of<TransactionProvider>(context, listen: false),
      Provider.of<ConnectivityProvider>(context, listen: false),
      Provider.of<PriceProvider>(context, listen: false),
      Provider.of<PreferenceProvider>(context, listen: false),
      Provider.of<NodeProvider>(context, listen: false),
    );

    if (Platform.isIOS) {
      _enableStatusBarTapScroll();
    }
  }

  @override
  void dispose() {
    _statusBarTapOverlayEntry?.remove();
    _statusBarTapOverlayEntry = null;
    _scrollController.dispose();
    super.dispose();
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
                onTap: () {
                  _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                },
              ),
            ),
      );

      final overlayState = Overlay.of(context);
      overlayState.insert(_statusBarTapOverlayEntry!);
    });
  }

  bool _checkStateAndShowToast() {
    if (_viewModel.isNetworkOff) {
      CoconutToast.showToast(
        context: context,
        isVisibleIcon: true,
        iconPath: CommonStateIconPath.triangleWarning,
        text: ErrorCodes.networkError.message,
        level: CoconutToastLevel.warning,
      );
      return false;
    }

    if (_viewModel.networkStatus == NetworkStatus.connectionFailed) {
      CoconutToast.showToast(
        context: context,
        isVisibleIcon: true,
        iconPath: CommonStateIconPath.triangleWarning,
        text: t.errors.electrum_connection_failed,
        level: CoconutToastLevel.warning,
      );
      return false;
    }

    if (_viewModel.isWalletSyncing) {
      _showInfoToast(context, t.toast.fetching_onchain_data);
      return false;
    }

    return true;
  }

  void _toggleUnit() {
    setState(() {
      _currentUnit = _currentUnit.next;
    });
  }

  void _showInfoToast(BuildContext context, String text) {
    CoconutToast.showToast(
      context: context,
      isVisibleIcon: true,
      iconPath: CommonStateIconPath.circleInfo,
      text: text,
      level: CoconutToastLevel.info,
    );
  }
}

class _TransactionListHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _TransactionListHeaderDelegate({
    required this.topPadding,
    required this.animatedBalanceData,
    required this.currentUnit,
    required this.fiatPrice,
    required this.sendingAmount,
    required this.receivingAmount,
    required this.isRefreshing,
    required this.onPressedUnitToggle,
    required this.onBackPressed,
    required this.refreshButton,
  });

  final double topPadding;
  final AnimatedBalanceData animatedBalanceData;
  final BitcoinUnit currentUnit;
  final String fiatPrice;
  final int sendingAmount;
  final int receivingAmount;
  final bool isRefreshing;
  final VoidCallback onPressedUnitToggle;
  final VoidCallback onBackPressed;
  final Widget refreshButton;

  static const double _toolbarHeight = 56;

  static double expandedBodyExtent(int pendingCount) => switch (pendingCount) {
    0 => 88,
    1 => 108,
    _ => 132,
  };

  @override
  double get minExtent => topPadding + _toolbarHeight;

  @override
  double get maxExtent {
    final pendingCount = (sendingAmount != 0 ? 1 : 0) + (receivingAmount != 0 ? 1 : 0);
    return minExtent + expandedBodyExtent(pendingCount);
  }

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final collapseRange = maxExtent - minExtent;
    final progress = collapseRange == 0 ? 1.0 : (shrinkOffset / collapseRange).clamp(0.0, 1.0);
    final easedProgress = Curves.easeInOutCubic.transform(progress);
    final bodyExtent = collapseRange;
    final balanceTop = topPadding + _toolbarHeight * (1 - easedProgress);
    final balanceHeight = bodyExtent + (_toolbarHeight - bodyExtent) * easedProgress;
    return Material(
      color: context.coconutColors.background,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          Positioned(
            top: balanceTop,
            left: 0,
            right: 0,
            height: balanceHeight,
            child: TransactionListHeader(
              animatedBalanceData: animatedBalanceData,
              currentUnit: currentUnit,
              fiatPrice: fiatPrice,
              sendingAmount: sendingAmount,
              receivingAmount: receivingAmount,
              isRefreshing: isRefreshing,
              onPressedUnitToggle: onPressedUnitToggle,
              collapseProgress: easedProgress,
            ),
          ),
          Positioned(
            left: 4,
            top: topPadding + 4,
            child: BackButton(onPressed: onBackPressed, color: context.coconutColors.primaryText),
          ),
          Positioned(right: 4, top: topPadding + 4, child: refreshButton),
          Positioned(
            left: 0,
            right: 0,
            bottom: -16,
            height: 16,
            child: IgnorePointer(
              child: Opacity(
                opacity: easedProgress,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [context.coconutColors.background, context.coconutColors.background.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _TransactionListHeaderDelegate oldDelegate) =>
      animatedBalanceData != oldDelegate.animatedBalanceData ||
      currentUnit != oldDelegate.currentUnit ||
      fiatPrice != oldDelegate.fiatPrice ||
      sendingAmount != oldDelegate.sendingAmount ||
      receivingAmount != oldDelegate.receivingAmount ||
      isRefreshing != oldDelegate.isRefreshing ||
      topPadding != oldDelegate.topPadding ||
      refreshButton != oldDelegate.refreshButton;
}

class TransactionList extends StatefulWidget {
  const TransactionList({super.key, required BitcoinUnit currentUnit, required this.walldtId})
    : _currentUnit = currentUnit;

  final BitcoinUnit _currentUnit;
  final int walldtId;

  @override
  State<TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends State<TransactionList> {
  late List<TransactionRecord> _displayedTxList = [];
  final GlobalKey<SliverAnimatedListState> _txListKey = GlobalKey<SliverAnimatedListState>();
  final Duration _duration = const Duration(milliseconds: 1200);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Selector<WalletDetailViewModel, Tuple2<List<TransactionRecord>, bool>>(
      selector: (_, viewModel) => Tuple2(viewModel.txList, viewModel.isWalletSyncing),
      builder: (_, data, __) {
        final txList = data.item1;
        final isWalletSyncing = data.item2;
        if (!listEquals(_displayedTxList, txList) || !_deepEquals(_displayedTxList, txList)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleTransactionListUpdate(txList);
          });
        }
        if (txList.isNotEmpty) return _buildSliverAnimatedList(_displayedTxList);
        return _buildEmptyState(isWalletSyncing ? t.tx_loading : t.tx_not_found);
      },
    );
  }

  // 내부 필드가 변경된 경우 감지(memo, amount, blockHeight 등)
  bool _deepEquals(List<TransactionRecord> a, List<TransactionRecord> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].contentHashCode != b[i].contentHashCode) {
        return false;
      }
    }
    return true;
  }

  Future<void> _handleTransactionListUpdate(List<TransactionRecord> txList) async {
    final isFirstLoad = _displayedTxList.isEmpty && txList.isNotEmpty;

    const Duration animationDuration = Duration(milliseconds: 100);
    final oldTxMap = {for (var tx in _displayedTxList) tx.transactionHash: tx};
    final newTxMap = {for (var tx in txList) tx.transactionHash: tx};

    final List<int> insertedIndexes = [];
    final List<int> removedIndexes = [];

    for (int i = 0; i < txList.length; i++) {
      if (!oldTxMap.containsKey(txList[i].transactionHash)) {
        insertedIndexes.add(i);
      }
    }

    for (int i = 0; i < _displayedTxList.length; i++) {
      if (!newTxMap.containsKey(_displayedTxList[i].transactionHash)) {
        removedIndexes.add(i);
      }
    }

    setState(() {
      _displayedTxList = List.from(txList);
    });

    // 마지막 인덱스부터 삭제 (index shift 문제 방지)
    for (var index in removedIndexes.reversed) {
      await Future.delayed(animationDuration);
      _txListKey.currentState?.removeItem(
        index,
        (context, animation) => _buildRemoveTransactionItem(_displayedTxList[index], animation),
        duration: _duration,
      );
    }

    // 삽입된 인덱스 순서대로 추가
    for (var index in insertedIndexes) {
      if (isFirstLoad) {
        await Future.delayed(animationDuration);
      }
      _txListKey.currentState?.insertItem(index, duration: _duration);
    }
  }

  Widget _buildSliverAnimatedList(List<TransactionRecord> txList) {
    return SliverAnimatedList(
      key: _txListKey,
      initialItemCount: txList.length,
      itemBuilder: (context, index, animation) {
        return index < txList.length
            ? _buildTransactionItem(txList[index], animation, txList.length - 1 == index)
            : const SizedBox();
      },
    );
  }

  Widget _buildTransactionItem(TransactionRecord tx, Animation<double> animation, bool isLastItem) {
    return Column(
      children: [
        SlideTransition(
          position: AnimationUtil.buildSlideInAnimation(animation),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TransactionItemCard(
              key: Key(tx.transactionHash),
              tx: tx,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              currentUnit: widget._currentUnit,
              id: widget.walldtId,
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  AppRouteNames.transactionDetail,
                  arguments: TransactionDetailRouteArgs(id: widget.walldtId, txHash: tx.transactionHash),
                );
              },
            ),
          ),
        ),
        isLastItem ? CoconutLayout.spacing_1000h : CoconutLayout.spacing_200h,
      ],
    );
  }

  Widget _buildRemoveTransactionItem(TransactionRecord tx, Animation<double> animation) {
    var offsetAnimation = AnimationUtil.buildSlideOutAnimation(animation);

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: offsetAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TransactionItemCard(
            key: Key(tx.transactionHash),
            tx: tx,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            currentUnit: widget._currentUnit,
            id: widget.walldtId,
            onPressed: () {
              Navigator.pushNamed(
                context,
                AppRouteNames.transactionDetail,
                arguments: TransactionDetailRouteArgs(id: widget.walldtId, txHash: tx.transactionHash),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return SliverFillRemaining(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(message, style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText)),
        ),
      ),
    );
  }
}
