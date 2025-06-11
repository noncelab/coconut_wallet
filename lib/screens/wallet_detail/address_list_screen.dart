import 'dart:async';
import 'dart:ui';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
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
  static const int kFirstCount = 20;

  AddressListViewModel? viewModel;
  final int _limit = 5;
  int _receivingAddressPage = 0;
  int _changeAddressPage = 0;
  bool _isFirstLoadRunning = true;
  bool _isLoadMoreRunning = false;
  bool isReceivingSelected = true;

  /// 툴팁
  final GlobalKey _receivingTooltipKey = GlobalKey();
  final GlobalKey _changeTooltipKey = GlobalKey();
  final GlobalKey _toolbarWidgetKey = GlobalKey();

  Offset _receivingTooltipIconPosition = Offset.zero;
  Offset _changeTooltipIconPosition = Offset.zero;

  late RenderBox _receivingTooltipIconRenderBox;
  late RenderBox _changeTooltipIconRenderBox;

  Size _toolbarWidgetSize = const Size(0, 0);

  bool _receivingTooltipVisible = false;
  bool _changeTooltipVisible = false;
  Timer? _tooltipTimer;
  int _tooltipRemainingTime = 5;

  /// 스크롤
  double topPadding = 0;
  final bool _isScrollOverTitleHeight = false;
  late ScrollController _controller;
  late BitcoinUnit _currentUnit;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AddressListViewModel(
          Provider.of<WalletProvider>(context, listen: false), widget.id, kFirstCount),
      child: Consumer<AddressListViewModel>(
        builder: (context, viewModel, child) {
          if (this.viewModel == null) {
            this.viewModel = viewModel;
          }
          List<WalletAddress>? addressList =
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
                      appBar: AppBar(
                        scrolledUnderElevation: 0,
                        backgroundColor: _isScrollOverTitleHeight
                            ? CoconutColors.black.withOpacity(0.5)
                            : CoconutColors.black,
                        toolbarHeight: kToolbarHeight + 30,
                        leading: IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            icon: SvgPicture.asset('assets/svg/back.svg',
                                width: 24,
                                colorFilter:
                                    const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn))),
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
                        padding: EdgeInsets.only(
                          left: 10,
                          right: 10,
                          top: _toolbarWidgetSize.height +
                              kToolbarHeight +
                              MediaQuery.of(context).padding.top,
                        ),
                        child: _isFirstLoadRunning
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
                                        itemCount: addressList!.length,
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
                                                    title: t.address_list_screen
                                                        .address_index(index: index)));
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
                      )),
                ),
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
    _currentUnit = context.read<PreferenceProvider>().currentUnit;
    _isFirstLoadRunning = false;
    _controller = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.addListener(_nextLoad);
      RenderBox toolbarWidgetRenderBox;

      _receivingTooltipIconRenderBox =
          _receivingTooltipKey.currentContext!.findRenderObject() as RenderBox;
      _receivingTooltipIconPosition = _receivingTooltipIconRenderBox.localToGlobal(Offset.zero);

      _changeTooltipIconRenderBox =
          _changeTooltipKey.currentContext!.findRenderObject() as RenderBox;
      _changeTooltipIconPosition = _changeTooltipIconRenderBox.localToGlobal(Offset.zero);

      toolbarWidgetRenderBox = _toolbarWidgetKey.currentContext!.findRenderObject() as RenderBox;
      setState(() {
        _toolbarWidgetSize = toolbarWidgetRenderBox.size;
      });
    });
  }

  void scrollToTop() {
    _controller.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.decelerate);
  }

  Widget toolbarWidget() {
    return Container(
      key: _toolbarWidgetKey,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 10,
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
              iconKey: _receivingTooltipKey,
              iconPadding: const EdgeInsets.all(8.0),
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
              iconPadding: const EdgeInsets.all(8.0),
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

  void _nextLoad() {
    if (!_isFirstLoadRunning && !_isLoadMoreRunning && _controller.position.extentAfter < 100) {
      setState(() {
        _isLoadMoreRunning = true;
      });

      try {
        final newAddresses = viewModel?.walletProvider.getWalletAddressList(
            viewModel!.walletBaseItem!,
            kFirstCount +
                (isReceivingSelected ? _receivingAddressPage : _changeAddressPage) * _limit,
            _limit,
            !isReceivingSelected);

        setState(() {
          if (isReceivingSelected) {
            viewModel?.receivingAddressList?.addAll(newAddresses!);
            _receivingAddressPage += 1;
          } else {
            viewModel?.changeAddressList?.addAll(newAddresses!);
            _changeAddressPage += 1;
          }
        });
      } catch (e) {
        Logger.log(e.toString());
      } finally {
        Timer(const Duration(seconds: 1), () {
          setState(() {
            _isLoadMoreRunning = false;
          });
        });
      }
    }
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
