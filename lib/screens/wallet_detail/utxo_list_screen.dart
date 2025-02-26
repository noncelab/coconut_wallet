import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_list_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/body/utxo_list_body.dart';
import 'package:coconut_wallet/widgets/header/utxo_list_header.dart';
import 'package:coconut_wallet/widgets/header/utxo_list_sticky_header.dart';
import 'package:coconut_wallet/widgets/overlays/custom_toast.dart';
import 'package:coconut_wallet/widgets/dropdown/utxo_filter_dropdown.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UtxoListScreen extends StatefulWidget {
  final int id;

  const UtxoListScreen({super.key, required this.id});

  @override
  State<UtxoListScreen> createState() => _UtxoListScreenState();
}

class _UtxoListScreenState extends State<UtxoListScreen> {
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _appBarKey = GlobalKey();
  final GlobalKey _headerDropdownKey = GlobalKey();
  final GlobalKey _stickyHeaderDropdownKey = GlobalKey();

  Size _appBarSize = const Size(0, 0);

  Offset _headerDropdownPosition = Offset.zero;
  Offset _stickyHeaderDropdownPosition = Offset.zero;

  Size _headerDropdownSize = Size.zero;
  Size _stickyHeaderDropdownSize = Size.zero;

  bool _isHeaderDropdownVisible = false;
  bool _stickyHeaderVisible = false;
  bool _isStickyHeaderDropdownVisible = false;
  bool _isPullToRefreshing = false;

  final GlobalKey _utxoSliverListKey = GlobalKey();

  late UtxoListViewModel _viewModel;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider4<WalletProvider, UtxoTagProvider,
        ConnectivityProvider, UpbitConnectModel, UtxoListViewModel>(
      create: (_) {
        _viewModel = UtxoListViewModel(
          widget.id,
          Provider.of<WalletProvider>(_, listen: false),
          Provider.of<UtxoTagProvider>(_, listen: false),
          Provider.of<ConnectivityProvider>(_, listen: false),
          Provider.of<UpbitConnectModel>(_, listen: false),
        );
        return _viewModel;
      },
      update: (_, walletProvider, utxoTagProvider, connectProvider, upbitModel,
          viewModel) {
        return viewModel!..updateProvider();
      },
      child: Consumer<UtxoListViewModel>(
        builder: (context, viewModel, child) {
          final state = viewModel.walletInitState;
          final balance = viewModel.balance;
          final isNetworkOn = viewModel.isNetworkOn;
          return PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, _) {
              _removeFilterDropdown();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _removeFilterDropdown();
              },
              child: Stack(
                children: [
                  Scaffold(
                    backgroundColor: MyColors.black,
                    appBar: CoconutAppBar.build(
                      entireWidgetKey: _appBarKey,
                      title: t.utxo_list,
                      context: context,
                      backgroundColor: CoconutColors.black,
                    ),
                    body: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: _scrollController,
                      semanticChildCount: viewModel.isUtxoTagListEmpty
                          ? 1
                          : viewModel.utxoList.length,
                      slivers: [
                        CupertinoSliverRefreshControl(
                          onRefresh: () async {
                            _isPullToRefreshing = true;
                            try {
                              if (!_checkStateAndShowToast(
                                  state, balance, isNetworkOn)) {
                                return;
                              }
                            } finally {
                              _isPullToRefreshing = false;
                            }
                          },
                        ),
                        SliverToBoxAdapter(
                          child: UtxoListHeader(
                            dropdownGlobalKey: _headerDropdownKey,
                            balance: balance,
                            btcPriceInKrw: viewModel.bitcoinPriceKrw,
                            selectedFilter: viewModel.selectedUtxoOrder.text,
                            onTapDropdown: () {
                              setState(() {
                                if (_isHeaderDropdownVisible ||
                                    _isStickyHeaderDropdownVisible) {
                                  _isHeaderDropdownVisible = false;
                                } else {
                                  _isHeaderDropdownVisible = true;
                                }
                              });
                            },
                          ),
                        ),
                        SliverSafeArea(
                          minimum: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: UtxoListBody(
                            utxoSliverListKey: _utxoSliverListKey,
                            walletId: widget.id,
                            walletType: viewModel.walletType,
                            isUtxoListLoadComplete:
                                viewModel.isUtxoListLoadComplete,
                            utxoList: viewModel.utxoList,
                            removePopup: () {
                              _removeFilterDropdown();
                            },
                            popFromUtxoDetail: (resultUtxo) {
                              if (viewModel.isUpdatedTagList) {
                                viewModel.updateUtxoTagList(resultUtxo.utxoId,
                                    viewModel.selectedTagList);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  UtxoListStickyHeader(
                    dropdownGlobalKey: _stickyHeaderDropdownKey,
                    height: _appBarSize.height,
                    isVisible: _stickyHeaderVisible,
                    balance: balance,
                    totalCount: viewModel.utxoList.length,
                    selectedFilter: viewModel.selectedUtxoOrder.text,
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
                    removePopup: () {
                      _removeFilterDropdown();
                    },
                  ),
                  UtxoFilterDropdown(
                    isVisible: _isHeaderDropdownVisible ||
                        _isStickyHeaderDropdownVisible,
                    positionTop: _isHeaderDropdownVisible
                        ? _headerDropdownPosition.dy +
                            _headerDropdownSize.height
                        : _isStickyHeaderDropdownVisible
                            ? _stickyHeaderDropdownPosition.dy +
                                _stickyHeaderDropdownSize.height
                            : 0,
                    selectedFilter: viewModel.selectedUtxoOrder,
                    onSelected: (filter) {
                      setState(() {
                        _isHeaderDropdownVisible =
                            _isStickyHeaderDropdownVisible = false;
                      });
                      if (_stickyHeaderVisible) {
                        _scrollController.animateTo(kToolbarHeight + 28,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut);
                      }
                      viewModel.updateUtxoFilter(filter);
                    },
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

      _appBarSize = appBarRenderBox.size;

      _updateHeaderDropdownPosition();

      _scrollController.addListener(() {
        if (_isHeaderDropdownVisible || _isStickyHeaderDropdownVisible) {
          _removeFilterDropdown();
        }
        if (_scrollController.offset > kToolbarHeight + 27) {
          _updateStickyHeaderDropdownPosition();
        } else {
          _updateHeaderDropdownPosition();
        }
      });
    });
  }

  void _updateHeaderDropdownPosition() {
    RenderBox? headerDropdownRenderBox;
    if (!_isPullToRefreshing) {
      setState(() {
        _stickyHeaderVisible = false;
        _isStickyHeaderDropdownVisible = false;
      });

      headerDropdownRenderBox =
          _headerDropdownKey.currentContext?.findRenderObject() as RenderBox;
      if (_headerDropdownSize == Size.zero) {
        _headerDropdownSize = headerDropdownRenderBox.size;
      }
      _headerDropdownPosition =
          headerDropdownRenderBox.localToGlobal(Offset.zero);
    }
  }

  void _updateStickyHeaderDropdownPosition() {
    if (!_isPullToRefreshing) {
      setState(() {
        _stickyHeaderVisible = true;
        _isHeaderDropdownVisible = false;
      });
      RenderBox? stickyHeaderDropdownRenderBox;

      if (_viewModel.utxoList.isNotEmpty == true) {
        stickyHeaderDropdownRenderBox = _stickyHeaderDropdownKey.currentContext
            ?.findRenderObject() as RenderBox;
        if (_stickyHeaderDropdownSize == Size.zero) {
          _stickyHeaderDropdownSize = stickyHeaderDropdownRenderBox.size;
        }
        _stickyHeaderDropdownPosition =
            stickyHeaderDropdownRenderBox.localToGlobal(Offset.zero);
      }
    }
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

  void _removeFilterDropdown() {
    setState(() {
      _isHeaderDropdownVisible = false;
      _isStickyHeaderDropdownVisible = false;
    });
  }
}
