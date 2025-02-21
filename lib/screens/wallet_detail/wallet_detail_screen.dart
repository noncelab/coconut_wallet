import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/body/wallet_detail_body.dart';
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
                    backgroundColor: MyColors.black,
                    appBar: _buildAppBar(context, viewModel),
                    body: _buildBody(context, viewModel),
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
    );
    return _viewModel;
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, WalletDetailViewModel viewModel) {
    final state = viewModel.walletInitState;
    final balance = viewModel.balance;
    final isNetworkOn = viewModel.isNetworkOn;

    return CoconutAppBar.build(
      entireWidgetKey: _appBarKey,
      faucetIconKey: _faucetIconKey,
      backgroundColor: MyColors.black,
      title: TextUtils.ellipsisIfLonger(viewModel.walletListBaseItem!.name,
          maxLength: 15),
      context: context,
      hasRightIcon: true,
      onTitlePressed: () => _navigateToWalletInfo(context, viewModel),
      actionButtonList: [
        IconButton(
          onPressed: () =>
              _onFaucetIconPressed(viewModel, state, balance, isNetworkOn),
          icon:
              SvgPicture.asset('assets/svg/faucet.svg', width: 18, height: 18),
        ),
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/utxo-list'),
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

  Widget _buildBody(BuildContext context, WalletDetailViewModel viewModel) {
    final state = viewModel.walletInitState;
    final balance = viewModel.balance;
    final isNetworkOn = viewModel.isNetworkOn; // todo : null인 경우가 있어??

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      controller: _scrollController,
      slivers: [
        CupertinoSliverRefreshControl(
          onRefresh: () async =>
              _onRefresh(viewModel, state, balance, isNetworkOn ?? true),
        ),
        SliverToBoxAdapter(
          child: WalletDetailHeader(
            key: _headerWidgetKey,
            walletId: widget.id,
            address: viewModel.walletAddress,
            derivationPath: viewModel.derivationPath,
            balance: balance,
            currentUnit: _currentUnit,
            btcPriceInKrw: viewModel.bitcoinPriceKrw,
            onPressedUnitToggle: _toggleUnit,
            removePopup: _removeFilterDropdown,
            checkPrerequisites: () =>
                _checkStateAndShowToast(state, balance, isNetworkOn),
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
                child: Text(t.tx_list, style: Styles.h3))),
        SliverSafeArea(
          minimum: const EdgeInsets.symmetric(horizontal: 16),
          sliver: WalletDetailBody(
            txSliverListKey: _txSliverListKey,
            walletId: widget.id,
            walletType: viewModel.walletType,
            currentUnit: _currentUnit,
            txList: viewModel.txList,
            removePopup: _removeFilterDropdown,
          ),
        ),
      ],
    );
  }

  void _onRefresh(WalletDetailViewModel viewModel, WalletInitState state,
      int balance, bool isNetworkOn) async {
    _isPullToRefreshing = true;
    try {
      if (!_checkStateAndShowToast(state, balance, isNetworkOn)) {
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

  void _onFaucetIconPressed(WalletDetailViewModel viewModel,
      WalletInitState state, int balance, bool? isNetworkOn) async {
    _removeFilterDropdown();
    viewModel.removeFaucetTooltip();
    if (!_checkStateAndShowToast(state, balance, isNetworkOn)) {
      return;
    }
    await CommonBottomSheets.showBottomSheet_50(
        context: context,
        child: FaucetRequestBottomSheet(
          // TODO: walletAddressBook
          // walletAddressBook: const [],
          walletData: {
            'wallet_id': viewModel.walletId,
            'wallet_address': viewModel.walletAddress,
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
                Future.delayed(const Duration(seconds: 1), () {
                  viewModel.walletProvider
                      ?.initWallet(targetId: widget.id, syncOthers: false);
                });
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
    final state = viewModel.walletInitState;
    final balance = viewModel.balance;
    final isNetworkOn = viewModel.isNetworkOn;

    return WalletDetailStickyHeader(
      widgetKey: _stickyHeaderWidgetKey,
      height: _appBarSize.height,
      isVisible: _stickyHeaderVisible,
      currentUnit: _currentUnit,
      // TODO: receiveAddress
      receiveAddress: WalletAddress('', '', 0, false, 0, 0, 0),
      // receiveAddress: viewModel.walletListBaseItem!.walletBase
      //     .getReceiveAddress(),
      // TODO: walletStatus
      // walletStatus: viewModel.getInitializedWalletStatus(),
      // walletStatus: null,
      balance: balance,
      onTapReceive: (balance, address, path) {
        _onTapReceiveOrSend(balance, state, isNetworkOn,
            address: address, path: path);
      },
      onTapSend: (balance) {
        _onTapReceiveOrSend(balance, state, isNetworkOn);
      },
      removePopup: () {
        _removeFilterDropdown();
        viewModel.removeFaucetTooltip();
      },
    );
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

  bool _checkStateAndShowToast(
      WalletInitState state, int? balance, bool? isNetworkOn) {
    if (isNetworkOn != true) {
      CustomToast.showWarningToast(
          context: context, text: ErrorCodes.networkError.message);
      return false;
    }

    if (state == WalletInitState.processing) {
      CustomToast.showToast(
          context: context, text: t.toast.fetching_onchain_data);
      return false;
    }

    if (!_isPullToRefreshing) {
      if (balance == null || state == WalletInitState.error) {
        CustomToast.showWarningToast(
            context: context, text: t.toast.wallet_detail_refresh);
        return false;
      }
    }

    return true;
  }

  void _onTapReceiveOrSend(
      int? balance, WalletInitState state, bool? isNetworkOn,
      {String? address, String? path}) {
    if (!_checkStateAndShowToast(state, balance, isNetworkOn)) return;
    if (address != null && path != null) {
      CommonBottomSheets.showBottomSheet_90(
        context: context,
        child: ReceiveAddressBottomSheet(
          id: widget.id,
          address: address,
          derivationPath: path,
        ),
      );
    } else {
      Navigator.pushNamed(context, '/send-address',
          arguments: {'id': widget.id});
    }
  }

  void _removeFilterDropdown() {
    setState(() {});
  }

  void _toggleUnit() {
    setState(() {
      _currentUnit = _currentUnit == Unit.btc ? Unit.sats : Unit.btc;
    });
  }
}
