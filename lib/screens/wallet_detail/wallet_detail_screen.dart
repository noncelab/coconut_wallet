import 'dart:async';

import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_detail_view_model.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/header/wallet_detail_header.dart';
import 'package:coconut_wallet/widgets/dropdown/utxo_filter_dropdown.dart';
import 'package:coconut_wallet/widgets/header/wallet_detail_sticky_header.dart';
import 'package:coconut_wallet/widgets/selector/wallet_detail_tab.dart';
import 'package:coconut_wallet/widgets/tooltip/faucet_tooltip.dart';
import 'package:coconut_wallet/widgets/body/wallet_detail_body.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/model/app/error/app_error.dart';
import 'package:coconut_wallet/model/app/utxo/utxo.dart' as model;
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/widgets/overlays/faucet_request_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/overlays/receive_address_bottom_sheet.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:provider/provider.dart';

enum Unit { btc, sats }

class WalletDetailScreen extends StatefulWidget {
  const WalletDetailScreen({super.key, required this.id, this.syncResult});

  final int id;
  final WalletSyncResult? syncResult;

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
  Size _txSliverListSize = const Size(0, 0);

  final GlobalKey _utxoSliverListKey = GlobalKey();
  Size _utxoSliverListSize = const Size(0, 0);

  WalletDetailTabType _selectedListType = WalletDetailTabType.transaction;
  bool _isPullToRefreshing = false;
  Unit _currentUnit = Unit.btc;

  WalletDetailViewModel? viewModel;

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

      if (viewModel?.txList.isNotEmpty == true) {
        final RenderBox txSliverListRenderBox =
            _txSliverListKey.currentContext?.findRenderObject() as RenderBox;
        _txSliverListSize = txSliverListRenderBox.size;
      }

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
                viewModel?.utxoList.isNotEmpty == true &&
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

      if (widget.syncResult != null) {
        String message = "";
        switch (widget.syncResult) {
          case WalletSyncResult.newWalletAdded:
            message = "새로운 지갑을 추가했어요";
          case WalletSyncResult.existingWalletUpdated:
            message = "지갑 정보가 업데이트 됐어요";
          case WalletSyncResult.existingWalletNoUpdate:
            message = "이미 추가한 지갑이에요";
          default:
        }

        if (message.isNotEmpty) {
          CustomToast.showToast(context: context, text: message);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  void _toggleUnit() {
    setState(() {
      _currentUnit = _currentUnit == Unit.btc ? Unit.sats : Unit.btc;
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
        final RenderBox utxoSliverListRenderBox =
            _utxoSliverListKey.currentContext?.findRenderObject() as RenderBox;
        _utxoSliverListSize = utxoSliverListRenderBox.size;
      }
    }
  }

  void _removeFilterDropdown() {
    setState(() {
      _isHeaderDropdownVisible = false;
      _isStickyHeaderDropdownVisible = false;
    });
  }

  void _onTapReceiveOrSend(int? balance, {String? address, String? path}) {
    if (!_checkStateAndShowToast()) return;
    if (!_checkBalanceIsNotNullAndShowToast(balance)) return;
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

  bool _checkStateAndShowToast() {
    var appState = Provider.of<AppStateModel>(context, listen: false);
    if (appState.isNetworkOn == false) {
      CustomToast.showWarningToast(
          context: context, text: ErrorCodes.networkError.message);
      return false;
    }

    if (appState.walletInitState == WalletInitState.processing) {
      CustomToast.showToast(
          context: context, text: "최신 데이터를 가져오는 중입니다. 잠시만 기다려주세요.");
      return false;
    }

    return true;
  }

  bool _checkBalanceIsNotNullAndShowToast(int? balance) {
    if (balance == null) {
      CustomToast.showToast(
          context: context, text: "화면을 아래로 당겨 최신 데이터를 가져와 주세요.");
      return false;
    }
    return true;
  }

  double _listBottomMarginHeight(WalletDetailViewModel viewModel) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final availableHeight = screenHeight - _topPadding;
    if (_selectedListType == WalletDetailTabType.transaction &&
        viewModel.txList.isNotEmpty) {
      if (_stickyHeaderVisible) return 0;
      final totalHeight =
          _txSliverListSize.height * viewModel.txList.length + 80;
      if (totalHeight > availableHeight) return 0;
      final remainingHeight = availableHeight -
          totalHeight -
          _appBarSize.height -
          kToolbarHeight +
          10;
      if (remainingHeight < 0) return 0;
      return 300;
    }

    if (_selectedListType == WalletDetailTabType.utxo &&
        viewModel.utxoList.isNotEmpty) {
      if (_stickyHeaderVisible) return 0;
      final totalHeight =
          _utxoSliverListSize.height * viewModel.utxoList.length +
              (12 * (viewModel.utxoList.length - 1));
      if (totalHeight > availableHeight) return 0;
      final remainingHeight = availableHeight -
          totalHeight -
          _appBarSize.height -
          kToolbarHeight +
          10;
      if (remainingHeight < 0) return 0;
      return 300;
    }
    return 0;
  }

  bool _isSelectedTx() {
    return _selectedListType == WalletDetailTabType.transaction;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider<AppStateModel, WalletDetailViewModel>(
      create: (_) => WalletDetailViewModel(widget.id),
      update: (_, appStateModel, viewModel) {
        _updateFilterDropdownButtonRenderBox();
        return viewModel!..appStateModelListener(appStateModel);
      },
      child: Consumer<WalletDetailViewModel>(
        builder: (context, viewModel, child) {
          if (this.viewModel == null) {
            this.viewModel = viewModel;
          }

          return PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, _) {
              viewModel.removeFaucetTooltip();
              _removeFilterDropdown();
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
                      viewModel.walletListBaseItem.name,
                      maxLength: 15,
                    ),
                    context: context,
                    hasRightIcon: true,
                    onFaucetIconPressed: () async {
                      viewModel.removeFaucetTooltip();
                      if (!_checkStateAndShowToast()) return;
                      if (!_checkBalanceIsNotNullAndShowToast(
                          viewModel.walletListBaseItem.balance)) return;
                      await CommonBottomSheets.showBottomSheet_50(
                          context: context,
                          child: FaucetRequestBottomSheet(
                            walletAddressBook: viewModel.walletAddressBook,
                            walletData: {
                              'wallet_address': viewModel.walletAddress,
                              'wallet_name': viewModel.walletName,
                              'wallet_index': viewModel.receiveAddressIndex,
                              'wallet_request_amount': viewModel.requestAmount,
                            },
                            isFaucetRequestLimitExceeded:
                                viewModel.isFaucetRequestLimitExceeded,
                            isRequesting: viewModel.isRequesting,
                            onRequest: (address) {
                              if (viewModel.isRequesting) return;

                              viewModel.requestTestBitcoin(address,
                                  (success, message) {
                                if (success) {
                                  Navigator.pop(context);
                                  vibrateLight();
                                  Future.delayed(const Duration(seconds: 1),
                                      () {
                                    viewModel.appStateModel?.initWallet(
                                        targetId: widget.id, syncOthers: false);
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
                      if (viewModel.walletType == WalletType.multiSignature) {
                        await Navigator.pushNamed(
                            context, '/wallet-multisig-info',
                            arguments: {'id': widget.id});
                      } else {
                        await Navigator.pushNamed(
                            context, '/wallet-singlesig-info',
                            arguments: {'id': widget.id});
                      }

                      if (viewModel.appStateModel?.isUpdatedSelectedTagList ==
                          true) {
                        viewModel.appStateModel
                            ?.setIsUpdateSelectedTagList(false);
                        viewModel.getUtxoListWithHoldingAddress();
                      }
                    },
                    showFaucetIcon: true,
                  ),
                  body: CustomScrollView(
                    controller: _scrollController,
                    semanticChildCount:
                        viewModel.txList.isEmpty ? 1 : viewModel.txList.length,
                    slivers: [
                      CupertinoSliverRefreshControl(
                        onRefresh: () async {
                          _isPullToRefreshing = true;
                          try {
                            if (!_checkStateAndShowToast()) {
                              return;
                            }
                            viewModel.appStateModel
                                ?.initWallet(targetId: widget.id);
                          } finally {
                            _isPullToRefreshing = false;
                          }
                        },
                      ),
                      SliverToBoxAdapter(
                        child: Selector<UpbitConnectModel, int?>(
                          selector: (context, model) => model.bitcoinPriceKrw,
                          builder: (context, bitcoinPriceKrw, child) {
                            return WalletDetailHeader(
                              key: _headerWidgetKey,
                              walletId: widget.id,
                              address: viewModel.walletAddress,
                              derivationPath: viewModel.derivationPath,
                              balance: viewModel.walletListBaseItem.balance,
                              currentUnit: _currentUnit,
                              btcPriceInKrw: bitcoinPriceKrw,
                              onPressedUnitToggle: () {
                                _toggleUnit();
                              },
                              checkPrerequisites: () {
                                return _checkStateAndShowToast() &&
                                    _checkBalanceIsNotNullAndShowToast(
                                        viewModel.walletListBaseItem.balance);
                              },
                            );
                          },
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: Selector<AppStateModel, WalletInitState>(
                          selector: (_, selectorModel) =>
                              selectorModel.walletInitState,
                          builder: (context, state, child) {
                            return WalletDetailTab(
                              key: _tabWidgetKey,
                              selectedListType: _selectedListType,
                              utxoListLength: viewModel.utxoList.length,
                              isUpdateProgress: !_isPullToRefreshing &&
                                  state == WalletInitState.processing,
                              isUtxoDropdownVisible: _selectedListType ==
                                      WalletDetailTabType.utxo &&
                                  viewModel.utxoList.isNotEmpty &&
                                  !_stickyHeaderVisible,
                              utxoOrderText: viewModel.selectedUtxoOrder.text,
                              onTapTransaction: () {
                                _toggleListType(WalletDetailTabType.transaction,
                                    viewModel.utxoList);
                              },
                              onTapUtxo: () {
                                _toggleListType(WalletDetailTabType.utxo,
                                    viewModel.utxoList);
                              },
                              onTapUtxoDropdown: () {
                                _scrollController
                                    .jumpTo(_scrollController.offset);
                                if (_isHeaderDropdownVisible ||
                                    _isStickyHeaderDropdownVisible) {
                                  _isHeaderDropdownVisible = false;
                                } else {
                                  _isHeaderDropdownVisible = true;
                                }
                                setState(() {});
                              },
                            );
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
                          popFromUtxoDetail: (resultUtxo) {
                            if (viewModel
                                    .appStateModel?.isUpdatedSelectedTagList ==
                                true) {
                              viewModel.appStateModel
                                  ?.setIsUpdateSelectedTagList(false);
                              for (var utxo in viewModel.utxoList) {
                                if (utxo.utxoId == resultUtxo.utxoId) {
                                  utxo.tags?.clear();
                                  utxo.tags?.addAll(viewModel
                                          .appStateModel?.selectedTagList ??
                                      []);
                                  setState(() {});
                                  break;
                                }
                              }
                            }
                          },
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: _listBottomMarginHeight(viewModel),
                        ),
                      ),
                    ],
                  ),
                ),
                FaucetTooltip(
                  text: '테스트용 비트코인으로 마음껏 테스트 해보세요',
                  isVisible: viewModel.faucetTooltipVisible,
                  width: MediaQuery.of(context).size.width,
                  iconPosition: _faucetIconPosition,
                  iconSize: _faucetIconSize,
                  onTapRemove: viewModel.removeFaucetTooltip,
                ),
                WalletDetailStickyHeader(
                  wallet: viewModel.walletListBaseItem,
                  widgetKey: _stickyHeaderWidgetKey,
                  height: _appBarSize.height,
                  isVisible: _stickyHeaderVisible,
                  currentUnit: _currentUnit,
                  selectedListType: _selectedListType,
                  selectedFilter: viewModel.selectedUtxoOrder.text,
                  onTapReceive: (balance, address, path) {
                    _onTapReceiveOrSend(balance, address: address, path: path);
                  },
                  onTapSend: (balance) {
                    _onTapReceiveOrSend(balance);
                  },
                  onTapDropdown: () {
                    setState(() {
                      _scrollController.jumpTo(_scrollController.offset);
                      if (_isHeaderDropdownVisible ||
                          _isStickyHeaderDropdownVisible) {
                        _isStickyHeaderDropdownVisible = false;
                      } else {
                        _isStickyHeaderDropdownVisible = true;
                      }
                    });
                  },
                ),
                UtxoFilterDropdown(
                  isVisible: viewModel.utxoList.isNotEmpty &&
                          _isHeaderDropdownVisible ||
                      _isStickyHeaderDropdownVisible,
                  positionTop: _isHeaderDropdownVisible
                      ? _headerDropdownPosition.dy +
                          80 -
                          _scrollController.offset * 0.01
                      : _isStickyHeaderDropdownVisible
                          ? _stickyHeaderDropdownPosition.dy + 92
                          : 0,
                  selectedFilter: viewModel.selectedUtxoOrder,
                  onSelected: (filter) {
                    setState(() {
                      _isHeaderDropdownVisible =
                          _isStickyHeaderDropdownVisible = false;
                    });
                    viewModel.updateUtxoFilter(filter);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
