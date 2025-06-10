import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
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

  double _topPadding = 0;
  final GlobalKey _appBarKey = GlobalKey();
  final GlobalKey _headerDropdownKey = GlobalKey();
  final GlobalKey _stickyHeaderDropdownKey = GlobalKey();

  final ValueNotifier<bool> _stickyHeaderVisibleNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _dropdownEnabledNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _dropdownVisibleNotifier = ValueNotifier<bool>(false);

  Size _appBarSize = const Size(0, 0);

  Offset _headerDropdownPosition = Offset.zero;
  Offset _stickyHeaderDropdownPosition = Offset.zero;

  Size _headerDropdownSize = Size.zero;
  Size _stickyHeaderDropdownSize = Size.zero;

  OverlayEntry? _statusBarTapOverlayEntry; // iOS 노치 터치 시 scrol to top

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Size topHeaderWidgetSize = const Size(0, 0);
      Size positionedTopWidgetSize = const Size(0, 0);

      if (_appBarKey.currentContext != null) {
        final appBarWidgetRenderBox = _appBarKey.currentContext?.findRenderObject() as RenderBox;
        _appBarSize = appBarWidgetRenderBox.size;
      }

      if (_headerDropdownKey.currentContext != null) {
        final topHeaderWidgetRenderBox =
            _headerDropdownKey.currentContext?.findRenderObject() as RenderBox;
        topHeaderWidgetSize = topHeaderWidgetRenderBox.size;
      }

      setState(() {
        _topPadding = topHeaderWidgetSize.height - positionedTopWidgetSize.height;
      });

      _scrollController.addListener(() {
        _hideDropdown();

        if (_scrollController.offset > _topPadding) {
          _showStickyHeaderAndUpdateDropdownPosition();
        } else {
          _hideStickyHeaderAndUpdateDropdownPosition();
        }
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
        create: (_) => _createViewModel(),
        update: (_, walletProvider, utxoTagProvider, viewModel) {
          viewModel ??= _createViewModel();
          return viewModel..updateProvider();
        },
        child: Builder(builder: (context) {
          return PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, _) {
              _hideDropdown();
            },
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _hideDropdown();
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
                    body: Selector<UtxoListViewModel, Tuple3<bool, bool, List<UtxoState>>>(
                        selector: (_, viewModel) => Tuple3(
                            viewModel.isSyncing, viewModel.isUtxoTagListEmpty, viewModel.utxoList),
                        builder: (context, data, child) {
                          final isSyncing = data.item1;
                          final isUtxoTagListEmpty = data.item2;
                          final utxoList = data.item3;

                          return CustomScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            controller: _scrollController,
                            semanticChildCount: isUtxoTagListEmpty ? 1 : utxoList.length,
                            slivers: [
                              if (isSyncing) const SliverToBoxAdapter(child: LoadingIndicator()),
                              CupertinoSliverRefreshControl(
                                onRefresh: () async {
                                  final viewModel = context.read<UtxoListViewModel>();
                                  viewModel.refetchFromDB();
                                },
                              ),
                              SliverToBoxAdapter(child: _buildHeader(context)),
                              UtxoList(
                                walletId: widget.id,
                                onRemoveDropdown: _hideDropdown,
                                onFirstBuildCompleted: () {
                                  if (!mounted) return;
                                  _dropdownEnabledNotifier.value = true;
                                },
                              ),
                            ],
                          );
                        }),
                  ),
                  _buildStickyHeader(context),
                  _buildUtxoOrderDropdownMenu(context),
                ],
              ),
            ),
          );
        }));
  }

  void _hideStickyHeaderAndUpdateDropdownPosition() {
    _stickyHeaderVisibleNotifier.value = false;

    if (_headerDropdownKey.currentContext != null) {
      final renderBox = _headerDropdownKey.currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      if (_headerDropdownPosition != position || _headerDropdownSize != size) {
        setState(() {
          _headerDropdownPosition = position;
          _headerDropdownSize = size;
        });
      }
    }
  }

  void _showStickyHeaderAndUpdateDropdownPosition() {
    _stickyHeaderVisibleNotifier.value = true;

    if (_stickyHeaderDropdownKey.currentContext != null) {
      final renderBox = _stickyHeaderDropdownKey.currentContext!.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;

      if (_stickyHeaderDropdownPosition != position || _stickyHeaderDropdownSize != size) {
        setState(() {
          _stickyHeaderDropdownPosition = position;
          _stickyHeaderDropdownSize = size;
        });
      }
    }
  }

  void _hideDropdown() {
    if (_dropdownVisibleNotifier.value) {
      _dropdownVisibleNotifier.value = false;
    }
  }

  Widget _buildHeader(BuildContext context) {
    final viewModel = context.read<UtxoListViewModel>();
    return ValueListenableBuilder<bool>(
        valueListenable: _dropdownEnabledNotifier,
        builder: (context, canShowDropdown, child) {
          return Selector<UtxoListViewModel, UtxoOrder>(
              selector: (_, viewModel) => viewModel.selectedUtxoOrder,
              builder: (context, selectedOrder, child) {
                return UtxoListHeader(
                    key: ValueKey(viewModel.utxoTagListKey),
                    dropdownGlobalKey: _headerDropdownKey,
                    canShowDropdown: canShowDropdown,
                    animatedBalanceData:
                        AnimatedBalanceData(viewModel.balance, viewModel.prevBalance),
                    selectedOption: selectedOrder.text,
                    utxoTagList: viewModel.utxoTagList,
                    selectedUtxoTagName: viewModel.selectedUtxoTagName,
                    onTapDropdown: () {
                      if (!canShowDropdown) return;
                      _dropdownVisibleNotifier.value = !_dropdownVisibleNotifier.value;
                      _hideStickyHeaderAndUpdateDropdownPosition();
                    },
                    onTagSelected: (tagName) {
                      viewModel.setSelectedUtxoTagName(tagName);
                    });
              });
        });
  }

  Widget _buildUtxoOrderDropdownMenu(BuildContext context) {
    final viewModel = context.read<UtxoListViewModel>();
    final selectedOrder = viewModel.selectedUtxoOrder;
    return ValueListenableBuilder<bool>(
        valueListenable: _dropdownEnabledNotifier,
        builder: (context, canShowDropdown, child) {
          return ValueListenableBuilder<bool>(
              valueListenable: _stickyHeaderVisibleNotifier,
              builder: (context, isStickyHeaderVisible, child) {
                return ValueListenableBuilder<bool>(
                    valueListenable: _dropdownVisibleNotifier,
                    builder: (context, isDropdownVisible, child) {
                      return UtxoOrderDropdown(
                        isVisible: isDropdownVisible,
                        positionTop: isStickyHeaderVisible
                            ? _stickyHeaderDropdownPosition.dy + _stickyHeaderDropdownSize.height
                            : _headerDropdownPosition.dy + _headerDropdownSize.height,
                        selectedOption: selectedOrder,
                        onOptionSelected: (filter) {
                          _hideDropdown();
                          if (isStickyHeaderVisible) {
                            _scrollController.animateTo(kToolbarHeight + 28,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut);
                          }
                          viewModel.updateUtxoFilter(filter);
                        },
                      );
                    });
              });
        });
  }

  Widget _buildStickyHeader(BuildContext context) {
    final viewModel = context.read<UtxoListViewModel>();
    final currentBalane = viewModel.balance;
    final prevBalance = viewModel.prevBalance;
    final totalCount = viewModel.utxoList.length;
    return ValueListenableBuilder<bool>(
        valueListenable: _dropdownEnabledNotifier,
        builder: (context, enableDropdown, _) {
          return ValueListenableBuilder<bool>(
              valueListenable: _stickyHeaderVisibleNotifier,
              builder: (context, isStickyHeaderVisible, _) {
                return Selector<UtxoListViewModel, UtxoOrder>(
                  selector: (_, viewModel) => viewModel.selectedUtxoOrder,
                  builder: (context, order, child) {
                    return UtxoListStickyHeader(
                      key: ValueKey(viewModel.utxoTagListKey),
                      dropdownGlobalKey: _stickyHeaderDropdownKey,
                      height: _appBarSize.height,
                      isVisible: isStickyHeaderVisible,
                      enableDropdown: enableDropdown,
                      animatedBalanceData: AnimatedBalanceData(currentBalane, prevBalance),
                      totalCount: totalCount,
                      selectedOption: order.text,
                      onTapDropdown: () {
                        _dropdownVisibleNotifier.value = !_dropdownVisibleNotifier.value;
                        _scrollController.jumpTo(_scrollController.offset);
                      },
                      removePopup: () {
                        _hideDropdown();
                      },
                    );
                  },
                );
              });
        });
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
    this.onRemoveDropdown,
    this.onFirstBuildCompleted,
  });

  final int walletId;
  final Function? onRemoveDropdown;
  final VoidCallback? onFirstBuildCompleted;

  @override
  State<UtxoList> createState() => _UtxoListState();
}

class _UtxoListState extends State<UtxoList> {
  late List<UtxoState> _displayedUtxoList = [];
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

          if (_isListChanged(_displayedUtxoList, utxoList)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _handleUtxoListChange(utxoList);
            });
          }

          return utxoList.isNotEmpty
              ? _buildSliverAnimatedList(_displayedUtxoList, selectedUtxoTagName)
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
    final isFirstLoad = _displayedUtxoList.isEmpty && utxoList.isNotEmpty;

    if (_isListLoading) return;
    _isListLoading = true;

    final oldUtxoMap = {for (var utxo in _displayedUtxoList) utxo.utxoId: utxo};
    final newUtxoMap = {for (var utxo in utxoList) utxo.utxoId: utxo};

    final List<int> insertedIndexes = [];
    final List<int> removedIndexes = [];

    for (int i = 0; i < utxoList.length; i++) {
      if (!oldUtxoMap.containsKey(utxoList[i].utxoId)) {
        insertedIndexes.add(i);
      }
    }

    for (int i = 0; i < _displayedUtxoList.length; i++) {
      if (!newUtxoMap.containsKey(_displayedUtxoList[i].utxoId)) {
        removedIndexes.add(i);
      }
    }

    setState(() {
      _displayedUtxoList = List.from(utxoList);
    });

    // 삭제된 인덱스 역순으로 삭제
    for (var index in removedIndexes.reversed) {
      if (index >= _displayedUtxoList.length) {
        debugPrint('❌ 리스트를 초과하는 인덱스 $index < ${_displayedUtxoList.length}');
        continue;
      }

      await Future.delayed(_animationDuration);
      _utxoListKey.currentState?.removeItem(
        index,
        (context, animation) => _buildRemoveUtxoItem(_displayedUtxoList[index], animation),
        duration: _duration,
      );
    }

    // 삽입된 인덱스 순서대로 추가
    for (var index in insertedIndexes) {
      await Future.delayed(_animationDuration);
      _utxoListKey.currentState?.insertItem(index, duration: _duration);
    }

    _isListLoading = false;
    if (isFirstLoad && widget.onFirstBuildCompleted != null) {
      widget.onFirstBuildCompleted!();
    }
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

    // 동일한 transactionHash에 대해 status와 tagList가 다르면 변경
    for (var txHash in oldMap.keys) {
      final oldUtxo = oldMap[txHash]!;
      final newUtxo = newMap[txHash]!;

      final oldTags = oldUtxo.tags ?? [];
      final newTags = newUtxo.tags ?? [];

      if (oldTags.length != newTags.length || !_equalTagLists(oldTags, newTags)) {
        return true;
      }
      if (oldUtxo.status != newUtxo.status) return true;
    }
    return false;
  }

  // tags 리스트를 비교하는 유틸 함수
  bool _equalTagLists(List<UtxoTag> a, List<UtxoTag> b) {
    // 순서를 고려하지 않는다면 Set 비교
    return Set.from(a) == Set.from(b);
  }

  @override
  void dispose() {
    super.dispose();
  }
}
