import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo.dart' as model;
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/body/wallet_detail_body.dart';
import 'package:coconut_wallet/widgets/overlays/custom_toast.dart';
import 'package:coconut_wallet/widgets/dropdown/utxo_filter_dropdown.dart';
import 'package:coconut_wallet/widgets/header/wallet_detail_header.dart';
import 'package:coconut_wallet/widgets/header/wallet_detail_sticky_header.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_faucet_request_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_receive_address_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/selector/wallet_detail_tab.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
  Offset _headerDropdownPosition = Offset.zero;
  bool _isHeaderDropdownVisible = false;

  final GlobalKey _stickyHeaderWidgetKey = GlobalKey();
  RenderBox? _stickyHeaderRenderBox;
  Offset _stickyHeaderDropdownPosition = Offset.zero;
  bool _stickyHeaderVisible = false;
  bool _isStickyHeaderDropdownVisible = false;

  final GlobalKey _tabWidgetKey = GlobalKey();
  late RenderBox _tabWidgetRenderBox;

  final GlobalKey _txSliverListKey = GlobalKey();

  final GlobalKey _utxoSliverListKey = GlobalKey();

  WalletDetailTabType _selectedListType = WalletDetailTabType.transaction;
  bool _isPullToRefreshing = false;
  Unit _currentUnit = Unit.btc;

  late WalletDetailViewModel _viewModel;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider4<WalletProvider, TransactionProvider,
        ConnectivityProvider, UpbitConnectModel, WalletDetailViewModel>(
      create: (_) {
        _viewModel = WalletDetailViewModel(
          widget.id,
          Provider.of<WalletProvider>(_, listen: false),
          Provider.of<TransactionProvider>(_, listen: false),
          Provider.of<UtxoTagProvider>(_, listen: false),
          Provider.of<ConnectivityProvider>(_, listen: false),
          Provider.of<UpbitConnectModel>(_, listen: false),
        );
        return _viewModel;
      },
      update: (_, walletProvider, txProvider, connectProvider, upbitModel,
          viewModel) {
        _updateFilterDropdownButtonRenderBox();
        return viewModel!..updateProvider();
      },
      child: Consumer<WalletDetailViewModel>(
        builder: (context, viewModel, child) {
          final state = viewModel.walletInitState;
          final balance = viewModel.walletListBaseItem?.balance;
          final isNetworkOn = viewModel.isNetworkOn;
          return PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, _) {
              viewModel.removeFaucetTooltip();
              _removeFilterDropdown();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque, // 빈 영역도 감지 가능
              onTap: () {
                _removeFilterDropdown(); // 모든 터치 이벤트에서 실행
              },
              child: Stack(
                children: [
                  Scaffold(
                    backgroundColor: MyColors.black,
                    appBar: CustomAppBar.build(
                      entireWidgetKey: _appBarKey,
                      faucetIconKey: _faucetIconKey,
                      backgroundColor: MyColors.black,
                      title: TextUtils.ellipsisIfLonger(
                        viewModel.walletListBaseItem!.name,
                        maxLength: 15,
                      ),
                      context: context,
                      hasRightIcon: true,
                      onFaucetIconPressed: () async {
                        _removeFilterDropdown();
                        viewModel.removeFaucetTooltip();
                        if (!_checkStateAndShowToast(
                            state, balance, isNetworkOn)) {
                          return;
                        }
                        await CommonBottomSheets.showCustomBottomSheet(
                            context: context,
                            child: FaucetRequestBottomSheet(
                              walletAddressBook: viewModel.walletAddressBook,
                              walletData: {
                                'wallet_id': viewModel.walletId,
                                'wallet_address': viewModel.walletAddress,
                                'wallet_name': viewModel.walletName,
                                'wallet_index': viewModel.receiveAddressIndex,
                              },
                              isRequesting: viewModel.isRequesting,
                              onRequest: (address, requestAmount) {
                                if (viewModel.isRequesting) return;

                                viewModel.requestTestBitcoin(
                                    address, requestAmount, (success, message) {
                                  if (success) {
                                    Navigator.pop(context);
                                    vibrateLight();
                                    Future.delayed(const Duration(seconds: 1),
                                        () {
                                      viewModel.walletProvider?.initWallet(
                                          targetId: widget.id,
                                          syncOthers: false);
                                    });
                                    CustomToast.showToast(
                                        context: context, text: message);
                                  } else {
                                    vibrateMedium();
                                    CustomToast.showWarningToast(
                                        context: context, text: message);
                                  }
                                });
                              },
                            ));
                      },
                      onTitlePressed: () async {
                        await Navigator.pushNamed(
                            context, '/wallet-info', arguments: {
                          'id': widget.id,
                          'isMultisig':
                              viewModel.walletType == WalletType.multiSignature
                        });

                        if (viewModel.isUpdatedTagList) {
                          viewModel.getUtxoListWithHoldingAddress();
                        }
                      },
                      showFaucetIcon: true,
                    ),
                    body: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: _scrollController,
                      semanticChildCount: viewModel.txList.isEmpty
                          ? 1
                          : viewModel.txList.length,
                      slivers: [
                        CupertinoSliverRefreshControl(
                          onRefresh: () async {
                            _isPullToRefreshing = true;
                            try {
                              if (!_checkStateAndShowToast(
                                  state, balance, isNetworkOn)) {
                                return;
                              }
                              viewModel.walletProvider
                                  ?.initWallet(targetId: widget.id);
                            } finally {
                              _isPullToRefreshing = false;
                            }
                          },
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
                            onPressedUnitToggle: () {
                              _toggleUnit();
                            },
                            removePopup: () {
                              _removeFilterDropdown();
                              viewModel.removeFaucetTooltip();
                            },
                            checkPrerequisites: () {
                              return _checkStateAndShowToast(
                                  state, balance, isNetworkOn);
                            },
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: WalletDetailTab(
                            key: _tabWidgetKey,
                            selectedListType: _selectedListType,
                            utxoListLength: viewModel.utxoList.length,
                            state: state,
                            isUtxoDropdownVisible:
                                _selectedListType == WalletDetailTabType.utxo &&
                                    viewModel.utxoList.isNotEmpty &&
                                    !_stickyHeaderVisible,
                            isVisibleDropdownMenu: _isHeaderDropdownVisible,
                            isPullToRefreshing: _isPullToRefreshing,
                            utxoOrderText: viewModel.selectedUtxoOrder.text,
                            onTapTransaction: () {
                              _toggleListType(WalletDetailTabType.transaction,
                                  viewModel.utxoList);
                            },
                            onTapUtxo: () {
                              _toggleListType(
                                  WalletDetailTabType.utxo, viewModel.utxoList);
                            },
                            onTapUtxoDropdown: (value) {
                              _scrollController
                                  .jumpTo(_scrollController.offset);
                              _isHeaderDropdownVisible = value;
                              setState(() {});
                            },
                          ),
                        ),
                        SliverSafeArea(
                          minimum: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: WalletDetailBody(
                            txSliverListKey: _txSliverListKey,
                            utxoSliverListKey: _utxoSliverListKey,
                            walletId: widget.id,
                            walletType: viewModel.walletType,
                            currentUnit: _currentUnit,
                            isTransaction: _isSelectedTx(),
                            isUtxoListLoadComplete:
                                viewModel.isUtxoListLoadComplete,
                            txList: viewModel.txList,
                            utxoList: viewModel.utxoList,
                            removePopup: () {
                              _removeFilterDropdown();
                              viewModel.removeFaucetTooltip();
                            },
                            popFromUtxoDetail: (resultUtxo) {
                              if (viewModel.isUpdatedTagList) {
                                viewModel.updateUtxoTagList(resultUtxo.utxoId,
                                    viewModel.selectedTagList);
                              }
                            },
                          ),
                        ),
                        // SliverToBoxAdapter(
                        //   child: SizedBox(
                        //     height: _listBottomMarginHeight(),
                        //   ),
                        // ),
                      ],
                    ),
                  ),
                  WalletDetailStickyHeader(
                    widgetKey: _stickyHeaderWidgetKey,
                    height: _appBarSize.height,
                    isVisible: _stickyHeaderVisible,
                    isVisibleDropdownMenu: _isStickyHeaderDropdownVisible,
                    currentUnit: _currentUnit,
                    balance: balance,
                    receiveAddress: viewModel.walletListBaseItem!.walletBase
                        .getReceiveAddress(),
                    walletStatus: viewModel.getInitializedWalletStatus(),
                    selectedListType: _selectedListType,
                    selectedFilter: viewModel.selectedUtxoOrder.text,
                    onTapReceive: (balance, address, path) {
                      _onTapReceiveOrSend(balance, state, isNetworkOn,
                          address: address, path: path);
                    },
                    onTapSend: (balance) {
                      _onTapReceiveOrSend(balance, state, isNetworkOn);
                    },
                    onTapDropdown: (value) {
                      _scrollController.jumpTo(_scrollController.offset);
                      _isStickyHeaderDropdownVisible = value;
                      setState(() {});
                    },
                    removePopup: () {
                      _removeFilterDropdown();
                      viewModel.removeFaucetTooltip();
                    },
                  ),
                  UtxoFilterDropdown(
                    isVisible: viewModel.utxoList.isNotEmpty &&
                            _isHeaderDropdownVisible ||
                        _isStickyHeaderDropdownVisible,
                    positionTop: _isHeaderDropdownVisible
                        ? _headerDropdownPosition.dy +
                            78 -
                            _scrollController.offset * 0.01
                        : _isStickyHeaderDropdownVisible
                            ? _stickyHeaderDropdownPosition.dy + 90
                            : 0,
                    positionRight: 16,
                    selectedFilter: viewModel.selectedUtxoOrder,
                    onSelected: (filter) {
                      setState(() {
                        _isHeaderDropdownVisible =
                            _isStickyHeaderDropdownVisible = false;
                      });
                      if (_stickyHeaderVisible) {
                        _scrollController.animateTo(_topPadding + 1,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      }
                      viewModel.updateUtxoFilter(filter);
                    },
                  ),
                  Positioned(
                    top: _faucetIconPosition.dy + _faucetIconSize.height - 10,
                    right: MediaQuery.of(context).size.width -
                        _faucetIconPosition.dx -
                        _faucetIconSize.width +
                        5,
                    child: CoconutToolTip(
                      tooltipType: CoconutTooltipType.placement,
                      backgroundColor: MyColors.skybule,
                      animateOnBuild: true,
                      isBubbleClipperSideLeft: false,
                      isPlacementTooltipVisible: viewModel.faucetTooltipVisible,
                      richText: RichText(
                        text: TextSpan(
                          text: t.tooltip.faucet,
                          style: CoconutTypography.body3_12
                              .setColor(CoconutColors.black),
                        ),
                      ),
                      width: MediaQuery.of(context).size.width,
                      onTapRemove: viewModel.removeFaucetTooltip,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
      final positionedTopWidgetRenderBox = _stickyHeaderWidgetKey.currentContext
          ?.findRenderObject() as RenderBox;

      _appBarSize = appBarRenderBox.size;
      final topSelectorWidgetSize = headerWidgetRenderBox.size;
      final topHeaderWidgetSize = _tabWidgetRenderBox.size;
      final positionedTopWidgetSize =
          positionedTopWidgetRenderBox.size; // 거래내역 - UTXO 리스트 위젯 영역

      setState(() {
        _topPadding = topSelectorWidgetSize.height +
            topHeaderWidgetSize.height -
            positionedTopWidgetSize.height;
      });

      _scrollController.addListener(() {
        if (_isHeaderDropdownVisible || _isStickyHeaderDropdownVisible) {
          _removeFilterDropdown();
        }

        if (_scrollController.offset > _topPadding) {
          if (!_isPullToRefreshing) {
            setState(() {
              _stickyHeaderVisible = true;
              _isHeaderDropdownVisible = false;
            });
            if (_stickyHeaderRenderBox == null &&
                _viewModel.utxoList.isNotEmpty == true &&
                _selectedListType == WalletDetailTabType.utxo) {
              _stickyHeaderRenderBox = _stickyHeaderWidgetKey.currentContext
                  ?.findRenderObject() as RenderBox;
              _stickyHeaderDropdownPosition =
                  _stickyHeaderRenderBox!.localToGlobal(Offset.zero);
            }
          }
        } else {
          if (!_isPullToRefreshing) {
            setState(() {
              _stickyHeaderVisible = false;
              _isStickyHeaderDropdownVisible = false;
            });
          }
        }
      });

      final faucetRenderBox =
          _faucetIconKey.currentContext?.findRenderObject() as RenderBox;
      _faucetIconPosition = faucetRenderBox.localToGlobal(Offset.zero);
      _faucetIconSize = faucetRenderBox.size;
    });
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

  bool _isSelectedTx() {
    return _selectedListType == WalletDetailTabType.transaction;
  }

  void _onTapReceiveOrSend(
      int? balance, WalletInitState state, bool? isNetworkOn,
      {String? address, String? path}) {
    if (!_checkStateAndShowToast(state, balance, isNetworkOn)) return;
    if (address != null && path != null) {
      CommonBottomSheets.showCustomBottomSheet(
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
    setState(() {
      _isHeaderDropdownVisible = false;
      _isStickyHeaderDropdownVisible = false;
    });
  }

  void _toggleListType(
      WalletDetailTabType type, List<model.UTXO> utxoList) async {
    if (type == WalletDetailTabType.transaction) {
      setState(() {
        _selectedListType = WalletDetailTabType.transaction;
        _isHeaderDropdownVisible = false;
        _isStickyHeaderDropdownVisible = false;
      });
    } else {
      setState(() {
        _selectedListType = WalletDetailTabType.utxo;
      });
      if (utxoList.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 200));
        _tabWidgetRenderBox =
            _tabWidgetKey.currentContext?.findRenderObject() as RenderBox;

        _headerDropdownPosition =
            _tabWidgetRenderBox.localToGlobal(Offset.zero);
      }
    }
  }

  void _toggleUnit() {
    setState(() {
      _currentUnit = _currentUnit == Unit.btc ? Unit.sats : Unit.btc;
    });
  }

  void _updateFilterDropdownButtonRenderBox() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_tabWidgetKey.currentContext?.findRenderObject() != null) {
        _tabWidgetRenderBox =
            _tabWidgetKey.currentContext!.findRenderObject() as RenderBox;
        _headerDropdownPosition =
            _tabWidgetRenderBox.localToGlobal(Offset.zero);
      }
    });
  }
}
