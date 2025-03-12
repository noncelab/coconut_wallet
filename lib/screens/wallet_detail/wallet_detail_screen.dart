import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/card/transaction_item_card.dart';
import 'package:coconut_wallet/widgets/overlays/custom_toast.dart';
import 'package:coconut_wallet/widgets/header/wallet_detail_header.dart';
import 'package:coconut_wallet/widgets/header/wallet_detail_sticky_header.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_faucet_request_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_receive_address_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/tooltip/faucet_tooltip.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';
import 'package:lottie/lottie.dart';

enum Unit { btc, sats }

class WalletDetailScreen extends StatefulWidget {
  final int id;

  const WalletDetailScreen({super.key, required this.id});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  bool _isPullToRefreshing = false;
  Unit _currentUnit = Unit.btc;

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
                  backgroundColor: MyColors.black,
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
                                Tuple4<int, String, int, int>>(
                            selector: (_, viewModel) => Tuple4(
                                viewModel.balance,
                                viewModel.bitcoinPriceKrwInString,
                                viewModel.sendingAmount,
                                viewModel.receivingAmount),
                            builder: (_, data, __) {
                              return WalletDetailHeader(
                                key: _headerWidgetKey,
                                balance: data.item1,
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
                      Selector<WalletDetailViewModel, bool>(
                        selector: (_, viewModel) => viewModel.isWalletSyncing,
                        builder: (_, isWalletSyncing, __) {
                          return SliverToBoxAdapter(
                              child: SizedBox(
                                  height: 32,
                                  child: isWalletSyncing
                                      ? Padding(
                                          padding: const EdgeInsets.only(
                                              right: 16.0),
                                          child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.end,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                Text(t.status_updating,
                                                    style: CoconutTypography
                                                        .body3_12_Bold
                                                        .setColor(CoconutColors
                                                            .primary)),
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
                      ),
                      SliverToBoxAdapter(
                          child: Padding(
                              key: _txListLabelWidgetKey,
                              padding: const EdgeInsets.only(
                                left: 16.0,
                                right: 16.0,
                                bottom: 12.0,
                              ),
                              child: Text(t.tx_list, style: Styles.h3))),
                      TransactionList(
                          // txListKey: _txListKey,
                          currentUnit: _currentUnit,
                          widget: widget),
                    ],
                  ),
                ),
                _buildFaucetTooltip(),
                _buildStickyHeader(),
              ],
            ),
          ),
        ));
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return CoconutAppBar.build(
      entireWidgetKey: _appBarKey,
      faucetIconKey: _faucetIconKey,
      backgroundColor: MyColors.black,
      title: TextUtils.ellipsisIfLonger(_viewModel.walletName, maxLength: 15),
      context: context,
      onTitlePressed: () => _navigateToWalletInfo(context),
      actionButtonList: [
        IconButton(
          onPressed: () => _onFaucetIconPressed(),
          icon:
              SvgPicture.asset('assets/svg/faucet.svg', width: 18, height: 18),
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
    return WalletDetailStickyHeader(
        widgetKey: _stickyHeaderWidgetKey,
        height: _appBarSize.height,
        isVisible: _stickyHeaderVisible,
        currentUnit: _currentUnit,
        balance: _viewModel.balance,
        onTapReceive: () {
          _viewModel.removeFaucetTooltip();
          _onTapReceive();
        },
        onTapSend: () {
          _viewModel.removeFaucetTooltip();
          _onTapSend();
        });
  }

  // 스크롤 시 sticky header 렌더링을 위한 상태 변수들
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _appBarKey = GlobalKey();
  Size _appBarSize = const Size(0, 0);
  double _topPadding = 0;

  final GlobalKey _faucetIconKey = GlobalKey();
  Size _faucetIconSize = const Size(0, 0);
  Offset _faucetIconPosition = Offset.zero;

  final GlobalKey _headerWidgetKey = GlobalKey();

  final GlobalKey _stickyHeaderWidgetKey = GlobalKey();
  RenderBox? _stickyHeaderRenderBox;
  bool _stickyHeaderVisible = false;

  final GlobalKey _txListLabelWidgetKey = GlobalKey();
  late RenderBox _txlistLabelRenderBox;

  @override
  void initState() {
    super.initState();

    _viewModel = WalletDetailViewModel(
      widget.id,
      Provider.of<WalletProvider>(context, listen: false),
      Provider.of<TransactionProvider>(context, listen: false),
      Provider.of<ConnectivityProvider>(context, listen: false),
      Provider.of<UpbitConnectModel>(context, listen: false),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appBarRenderBox =
          _appBarKey.currentContext?.findRenderObject() as RenderBox;
      final headerWidgetRenderBox =
          _headerWidgetKey.currentContext?.findRenderObject() as RenderBox;

      if (_faucetIconKey.currentContext != null) {
        final faucetRenderBox =
            _faucetIconKey.currentContext?.findRenderObject() as RenderBox;
        _faucetIconPosition = faucetRenderBox.localToGlobal(Offset.zero);
        _faucetIconSize = faucetRenderBox.size;
      }

      if (_txListLabelWidgetKey.currentContext != null) {
        _txlistLabelRenderBox = _txListLabelWidgetKey.currentContext
            ?.findRenderObject() as RenderBox;
      }

      final positionedTopWidgetRenderBox = _stickyHeaderWidgetKey.currentContext
          ?.findRenderObject() as RenderBox;

      _appBarSize = appBarRenderBox.size;
      final topSelectorWidgetSize = headerWidgetRenderBox.size;
      final topHeaderWidgetSize = _txlistLabelRenderBox.size;
      final positionedTopWidgetSize =
          positionedTopWidgetRenderBox.size; // 거래내역 - Utxo 리스트 위젯 영역

      setState(() {
        _topPadding = topSelectorWidgetSize.height +
            topHeaderWidgetSize.height -
            positionedTopWidgetSize.height;
      });

      _scrollController.addListener(() {
        if (_scrollController.offset > _topPadding) {
          if (!_isPullToRefreshing) {
            setState(() {
              _stickyHeaderVisible = true;
            });
            _stickyHeaderRenderBox ??= _stickyHeaderWidgetKey.currentContext
                ?.findRenderObject() as RenderBox;
          }
        } else {
          if (!_isPullToRefreshing) {
            setState(() {
              _stickyHeaderVisible = false;
            });
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _checkStateAndShowToast() {
    if (_viewModel.isNetworkOn != true) {
      CustomToast.showWarningToast(
          context: context, text: ErrorCodes.networkError.message);
      return false;
    }

    if (_viewModel.isWalletSyncing) {
      CustomToast.showToast(
          context: context, text: t.toast.fetching_onchain_data);
      return false;
    }

    return true;
  }

  void _onTapReceive() {
    CommonBottomSheets.showBottomSheet_90(
      context: context,
      child: ReceiveAddressBottomSheet(
        id: widget.id,
        address: _viewModel.receiveAddress,
        derivationPath: _viewModel.derivationPath,
      ),
    );
  }

  void _onTapSend() {
    if (!_checkStateAndShowToast()) return;

    Navigator.pushNamed(context, '/send-address', arguments: {'id': widget.id});
  }

  void _toggleUnit() {
    setState(() {
      _currentUnit = _currentUnit == Unit.btc ? Unit.sats : Unit.btc;
    });
  }

  // Faucet 메서드
  Widget _buildFaucetTooltip() {
    return FaucetTooltip(
      text: t.tooltip.faucet,
      isVisible: _viewModel.faucetTooltipVisible,
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
          // TODO: walletAddressBook
          // walletAddressBook: const [],
          walletData: {
            'wallet_id': _viewModel.walletId,
            'wallet_address': _viewModel.receiveAddress,
            'wallet_name': _viewModel.walletName,
            'wallet_index': _viewModel.receiveAddressIndex,
          },
          isRequesting: _viewModel.isRequesting,
          onRequest: (address, requestAmount) {
            if (_viewModel.isRequesting) return;

            _viewModel.requestTestBitcoin(address, requestAmount,
                (success, message) {
              if (success) {
                Navigator.pop(context);
                vibrateLight();
                CustomToast.showToast(context: context, text: message);
              } else {
                vibrateMedium();
                CustomToast.showWarningToast(context: context, text: message);
              }
            });
          },
          walletProvider: _viewModel.walletProvider!,
          walletItem: _viewModel.walletListBaseItem!,
        ));
  }
}

class TransactionList extends StatefulWidget {
  const TransactionList({
    super.key,
    required Unit currentUnit,
    required this.widget,
  }) : _currentUnit = currentUnit;

  final Unit _currentUnit;
  final WalletDetailScreen widget;

  @override
  State<TransactionList> createState() => _TransactionListState();
}

class _TransactionListState extends State<TransactionList> {
  late List<TransactionRecord> _previousTxList = [];
  final GlobalKey<SliverAnimatedListState> _txListKey =
      GlobalKey<SliverAnimatedListState>();
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
          _handleTransactionListUpdate(txList);

          return txList.isNotEmpty
              ? _buildSliverAnimatedList(txList)
              : _buildEmptyState();
        });
  }

  void _handleTransactionListUpdate(List<TransactionRecord> txList) {
    // TODO: 로직 변경 필요
    // 1. 트랜잭션 추가 위치: 반드시 맨 앞이 아닐수 있음
    // 2. 삭제 케이스: rbf 시 기존 트랜잭션은 삭제됨.
    // 3. 트랜잭션의 상태만 바뀌는 경우, 부분 렌더링 가능할까?
    if (txList.length > _previousTxList.length) {
      _txListKey.currentState?.insertItem(0, duration: _duration);
    }
    _previousTxList = List.from(txList);
  }

  Widget _buildSliverAnimatedList(List<TransactionRecord> txList) {
    return SliverAnimatedList(
      key: _txListKey,
      initialItemCount: txList.length,
      itemBuilder: (context, index, animation) {
        return _buildTransactionItem(txList, index, animation);
      },
    );
  }

  Animation<Offset> _buildSlideAnimation(Animation<double> animation) {
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.easeOutExpo;

    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    return animation.drive(tween);
  }

  Widget _buildTransactionItem(
      List<TransactionRecord> txList, int index, Animation<double> animation) {
    var offsetAnimation = _buildSlideAnimation(animation);

    return Column(
      children: [
        SlideTransition(
          position: offsetAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TransactionItemCard(
              key: Key(txList[index].transactionHash),
              tx: txList[index],
              currentUnit: widget._currentUnit,
              id: widget.widget.id,
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  '/transaction-detail',
                  arguments: {
                    'id': widget.widget.id,
                    'txHash': txList[index].transactionHash,
                  },
                );
              },
            ),
          ),
        ),
        txList.length - 1 == index
            ? CoconutLayout.spacing_1000h
            : CoconutLayout.spacing_200h,
      ],
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
