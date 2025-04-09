import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/upbit_connect_model.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_list_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/amimation_util.dart';
import 'package:coconut_wallet/widgets/card/utxo_item_card.dart';
import 'package:coconut_wallet/widgets/header/utxo_list_header.dart';
import 'package:coconut_wallet/widgets/header/utxo_list_sticky_header.dart';
import 'package:coconut_wallet/widgets/dropdown/utxo_filter_dropdown.dart';
import 'package:coconut_wallet/widgets/loading_indicator/loading_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

class UtxoListScreen extends StatefulWidget {
  final int id; // wallet id

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
  bool _isAnimating = false;

  late UtxoListViewModel _viewModel;
  OverlayEntry? _statusBarTapOverlayEntry; // iOS 노치 터치 시 scrol to top

  @override
  void initState() {
    super.initState();
    _viewModel = _createViewModel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appBarRenderBox = _appBarKey.currentContext?.findRenderObject() as RenderBox;
      _appBarSize = appBarRenderBox.size;

      _checkAndUpdateStickyHeaderVisibility(ignoreAnimating: true);

      _scrollController.addListener(() {
        // fixme: 리스트가 렌더링 되고 있는 상태에서 스크롤이 발생해도 sticky header가 보이지 않음
        if (_isAnimating) return;
        if (_isHeaderDropdownVisible || _isStickyHeaderDropdownVisible) {
          _removeFilterDropdown();
        }
        _checkAndUpdateStickyHeaderVisibility();
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
    super.dispose();
  }

  UtxoListViewModel _createViewModel() {
    return UtxoListViewModel(
      widget.id,
      Provider.of<WalletProvider>(context, listen: false),
      Provider.of<TransactionProvider>(context, listen: false),
      Provider.of<UtxoTagProvider>(context, listen: false),
      Provider.of<ConnectivityProvider>(context, listen: false),
      Provider.of<UpbitConnectModel>(context, listen: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<WalletProvider, UtxoTagProvider, UtxoListViewModel>(
        create: (_) => _viewModel,
        update: (_, walletProvider, utxoTagProvider, viewModel) {
          viewModel ??= _createViewModel();
          return viewModel..updateProvider();
        },
        child: PopScope(
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
                  body: Consumer<UtxoListViewModel>(builder: (context, viewModel, child) {
                    return CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      controller: _scrollController,
                      semanticChildCount:
                          viewModel.isUtxoTagListEmpty ? 1 : viewModel.utxoList.length,
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
                        UtxoList(
                          walletId: widget.id,
                          onRemoveDropdown: _removeFilterDropdown,
                          onAnimatingStateChanged: _changeAnimatingState,
                        ),
                      ],
                    );
                  }),
                ),
                _buildStickyHeader(),
                _buildUtxoOrderDropdownMenu(),
              ],
            ),
          ),
        ));
  }

  void _updateHeaderDropdownPosition() {
    RenderBox? headerDropdownRenderBox;
    if (!_isPullToRefreshing) {
      setState(() {
        _stickyHeaderVisible = false;
        _isStickyHeaderDropdownVisible = false;
      });

      headerDropdownRenderBox = _headerDropdownKey.currentContext?.findRenderObject() as RenderBox;
      if (_headerDropdownSize == Size.zero) {
        _headerDropdownSize = headerDropdownRenderBox.size;
      }
      _headerDropdownPosition = headerDropdownRenderBox.localToGlobal(Offset.zero);
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
        stickyHeaderDropdownRenderBox =
            _stickyHeaderDropdownKey.currentContext?.findRenderObject() as RenderBox;
        if (_stickyHeaderDropdownSize == Size.zero) {
          _stickyHeaderDropdownSize = stickyHeaderDropdownRenderBox.size;
        }
        _stickyHeaderDropdownPosition = stickyHeaderDropdownRenderBox.localToGlobal(Offset.zero);
      }
    }
  }

  void _removeFilterDropdown() {
    setState(() {
      _isHeaderDropdownVisible = false;
      _isStickyHeaderDropdownVisible = false;
    });
  }

  void _changeAnimatingState(bool isAnimating) {
    _isAnimating = isAnimating;
  }

  void _checkAndUpdateStickyHeaderVisibility({bool ignoreAnimating = false}) {
    if (!ignoreAnimating && _isAnimating) return;
    if (_scrollController.offset > kToolbarHeight + 27) {
      _updateStickyHeaderDropdownPosition();
    } else {
      _updateHeaderDropdownPosition();
    }
  }

  Widget _buildHeader(UtxoListViewModel viewModel) {
    return UtxoListHeader(
        key: ValueKey(viewModel.utxoTagListKey),
        dropdownGlobalKey: _headerDropdownKey,
        animatedBalanceData: AnimatedBalanceData(viewModel.balance, viewModel.prevBalance),
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

  Widget _buildUtxoOrderDropdownMenu() {
    return UtxoOrderDropdown(
      isVisible: _isHeaderDropdownVisible || _isStickyHeaderDropdownVisible,
      positionTop: _isHeaderDropdownVisible
          ? _headerDropdownPosition.dy + _headerDropdownSize.height
          : _isStickyHeaderDropdownVisible
              ? _stickyHeaderDropdownPosition.dy + _stickyHeaderDropdownSize.height
              : 0,
      selectedFilter: _viewModel.selectedUtxoOrder,
      onSelected: (filter) {
        setState(() {
          _isHeaderDropdownVisible = _isStickyHeaderDropdownVisible = false;
        });
        if (_stickyHeaderVisible) {
          _scrollController.animateTo(kToolbarHeight + 28,
              duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
        }
        _viewModel.updateUtxoFilter(filter);
      },
    );
  }

  Widget _buildStickyHeader() {
    return Selector<UtxoListViewModel, int>(
      selector: (_, viewModel) => viewModel.balance,
      builder: (context, balance, child) {
        return UtxoListStickyHeader(
          key: ValueKey(_viewModel.utxoTagListKey),
          dropdownGlobalKey: _stickyHeaderDropdownKey,
          height: _appBarSize.height,
          isVisible: _stickyHeaderVisible,
          animatedBalanceData: AnimatedBalanceData(_viewModel.balance, _viewModel.prevBalance),
          totalCount: _viewModel.utxoList.length,
          selectedFilter: _viewModel.selectedUtxoOrder.text,
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
      },
    );
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
}

class UtxoList extends StatefulWidget {
  const UtxoList({
    super.key,
    required this.walletId,
    required this.onAnimatingStateChanged,
    this.onRemoveDropdown,
  });

  final int walletId;
  final Function? onRemoveDropdown;
  final Function(bool) onAnimatingStateChanged;

  @override
  State<UtxoList> createState() => _UtxoListState();
}

class _UtxoListState extends State<UtxoList> {
  late List<UtxoState> _previousUtxoList = [];
  final GlobalKey<SliverAnimatedListState> _utxoListKey = GlobalKey<SliverAnimatedListState>();

  final Duration _duration = const Duration(milliseconds: 1200);
  final Duration _animationDuration = const Duration(milliseconds: 100);
  bool _isListLoading = false;

  @override
  Widget build(BuildContext context) {
    return Selector<UtxoListViewModel, Tuple2<List<UtxoState>, String>>(
        selector: (_, viewModel) => Tuple2(viewModel.utxoList, viewModel.selectedUtxoTagName),
        builder: (_, data, __) {
          final utxoList = data.item1;
          final selectedUtxoTagName = data.item2;

          if (_isListChanged(_previousUtxoList, utxoList)) {
            _handleUtxoListChange(utxoList);
          }

          return utxoList.isNotEmpty
              ? _buildSliverAnimatedList(utxoList, selectedUtxoTagName)
              : _buildEmptyState();
        });
  }

  Widget _buildSliverAnimatedList(List<UtxoState> utxoList, String selectedUtxoTagName) {
    return SliverAnimatedList(
      key: _utxoListKey,
      initialItemCount: utxoList.length,
      itemBuilder: (context, index, animation) {
        final isSelected = selectedUtxoTagName == t.all ||
            (utxoList[index].tags != null &&
                utxoList[index].tags!.any((e) => e.name == selectedUtxoTagName));

        return isSelected && index < utxoList.length
            ? _buildUtxoItem(utxoList[index], animation, index == utxoList.length - 1)
            : const SizedBox();
      },
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(
            t.utxo_not_found,
            style: CoconutTypography.body1_16,
          ),
        ),
      ),
    );
  }

  Animation<Offset> _buildSlideAnimation(Animation<double> animation) {
    const begin = Offset(1.0, 0.0);
    const end = Offset.zero;
    const curve = Curves.easeOutExpo;

    var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    return animation.drive(tween);
  }

  Future<void> _handleUtxoListChange(List<UtxoState> utxoList) async {
    if (_isListLoading) return;
    _isListLoading = true;

    final oldUtxoMap = {for (var utxo in _previousUtxoList) utxo.utxoId: utxo};
    final newUtxoMap = {for (var utxo in utxoList) utxo.utxoId: utxo};

    final List<int> insertedIndexes = [];
    final List<int> removedIndexes = [];

    for (int i = 0; i < utxoList.length; i++) {
      if (!oldUtxoMap.containsKey(utxoList[i].utxoId)) {
        insertedIndexes.add(i);
      }
    }

    for (int i = 0; i < _previousUtxoList.length; i++) {
      if (!newUtxoMap.containsKey(_previousUtxoList[i].utxoId)) {
        removedIndexes.add(i);
      }
    }

    if (removedIndexes.isNotEmpty || insertedIndexes.isNotEmpty) {
      widget.onAnimatingStateChanged(true);
    }

    // 삭제된 인덱스 역순으로 삭제
    for (var index in removedIndexes.reversed) {
      if (index >= _previousUtxoList.length) {
        debugPrint('❌ 리스트를 초과하는 인덱스 $index < ${_previousUtxoList.length}');
        continue;
      }

      await Future.delayed(_animationDuration);
      _utxoListKey.currentState?.removeItem(
        index,
        (context, animation) => _buildRemoveUtxoItem(_previousUtxoList[index], animation),
        duration: _duration,
      );
    }

    // 삽입된 인덱스 순서대로 추가
    for (var index in insertedIndexes) {
      await Future.delayed(_animationDuration);
      _utxoListKey.currentState?.insertItem(index, duration: _duration);
    }

    widget.onAnimatingStateChanged(false);
    final totalDelay =
        _duration + _animationDuration * (insertedIndexes.length + removedIndexes.length);
    Future.delayed(totalDelay, () {
      // 모든 애니메이션 끝난 후 상태 업데이트
      _previousUtxoList = List.from(utxoList);
      _isListLoading = false;
    });
  }

  Widget _buildRemoveUtxoItem(UtxoState utxo, Animation<double> animation) {
    var offsetAnimation = AnimationUtil.buildSlideOutAnimation(animation);

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
          position: offsetAnimation,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: UtxoItemCard(
                  key: Key(utxo.utxoId),
                  onPressed: () async {
                    if (widget.onRemoveDropdown != null) {
                      widget.onRemoveDropdown!();
                    }

                    await Navigator.pushNamed(
                      context,
                      '/utxo-detail',
                      arguments: {
                        'utxo': utxo,
                        'id': widget.walletId,
                      },
                    );
                  },
                  utxo: utxo))),
    );
  }

  Widget _buildUtxoItem(UtxoState utxo, Animation<double> animation, bool isLastItem) {
    var offsetAnimation = _buildSlideAnimation(animation);
    return Column(
      children: [
        SlideTransition(
          position: offsetAnimation,
          child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: UtxoItemCard(
                  key: Key(utxo.utxoId),
                  onPressed: () async {
                    if (widget.onRemoveDropdown != null) {
                      widget.onRemoveDropdown!();
                    }

                    await Navigator.pushNamed(
                      context,
                      '/utxo-detail',
                      arguments: {
                        'utxo': utxo,
                        'id': widget.walletId,
                      },
                    );
                  },
                  utxo: utxo)),
        ),
        isLastItem ? CoconutLayout.spacing_1000h : CoconutLayout.spacing_200h,
      ],
    );
  }

  bool _isListChanged(List<UtxoState> oldList, List<UtxoState> newList) {
    if (oldList.length != newList.length) return true;

    final oldMap = {for (var utxo in oldList) utxo.transactionHash: utxo};
    final newMap = {for (var utxo in newList) utxo.transactionHash: utxo};

    // 한쪽에만 존재하는 transactionHash가 있는 경우
    if (!oldMap.keys.toSet().containsAll(newMap.keys) ||
        !newMap.keys.toSet().containsAll(oldMap.keys)) {
      return true;
    }

    // 동일한 transactionHash에 대해 status가 다르면 변경
    for (var txHash in oldMap.keys) {
      final oldUtxo = oldMap[txHash]!;
      final newUtxo = newMap[txHash]!;

      if (oldUtxo.status != newUtxo.status) return true;
    }
    return false;
  }

  @override
  void dispose() {
    super.dispose();
  }
}
