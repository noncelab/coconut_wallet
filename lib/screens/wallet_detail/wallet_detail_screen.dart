import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/body/wallet_detail_body.dart';
import 'package:coconut_wallet/widgets/loading_indicator/loading_indicator.dart';
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

enum Unit { btc, sats }

class WalletDetailScreen extends StatefulWidget {
  final int id;

  const WalletDetailScreen({super.key, required this.id});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
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

  final GlobalKey _tabWidgetKey = GlobalKey();
  late RenderBox _tabWidgetRenderBox;

  final GlobalKey _txSliverListKey = GlobalKey();
  bool _isPullToRefreshing = false;
  Unit _currentUnit = Unit.btc;

  late WalletDetailViewModel _viewModel;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider4<WalletProvider, TransactionProvider,
        ConnectivityProvider, UpbitConnectModel, WalletDetailViewModel>(
      create: (_) => _createViewModel(_),
      update: (_, walletProvider, txProvider, connectProvider, upbitModel,
          viewModel) {
        return viewModel!..updateProvider();
      },
      child: Consumer<WalletDetailViewModel>(
        builder: (context, viewModel, child) {
          return PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, _) {
              viewModel.removeFaucetTooltip();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, // 빈 영역도 감지 가능
              child: Stack(
                children: [
                  Scaffold(
                    backgroundColor: CoconutColors.black,
                    appBar: _buildAppBar(context, viewModel),
                    body: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: _scrollController,
                      slivers: [
                        if (viewModel.isWalletSyncing)
                          const SliverToBoxAdapter(child: LoadingIndicator()),
                        CupertinoSliverRefreshControl(
                          onRefresh: () async => _onRefresh(
                              viewModel,
                              viewModel.balance,
                              viewModel.isNetworkOn ?? false),
                        ),
                        SliverToBoxAdapter(
                          child: WalletDetailHeader(
                            key: _headerWidgetKey,
                            prevBalance: viewModel.prevBalance,
                            balance: viewModel.balance,
                            currentUnit: _currentUnit,
                            btcPriceInKrw: viewModel.bitcoinPriceKrw,
                            onPressedUnitToggle: _toggleUnit,
                            onTapReceive: _onTapReceive,
                            onTapSend: _onTapSend,
                          ),
                        ),
                        // todo: 지갑 업데이트 상태 표기
                        SliverToBoxAdapter(
                          child: Padding(
                            key: _tabWidgetKey,
                            padding: const EdgeInsets.only(
                              left: 16.0,
                              right: 16.0,
                              bottom: 12.0,
                              top: 30,
                            ),
                            child: Text(
                              t.tx_list,
                              style: const TextStyle(
                                fontFamily: 'Pretendard',
                                color: Colors.white,
                                fontSize: 18,
                                fontStyle: FontStyle.normal,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ),
                        SliverSafeArea(
                          minimum: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: WalletDetailBody(
                            txSliverListKey: _txSliverListKey,
                            walletId: widget.id,
                            walletType: viewModel.walletType,
                            currentUnit: _currentUnit,
                            txList: viewModel.txList,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildFaucetTooltip(viewModel),
                  _buildStickyHeader(viewModel),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  WalletDetailViewModel _createViewModel(BuildContext context) {
    _viewModel = WalletDetailViewModel(
        widget.id,
        Provider.of<WalletProvider>(context, listen: false),
        Provider.of<TransactionProvider>(context, listen: false),
        Provider.of<ConnectivityProvider>(context, listen: false),
        Provider.of<UpbitConnectModel>(context, listen: false),
        Provider.of<SendInfoProvider>(context, listen: false));
    return _viewModel;
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, WalletDetailViewModel viewModel) {
    final balance = viewModel.balance;
    final isNetworkOn = viewModel.isNetworkOn;

    return CoconutAppBar.build(
      entireWidgetKey: _appBarKey,
      faucetIconKey: _faucetIconKey,
      backgroundColor: CoconutColors.black,
      title: TextUtils.ellipsisIfLonger(viewModel.walletListBaseItem!.name,
          maxLength: 15),
      context: context,
      onTitlePressed: () => _navigateToWalletInfo(context, viewModel),
      actionButtonList: [
        IconButton(
          onPressed: () =>
              _onFaucetIconPressed(viewModel, balance, isNetworkOn),
          icon:
              SvgPicture.asset('assets/svg/faucet.svg', width: 18, height: 18),
        ),
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/utxo-list',
              arguments: {'id': widget.id}),
          icon: SvgPicture.asset('assets/svg/coins.svg', width: 18, height: 18),
        ),
      ],
    );
  }

  void _navigateToWalletInfo(
      BuildContext context, WalletDetailViewModel viewModel) async {
    await Navigator.pushNamed(context, '/wallet-info', arguments: {
      'id': widget.id,
      'isMultisig': viewModel.walletType == WalletType.multiSignature
    });
  }

  void _onRefresh(
      WalletDetailViewModel viewModel, int balance, bool isNetworkOn) async {
    _isPullToRefreshing = true;
    try {
      if (!_checkStateAndShowToast()) {
        return;
      }
      viewModel.refreshWallet();
    } finally {
      _isPullToRefreshing = false;
    }
  }

  Widget _buildFaucetTooltip(WalletDetailViewModel viewModel) {
    return FaucetTooltip(
      text: t.tooltip.faucet,
      isVisible: viewModel.faucetTooltipVisible,
      width: MediaQuery.of(context).size.width,
      iconPosition: _faucetIconPosition,
      iconSize: _faucetIconSize,
      onTapRemove: viewModel.removeFaucetTooltip,
    );
  }

  void _onFaucetIconPressed(
      WalletDetailViewModel viewModel, int balance, bool? isNetworkOn) async {
    viewModel.removeFaucetTooltip();
    if (!_checkStateAndShowToast()) {
      return;
    }
    await CommonBottomSheets.showBottomSheet_50(
        context: context,
        child: FaucetRequestBottomSheet(
          // TODO: walletAddressBook
          // walletAddressBook: const [],
          walletData: {
            'wallet_id': viewModel.walletId,
            'wallet_address': viewModel.receiveAddress,
            'wallet_name': viewModel.walletName,
            'wallet_index': viewModel.receiveAddressIndex,
          },
          isRequesting: viewModel.isRequesting,
          onRequest: (address, requestAmount) {
            if (viewModel.isRequesting) return;

            viewModel.requestTestBitcoin(address, requestAmount,
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
          walletProvider: viewModel.walletProvider!,
          walletItem: viewModel.walletListBaseItem!,
        ));
  }

  Widget _buildStickyHeader(WalletDetailViewModel viewModel) {
    final balance = viewModel.balance;
    return WalletDetailStickyHeader(
        widgetKey: _stickyHeaderWidgetKey,
        height: _appBarSize.height,
        isVisible: _stickyHeaderVisible,
        currentUnit: _currentUnit,
        balance: balance,
        prevBalance: viewModel.prevBalance,
        onTapReceive: () {
          viewModel.removeFaucetTooltip();
          _onTapReceive();
        },
        onTapSend: () {
          viewModel.removeFaucetTooltip();
          _onTapSend();
        });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appBarRenderBox =
          _appBarKey.currentContext?.findRenderObject() as RenderBox;
      final headerWidgetRenderBox =
          _headerWidgetKey.currentContext?.findRenderObject() as RenderBox;
      _tabWidgetRenderBox =
          _tabWidgetKey.currentContext?.findRenderObject() as RenderBox;

      if (_faucetIconKey.currentContext != null) {
        final faucetRenderBox =
            _faucetIconKey.currentContext?.findRenderObject() as RenderBox;
        _faucetIconPosition = faucetRenderBox.localToGlobal(Offset.zero);
        _faucetIconSize = faucetRenderBox.size;
      }

      final positionedTopWidgetRenderBox = _stickyHeaderWidgetKey.currentContext
          ?.findRenderObject() as RenderBox;

      _appBarSize = appBarRenderBox.size;
      final topSelectorWidgetSize = headerWidgetRenderBox.size;
      final topHeaderWidgetSize = _tabWidgetRenderBox.size;
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
    _viewModel.clearSendInfo();
    Navigator.pushNamed(context, '/send-address', arguments: {'id': widget.id});
  }

  void _toggleUnit() {
    setState(() {
      _currentUnit = _currentUnit == Unit.btc ? Unit.sats : Unit.btc;
    });
  }
}
