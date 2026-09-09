import 'dart:io';
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
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
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
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/common/loading/loading_indicator.dart';
import 'package:coconut_wallet/widgets/features/transaction/card/transaction_item_card.dart';
import 'package:coconut_wallet/widgets/features/wallet/header/wallet_detail_header.dart';
import 'package:coconut_wallet/widgets/features/wallet/header/wallet_detail_sticky_header.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_refresh_icon.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

class WalletDetailScreen extends StatefulWidget {
  final int id;
  final String entryPoint;

  const WalletDetailScreen({super.key, required this.id, required this.entryPoint});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  static const _minimumRefreshIndicatorDuration = Duration(milliseconds: 700);
  bool _isPullToRefreshing = false;
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
                appBar: _buildAppBar(context),
                body: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  controller: _scrollController,
                  slivers: [
                    Selector<WalletDetailViewModel, bool>(
                      selector: (_, viewModel) => viewModel.isWalletSyncing,
                      builder:
                          (_, isWalletSyncing, _) =>
                              isWalletSyncing
                                  ? const SliverToBoxAdapter(child: SizedBox.shrink())
                                  : CupertinoSliverRefreshControl(
                                    onRefresh: _onRefresh,
                                    refreshTriggerPullDistance: 80,
                                  ),
                    ),
                    SliverToBoxAdapter(
                      child: Selector<WalletDetailViewModel, Tuple5<AnimatedBalanceData, String, int, int, bool>>(
                        selector:
                            (_, viewModel) => Tuple5(
                              AnimatedBalanceData(viewModel.balance, viewModel.prevBalance),
                              viewModel.fiatPriceString,
                              viewModel.sendingAmount,
                              viewModel.receivingAmount,
                              viewModel.isWalletSyncing,
                            ),
                        builder: (_, data, __) {
                          return TransactionDetailHeader(
                            key: _headerWidgetKey,
                            animatedBalanceData: data.item1,
                            currentUnit: _currentUnit,
                            fiatPrice: data.item2,
                            sendingAmount: data.item3,
                            receivingAmount: data.item4,
                            isRefreshing: _isPullToRefreshing || data.item5,
                            onPressedUnitToggle: _toggleUnit,
                          );
                        },
                      ),
                    ),
                    _buildTxListLabel(),
                    TransactionList(currentUnit: _currentUnit, walldtId: widget.id),

                    SliverToBoxAdapter(child: SizedBox(height: 35 + MediaQuery.of(context).padding.bottom)),
                  ],
                ),
              ),
              _buildStickyHeader(),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return CoconutAppBar.build(
      // FIXME: CDN 백버튼 및 닫기 버튼 지정할 수 있어야 함.
      // 예: iconColor: context.coconutColors.iconPrimary,
      entireWidgetKey: _appBarKey,
      backgroundColor: context.coconutColors.background,
      title: '',
      context: context,
      actionButtonList: [
        ListenableBuilder(
          listenable: _viewModel,
          builder:
              (_, _) => CoconutAppBarActionButton(
                onPressed: _isPullToRefreshing || _viewModel.isWalletSyncing ? null : _onRefresh,
                icon: WalletRefreshIcon(isRefreshing: _isPullToRefreshing, size: 20),
              ),
        ),
      ],
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

  Widget _buildStickyHeader() {
    return ValueListenableBuilder<bool>(
      valueListenable: _stickyHeaderVisibleNotifier,
      builder: (context, isVisible, child) {
        return Selector<WalletDetailViewModel, Tuple2<AnimatedBalanceData, String>>(
          selector:
              (_, viewModel) =>
                  Tuple2(AnimatedBalanceData(viewModel.balance, viewModel.prevBalance), viewModel.fiatPriceString),
          builder: (context, data, child) {
            return TransactionDetailStickyHeader(
              widgetKey: _stickyHeaderWidgetKey,
              height: _appBarSize.height,
              isVisible: isVisible,
              currentUnit: _currentUnit,
              animatedBalanceData: data.item1,
              fiatPrice: data.item2,
            );
          },
        );
      },
    );
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

  final GlobalKey _appBarKey = GlobalKey();
  Size _appBarSize = const Size(0, 0);
  double _topPadding = 0;

  final GlobalKey _headerWidgetKey = GlobalKey();

  final GlobalKey _stickyHeaderWidgetKey = GlobalKey();
  RenderBox? _stickyHeaderRenderBox;
  final ValueNotifier<bool> _stickyHeaderVisibleNotifier = ValueNotifier<bool>(false);

  final GlobalKey _txListLabelWidgetKey = GlobalKey();

  static const double _stickyHeaderScrollThresholdOffset = 45;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Size topSelectorWidgetSize = const Size(0, 0);
      Size positionedTopWidgetSize = const Size(0, 0);

      if (_appBarKey.currentContext != null) {
        final appBarRenderBox = _appBarKey.currentContext?.findRenderObject() as RenderBox;
        _appBarSize = appBarRenderBox.size;
      }

      if (_headerWidgetKey.currentContext != null) {
        final headerWidgetRenderBox = _headerWidgetKey.currentContext?.findRenderObject() as RenderBox;
        topSelectorWidgetSize = headerWidgetRenderBox.size;
      }

      if (_stickyHeaderWidgetKey.currentContext != null) {
        final positionedTopWidgetRenderBox = _stickyHeaderWidgetKey.currentContext?.findRenderObject() as RenderBox;
        positionedTopWidgetSize = positionedTopWidgetRenderBox.size; // 거래내역 - Utxo 리스트 위젯 영역
      }

      setState(() {
        _topPadding = topSelectorWidgetSize.height - positionedTopWidgetSize.height;
      });

      _scrollController.addListener(() {
        if (_scrollController.offset > _topPadding + _stickyHeaderScrollThresholdOffset) {
          if (!_isPullToRefreshing) {
            _stickyHeaderVisibleNotifier.value = true;
            _stickyHeaderRenderBox ??= _stickyHeaderWidgetKey.currentContext?.findRenderObject() as RenderBox;
          }
        } else {
          if (!_isPullToRefreshing) {
            _stickyHeaderVisibleNotifier.value = false;
          }
        }
      });
    });

    if (Platform.isIOS) {
      _enableStatusBarTapScroll();
    }
  }

  @override
  void dispose() {
    _statusBarTapOverlayEntry?.remove();
    _statusBarTapOverlayEntry = null;
    _scrollController.dispose();
    _stickyHeaderVisibleNotifier.dispose();
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
    return Selector<WalletDetailViewModel, List<TransactionRecord>>(
      selector: (_, viewModel) => viewModel.txList,
      builder: (_, txList, __) {
        if (!listEquals(_displayedTxList, txList) || !_deepEquals(_displayedTxList, txList)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleTransactionListUpdate(txList);
          });
        }
        return txList.isNotEmpty ? _buildSliverAnimatedList(_displayedTxList) : _buildEmptyState();
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
              currentUnit: widget._currentUnit,
              id: widget.walldtId,
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/transaction-detail',
                  arguments: {'id': widget.walldtId, 'txHash': tx.transactionHash},
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
            currentUnit: widget._currentUnit,
            id: widget.walldtId,
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/transaction-detail',
                arguments: {'id': widget.walldtId, 'txHash': tx.transactionHash},
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(t.tx_not_found, style: CoconutTypography.body1_16.setColor(context.coconutColors.primaryText)),
        ),
      ),
    );
  }
}
