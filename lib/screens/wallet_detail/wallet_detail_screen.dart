import 'dart:async';

import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_detail_view_model.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/utils/derivation_path_util.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/button/balance_and_buttons.dart';
import 'package:coconut_wallet/widgets/dropdown/utxo_filter_dropdown.dart';
import 'package:coconut_wallet/widgets/header/wallet_detail_sticky_header.dart';
import 'package:coconut_wallet/widgets/item/transaction_row_item.dart';
import 'package:coconut_wallet/widgets/selector/wallet_detail_tab.dart';
import 'package:coconut_wallet/widgets/tooltip/faucet_tooltip.dart';
import 'package:coconut_wallet/widgets/utxo_item_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:coconut_wallet/model/app/error/app_error.dart';
import 'package:coconut_wallet/model/app/utxo/utxo.dart' as model;
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/widgets/overlays/faucet_request_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/overlays/receive_address_bottom_sheet.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/button/small_action_button.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:provider/provider.dart';

class WalletDetailScreen extends StatefulWidget {
  const WalletDetailScreen({super.key, required this.id, this.syncResult});

  final int id;
  final WalletSyncResult? syncResult;

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

enum Unit { btc, sats }

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  static const SizedBox gapOfRowItems = SizedBox(
    height: 8,
  );
  final GlobalKey _faucetIconKey = GlobalKey();
  final GlobalKey _appBarKey = GlobalKey();
  final GlobalKey _topToggleButtonKey = GlobalKey();
  final GlobalKey _topSelectorWidgetKey = GlobalKey();
  final GlobalKey _topHeaderWidgetKey = GlobalKey();
  final GlobalKey _positionedTopWidgetKey = GlobalKey();
  final GlobalKey _filterDropdownButtonKey = GlobalKey();
  final GlobalKey _scrolledFilterDropdownButtonKey = GlobalKey();
  final GlobalKey _txSliverListKey = GlobalKey();
  final GlobalKey _utxoSliverListKey = GlobalKey();
  late RenderBox _faucetRenderBox;
  late RenderBox _appBarRenderBox;
  late RenderBox _topToggleButtonRenderBox;
  late RenderBox _topSelectorWidgetRenderBox;
  late RenderBox _topHeaderWidgetRenderBox;
  late RenderBox _positionedTopWidgetRenderBox;
  late RenderBox _filterDropdownButtonRenderBox;

  RenderBox? _scrolledFilterDropdownButtonRenderBox;
  Size _appBarSize = const Size(0, 0);
  Size _topToggleButtonSize = const Size(0, 0); // BTC sats 버튼
  Size _topSelectorWidgetSize = const Size(0, 0); // 원화 영역
  Size _topHeaderWidgetSize = const Size(0, 0); // 거래내역 - UTXO 리스트 위젯 영역
  Size _positionedTopWidgetSize = const Size(0, 0); // 거래내역 - UTXO 리스트 위젯 영역
  Size _filterDropdownButtonSize = const Size(0, 0); // 필터 버튼(확장형)
  Size _scrolledFilterDropdownButtonSize = const Size(0, 0); // 필터 버튼(축소형))
  Size _txSliverListSize = const Size(0, 0); // 거래내역 리스트 사이즈
  Size _utxoSliverListSize = const Size(0, 0); // utxo 리스트 사이즈

  Offset _filterDropdownButtonPosition = Offset.zero;
  Offset _scrolledFilterDropdownButtonPosition = Offset.zero;

  Offset _faucetIconPosition = Offset.zero;
  Size _faucetIconSize = const Size(0, 0);

  double topPadding = 0;

  SelectedListType _selectedListType = SelectedListType.transaction;

  bool _positionedTopWidgetVisible = false; // 스크롤시 상단에 붙어있는 위젯
  bool _isFilterDropdownVisible = false; // 필터 드롭다운(확장형)
  bool _isScrolledFilterDropdownVisible = false; // 필터 드롭다운(축소형)

  bool _isPullToRefreshing = false;

  Unit _current = Unit.btc;

  WalletDetailViewModel? viewModel;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appBarRenderBox =
          _appBarKey.currentContext?.findRenderObject() as RenderBox;
      _topToggleButtonRenderBox =
          _topToggleButtonKey.currentContext?.findRenderObject() as RenderBox;
      _topSelectorWidgetRenderBox =
          _topSelectorWidgetKey.currentContext?.findRenderObject() as RenderBox;
      _topHeaderWidgetRenderBox =
          _topHeaderWidgetKey.currentContext?.findRenderObject() as RenderBox;
      _positionedTopWidgetRenderBox = _positionedTopWidgetKey.currentContext
          ?.findRenderObject() as RenderBox;

      // _filterDropdownButtonKey가 할당된 오브젝트가 생성되기 전이기 때문에 기본값으로 초기화 합니다.
      _filterDropdownButtonRenderBox = RenderConstrainedBox(
          additionalConstraints:
              const BoxConstraints.tightFor(width: 0, height: 0));

      _appBarSize = _appBarRenderBox.size;
      _topToggleButtonSize = _topToggleButtonRenderBox.size;
      _topSelectorWidgetSize = _topSelectorWidgetRenderBox.size;
      _topHeaderWidgetSize = _topHeaderWidgetRenderBox.size;
      _positionedTopWidgetSize = _positionedTopWidgetRenderBox.size;

      setState(() {
        topPadding = _topToggleButtonSize.height +
            _topSelectorWidgetSize.height +
            _topHeaderWidgetSize.height -
            _positionedTopWidgetSize.height;
      });

      if (viewModel?.txList.isNotEmpty == true) {
        final RenderBox txSliverListRenderBox =
            _txSliverListKey.currentContext?.findRenderObject() as RenderBox;
        _txSliverListSize = txSliverListRenderBox.size;
      }

      _scrollController.addListener(() {
        if (_isFilterDropdownVisible || _isScrolledFilterDropdownVisible) {
          _removeFilterDropdown();
        }

        if (_scrollController.offset > topPadding) {
          if (!_isPullToRefreshing) {
            setState(() {
              _positionedTopWidgetVisible = true;
              _isFilterDropdownVisible = false;
            });
            if (_scrolledFilterDropdownButtonRenderBox == null &&
                viewModel?.utxoList.isNotEmpty == true &&
                _selectedListType == SelectedListType.utxo) {
              _scrolledFilterDropdownButtonRenderBox =
                  _scrolledFilterDropdownButtonKey.currentContext
                      ?.findRenderObject() as RenderBox;
              _scrolledFilterDropdownButtonPosition =
                  _scrolledFilterDropdownButtonRenderBox!
                      .localToGlobal(Offset.zero);
              _scrolledFilterDropdownButtonSize =
                  _scrolledFilterDropdownButtonRenderBox!.size;
            }
          }
        } else {
          if (!_isPullToRefreshing) {
            setState(() {
              _positionedTopWidgetVisible = false;
              _isScrolledFilterDropdownVisible = false;
            });
          }
        }
      });

      _faucetRenderBox =
          _faucetIconKey.currentContext?.findRenderObject() as RenderBox;
      _faucetIconPosition = _faucetRenderBox.localToGlobal(Offset.zero);
      _faucetIconSize = _faucetRenderBox.size;

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
      if (_filterDropdownButtonKey.currentContext?.findRenderObject() != null) {
        _filterDropdownButtonRenderBox =
            _filterDropdownButtonKey.currentContext!.findRenderObject()
                as RenderBox;

        _filterDropdownButtonSize = _filterDropdownButtonRenderBox.size;
        _filterDropdownButtonPosition =
            _filterDropdownButtonRenderBox.localToGlobal(Offset.zero);
      }
    });
  }

  void _toggleUnit() {
    setState(() {
      _current = _current == Unit.btc ? Unit.sats : Unit.btc;
    });
  }

  void _toggleListType(SelectedListType type, List<model.UTXO> utxoList) async {
    if (type == SelectedListType.transaction) {
      setState(() {
        _selectedListType = SelectedListType.transaction;
        _isFilterDropdownVisible = false;
        _isScrolledFilterDropdownVisible = false;
      });
    } else {
      setState(() {
        _selectedListType = SelectedListType.utxo;
      });
      if (utxoList.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 200));
        _filterDropdownButtonRenderBox = _filterDropdownButtonKey.currentContext
            ?.findRenderObject() as RenderBox;
        _filterDropdownButtonSize = _filterDropdownButtonRenderBox.size;

        _filterDropdownButtonPosition =
            _filterDropdownButtonRenderBox.localToGlobal(Offset.zero);
        final RenderBox utxoSliverListRenderBox =
            _utxoSliverListKey.currentContext?.findRenderObject() as RenderBox;
        _utxoSliverListSize = utxoSliverListRenderBox.size;
      }
    }
  }

  void _removeFilterDropdown() {
    setState(() {
      _isFilterDropdownVisible = false;
      _isScrolledFilterDropdownVisible = false;
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

    // 에러체크
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
                        child: Padding(
                          key: _topToggleButtonKey,
                          padding: const EdgeInsets.only(top: 20.0),
                          child: Center(
                            child: SmallActionButton(
                              onPressed: () {
                                _toggleUnit();
                              },
                              height: 32,
                              width: 64,
                              child: Text(
                                _current == Unit.btc ? 'BTC' : 'sats',
                                style: Styles.label.merge(
                                  TextStyle(
                                      fontFamily:
                                          CustomFonts.number.getFontFamily,
                                      color: MyColors.white),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Selector<UpbitConnectModel, int?>(
                        selector: (context, model) => model.bitcoinPriceKrw,
                        builder: (context, bitcoinPriceKrw, child) {
                          return SliverToBoxAdapter(
                            child: BalanceAndButtons(
                              key: _topSelectorWidgetKey,
                              walletId: widget.id,
                              address: viewModel.walletAddress,
                              derivationPath: viewModel.derivationPath,
                              balance: viewModel.walletListBaseItem.balance,
                              currentUnit: _current,
                              btcPriceInKrw: bitcoinPriceKrw,
                              checkPrerequisites: () {
                                return _checkStateAndShowToast() &&
                                    _checkBalanceIsNotNullAndShowToast(
                                        viewModel.walletListBaseItem.balance);
                              },
                            ),
                          );
                        },
                      ),
                      SliverToBoxAdapter(
                        child: Column(
                          key: _topHeaderWidgetKey,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 16.0,
                                  right: 16.0,
                                  bottom: 12.0,
                                  top: 30),
                              child: Selector<AppStateModel, WalletInitState>(
                                  selector: (_, selectorModel) =>
                                      selectorModel.walletInitState,
                                  builder: (context, state, child) {
                                    return Column(
                                      children: [
                                        Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              WalletDetailTab(
                                                selectedListType:
                                                    _selectedListType,
                                                utxoListLength:
                                                    viewModel.utxoList.length,
                                                onTapTransaction: () {
                                                  _toggleListType(
                                                      SelectedListType
                                                          .transaction,
                                                      viewModel.utxoList);
                                                },
                                                onTapUtxo: () {
                                                  _toggleListType(
                                                      SelectedListType.utxo,
                                                      viewModel.utxoList);
                                                },
                                              ),
                                              Visibility(
                                                visible: !_isPullToRefreshing &&
                                                    state ==
                                                        WalletInitState
                                                            .processing,
                                                child: Row(
                                                  children: [
                                                    const Text(
                                                      '업데이트 중',
                                                      style: TextStyle(
                                                        fontFamily:
                                                            'Pretendard',
                                                        color: MyColors.primary,
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontStyle:
                                                            FontStyle.normal,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    LottieBuilder.asset(
                                                      'assets/files/status_loading.json',
                                                      width: 20,
                                                      height: 20,
                                                    ),
                                                  ],
                                                ),
                                              )
                                            ]),
                                        if (_selectedListType ==
                                                SelectedListType.utxo &&
                                            viewModel.utxoList.isNotEmpty) ...{
                                          const SizedBox(height: 8),
                                          IgnorePointer(
                                            ignoring:
                                                _positionedTopWidgetVisible,
                                            child: Visibility(
                                              maintainSize: true,
                                              maintainAnimation: true,
                                              maintainState: true,
                                              maintainSemantics: false,
                                              maintainInteractivity: false,
                                              visible:
                                                  !_positionedTopWidgetVisible,
                                              child: CupertinoButton(
                                                onPressed: () {
                                                  setState(
                                                    () {
                                                      _scrollController.jumpTo(
                                                          _scrollController
                                                              .offset);
                                                      if (_isFilterDropdownVisible ||
                                                          _isScrolledFilterDropdownVisible) {
                                                        _isFilterDropdownVisible =
                                                            false;
                                                      } else {
                                                        _isFilterDropdownVisible =
                                                            true;
                                                      }
                                                    },
                                                  );
                                                },
                                                minSize: 0,
                                                padding: const EdgeInsets.only(
                                                    left: 8),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.end,
                                                  children: [
                                                    Text(
                                                      key:
                                                          _filterDropdownButtonKey,
                                                      viewModel
                                                          .selectedUtxoFilter
                                                          .text,
                                                      style:
                                                          Styles.caption2.merge(
                                                        const TextStyle(
                                                          color: MyColors.white,
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: 4,
                                                    ),
                                                    SvgPicture.asset(
                                                      'assets/svg/arrow-down.svg',
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        },
                                      ],
                                    );
                                  }),
                            ),
                          ],
                        ),
                      ),
                      SliverSafeArea(
                        minimum: const EdgeInsets.symmetric(horizontal: 16),
                        sliver:
                            _selectedListType == SelectedListType.transaction
                                ? _transactionListWidget(viewModel)
                                : _utxoListWidget(viewModel),
                      ),
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height: _listBottomMarginHeight(viewModel),
                        ),
                      ),
                    ],
                  ),
                ),
                WalletDetailStickyHeader(
                  wallet: viewModel.walletListBaseItem,
                  widgetKey: _positionedTopWidgetKey,
                  dropdownKey: _scrolledFilterDropdownButtonKey,
                  height: _appBarSize.height,
                  isVisible: _positionedTopWidgetVisible,
                  currentUnit: _current,
                  selectedListType: _selectedListType,
                  selectedFilter: viewModel.selectedUtxoFilter.text,
                  onTapReceive: (balance, address, path) {
                    _onTapReceiveOrSend(balance, address: address, path: path);
                  },
                  onTapSend: (balance) {
                    _onTapReceiveOrSend(balance);
                  },
                  onTapDropdown: () {
                    setState(() {
                      _scrollController.jumpTo(_scrollController.offset);
                      if (_isFilterDropdownVisible ||
                          _isScrolledFilterDropdownVisible) {
                        _isScrolledFilterDropdownVisible = false;
                      } else {
                        _isScrolledFilterDropdownVisible = true;
                      }
                    });
                  },
                ),
                FaucetTooltip(
                  text: '테스트용 비트코인으로 마음껏 테스트 해보세요',
                  isVisible: viewModel.faucetTooltipVisible,
                  width: MediaQuery.of(context).size.width,
                  iconPosition: _faucetIconPosition,
                  iconSize: _faucetIconSize,
                  onTapRemove: viewModel.removeFaucetTooltip,
                ),
                _utxoFilterDropDown(viewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _transactionListWidget(WalletDetailViewModel viewModel) {
    return viewModel.txList.isNotEmpty
        ? SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, index) {
                return Column(
                  key: index == 0 ? _txSliverListKey : null,
                  children: [
                    TransactionRowItem(
                      tx: viewModel.txList[index],
                      currentUnit: _current,
                      id: widget.id,
                    ),
                    gapOfRowItems,
                    if (index == viewModel.txList.length - 1)
                      const SizedBox(
                        height: 80,
                      ),
                  ],
                );
              },
              childCount: viewModel.txList.length,
            ),
          )
        : const SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.only(top: 100),
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(
                  '거래 내역이 없어요',
                  style: Styles.body1,
                ),
              ),
            ),
          );
  }

  Widget _utxoListWidget(WalletDetailViewModel viewModel) {
    return viewModel.utxoList.isNotEmpty
        ? SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index.isOdd) {
                  // 분리자
                  return gapOfRowItems;
                }

                // 실제 아이템
                final itemIndex = index ~/ 2; // 실제 아이템 인덱스
                return ShrinkAnimationButton(
                  key: index == 0 ? _utxoSliverListKey : null,
                  defaultColor: Colors.transparent,
                  borderRadius: 20,
                  onPressed: () async {
                    await Navigator.pushNamed(
                      context,
                      '/utxo-detail',
                      arguments: {
                        'utxo': viewModel.utxoList[itemIndex],
                        'id': widget.id,
                        'isChange': DerivationPathUtil.getChangeElement(
                                viewModel.walletType,
                                viewModel.utxoList[itemIndex].derivationPath) ==
                            1,
                      },
                    );

                    if (viewModel.appStateModel?.isUpdatedSelectedTagList ==
                        true) {
                      viewModel.appStateModel
                          ?.setIsUpdateSelectedTagList(false);
                      for (var utxo in viewModel.utxoList) {
                        if (utxo.utxoId ==
                            viewModel.utxoList[itemIndex].utxoId) {
                          utxo.tags?.clear();
                          utxo.tags?.addAll(
                              viewModel.appStateModel?.selectedTagList ?? []);
                          setState(() {});
                          break;
                        }
                      }
                    }
                  },
                  child: UTXOItemCard(
                    utxo: viewModel.utxoList[itemIndex],
                  ),
                );
              },
              childCount: viewModel.utxoList.length * 2 - 1, // 항목 개수 지정
            ),
          )
        : SliverFillRemaining(
            fillOverscroll: false,
            hasScrollBody: false,
            child: Padding(
                padding: const EdgeInsets.only(top: 100),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    viewModel.isUtxoListLoadComplete
                        ? 'UTXO가 없어요'
                        : 'UTXO를 확인하는 중이에요',
                    style: Styles.body1,
                    textAlign: TextAlign.center,
                  ),
                )),
          );
  }

  double _listBottomMarginHeight(WalletDetailViewModel viewModel) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final availableHeight = screenHeight - topPadding;
    if (_selectedListType == SelectedListType.transaction &&
        viewModel.txList.isNotEmpty) {
      if (_positionedTopWidgetVisible) return 0;
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

    if (_selectedListType == SelectedListType.utxo &&
        viewModel.utxoList.isNotEmpty) {
      if (_positionedTopWidgetVisible) return 0;
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

  Widget _utxoFilterDropDown(WalletDetailViewModel viewModel) {
    return _isFilterDropdownVisible && viewModel.utxoList.isNotEmpty
        ? Positioned(
            top: _filterDropdownButtonPosition.dy +
                _filterDropdownButtonSize.height +
                8 -
                _scrollController.offset * 0.01,
            right: 16,
            child: UtxoFilterDropdown(
              selectedFilter: viewModel.selectedUtxoFilter,
              onSelected: (filter) {
                setState(() {
                  _isFilterDropdownVisible =
                      _isScrolledFilterDropdownVisible = false;
                });
                viewModel.updateUtxoFilter(filter);
              },
            ),
          )
        : _isScrolledFilterDropdownVisible && viewModel.utxoList.isNotEmpty
            ? Positioned(
                top: (_scrolledFilterDropdownButtonPosition.dy +
                    _scrolledFilterDropdownButtonSize.height +
                    8),
                right: 16,
                child: UtxoFilterDropdown(
                  selectedFilter: viewModel.selectedUtxoFilter,
                  onSelected: (filter) {
                    setState(() {
                      _isFilterDropdownVisible =
                          _isScrolledFilterDropdownVisible = false;
                    });
                    viewModel.updateUtxoFilter(filter);
                  },
                ),
              )
            : Container();
  }
}
