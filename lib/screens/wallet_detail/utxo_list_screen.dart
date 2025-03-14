import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_list_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/body/utxo_list_body.dart';
import 'package:coconut_wallet/widgets/header/utxo_list_header.dart';
import 'package:coconut_wallet/widgets/header/utxo_list_sticky_header.dart';
import 'package:coconut_wallet/widgets/dropdown/utxo_filter_dropdown.dart';
import 'package:coconut_wallet/widgets/loading_indicator/loading_indicator.dart';
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
  void initState() {
    super.initState();
    _viewModel = UtxoListViewModel(
      widget.id,
      Provider.of<WalletProvider>(context, listen: false),
      Provider.of<TransactionProvider>(context, listen: false),
      Provider.of<UtxoTagProvider>(context, listen: false),
      Provider.of<ConnectivityProvider>(context, listen: false),
      Provider.of<UpbitConnectModel>(context, listen: false),
    );

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider4<WalletProvider, UtxoTagProvider,
        ConnectivityProvider, UpbitConnectModel, UtxoListViewModel>(
      create: (_) => _viewModel,
      update: (_, walletProvider, utxoTagProvider, connectivityProvider,
          upbitConnectModel, viewModel) {
        return viewModel!..updateProvider();
      },
      child: Consumer<UtxoListViewModel>(
        builder: (context, viewModel, child) {
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
                    backgroundColor: CoconutColors.black,
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
                        if (viewModel.isSyncing)
                          const SliverToBoxAdapter(child: LoadingIndicator()),
                        CupertinoSliverRefreshControl(
                          onRefresh: () async {
                            _isPullToRefreshing = true;
                            viewModel.refetchFromDB();
                            _isPullToRefreshing = false;
                          },
                        ),
                        SliverToBoxAdapter(child: _buildHeader(viewModel)),
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
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStickyHeader(viewModel),
                  _buildUtxoOrderDropdownMenu(viewModel),
                ],
              ),
            ),
          );
        },
      ),
    );
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

  void _removeFilterDropdown() {
    setState(() {
      _isHeaderDropdownVisible = false;
      _isStickyHeaderDropdownVisible = false;
    });
  }

  Widget _buildHeader(UtxoListViewModel viewModel) {
    return UtxoListHeader(
        key: ValueKey(viewModel.utxoTagListKey),
        dropdownGlobalKey: _headerDropdownKey,
        balance: viewModel.balance,
        btcPriceInKrw: viewModel.bitcoinPriceKrw,
        selectedFilter: viewModel.selectedUtxoOrder.text,
        utxoTagList: viewModel.utxoTagList,
        selectedUtxoTagName: viewModel.selectedUtxoTagName,
        onTapDropdown: () {
          setState(() {
            if (_isHeaderDropdownVisible || _isStickyHeaderDropdownVisible) {
              _isHeaderDropdownVisible = false;
            } else {
              _isHeaderDropdownVisible = true;
            }
          });
        },
        onTagSelected: (tagName) {
          viewModel.setSelectedUtxoTagName(tagName);
        });
  }

  Widget _buildUtxoOrderDropdownMenu(UtxoListViewModel viewModel) {
    return UtxoOrderDropdown(
      isVisible: _isHeaderDropdownVisible || _isStickyHeaderDropdownVisible,
      positionTop: _isHeaderDropdownVisible
          ? _headerDropdownPosition.dy + _headerDropdownSize.height
          : _isStickyHeaderDropdownVisible
              ? _stickyHeaderDropdownPosition.dy +
                  _stickyHeaderDropdownSize.height
              : 0,
      selectedFilter: viewModel.selectedUtxoOrder,
      onSelected: (filter) {
        setState(() {
          _isHeaderDropdownVisible = _isStickyHeaderDropdownVisible = false;
        });
        if (_stickyHeaderVisible) {
          _scrollController.animateTo(kToolbarHeight + 28,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut);
        }
        viewModel.updateUtxoFilter(filter);
      },
    );
  }

  Widget _buildStickyHeader(UtxoListViewModel viewModel) {
    return UtxoListStickyHeader(
      key: ValueKey(viewModel.utxoTagListKey),
      dropdownGlobalKey: _stickyHeaderDropdownKey,
      height: _appBarSize.height,
      isVisible: _stickyHeaderVisible,
      balance: viewModel.balance,
      totalCount: viewModel.utxoList.length,
      selectedFilter: viewModel.selectedUtxoOrder.text,
      onTapDropdown: () {
        setState(() {
          _scrollController.jumpTo(_scrollController.offset);
          if (_isHeaderDropdownVisible || _isStickyHeaderDropdownVisible) {
            _isStickyHeaderDropdownVisible = false;
          } else {
            _isStickyHeaderDropdownVisible = true;
          }
        });
      },
      removePopup: () {
        _removeFilterDropdown();
      },
    );
  }
}
