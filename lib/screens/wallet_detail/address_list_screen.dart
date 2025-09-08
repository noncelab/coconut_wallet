import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/constants/address.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/address_list_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/card/address_list_address_item_card.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/common/qrcode_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:tuple/tuple.dart';

class AddressListScreen extends StatefulWidget {
  final int id;
  final bool isFullScreen;
  final double paddingTop;

  const AddressListScreen(
      {super.key, required this.id, this.isFullScreen = true, this.paddingTop = 0});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  /// 페이지네이션
  late final AddressListViewModel viewModel;
  bool _isInitializing = false;
  bool _isLoadMoreRunning = false;
  bool _isScrollingToTop = false;
  bool _isReceivingSelected = true;

  final GlobalKey _appBarKey = GlobalKey();
  final GlobalKey _toolTipKey = GlobalKey();
  Size _appBarSize = const Size(0, 0);
  Size _toolTipSize = const Size(0, 0);

  /// 스크롤
  final bool _isScrollOverTitleHeight = false;
  late ScrollController _controller;
  late BitcoinUnit _currentUnit;

  @override
  Widget build(BuildContext context) {
    final Tuple2<bool, bool> isTooltipDisabled =
        context.select<PreferenceProvider, Tuple2<bool, bool>>(
      (provider) => Tuple2(provider.isReceivingTooltipDisabled, provider.isChangeTooltipDisabled),
    );
    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Consumer<AddressListViewModel>(
        builder: (context, viewModel, child) {
          List<WalletAddress> addressList =
              _isReceivingSelected ? viewModel.receivingAddressList : viewModel.changeAddressList;
          return Scaffold(
              extendBodyBehindAppBar: true,
              backgroundColor: CoconutColors.black,
              appBar: _buildAppBar(context),
              body: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                ),
                child: Column(
                  children: [
                    _buildSegmentedControl(),
                    _buildShowOnlyUsedAddressesButton(),
                    Expanded(
                      child: _buildAddressList(addressList, isTooltipDisabled),
                    ),
                  ],
                ),
              ));
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final preferenceProvider = context.read<PreferenceProvider>();

    viewModel = AddressListViewModel(context.read<WalletProvider>(), widget.id);
    _currentUnit = preferenceProvider.currentUnit;
    _controller = ScrollController();
    _initializeAddressList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_appBarKey.currentContext?.mounted ?? false) {
        final renderBox = _appBarKey.currentContext!.findRenderObject() as RenderBox;
        final renderSize = renderBox.size;
        final topPadding = widget.isFullScreen ? 0.0 : MediaQuery.of(context).padding.top;
        setState(() {
          _appBarSize = Size(renderSize.width, renderSize.height + topPadding);
        });
      }

      _controller.addListener(_nextLoad);
      _updateTooltipSize();
    });
  }

  Future<void> _initializeAddressList() async {
    if (_isInitializing) return;

    if (mounted) {
      setState(() {
        _isInitializing = true;
      });
    }

    final showOnlyUnusedAddresses = context.read<PreferenceProvider>().showOnlyUnusedAddresses;

    if (_isReceivingSelected) {
      viewModel.receivingAddressList.clear();
    } else {
      viewModel.changeAddressList.clear();
    }

    await viewModel.initializeAddressList(kInitialAddressCount, showOnlyUnusedAddresses);

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> scrollToTop() async {
    _isScrollingToTop = true;
    if (_controller.hasClients) {
      await _controller.animateTo(0,
          duration: const Duration(milliseconds: 500), curve: Curves.decelerate);
    }
    _isScrollingToTop = false;
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return CoconutAppBar.build(
        context: context,
        entireWidgetKey: _appBarKey,
        backgroundColor:
            _isScrollOverTitleHeight ? CoconutColors.black.withOpacity(0.5) : CoconutColors.black,
        title: t.address_list_screen.wallet_name(name: viewModel.walletBaseItem!.name),
        actionButtonList: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, '/address-search', arguments: {'id': widget.id});
            },
            icon: const Icon(Icons.search_rounded, color: CoconutColors.white),
          ),
        ]);
  }

  void _updateTooltipSize() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final context = _toolTipKey.currentContext;
      if (context != null && context.mounted) {
        final renderBox = context.findRenderObject();
        if (renderBox is RenderBox && renderBox.hasSize) {
          final newSize = renderBox.size;
          if (_toolTipSize != newSize) {
            setState(() {
              _toolTipSize = newSize;
            });
          }
        }
      }
    });
  }

  Widget _buildShowOnlyUsedAddressesButton() {
    return Selector<PreferenceProvider, bool>(
        selector: (_, viewModel) => viewModel.showOnlyUnusedAddresses,
        builder: (context, showOnlyUnusedAddresses, child) {
          return GestureDetector(
            onTap: () {
              context
                  .read<PreferenceProvider>()
                  .changeShowOnlyUnusedAddresses(!showOnlyUnusedAddresses);
              scrollToTop().then((_) => _initializeAddressList());
            },
            child: Container(
              color: Colors.transparent,
              padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 8),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/svg/check.svg',
                    colorFilter: ColorFilter.mode(
                        showOnlyUnusedAddresses ? CoconutColors.white : CoconutColors.gray700,
                        BlendMode.srcIn),
                    width: 10,
                    height: 10,
                  ),
                  CoconutLayout.spacing_100w,
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        t.address_list_screen.show_only_unused_address,
                        style: CoconutTypography.body3_12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }

  Widget _buildSegmentedControl() {
    return Padding(
      padding: EdgeInsets.only(top: _appBarSize.height),
      child: CoconutSegmentedControl(
          labels: [t.address_list_screen.receiving, t.address_list_screen.change],
          isSelected: [_isReceivingSelected, !_isReceivingSelected],
          onPressed: (index) async {
            if (index == 0) {
              if (!_isReceivingSelected) {
                setState(() {
                  _isReceivingSelected = true;
                });
                _updateTooltipSize();
              }
            } else {
              if (_isReceivingSelected) {
                setState(() {
                  _isReceivingSelected = false;
                });
                _updateTooltipSize();
              }
            }
            await scrollToTop();
            await _initializeAddressList();
          }),
    );
  }

  Widget _buildTooltipSection() {
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        child: Column(
          children: [
            CoconutLayout.spacing_100h,
            if (_isReceivingSelected)
              Selector<PreferenceProvider, bool>(
                selector: (context, provider) => provider.isReceivingTooltipDisabled,
                builder: (context, isReceivingTooltipDisabled, child) {
                  return _buildAnimatedTooltip(
                    isDisabled: isReceivingTooltipDisabled,
                    text: t.tooltip.address_receiving,
                    onDisable: () =>
                        context.read<PreferenceProvider>().setReceivingTooltipDisabledPermanently(),
                  );
                },
              ),
            if (!_isReceivingSelected)
              Selector<PreferenceProvider, bool>(
                selector: (context, provider) => provider.isChangeTooltipDisabled,
                builder: (context, isChangeTooltipDisabled, child) {
                  return _buildAnimatedTooltip(
                    isDisabled: isChangeTooltipDisabled,
                    text: t.tooltip.address_change,
                    onDisable: () =>
                        context.read<PreferenceProvider>().setChangeTooltipDisabledPermanently(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedTooltip({
    required bool isDisabled,
    required String text,
    required VoidCallback onDisable,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      height: isDisabled ? 0 : null,
      curve: Curves.easeInOut,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 500),
        opacity: isDisabled ? 0.0 : 1.0,
        child: Column(
          children: [
            _buildTooltip(text, onDisable),
            CoconutLayout.spacing_700h,
          ],
        ),
      ),
    );
  }

  Widget _buildTooltip(String text, VoidCallback onTap) {
    return Container(
      key: _toolTipKey,
      width: MediaQuery.sizeOf(context).width,
      padding: const EdgeInsets.only(top: 14, left: 12, right: 12, bottom: 2),
      decoration: BoxDecoration(
        color: CoconutColors.gray800,
        borderRadius: BorderRadius.circular(
          CoconutStyles.radius_250,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            'assets/svg/circle-info.svg',
            colorFilter: const ColorFilter.mode(
              CoconutColors.white,
              BlendMode.srcIn,
            ),
          ),
          CoconutLayout.spacing_200w,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: CoconutTypography.body3_12,
                ),
                CoconutLayout.spacing_50h,
                CoconutUnderlinedButton(
                    padding: const EdgeInsets.only(top: 8, right: 8, bottom: 8),
                    text: t.tooltip.dont_show_again,
                    textStyle: CoconutTypography.body3_12,
                    onTap: onTap)
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildAddressList(
    List<WalletAddress> addressList,
    Tuple2<bool, bool> isTooltipDisabled,
  ) {
    return _isInitializing
        ? const Center(child: CircularProgressIndicator())
        : NotificationListener<ScrollNotification>(
            onNotification: (ScrollNotification notification) {
              if (_controller.hasClients &&
                  (notification is ScrollEndNotification) &&
                  ((_isReceivingSelected && !isTooltipDisabled.item1) ||
                      (!_isReceivingSelected && !isTooltipDisabled.item2))) {
                final currentOffset = _controller.offset;
                final scrollTreshold = _appBarSize.height + 32 + widget.paddingTop;
                Future.microtask(() {
                  if (!_controller.hasClients) return;
                  if (currentOffset < scrollTreshold / 2) {
                    _controller.animateTo(
                      0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  } else if (currentOffset < scrollTreshold) {
                    _controller.animateTo(
                      scrollTreshold,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return true;
              }

              return false;
            },
            child: CustomScrollView(
              controller: _controller,
              slivers: [
                SliverToBoxAdapter(child: _buildTooltipSection()),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return Container(
                        color: CoconutColors.black,
                        child: Column(
                          children: [
                            AddressItemCard(
                              onPressed: () {
                                CommonBottomSheets.showBottomSheet_90(
                                  context: context,
                                  child: QrcodeBottomSheet(
                                    qrcodeTopWidget: Text(
                                      addressList[index].derivationPath,
                                      style: CoconutTypography.body2_14.merge(
                                        TextStyle(
                                          color: CoconutColors.white.withOpacity(0.7),
                                        ),
                                      ),
                                    ),
                                    qrData: addressList[index].address,
                                    isAddress: true,
                                    title: t.address_list_screen
                                        .address_index(index: addressList[index].index),
                                  ),
                                );
                              },
                              address: addressList[index].address,
                              derivationPath: addressList[index].derivationPath,
                              isUsed: addressList[index].isUsed,
                              balanceInSats: addressList[index].total,
                              currentUnit: _currentUnit,
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: addressList.length,
                  ),
                ),
                if (_isLoadMoreRunning)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 40, top: 20),
                      child: Center(
                        child: CircularProgressIndicator(color: CoconutColors.white),
                      ),
                    ),
                  ),
              ],
            ),
          );
  }

  Future<void> _nextLoad() async {
    final currentOffset = _controller.offset;
    if (currentOffset < _appBarSize.height + widget.paddingTop + 100) {
      final provider = context.read<PreferenceProvider>();
      final isTooltipDisabled = Tuple2(
        provider.isReceivingTooltipDisabled,
        provider.isChangeTooltipDisabled,
      );
      if ((_isReceivingSelected && !isTooltipDisabled.item1) ||
          (!_isReceivingSelected && !isTooltipDisabled.item2)) {
        // 스크롤이 _appBarSize.height + 32 부근에 도달하면 멈추도록 설정
        if (_controller.position.pixels.toInt() == _appBarSize.height + widget.paddingTop + 32) {
          _controller.jumpTo(_appBarSize.height + widget.paddingTop + 32);
        }
      }
    }

    if (_isInitializing || _isLoadMoreRunning || _controller.position.extentAfter > 500) {
      return;
    }

    // 현재 탭 상태 저장 (로딩 중 탭 변경 시 데이터 추가 방지)
    final wasReceivingSelected = _isReceivingSelected;

    setState(() {
      _isLoadMoreRunning = true;
    });

    List<WalletAddress> newAddresses = [];
    try {
      final cursor =
          !_isReceivingSelected ? viewModel.changeInitialCursor : viewModel.receivingInitialCursor;
      newAddresses = await viewModel.getWalletAddressList(
        viewModel.walletBaseItem!,
        cursor,
        kAddressLoadCount,
        !_isReceivingSelected,
        context.read<PreferenceProvider>().showOnlyUnusedAddresses,
      );

      // UI 업데이트 - 탭 상태가 변경되지 않았을 때만 데이터 추가
      if (mounted && wasReceivingSelected == _isReceivingSelected && !_isScrollingToTop) {
        setState(() {
          if (_isReceivingSelected) {
            viewModel.receivingAddressList.addAll(newAddresses);
          } else {
            viewModel.changeAddressList.addAll(newAddresses);
          }
        });
      }
    } catch (e) {
      Logger.log(e.toString());
    } finally {
      // 로딩 상태 해제
      if (mounted) {
        setState(() {
          _isLoadMoreRunning = false;
        });
        // 탭 상태가 변경되지 않았을 때만 백그라운드 저장
        if (wasReceivingSelected == _isReceivingSelected) {
          _addAddressesWithGapLimit(newAddresses, !_isReceivingSelected);
        }
      }
    }
  }

  /// 추후 다시 조회할 경우 조회 속도 향상을 위해 백그라운드에서 주소를 저장
  void _addAddressesWithGapLimit(List<WalletAddress> newAddresses, bool isChange) {
    if (viewModel.walletBaseItem == null) {
      return;
    }
    // 백그라운드에서 비동기적으로 실행하여 UI 블로킹 방지
    Future.microtask(() async {
      try {
        await viewModel.walletProvider.addAddressesWithGapLimit(
          walletItemBase: viewModel.walletBaseItem!,
          newAddresses: newAddresses,
          isChange: isChange,
        );
      } catch (e) {
        Logger.error('[_preloadAddressesInBackground] Failed to preload addresses: $e');
      }
    });
  }
}
