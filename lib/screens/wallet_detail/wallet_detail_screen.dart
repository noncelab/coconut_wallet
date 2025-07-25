import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/amimation_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/appbar/wallet_detail_title_widget.dart';
import 'package:coconut_wallet/widgets/card/transaction_item_card.dart';
import 'package:coconut_wallet/widgets/header/wallet_detail_header.dart';
import 'package:coconut_wallet/widgets/header/wallet_detail_sticky_header.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_faucet_request_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_receive_address_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/tooltip/faucet_tooltip.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:lottie/lottie.dart';

class WalletDetailScreen extends StatefulWidget {
  final int id;

  const WalletDetailScreen({super.key, required this.id});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  bool _isPullToRefreshing = false;
  late BitcoinUnit _currentUnit;
  late WalletDetailViewModel _viewModel;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
        create: (_) => _viewModel,
        child: PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, _) {
            _viewModel.removeFaucetTooltip();
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque, // 빈 영역도 감지 가능
            child: Stack(
              children: [
                Scaffold(
                  backgroundColor: CoconutColors.black,
                  appBar: _buildAppBar(context),
                  body: CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    controller: _scrollController,
                    slivers: [
                      CupertinoSliverRefreshControl(
                        onRefresh: () async => _onRefresh(),
                      ),
                      SliverToBoxAdapter(
                        child: Selector<WalletDetailViewModel,
                                Tuple4<AnimatedBalanceData, String, int, int>>(
                            selector: (_, viewModel) => Tuple4(
                                AnimatedBalanceData(viewModel.balance, viewModel.prevBalance),
                                viewModel.bitcoinPriceKrwInString,
                                viewModel.sendingAmount,
                                viewModel.receivingAmount),
                            builder: (_, data, __) {
                              return WalletDetailHeader(
                                key: _headerWidgetKey,
                                animatedBalanceData: data.item1,
                                currentUnit: _currentUnit,
                                btcPriceInKrw: data.item2,
                                sendingAmount: data.item3,
                                receivingAmount: data.item4,
                                onPressedUnitToggle: _toggleUnit,
                                onTapReceive: _onTapReceive,
                                onTapSend: _onTapSend,
                              );
                            }),
                      ),
                      _buildLoadingWidget(),
                      _buildTxListLabel(),
                      TransactionList(currentUnit: _currentUnit, walldtId: widget.id),
                    ],
                  ),
                ),
                _buildStickyHeader(),
                Selector<WalletDetailViewModel, bool>(
                    selector: (_, viewModel) => viewModel.faucetTooltipVisible,
                    builder: (_, isFaucetTooltipVisible, __) {
                      return _buildFaucetTooltip(isFaucetTooltipVisible);
                    }),
              ],
            ),
          ),
        ));
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return CoconutAppBar.build(
      entireWidgetKey: _appBarKey,
      backgroundColor: CoconutColors.black,
      customTitle: WalletDetailTitleWidget(
        walletName: _viewModel.walletName,
        onTap: () => _navigateToWalletInfo(context),
      ),
      titlePadding: const EdgeInsets.all(8),
      context: context,
      actionButtonList: [
        if (NetworkType.currentNetworkType.isTestnet)
          IconButton(
            key: _faucetIconKey,
            onPressed: () => _onFaucetIconPressed(),
            icon: SvgPicture.asset('assets/svg/faucet.svg', width: 18, height: 18),
          ),
        IconButton(
          onPressed: () => _navigateToUtxoList(context),
          icon: SvgPicture.asset('assets/svg/coins.svg', width: 18, height: 18),
        ),
      ],
    );
  }

  void _navigateToUtxoList(BuildContext context) {
    Navigator.pushNamed(context, '/utxo-list', arguments: {'id': widget.id});
  }

  void _navigateToWalletInfo(BuildContext context) async {
    await Navigator.pushNamed(context, '/wallet-info', arguments: {
      'id': widget.id,
      'isMultisig': _viewModel.walletType == WalletType.multiSignature
    });

    _viewModel.updateWalletName();
  }

  void _onRefresh() async {
    _isPullToRefreshing = true;
    try {
      if (!_checkStateAndShowToast()) {
        return;
      }
      _viewModel.refreshWallet();
    } finally {
      _isPullToRefreshing = false;
    }
  }

  Widget _buildStickyHeader() {
    return ValueListenableBuilder<bool>(
        valueListenable: _stickyHeaderVisibleNotifier,
        builder: (context, isVisible, child) {
          return Selector<WalletDetailViewModel, int>(
            selector: (_, viewModel) => viewModel.balance,
            builder: (context, balance, child) {
              return WalletDetailStickyHeader(
                widgetKey: _stickyHeaderWidgetKey,
                height: _appBarSize.height,
                isVisible: isVisible,
                currentUnit: _currentUnit,
                animatedBalanceData:
                    AnimatedBalanceData(_viewModel.balance, _viewModel.prevBalance),
                onTapReceive: () {
                  _viewModel.removeFaucetTooltip();
                  _onTapReceive();
                },
                onTapSend: () {
                  _viewModel.removeFaucetTooltip();
                  _onTapSend();
                },
              );
            },
          );
        });
  }

  Selector<WalletDetailViewModel, bool> _buildLoadingWidget() {
    return Selector<WalletDetailViewModel, bool>(
      selector: (_, viewModel) => viewModel.isWalletSyncing,
      builder: (_, isWalletSyncing, __) {
        return SliverToBoxAdapter(
            child: SizedBox(
                height: 32,
                child: isWalletSyncing
                    ? Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(t.status_updating,
                                  style: CoconutTypography.body3_12_Bold
                                      .setColor(CoconutColors.primary)),
                              CoconutLayout.spacing_100w,
                              LottieBuilder.asset(
                                'assets/files/status_loading.json',
                                width: 16,
                                height: 16,
                              ),
                            ]),
                      )
                    : null));
      },
    );
  }

  Widget _buildTxListLabel() {
    return SliverToBoxAdapter(
        child: Selector<WalletDetailViewModel, int>(
      selector: (_, viewModel) => viewModel.txList.length,
      builder: (_, txCount, __) {
        return Padding(
            key: _txListLabelWidgetKey,
            padding: const EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              bottom: 12.0,
            ),
            child: Row(
              children: [
                Text(t.tx_list,
                    style: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white)),
                CoconutLayout.spacing_100w,
                if (txCount > 0)
                  Text(t.total_item_count(count: txCount),
                      style: CoconutTypography.body3_12.setColor(CoconutColors.gray400)),
              ],
            ));
      },
    ));
  }

  // 스크롤 시 sticky header 렌더링을 위한 상태 변수들
  final ScrollController _scrollController = ScrollController();
  OverlayEntry? _statusBarTapOverlayEntry;

  final GlobalKey _appBarKey = GlobalKey();
  Size _appBarSize = const Size(0, 0);
  double _topPadding = 0;

  final GlobalKey _faucetIconKey = GlobalKey();
  Size _faucetIconSize = const Size(0, 0);
  Offset _faucetIconPosition = Offset.zero;

  final GlobalKey _headerWidgetKey = GlobalKey();

  final GlobalKey _stickyHeaderWidgetKey = GlobalKey();
  RenderBox? _stickyHeaderRenderBox;
  final ValueNotifier<bool> _stickyHeaderVisibleNotifier = ValueNotifier<bool>(false);

  final GlobalKey _txListLabelWidgetKey = GlobalKey();

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
        Provider.of<SendInfoProvider>(context, listen: false),
        Provider.of<NodeProvider>(context, listen: false));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Size topSelectorWidgetSize = const Size(0, 0);
      Size topHeaderWidgetSize = const Size(0, 0);
      Size positionedTopWidgetSize = const Size(0, 0);

      if (_appBarKey.currentContext != null) {
        final appBarRenderBox = _appBarKey.currentContext?.findRenderObject() as RenderBox;
        _appBarSize = appBarRenderBox.size;
      }

      if (_headerWidgetKey.currentContext != null) {
        final headerWidgetRenderBox =
            _headerWidgetKey.currentContext?.findRenderObject() as RenderBox;
        topSelectorWidgetSize = headerWidgetRenderBox.size;
      }

      if (_faucetIconKey.currentContext != null) {
        final faucetRenderBox = _faucetIconKey.currentContext?.findRenderObject() as RenderBox;
        _faucetIconPosition = faucetRenderBox.localToGlobal(Offset.zero);
        _faucetIconSize = faucetRenderBox.size;
      }

      if (_stickyHeaderWidgetKey.currentContext != null) {
        final positionedTopWidgetRenderBox =
            _stickyHeaderWidgetKey.currentContext?.findRenderObject() as RenderBox;
        positionedTopWidgetSize = positionedTopWidgetRenderBox.size; // 거래내역 - Utxo 리스트 위젯 영역
      }

      setState(() {
        _topPadding = topSelectorWidgetSize.height +
            topHeaderWidgetSize.height -
            positionedTopWidgetSize.height;
      });

      _scrollController.addListener(() {
        if (_scrollController.offset > _topPadding) {
          if (!_isPullToRefreshing) {
            _stickyHeaderVisibleNotifier.value = true;
            _stickyHeaderRenderBox ??=
                _stickyHeaderWidgetKey.currentContext?.findRenderObject() as RenderBox;
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
        builder: (context) => Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: MediaQuery.of(context).padding.top,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () {
              _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
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
      CoconutToast.showWarningToast(context: context, text: ErrorCodes.networkError.message);
      return false;
    }

    if (_viewModel.networkStatus == NetworkStatus.connectionFailed) {
      CoconutToast.showWarningToast(context: context, text: t.errors.electrum_connection_failed);
      return false;
    }

    if (_viewModel.isWalletSyncing) {
      CoconutToast.showToast(
          isVisibleIcon: true, context: context, text: t.toast.fetching_onchain_data);
      return false;
    }

    return true;
  }

  void _onTapReceive() {
    CommonBottomSheets.showBottomSheet_90(
      context: context,
      child: ChangeNotifierProvider.value(
        value: _viewModel,
        child: ReceiveAddressBottomSheet(
          id: widget.id,
          paddingTop: MediaQuery.of(context).padding.top,
        ),
      ),
    );
  }

  void _onTapSend() {
    if (!_viewModel.isMultisigWallet &&
        _viewModel.masterFingerprint == WalletAddService.masterFingerprintPlaceholder) {
      CoconutToast.showToast(
          isVisibleIcon: true,
          context: context,
          text: t.wallet_detail_screen.toast.no_mfp_wallet_cant_send);
      return;
    }
    if (!_checkStateAndShowToast()) return;
    _viewModel.clearSendInfo();
    Navigator.pushNamed(context, '/send-address', arguments: {'id': widget.id});
  }

  void _toggleUnit() {
    setState(() {
      _currentUnit = _currentUnit == BitcoinUnit.btc ? BitcoinUnit.sats : BitcoinUnit.btc;
    });
  }

  // Faucet 메서드
  Widget _buildFaucetTooltip(bool isVisible) {
    return FaucetTooltip(
      text: t.tooltip.faucet,
      isVisible: isVisible,
      width: MediaQuery.of(context).size.width,
      iconPosition: _faucetIconPosition,
      iconSize: _faucetIconSize,
      onTapRemove: _viewModel.removeFaucetTooltip,
    );
  }

  void _onFaucetIconPressed() async {
    _viewModel.removeFaucetTooltip();
    if (!_checkStateAndShowToast()) {
      return;
    }
    await CommonBottomSheets.showBottomSheet_50(
        context: context,
        child: FaucetRequestBottomSheet(
          walletData: {
            'wallet_id': _viewModel.walletId,
            'wallet_address': _viewModel.receiveAddress,
            'wallet_name': _viewModel.walletName,
            'wallet_index': _viewModel.receiveAddressIndex,
          },
          isRequesting: _viewModel.isRequesting,
          onRequest: (address, requestAmount) {
            if (_viewModel.isRequesting) return;

            _viewModel.requestTestBitcoin(address, requestAmount, (success, message) {
              if (success) {
                Navigator.pop(context);
                vibrateLight();
                CoconutToast.showToast(isVisibleIcon: true, context: context, text: message);
              } else {
                vibrateMedium();
                CoconutToast.showWarningToast(context: context, text: message);
              }
            });
          },
          walletProvider: _viewModel.walletProvider!,
          walletItem: _viewModel.walletListBaseItem,
        ));
  }
}

class TransactionList extends StatefulWidget {
  const TransactionList({
    super.key,
    required BitcoinUnit currentUnit,
    required this.walldtId,
  }) : _currentUnit = currentUnit;

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
          return txList.isNotEmpty
              ? _buildSliverAnimatedList(_displayedTxList)
              : _buildEmptyState();
        });
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
                  arguments: {
                    'id': widget.walldtId,
                    'txHash': tx.transactionHash,
                  },
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
              Navigator.pushNamed(context, '/transaction-detail',
                  arguments: {'id': widget.walldtId, 'txHash': tx.transactionHash});
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
          child: Text(
            t.tx_not_found,
            style: CoconutTypography.body1_16,
          ),
        ),
      ),
    );
  }
}
