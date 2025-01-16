import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_detail_view_model.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/utils/derivation_path_util.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/button/balance_and_buttons.dart';
import 'package:coconut_wallet/widgets/custom_dropdown.dart';
import 'package:coconut_wallet/widgets/item/transaction_row_item.dart';
import 'package:coconut_wallet/widgets/utxo_item_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:coconut_wallet/model/app/error/app_error.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/widgets/overlays/faucet_request_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/overlays/receive_address_bottom_sheet.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
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

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  WalletDetailViewModel? viewModel;
  final ScrollController _scrollController = ScrollController();

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

  // TODO: 리뷰 완료 후 삭제
  // late RenderBox _faucetRenderBox;
  // late RenderBox _appBarRenderBox;
  // late RenderBox _topToggleButtonRenderBox;
  // late RenderBox _topSelectorWidgetRenderBox;
  // late RenderBox _topHeaderWidgetRenderBox;
  // late RenderBox _positionedTopWidgetRenderBox;
  //late RenderBox _filterDropdownButtonRenderBox;
  // RenderBox? _scrolledFilterDropdownButtonRenderBox;
  // Size _appBarSize = const Size(0, 0);
  // Size _topToggleButtonSize = const Size(0, 0); // BTC sats 버튼
  // Size _topSelectorWidgetSize = const Size(0, 0); // 원화 영역
  // Size _topHeaderWidgetSize = const Size(0, 0); // 거래내역 - UTXO 리스트 위젯 영역
  // Size _positionedTopWidgetSize = const Size(0, 0); // 거래내역 - UTXO 리스트 위젯 영역
  // Size _filterDropdownButtonSize = const Size(0, 0); // 필터 버튼(확장형)
  // Size _scrolledFilterDropdownButtonSize = const Size(0, 0); // 필터 버튼(축소형))
  // Size _txSliverListSize = const Size(0, 0); // 거래내역 리스트 사이즈
  // Size _utxoSliverListSize = const Size(0, 0); // utxo 리스트 사이즈
  //
  // Offset _filterDropdownButtonPosition = Offset.zero;
  // Offset _scrolledFilterDropdownButtonPosition = Offset.zero;
  //
  // Offset _faucetIconPosition = Offset.zero;
  // Size _faucetIconSize = const Size(0, 0);
  //
  // double topPadding = 0;
  //
  // SelectedListType _selectedListType = SelectedListType.transaction;
  //
  // bool _positionedTopWidgetVisible = false; // 스크롤시 상단에 붙어있는 위젯
  // bool _isFilterDropdownVisible = false; // 필터 드롭다운(확장형)
  // bool _isScrolledFilterDropdownVisible = false; // 필터 드롭다운(축소형)
  //
  // bool _isPullToRefeshing = false;
  // String faucetTip = '테스트용 비트코인으로 마음껏 테스트 해보세요';
  //
  // Unit _current = Unit.btc;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appBar = _appBarKey.currentContext?.findRenderObject() as RenderBox;
      final topToggle =
          _topToggleButtonKey.currentContext?.findRenderObject() as RenderBox;
      final topSelector =
          _topSelectorWidgetKey.currentContext?.findRenderObject() as RenderBox;
      final topHeader =
          _topHeaderWidgetKey.currentContext?.findRenderObject() as RenderBox;
      final positionedTop = _positionedTopWidgetKey.currentContext
          ?.findRenderObject() as RenderBox;

      final faucetRenderBox =
          _faucetIconKey.currentContext?.findRenderObject() as RenderBox;

      // TODO: 리뷰 완료 후 삭제
      // _filterDropdownButtonKey가 할당된 오브젝트가 생성되기 전이기 때문에 기본값으로 초기화 합니다.
      // _filterDropdownButtonRenderBox = RenderConstrainedBox(
      //     additionalConstraints:
      //         const BoxConstraints.tightFor(width: 0, height: 0));
      // _faucetIconPosition = _faucetRenderBox.localToGlobal(Offset.zero);
      // _faucetIconSize = _faucetRenderBox.size;
      // _appBarSize = _appBarRenderBox.size;
      // _topToggleButtonSize = _topToggleButtonRenderBox.size;
      // _topSelectorWidgetSize = _topSelectorWidgetRenderBox.size;
      // _topHeaderWidgetSize = _topHeaderWidgetRenderBox.size;
      // _positionedTopWidgetSize = _positionedTopWidgetRenderBox.size;
      //
      // setState(() {
      //   topPadding = _topToggleButtonSize.height +
      //       _topSelectorWidgetSize.height +
      //       _topHeaderWidgetSize.height -
      //       _positionedTopWidgetSize.height;
      // });

      final txSliverSize = (viewModel?.txList.isNotEmpty == true)
          ? (_txSliverListKey.currentContext?.findRenderObject() as RenderBox)
              .size
          : Size.zero;

      viewModel?.initViewState(
        appBarSize: appBar.size,
        topToggleSize: topToggle.size,
        topSelectorSize: topSelector.size,
        topHeaderSize: topHeader.size,
        positionedTopSize: positionedTop.size,
        txSliverSize: txSliverSize,
        faucetSize: faucetRenderBox.size,
        faucetOffset: faucetRenderBox.localToGlobal(Offset.zero),
      );

      // TODO: 리뷰 완료 후 삭제
      // if (viewModel?.txList.isNotEmpty == true) {
      //   final RenderBox txSliverListRenderBox =
      //       _txSliverListKey.currentContext?.findRenderObject() as RenderBox;
      //   _txSliverListSize = txSliverListRenderBox.size;
      // }

      _scrollController.addListener(() {
        final renderBox = _scrolledFilterDropdownButtonKey.currentContext
            ?.findRenderObject() as RenderBox;

        viewModel?.scrollControllerListener(
          scrollPosition: _scrollController.offset,
          filterButtonPosition: renderBox.localToGlobal(Offset.zero),
          filterButtonSize: renderBox.size,
        );

        // TODO: 리뷰 완료 후 삭제
        // if (_isFilterDropdownVisible || _isScrolledFilterDropdownVisible) {
        //   _removeFilterDropdown();
        // }
        //
        // if (_scrollController.offset > topPadding) {
        //   if (!_isPullToRefeshing) {
        //     setState(() {
        //       _positionedTopWidgetVisible = true;
        //       _isFilterDropdownVisible = false;
        //     });
        //     if (_scrolledFilterDropdownButtonRenderBox == null &&
        //         viewModel?.utxoList.isNotEmpty == true &&
        //         _selectedListType == SelectedListType.utxo) {
        //       _scrolledFilterDropdownButtonRenderBox =
        //           _scrolledFilterDropdownButtonKey.currentContext
        //               ?.findRenderObject() as RenderBox;
        //       _scrolledFilterDropdownButtonPosition =
        //           _scrolledFilterDropdownButtonRenderBox!
        //               .localToGlobal(Offset.zero);
        //       _scrolledFilterDropdownButtonSize =
        //           _scrolledFilterDropdownButtonRenderBox!.size;
        //     }
        //   }
        // } else {
        //   if (!_isPullToRefeshing) {
        //     setState(() {
        //       _positionedTopWidgetVisible = false;
        //       _isScrolledFilterDropdownVisible = false;
        //     });
        //   }
        // }
      });

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

  // TODO: 주석 처리해도 정상 동작함
  // _updateFilterDropdownButtonRenderBox() {
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     if (_filterDropdownButtonKey.currentContext?.findRenderObject() != null) {
  //       final renderBox = _filterDropdownButtonKey.currentContext!
  //           .findRenderObject() as RenderBox;
  //
  //
  //       // _filterDropdownButtonSize = _filterDropdownButtonRenderBox.size;
  //       // _filterDropdownButtonPosition =
  //       //     _filterDropdownButtonRenderBox.localToGlobal(Offset.zero);
  //
  //       viewModel?.setFilterDropdownButton(
  //         renderBox.size,
  //         renderBox.localToGlobal(Offset.zero),
  //       );
  //     }
  //   });
  // }

  // TODO: 리뷰 완료 후 삭제
  // void _toggleUnit() {
  //   setState(() {
  //     _current = _current == Unit.btc ? Unit.sats : Unit.btc;
  //   });
  // }
  // void _toggleListType(SelectedListType type, List<model.UTXO> utxoList) async {
  //   if (type == SelectedListType.transaction) {
  //     setState(() {
  //       _selectedListType = SelectedListType.transaction;
  //       _isFilterDropdownVisible = false;
  //       _isScrolledFilterDropdownVisible = false;
  //     });
  //   } else {
  //     setState(() {
  //       _selectedListType = SelectedListType.utxo;
  //     });
  //     if (utxoList.isNotEmpty) {
  //       await Future.delayed(const Duration(milliseconds: 200));
  //       _filterDropdownButtonRenderBox = _filterDropdownButtonKey.currentContext
  //           ?.findRenderObject() as RenderBox;
  //       _filterDropdownButtonSize = _filterDropdownButtonRenderBox.size;
  //
  //       _filterDropdownButtonPosition =
  //           _filterDropdownButtonRenderBox.localToGlobal(Offset.zero);
  //       final RenderBox utxoSliverListRenderBox =
  //           _utxoSliverListKey.currentContext?.findRenderObject() as RenderBox;
  //       _utxoSliverListSize = utxoSliverListRenderBox.size;
  //     }
  //   }
  // }
  // void _removeFilterDropdown() {
  //   setState(() {
  //     _isFilterDropdownVisible = false;
  //     _isScrolledFilterDropdownVisible = false;
  //   });
  // }

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
        // TODO: 리뷰 완료 후 삭제
        // _updateFilterDropdownButtonRenderBox();
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
              viewModel.removeFilterDropdown();
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
                      semanticChildCount: viewModel.txList.isEmpty
                          ? 1
                          : viewModel.txList.length,
                      slivers: [
                        CupertinoSliverRefreshControl(
                          onRefresh: () async {
                            viewModel.setPullToRefresh(true);
                            try {
                              if (!_checkStateAndShowToast()) {
                                return;
                              }
                              viewModel.appStateModel
                                  ?.initWallet(targetId: widget.id);
                            } finally {
                              viewModel.setPullToRefresh(false);
                            }
                          },
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            key: _topToggleButtonKey,
                            padding: const EdgeInsets.only(top: 20.0),
                            child: Center(
                              child: SmallActionButton(
                                onPressed: viewModel.toggleUnit,
                                height: 32,
                                width: 64,
                                child: Text(
                                  viewModel.currentUnit == Unit.btc
                                      ? 'BTC'
                                      : 'sats',
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
                                currentUnit: viewModel.currentUnit,
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
                                        if (!viewModel.isPullToRefreshing &&
                                            state ==
                                                WalletInitState.processing) ...{
                                          Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment
                                                      .spaceBetween,
                                              children: [
                                                _listTypeSelectionRow(
                                                    viewModel),
                                                Row(
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
                                                )
                                              ]),
                                        } else ...{
                                          Column(
                                            children: [
                                              _listTypeSelectionRow(viewModel),
                                            ],
                                          ),
                                        },
                                        if (viewModel.selectedListType ==
                                                SelectedListType.utxo &&
                                            viewModel.utxoList.isNotEmpty) ...{
                                          const SizedBox(height: 8),
                                          IgnorePointer(
                                            ignoring: viewModel
                                                .positionedTopWidgetVisible,
                                            child: Visibility(
                                              maintainSize: true,
                                              maintainAnimation: true,
                                              maintainState: true,
                                              maintainSemantics: false,
                                              maintainInteractivity: false,
                                              visible: !viewModel
                                                  .positionedTopWidgetVisible,
                                              child: CupertinoButton(
                                                onPressed: () {
                                                  // setState(
                                                  //   () {
                                                  //     _scrollController.jumpTo(
                                                  //         _scrollController
                                                  //             .offset);
                                                  //     if (_isFilterDropdownVisible ||
                                                  //         _isScrolledFilterDropdownVisible) {
                                                  //       _isFilterDropdownVisible =
                                                  //           false;
                                                  //     } else {
                                                  //       _isFilterDropdownVisible =
                                                  //           true;
                                                  //     }
                                                  //   },
                                                  // );
                                                  _scrollController.jumpTo(
                                                      _scrollController.offset);
                                                  viewModel.tapFilterButton();
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
                                                          .selectedFilter.text,
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
                        )),
                        viewModel.selectedListType ==
                                SelectedListType.transaction
                            ? _transactionListWidget(viewModel)
                            : _utxoListWidget(viewModel),
                        if ((viewModel.selectedListType ==
                                SelectedListType.transaction &&
                            viewModel.txList.isNotEmpty)) ...{
                          SliverToBoxAdapter(
                            child: Container(
                              height: viewModel.positionedTopWidgetVisible
                                  ? 0
                                  : viewModel.txSliverListSize.height *
                                                  viewModel.txList.length +
                                              80 >
                                          MediaQuery.sizeOf(context).height -
                                              viewModel.topPadding
                                      ? 0
                                      : MediaQuery.sizeOf(context).height -
                                                  viewModel.topPadding -
                                                  (viewModel.txSliverListSize
                                                              .height *
                                                          viewModel
                                                              .txList.length +
                                                      80) -
                                                  viewModel.appBarSize.height -
                                                  kToolbarHeight +
                                                  10 <
                                              0
                                          ? 0
                                          : 300,
                            ),
                          ),
                        },
                        if ((viewModel.selectedListType ==
                                SelectedListType.utxo &&
                            viewModel.utxoList.isNotEmpty)) ...{
                          SliverToBoxAdapter(
                            child: Container(
                              height: viewModel.positionedTopWidgetVisible
                                  ? 0
                                  : viewModel.utxoSliverListSize.height *
                                                  viewModel.utxoList.length +
                                              (12 *
                                                  (viewModel.utxoList.length -
                                                      1)) >
                                          MediaQuery.sizeOf(context).height -
                                              viewModel.topPadding
                                      ? 0
                                      : MediaQuery.sizeOf(context).height -
                                                  viewModel.topPadding -
                                                  ((viewModel.utxoSliverListSize
                                                                  .height -
                                                              20) *
                                                          viewModel
                                                              .utxoList.length +
                                                      (12 *
                                                          (viewModel.utxoList
                                                                  .length -
                                                              1))) -
                                                  viewModel.appBarSize.height -
                                                  kToolbarHeight +
                                                  10 <
                                              0
                                          ? 0
                                          : 300,
                            ),
                          ),
                        }
                      ]),
                ),
                _afterScrolledWidget(viewModel),
                _faucetTooltipWidget(context, viewModel),
                if (viewModel.isFilterDropdownVisible &&
                    viewModel.utxoList.isNotEmpty) ...{
                  Positioned(
                    top: viewModel.filterDropdownButtonPosition.dy +
                        viewModel.filterDropdownButtonSize.height +
                        8 -
                        _scrollController.offset,
                    right: 16,
                    child: _filterDropDownWidget(viewModel),
                  ),
                },
                if (viewModel.isScrolledFilterDropdownVisible &&
                    viewModel.utxoList.isNotEmpty) ...{
                  Positioned(
                    top: viewModel.scrolledFilterDropdownButtonPosition.dy +
                        viewModel.scrolledFilterDropdownButtonSize.height +
                        8,
                    right: 16,
                    child: _filterDropDownWidget(viewModel),
                  ),
                },
              ],
            ),
          );
        },
      ),
    );
  }

  /// 필터 드롭다운 위젯
  Widget _filterDropDownWidget(WalletDetailViewModel viewModel) {
    return Material(
      borderRadius: BorderRadius.circular(16),
      child: CustomDropdown(
        buttons: [
          UtxoOrderEnum.byTimestampDesc.text,
          UtxoOrderEnum.byTimestampAsc.text,
          UtxoOrderEnum.byAmountDesc.text,
          UtxoOrderEnum.byAmountAsc.text,
        ],
        dividerColor: Colors.black,
        onTapButton: (index) {
          viewModel.tapDropdownButton(index);
          // TODO: 리뷰 완료 후 삭제
          // setState(() {
          //   _isFilterDropdownVisible = _isScrolledFilterDropdownVisible = false;
          // });
          // switch (index) {
          //   case 0: // 큰 금액순
          //     if (viewModel.selectedFilter != UtxoOrderEnum.byTimestampDesc) {
          //       viewModel.updateUtxoFilter(UtxoOrderEnum.byTimestampDesc);
          //     }
          //     break;
          //   case 1: // 작은 금액순
          //     if (viewModel.selectedFilter != UtxoOrderEnum.byTimestampAsc) {
          //       viewModel.updateUtxoFilter(UtxoOrderEnum.byTimestampAsc);
          //     }
          //     break;
          //   case 2: // 최신순
          //     if (viewModel.selectedFilter != UtxoOrderEnum.byAmountDesc) {
          //       viewModel.updateUtxoFilter(UtxoOrderEnum.byAmountDesc);
          //     }
          //     break;
          //   case 3: // 오래된 순
          //     if (viewModel.selectedFilter != UtxoOrderEnum.byAmountAsc) {
          //       viewModel.updateUtxoFilter(UtxoOrderEnum.byAmountAsc);
          //     }
          //     break;
          // }
        },
        selectedButton: viewModel.selectedFilter.text,
      ),
    );
  }

  /// 거래 내역 리스트
  Widget _transactionListWidget(WalletDetailViewModel viewModel) {
    return SliverSafeArea(
      minimum: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
      sliver: viewModel.txList.isNotEmpty
          ? SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, index) {
                  return Column(
                    key: index == 0 ? _txSliverListKey : null,
                    children: [
                      TransactionRowItem(
                        tx: viewModel.txList[index],
                        currentUnit: viewModel.currentUnit,
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
            ),
    );
  }

  /// UTXO 목록
  Widget _utxoListWidget(WalletDetailViewModel viewModel) {
    return SliverSafeArea(
      minimum: const EdgeInsets.symmetric(horizontal: 16),
      sliver: viewModel.utxoList.isNotEmpty
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
                                  viewModel
                                      .utxoList[itemIndex].derivationPath) ==
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
            ),
    );
  }

  Widget _faucetTooltipWidget(
      BuildContext context, WalletDetailViewModel viewModel) {
    return viewModel.faucetTooltipVisible
        ? Positioned(
            top: viewModel.faucetIconPosition.dy +
                viewModel.faucetIconSize.height -
                10,
            right: MediaQuery.of(context).size.width -
                viewModel.faucetIconPosition.dx -
                viewModel.faucetIconSize.width +
                5,
            child: AnimatedOpacity(
              opacity: viewModel.faucetTipVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 1000),
              child: GestureDetector(
                onTap: viewModel.removeFaucetTooltip,
                child: ClipPath(
                  clipper: RightTriangleBubbleClipper(),
                  child: Container(
                    padding: const EdgeInsets.only(
                      top: 25,
                      left: 18,
                      right: 18,
                      bottom: 10,
                    ),
                    color: MyColors.skybule,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '테스트용 비트코인으로 마음껏 테스트 해보세요',
                          style: Styles.caption.merge(TextStyle(
                            height: 1.3,
                            fontFamily: CustomFonts.text.getFontFamily,
                            color: MyColors.darkgrey,
                          )),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        : Container();
  }

  Widget _afterScrolledWidget(WalletDetailViewModel viewModel) {
    return Positioned(
      top: viewModel.appBarSize.height,
      left: 0,
      right: 0,
      child: IgnorePointer(
        ignoring: !viewModel.positionedTopWidgetVisible,
        child: AnimatedOpacity(
          opacity: viewModel.positionedTopWidgetVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: Column(
            key: _positionedTopWidgetKey,
            children: [
              Container(
                color: MyColors.black,
                padding: const EdgeInsets.only(
                  left: 16.0,
                  right: 16,
                  top: 20.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: viewModel.walletListBaseItem.balance != null
                              ? (viewModel.currentUnit == Unit.btc
                                  ? satoshiToBitcoinString(
                                      viewModel.walletListBaseItem.balance!)
                                  : addCommasToIntegerPart(viewModel
                                      .walletListBaseItem.balance!
                                      .toDouble()))
                              : '잔액 조회 불가',
                          style: Styles.h2Number,
                          children: [
                            TextSpan(
                              text: viewModel.walletListBaseItem.balance != null
                                  ? viewModel.currentUnit == Unit.btc
                                      ? ' BTC'
                                      : ' sats'
                                  : '잔액 조회 불가',
                              style: Styles.label.merge(
                                TextStyle(
                                  fontFamily: CustomFonts.number.getFontFamily,
                                  color: MyColors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    CupertinoButton(
                      onPressed: () {
                        if (!_checkStateAndShowToast()) return;
                        if (!_checkBalanceIsNotNullAndShowToast(
                            viewModel.walletListBaseItem.balance)) return;
                        CommonBottomSheets.showBottomSheet_90(
                          context: context,
                          child: ReceiveAddressBottomSheet(
                            id: widget.id,
                            address: viewModel.walletAddress,
                            derivationPath: viewModel.derivationPath,
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      minSize: 0,
                      color: MyColors.white,
                      child: SizedBox(
                        width: 35,
                        child: Center(
                          child: Text(
                            '받기',
                            style: Styles.caption.merge(
                              const TextStyle(
                                  color: MyColors.black,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 8,
                    ),
                    CupertinoButton(
                      onPressed: () {
                        if (viewModel.walletListBaseItem.balance == null) {
                          CustomToast.showToast(
                              context: context, text: "잔액이 없습니다.");
                          return;
                        }
                        if (!_checkStateAndShowToast()) return;
                        if (!_checkBalanceIsNotNullAndShowToast(
                            viewModel.walletListBaseItem.balance)) return;
                        Navigator.pushNamed(context, '/send-address',
                            arguments: {'id': widget.id});
                      },
                      borderRadius: BorderRadius.circular(8.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      minSize: 0,
                      color: MyColors.primary,
                      child: SizedBox(
                        width: 35,
                        child: Center(
                          child: Text(
                            '보내기',
                            style: Styles.caption.merge(
                              const TextStyle(
                                  color: MyColors.black,
                                  fontFamily: 'Pretendard',
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Stack(
                children: [
                  Column(
                    children: [
                      Container(
                        width: MediaQuery.sizeOf(context).width,
                        padding: const EdgeInsets.only(
                            top: 10, left: 16, right: 16, bottom: 9),
                        decoration: const BoxDecoration(
                          color: MyColors.black,
                          boxShadow: [
                            BoxShadow(
                              color: Color.fromRGBO(255, 255, 255, 0.2),
                              offset: Offset(0, 3),
                              blurRadius: 4,
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Visibility(
                          visible: viewModel.selectedListType ==
                                  SelectedListType.utxo &&
                              viewModel.utxoList.isNotEmpty,
                          maintainAnimation: true,
                          maintainState: true,
                          maintainSize: true,
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(),
                              ),
                              CupertinoButton(
                                padding: const EdgeInsets.only(
                                  top: 10,
                                ),
                                minSize: 0,
                                onPressed: () {
                                  _scrollController
                                      .jumpTo(_scrollController.offset);
                                  viewModel.tapPositionedFilterButton();
                                  // setState(() {
                                  //   _scrollController
                                  //       .jumpTo(_scrollController.offset);
                                  //   if (_isFilterDropdownVisible ||
                                  //       _isScrolledFilterDropdownVisible) {
                                  //     _isScrolledFilterDropdownVisible = false;
                                  //   } else {
                                  //     _isScrolledFilterDropdownVisible = true;
                                  //   }
                                  // });
                                },
                                child: Row(
                                  children: [
                                    Text(
                                      key: _scrolledFilterDropdownButtonKey,
                                      viewModel.selectedFilter.text,
                                      style: Styles.caption2.merge(
                                        const TextStyle(
                                          color: MyColors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(
                                      width: 5,
                                    ),
                                    SvgPicture.asset(
                                        'assets/svg/arrow-down.svg'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 16,
                        child: Container(),
                      ),
                    ],
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: MyColors.black,
                            border: Border.all(
                                color: MyColors.transparentWhite_50,
                                width: 0.5),
                            borderRadius: BorderRadius.circular(
                              16,
                            ),
                          ),
                          child: Text(
                            viewModel.selectedListType ==
                                    SelectedListType.transaction
                                ? '거래 내역'
                                : 'UTXO 목록', // TODO: 선택된 리스트 대입
                            style: Styles.caption2.merge(
                              const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                                color: MyColors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _listTypeSelectionRow(WalletDetailViewModel viewModel) {
    return Row(
      children: [
        CupertinoButton(
          pressedOpacity: 0.8,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minSize: 0,
          onPressed: () {
            viewModel.tapListTypeButton(SelectedListType.transaction);
          },
          child: Text(
            '거래 내역',
            style: Styles.h3.merge(
              TextStyle(
                color:
                    viewModel.selectedListType == SelectedListType.transaction
                        ? MyColors.white
                        : MyColors.transparentWhite_50,
              ),
            ),
          ),
        ),
        const SizedBox(
          width: 8,
        ),
        CupertinoButton(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          pressedOpacity: 0.8,
          // focusColor: MyColors.white,
          minSize: 0,
          onPressed: () async {
            viewModel.tapListTypeButton(SelectedListType.utxo);
            await Future.delayed(const Duration(milliseconds: 200));
            if (viewModel.utxoList.isNotEmpty) {
              final renderBox = _filterDropdownButtonKey.currentContext
                  ?.findRenderObject() as RenderBox;
              final utxoRenderBox = _utxoSliverListKey.currentContext
                  ?.findRenderObject() as RenderBox;
              viewModel.setUtxoListRenderBoxSize(
                  dropdownButtonSize: renderBox.size,
                  dropdownButtonPosition: renderBox.localToGlobal(Offset.zero),
                  utxoListSize: utxoRenderBox.size);
            }
          },
          child: Text.rich(TextSpan(
              text: 'UTXO 목록',
              style: Styles.h3.merge(
                TextStyle(
                  color: viewModel.selectedListType == SelectedListType.utxo
                      ? MyColors.white
                      : MyColors.transparentWhite_50,
                ),
              ),
              children: [
                if (viewModel.utxoList.isNotEmpty) ...{
                  TextSpan(
                    text: ' (${viewModel.utxoList.length}개)',
                    style: Styles.caption.merge(
                      TextStyle(
                        color:
                            viewModel.selectedListType == SelectedListType.utxo
                                ? MyColors.transparentWhite_70
                                : MyColors.transparentWhite_50,
                        fontFamily: 'Pretendard',
                      ),
                    ),
                  ),
                }
              ])),
        ),
      ],
    );
  }
}
