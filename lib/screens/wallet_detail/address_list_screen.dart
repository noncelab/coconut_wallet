import 'dart:async';
import 'dart:ui';

import 'package:coconut_design_system/coconut_design_system.dart';
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
  /// 페이지네이션
  late final AddressListViewModel viewModel;
  final int _limit = kAddressPaginationLimit;
  int _receivingAddressPage = 0;
  int _changeAddressPage = 0;
  int _receivingInitialCursor = kInitialAddressCount;
  int _changeInitialCursor = kInitialAddressCount;
  bool _isFirstLoadRunning = true;
  bool _isLoadMoreRunning = false;
  bool isReceivingSelected = true;

  /// 툴팁
  final GlobalKey _depositTooltipKey = GlobalKey();
  final GlobalKey _changeTooltipKey = GlobalKey();
  late RenderBox _depositTooltipIconRenderBox;
  late RenderBox _changeTooltipIconRenderBox;
  Offset _depositTooltipIconPosition = Offset.zero;
  Offset _changeTooltipIconPosition = Offset.zero;
  bool _depositTooltipVisible = false;
  bool _changeTooltipVisible = false;
  Timer? _tooltipTimer;
  int _tooltipRemainingTime = 5;

  /// 스크롤
  double topPadding = 0;
  final bool _isScrollOverTitleHeight = false;
  late ScrollController _controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => viewModel,
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
                Scaffold(
                    extendBodyBehindAppBar: true,
                    backgroundColor: CoconutColors.black,
                    appBar: AppBar(
                      scrolledUnderElevation: 0,
                      backgroundColor: _isScrollOverTitleHeight
                          ? CoconutColors.black.withOpacity(0.5)
                          : CoconutColors.black,
                      toolbarHeight: kToolbarHeight + 30,
                      leading: IconButton(
                        icon: SvgPicture.asset(
                          'assets/svg/arrow-back.svg',
                          colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                          width: 24,
                          height: 24,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      actions: [
                        IconButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/address-search',
                                arguments: {'id': widget.id});
                          },
                          icon: const Icon(Icons.search_rounded, color: CoconutColors.white),
                        ),
                      ],
                      flexibleSpace: _isScrollOverTitleHeight
                          ? ClipRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                                child: Container(
                                  color: CoconutColors.white.withOpacity(0.6),
                                ),
                              ),
                            )
                          : null,
                      title: Text(
                        t.address_list_screen.wallet_name(name: viewModel.walletBaseItem!.name),
                        style: CoconutTypography.heading4_18,
                      ),
                      centerTitle: true,
                      bottom: PreferredSize(
                        preferredSize: const Size.fromHeight(50.0),
                        child: toolbarWidget(),
                      ),
                    ),
                    body: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: _isFirstLoadRunning
                          ? const Center(child: CircularProgressIndicator())
                          : Column(
                              children: [
                                Expanded(
                                  child: Stack(
                                    children: [
                                      ListView.builder(
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
                                                          color:
                                                              CoconutColors.white.withOpacity(0.7),
                                                        ),
                                                      ),
                                                    ),
                                                    qrData: addressList[index].address,
                                                    title: t.address_list_screen.address_index(
                                                        index: addressList[index].index)));
                                          },
                                          address: addressList[index].address,
                                          derivationPath: addressList[index].derivationPath,
                                          isUsed: addressList[index].isUsed,
                                          balanceInSats: addressList[index].total,
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
                              ],
                            ),
                    )),
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
    viewModel = AddressListViewModel(context.read<WalletProvider>(), _onCursorUpdate, widget.id);
    _controller = ScrollController();
    _initializeAddressList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.addListener(_nextLoad);
      _depositTooltipIconRenderBox =
          _depositTooltipKey.currentContext!.findRenderObject() as RenderBox;
      _depositTooltipIconPosition = _depositTooltipIconRenderBox.localToGlobal(Offset.zero);

      _changeTooltipIconRenderBox =
          _changeTooltipKey.currentContext!.findRenderObject() as RenderBox;
      _changeTooltipIconPosition = _changeTooltipIconRenderBox.localToGlobal(Offset.zero);
    });
  }

  Future<void> _initializeAddressList() async {
    final showOnlyUnusedAddresses = context.read<PreferenceProvider>().showOnlyUnusedAddresses;
    _receivingAddressPage = 0;
    _changeAddressPage = 0;
    _receivingInitialCursor = kInitialAddressCount;
    _changeInitialCursor = kInitialAddressCount;
    _isFirstLoadRunning = true;
    await viewModel.initializeAddressList(kInitialAddressCount, showOnlyUnusedAddresses);
    _isFirstLoadRunning = false;
  }

  void scrollToTop() {
    _controller.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.decelerate);
  }

  Widget toolbarWidget() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
          ),
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
                  iconKey: _depositTooltipKey,
                  onTap: () {
                    setState(() {
                      isReceivingSelected = true;
                    });
                    scrollToTop();
                    _removeTooltip();
                  },
                  onTapDown: (_) {
                    _showTooltip(
                      context,
                      true,
                    );
                  },
                )),
                Expanded(
                    child: TooltipButton(
                  isSelected: !isReceivingSelected,
                  text: t.address_list_screen.change,
                  isLeft: false,
                  iconKey: _changeTooltipKey,
                  onTap: () {
                    setState(() {
                      isReceivingSelected = false;
                    });
                    scrollToTop();
                    _removeTooltip();
                  },
                  onTapDown: (_) {
                    _showTooltip(
                      context,
                      false,
                    );
                  },
                )),
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
                      _initializeAddressList();
                      scrollToTop();
                    },
                    child: Container(
                      color: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Sizes.size16,
                        vertical: Sizes.size6,
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
      ],
    );
  }

  Widget tooltipWidget(BuildContext context) {
    if (_depositTooltipVisible) {
      _depositTooltipIconRenderBox =
          _depositTooltipKey.currentContext!.findRenderObject() as RenderBox;
      _depositTooltipIconPosition = _depositTooltipIconRenderBox.localToGlobal(Offset.zero);

      return Positioned(
        top: widget.isFullScreen
            ? _depositTooltipIconPosition.dy + _depositTooltipIconRenderBox.size.height
            : _depositTooltipIconPosition.dy - 70,
        left: _depositTooltipIconPosition.dx - 30,
        right: MediaQuery.of(context).size.width - _depositTooltipIconPosition.dx - 200,
        child: CoconutToolTip(
          onTapRemove: () => _removeTooltip(),
          width: MediaQuery.sizeOf(context).width,
          isPlacementTooltipVisible: _depositTooltipVisible,
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
            : _changeTooltipIconPosition.dy - 70,
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

  /// '사용 전 주소만 보기' 옵션 사용시, 저장된 WalletAddress 상태에 따라 cursor 값이 변경되어야 한다.
  /// 기존에 있는 AddressList는 그대로 두고 페이지네이션 정보만 초기 상태처럼 관리한다.
  void _onCursorUpdate(bool isChange, int cursor) {
    Logger.log("[onCursorUpdate] isChange = $isChange, cursor = $cursor");
    if (isChange) {
      _changeInitialCursor = cursor;
      _changeAddressPage = _isFirstLoadRunning ? 0 : -1;
      Logger.log(
          "_changeInitialCursor = $_changeInitialCursor, _changeAddressPage = $_changeAddressPage");
    } else {
      _receivingInitialCursor = cursor;
      _receivingAddressPage = _isFirstLoadRunning ? 0 : -1;
      Logger.log(
          "_receivingInitialCursor = $_receivingInitialCursor, _receivingAddressPage = $_receivingAddressPage");
    }
  }

  Future<void> _nextLoad() async {
    if (_isFirstLoadRunning || _isLoadMoreRunning || _controller.position.extentAfter > 500) {
      return;
    }

    setState(() {
      _isLoadMoreRunning = true;
    });

    List<WalletAddress> newAddresses = [];
    try {
      final initialCursor = !isReceivingSelected ? _changeInitialCursor : _receivingInitialCursor;
      final pageIndex = !isReceivingSelected ? _changeAddressPage : _receivingAddressPage;
      newAddresses = await viewModel.walletProvider.getWalletAddressList(
          viewModel.walletBaseItem!,
          initialCursor + pageIndex * _limit,
          _limit,
          !isReceivingSelected,
          context.read<PreferenceProvider>().showOnlyUnusedAddresses,
          _onCursorUpdate);

      // UI 업데이트
      if (mounted) {
        setState(() {
          if (isReceivingSelected) {
            viewModel.receivingAddressList.addAll(newAddresses);
            _receivingAddressPage += 1;
          } else {
            viewModel.changeAddressList.addAll(newAddresses);
            _changeAddressPage += 1;
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
        _addAddressesWithGapLimit(newAddresses, !isReceivingSelected);
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
    setState(() {
      _tooltipRemainingTime = 0;
      _depositTooltipVisible = false;
      _changeTooltipVisible = false;
    });
    if (_tooltipTimer != null) {
      _tooltipTimer!.cancel();
    }
  }

  void _showTooltip(BuildContext context, bool isLeft) {
    _removeTooltip();
    if (isLeft) {
      setState(() {
        _depositTooltipVisible = true;
        _changeTooltipVisible = false;
      });
    } else {
      setState(() {
        _depositTooltipVisible = false;
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
