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
import 'package:coconut_wallet/widgets/button/tooltip_button.dart';
import 'package:coconut_wallet/widgets/card/address_list_address_item_card.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/common/qrcode_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';

class AddressListScreen extends StatefulWidget {
  final int id;
  final bool isFullScreen;

  const AddressListScreen({super.key, required this.id, this.isFullScreen = true});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  bool _isTapOnTooltipButton(Offset globalPosition) {
    final keys = [_receivingTooltipKey, _changeTooltipKey];

    for (final key in keys) {
      final context = key.currentContext;
      if (context == null) continue;

      final box = context.findRenderObject() as RenderBox;
      final position = box.localToGlobal(Offset.zero);
      final size = box.size;
      final rect = position & size;

      if (rect.contains(globalPosition)) {
        return true;
      }
    }

    return false;
  }

  /// 페이지네이션
  late final AddressListViewModel viewModel;
  bool _isInitializing = false;
  bool _isLoadMoreRunning = false;
  bool _isScrollingToTop = false;
  bool isReceivingSelected = true;

  /// 툴팁
  final GlobalKey _receivingTooltipKey = GlobalKey();
  final GlobalKey _changeTooltipKey = GlobalKey();
  final GlobalKey _toolbarWidgetKey = GlobalKey();

  Offset _receivingTooltipIconPosition = Offset.zero;
  Offset _changeTooltipIconPosition = Offset.zero;

  late RenderBox _receivingTooltipIconRenderBox;
  late RenderBox _changeTooltipIconRenderBox;

  final GlobalKey _appBarKey = GlobalKey();
  Size _appBarSize = const Size(0, 0);

  bool _receivingTooltipVisible = false;
  bool _changeTooltipVisible = false;
  Timer? _tooltipTimer;
  int _tooltipRemainingTime = 5;

  /// 스크롤
  final bool _isScrollOverTitleHeight = false;
  late ScrollController _controller;
  late BitcoinUnit _currentUnit;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Consumer<AddressListViewModel>(
        builder: (context, viewModel, child) {
          List<WalletAddress> addressList =
              isReceivingSelected ? viewModel.receivingAddressList : viewModel.changeAddressList;
          return PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, _) {
              _removeTooltip();
            },
            child: Stack(
              children: [
                GestureDetector(
                  onTapDown: (details) {
                    if (!_isTapOnTooltipButton(details.globalPosition)) {
                      _removeTooltip();
                    }
                  },
                  child: Scaffold(
                      extendBodyBehindAppBar: true,
                      backgroundColor: CoconutColors.black,
                      appBar: _buildAppBar(context),
                      body: Column(
                        children: [
                          _buildSegmentedControl(),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: _isInitializing
                                  ? const Center(child: CircularProgressIndicator())
                                  : GestureDetector(
                                      onTapDown: (_) {
                                        _removeTooltip();
                                      },
                                      behavior: HitTestBehavior.opaque,
                                      child: Stack(
                                        children: [
                                          NotificationListener<UserScrollNotification>(
                                            onNotification: (notification) {
                                              if (notification.direction != ScrollDirection.idle) {
                                                _removeTooltip();
                                              }
                                              return false;
                                            },
                                            child: ListView.builder(
                                              padding: EdgeInsets.zero,
                                              controller: _controller,
                                              itemCount: addressList.length,
                                              itemBuilder: (context, index) => AddressItemCard(
                                                onPressed: () {
                                                  _removeTooltip();
                                                  CommonBottomSheets.showBottomSheet_90(
                                                      context: context,
                                                      child: QrcodeBottomSheet(
                                                          qrcodeTopWidget: Text(
                                                            addressList[index].derivationPath,
                                                            style: CoconutTypography.body2_14.merge(
                                                              TextStyle(
                                                                color: CoconutColors.white
                                                                    .withOpacity(0.7),
                                                              ),
                                                            ),
                                                          ),
                                                          qrData: addressList[index].address,
                                                          title: t.address_list_screen
                                                              .address_index(
                                                                  index:
                                                                      addressList[index].index)));
                                                },
                                                address: addressList[index].address,
                                                derivationPath: addressList[index].derivationPath,
                                                isUsed: addressList[index].isUsed,
                                                balanceInSats: addressList[index].total,
                                                currentUnit: _currentUnit,
                                              ),
                                            ),
                                          ),
                                          if (_isLoadMoreRunning)
                                            Positioned(
                                              left: 0,
                                              right: 0,
                                              bottom: 40,
                                              child: Container(
                                                padding: const EdgeInsets.all(30),
                                                child: const Center(
                                                  child: CircularProgressIndicator(
                                                      color: CoconutColors.white),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      )),
                ),
                //
                tooltipWidget(context),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    if (_tooltipTimer != null) {
      _tooltipTimer!.cancel();
      _tooltipTimer = null;
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    viewModel = AddressListViewModel(context.read<WalletProvider>(), widget.id);
    _currentUnit = context.read<PreferenceProvider>().currentUnit;
    _controller = ScrollController();
    _initializeAddressList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.addListener(_nextLoad);

      if (_appBarKey.currentContext != null) {
        final appBarRenderBox = _appBarKey.currentContext?.findRenderObject() as RenderBox;
        _appBarSize = appBarRenderBox.size;
      }

      _receivingTooltipIconRenderBox =
          _receivingTooltipKey.currentContext!.findRenderObject() as RenderBox;
      _receivingTooltipIconPosition = _receivingTooltipIconRenderBox.localToGlobal(Offset.zero);

      _changeTooltipIconRenderBox =
          _changeTooltipKey.currentContext!.findRenderObject() as RenderBox;
      _changeTooltipIconPosition = _changeTooltipIconRenderBox.localToGlobal(Offset.zero);
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

    if (isReceivingSelected) {
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

  Widget _buildSegmentedControl() {
    return Container(
      padding: EdgeInsets.only(top: _appBarSize.height),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [CoconutColors.black, CoconutColors.black.withOpacity(0.8), Colors.transparent],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: Column(
        key: _toolbarWidgetKey,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: CoconutColors.white.withOpacity(0.15),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TooltipButton(
                      isSelected: isReceivingSelected,
                      text: t.address_list_screen.receiving,
                      isLeft: true,
                      iconKey: _receivingTooltipKey,
                      iconPadding: const EdgeInsets.all(8.0),
                      onTap: () async {
                        if (isReceivingSelected) {
                          await scrollToTop();
                          await _initializeAddressList();
                        } else {
                          setState(() {
                            isReceivingSelected = true;
                          });
                          await scrollToTop();
                          await _initializeAddressList();
                        }
                        _removeTooltip();
                      },
                      onTapDown: (_) {
                        _showTooltip(
                          context,
                          true,
                        );
                      },
                    ),
                  ),
                  Expanded(
                    child: TooltipButton(
                      isSelected: !isReceivingSelected,
                      text: t.address_list_screen.change,
                      isLeft: false,
                      iconKey: _changeTooltipKey,
                      iconPadding: const EdgeInsets.all(8.0),
                      onTap: () async {
                        if (!isReceivingSelected) {
                          await scrollToTop();
                          await _initializeAddressList();
                        } else {
                          setState(() {
                            isReceivingSelected = false;
                          });
                          await scrollToTop();
                          await _initializeAddressList();
                        }
                        _removeTooltip();
                      },
                      onTapDown: (_) {
                        _showTooltip(
                          context,
                          false,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Selector<PreferenceProvider, bool>(
              selector: (_, viewModel) => viewModel.showOnlyUnusedAddresses,
              builder: (context, showOnlyUnusedAddresses, child) {
                return Row(
                  children: [
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        context
                            .read<PreferenceProvider>()
                            .changeShowOnlyUnusedAddresses(!showOnlyUnusedAddresses);
                        scrollToTop().then((_) => _initializeAddressList());
                      },
                      child: Container(
                        color: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: Sizes.size16,
                        ),
                        child: Row(
                          children: [
                            SvgPicture.asset(
                              'assets/svg/check.svg',
                              colorFilter: ColorFilter.mode(
                                  showOnlyUnusedAddresses
                                      ? CoconutColors.white
                                      : CoconutColors.gray700,
                                  BlendMode.srcIn),
                              width: 10,
                              height: 10,
                            ),
                            CoconutLayout.spacing_100w,
                            Text(
                              t.address_list_screen.show_only_unused_address,
                              style: CoconutTypography.body3_12,
                            ),
                          ],
                        ),
                      ),
                    )
                  ],
                );
              }),
          CoconutLayout.spacing_400h
        ],
      ),
    );
  }

  Widget tooltipWidget(BuildContext context) {
    if (_receivingTooltipVisible) {
      _receivingTooltipIconRenderBox =
          _receivingTooltipKey.currentContext!.findRenderObject() as RenderBox;
      _receivingTooltipIconPosition = _receivingTooltipIconRenderBox.localToGlobal(Offset.zero);
      final tooltipIconPositionTop =
          _receivingTooltipIconPosition.dy + _receivingTooltipIconRenderBox.size.height;
      return Positioned(
        top: widget.isFullScreen
            ? tooltipIconPositionTop
            : tooltipIconPositionTop -
                MediaQuery.of(context).size.height *
                    0.1, // 0.1 : bottomSheet가 height * 0.9  만큼 차지하기 때문
        left: _receivingTooltipIconPosition.dx - 30,
        right: MediaQuery.of(context).size.width - _receivingTooltipIconPosition.dx - 200,
        child: CoconutToolTip(
          onTapRemove: () => _removeTooltip(),
          width: MediaQuery.sizeOf(context).width,
          isPlacementTooltipVisible: _receivingTooltipVisible,
          isBubbleClipperSideLeft: true,
          backgroundColor: CoconutColors.white,
          tooltipType: CoconutTooltipType.placement,
          brightness: Brightness.light,
          richText: RichText(
            text: TextSpan(
              text: t.tooltip.address_receiving,
              style: CoconutTypography.body3_12.setColor(CoconutColors.black).merge(
                    const TextStyle(
                      height: 1.3,
                    ),
                  ),
            ),
          ),
        ),
      );
    } else if (_changeTooltipVisible) {
      _changeTooltipIconRenderBox =
          _changeTooltipKey.currentContext!.findRenderObject() as RenderBox;
      _changeTooltipIconPosition = _changeTooltipIconRenderBox.localToGlobal(Offset.zero);
      return Positioned(
        top: widget.isFullScreen
            ? _changeTooltipIconPosition.dy + _changeTooltipIconRenderBox.size.height
            : _changeTooltipIconPosition.dy - 50,
        left: _changeTooltipIconPosition.dx - 200,
        right: MediaQuery.of(context).size.width -
            _changeTooltipIconPosition.dx +
            (_changeTooltipIconRenderBox.size.width) -
            46,
        child: CoconutToolTip(
          onTapRemove: () => _removeTooltip(),
          width: MediaQuery.sizeOf(context).width,
          isPlacementTooltipVisible: _changeTooltipVisible,
          isBubbleClipperSideLeft: false,
          backgroundColor: CoconutColors.white,
          tooltipType: CoconutTooltipType.placement,
          brightness: Brightness.light,
          richText: RichText(
            text: TextSpan(
              text: t.tooltip.address_change,
              style: CoconutTypography.body3_12.setColor(CoconutColors.black).merge(
                    const TextStyle(
                      height: 1.3,
                    ),
                  ),
            ),
          ),
        ),
      );
    }
    return Container();
  }

  Future<void> _nextLoad() async {
    if (_isInitializing || _isLoadMoreRunning || _controller.position.extentAfter > 500) {
      return;
    }

    // 현재 탭 상태 저장 (로딩 중 탭 변경 시 데이터 추가 방지)
    final wasReceivingSelected = isReceivingSelected;

    setState(() {
      _isLoadMoreRunning = true;
    });

    List<WalletAddress> newAddresses = [];
    try {
      final cursor =
          !isReceivingSelected ? viewModel.changeInitialCursor : viewModel.receivingInitialCursor;
      newAddresses = await viewModel.getWalletAddressList(
        viewModel.walletBaseItem!,
        cursor,
        kAddressLoadCount,
        !isReceivingSelected,
        context.read<PreferenceProvider>().showOnlyUnusedAddresses,
      );

      // UI 업데이트 - 탭 상태가 변경되지 않았을 때만 데이터 추가
      if (mounted && wasReceivingSelected == isReceivingSelected && !_isScrollingToTop) {
        setState(() {
          if (isReceivingSelected) {
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
        if (wasReceivingSelected == isReceivingSelected) {
          _addAddressesWithGapLimit(newAddresses, !isReceivingSelected);
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

  void _removeTooltip() {
    if (!_receivingTooltipVisible && !_changeTooltipVisible) return;
    setState(() {
      _tooltipRemainingTime = 0;
      _receivingTooltipVisible = false;
      _changeTooltipVisible = false;
    });
    if (_tooltipTimer != null) {
      _tooltipTimer!.cancel();
    }
  }

  void _showTooltip(BuildContext context, bool isLeft) {
    if (isLeft && _receivingTooltipVisible || !isLeft && _changeTooltipVisible) {
      debugPrint('Tooltip already visible');
      _removeTooltip();
      return;
    }

    _removeTooltip();
    if (isLeft) {
      setState(() {
        _receivingTooltipVisible = true;
        _changeTooltipVisible = false;
      });
    } else {
      setState(() {
        _receivingTooltipVisible = false;
        _changeTooltipVisible = true;
      });
    }

    _tooltipRemainingTime = 5;
    _tooltipTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_tooltipRemainingTime > 0) {
        _tooltipRemainingTime--;
      } else {
        setState(() {
          _removeTooltip();
        });

        timer.cancel();
      }
    });
  }
}
