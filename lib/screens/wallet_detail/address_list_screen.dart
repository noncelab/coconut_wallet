import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart' as coconut;
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/address_list_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/card/address_list_address_item_card.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/common/qrcode_bottom_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AddressListScreen extends StatefulWidget {
  final int id;
  final bool isFullScreen;

  const AddressListScreen(
      {super.key, required this.id, this.isFullScreen = true});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  /// 페이지네이션
  static const int kFirstCount = 20;

  AddressListViewModel? viewModel;
  List<bool> _segmentedSelectedValue = [true, false];
  final int _limit = 5;
  int _receivingAddressPage = 0;
  int _changeAddressPage = 0;
  bool _isFirstLoadRunning = true;
  bool _isLoadMoreRunning = false;

  final GlobalKey _depositLabelKey = GlobalKey();
  final GlobalKey _changeLabelKey = GlobalKey();
  late RenderBox _depositLabelRenderBox;
  late RenderBox _changeLabelRenderBox;
  Offset _depositLabelPosition = Offset.zero;
  Offset _changeLabelPosition = Offset.zero;
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
  late ScrollController _controller;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AddressListViewModel(
          Provider.of<WalletProvider>(context, listen: false),
          widget.id,
          kFirstCount),
      child: Consumer<AddressListViewModel>(
        builder: (context, viewModel, child) {
          if (this.viewModel == null) {
            this.viewModel = viewModel;
          }
          List<coconut.Address>? addressList = isReceivingSelected
              ? viewModel.receivingAddressList
              : viewModel.changeAddressList;
          return PopScope(
            canPop: true,
            onPopInvokedWithResult: (didPop, _) {
              _removeTooltip();
            },
            child: Stack(
              children: [
                Scaffold(
                  backgroundColor: widget.isFullScreen
                      ? CoconutColors.black
                      : Colors.transparent,
                  appBar: CoconutAppBar.build(
                    context: context,
                    title: t.address_list_screen
                        .wallet_name(name: viewModel.walletBaseItem!.name),
                    hasRightIcon: false,
                    isBottom: !widget.isFullScreen,
                  ),
                  body: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                    ),
                    child: _isFirstLoadRunning
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            children: [
                              toolbarWidget(),
                              Expanded(
                                child: Stack(
                                  children: [
                                    ListView.builder(
                                      controller: _controller,
                                      itemCount: addressList!.length,
                                      itemBuilder: (context, index) =>
                                          AddressItemCard(
                                        onPressed: () {
                                          _removeTooltip();
                                          CommonBottomSheets
                                              .showCustomBottomSheet(
                                                  context: context,
                                                  child: QrcodeBottomSheet(
                                                      qrcodeTopWidget: Text(
                                                        addressList[index]
                                                            .derivationPath,
                                                        style: Styles.body2.merge(
                                                            const TextStyle(
                                                                color: MyColors
                                                                    .transparentWhite_70)),
                                                      ),
                                                      qrData: addressList[index]
                                                          .address,
                                                      title: t
                                                          .address_list_screen
                                                          .address_index(
                                                              index: index)));
                                        },
                                        address: addressList[index].address,
                                        derivationPath:
                                            addressList[index].derivationPath,
                                        isUsed: addressList[index].isUsed,
                                        balanceInSats:
                                            addressList[index].amount,
                                      ),
                                    ),
                                    Visibility(
                                      visible: _isLoadMoreRunning,
                                      child: Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 40,
                                        child: Container(
                                          padding: const EdgeInsets.all(30),
                                          child: const Center(
                                            child: CircularProgressIndicator(
                                                color: MyColors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                  ),
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

    _isFirstLoadRunning = false;
    _controller = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.addListener(_nextLoad);
      _depositLabelRenderBox =
          _depositLabelKey.currentContext!.findRenderObject() as RenderBox;
      _changeLabelRenderBox =
          _changeLabelKey.currentContext!.findRenderObject() as RenderBox;

      setState(() {
        _depositLabelPosition =
            _depositLabelRenderBox.localToGlobal(Offset.zero);
        _changeLabelPosition = _changeLabelRenderBox.localToGlobal(Offset.zero);
      });
    });
  }

  void scrollToTop() {
    _controller.animateTo(0,
        duration: const Duration(milliseconds: 500), curve: Curves.decelerate);
  }

  Widget toolbarWidget() {
    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          child: CoconutSegmentedControl(
            keys: [_depositLabelKey, _changeLabelKey],
            labels: [
              t.address_list_screen.receiving,
              t.address_list_screen.change
            ],
            isSelected: _segmentedSelectedValue,
            onPressed: (index) {
              setState(() {
                _segmentedSelectedValue = List.generate(
                    _segmentedSelectedValue.length, (i) => i == index);
                isReceivingSelected = _segmentedSelectedValue[0];

                scrollToTop();
                _removeTooltip();
              });
            },
          ),
        ),
        Positioned(
          left: _depositLabelPosition.dx + 10,
          top: 17,
          child: GestureDetector(
            onTapDown: (_) => _showTooltip(
              context,
              true,
            ),
            child: Container(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                key: _depositTooltipKey,
                Icons.info_outline_rounded,
                color: isReceivingSelected
                    ? MyColors.white
                    : MyColors.transparentWhite_40,
                size: 16,
              ),
            ),
          ),
        ),
        Positioned(
          left: _changeLabelPosition.dx + 10,
          top: 17,
          child: GestureDetector(
            onTapDown: (_) => _showTooltip(
              context,
              false,
            ),
            child: Container(
              padding: const EdgeInsets.all(8.0),
              child: Icon(
                key: _changeTooltipKey,
                Icons.info_outline_rounded,
                color: isReceivingSelected
                    ? MyColors.transparentWhite_40
                    : MyColors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget tooltipWidget(BuildContext context) {
    if (_depositTooltipVisible) {
      _depositTooltipIconRenderBox =
          _depositTooltipKey.currentContext!.findRenderObject() as RenderBox;
      _depositTooltipIconPosition =
          _depositTooltipIconRenderBox.localToGlobal(Offset.zero);

      return Positioned(
          top: widget.isFullScreen
              ? _depositTooltipIconPosition.dy +
                  _depositTooltipIconRenderBox.size.height
              : _depositTooltipIconPosition.dy - 70,
          left: _depositTooltipIconPosition.dx - 31,
          right: MediaQuery.of(context).size.width -
              _depositTooltipIconPosition.dx -
              150,
          child: GestureDetector(
            onTap: () => _removeTooltip(),
            child: ClipPath(
              clipper: LeftTriangleBubbleClipper(),
              child: Container(
                padding: const EdgeInsets.only(
                  top: 25,
                  left: 18,
                  right: 18,
                  bottom: 10,
                ),
                color: MyColors.white,
                child: Text(
                  t.tooltip.address_receiving,
                  style: Styles.caption.merge(TextStyle(
                    height: 1.3,
                    fontFamily: CustomFonts.text.getFontFamily,
                    color: MyColors.darkgrey,
                  )),
                ),
              ),
            ),
          ));
    } else if (_changeTooltipVisible) {
      _changeTooltipIconRenderBox =
          _changeTooltipKey.currentContext!.findRenderObject() as RenderBox;
      _changeTooltipIconPosition =
          _changeTooltipIconRenderBox.localToGlobal(Offset.zero);
      return Positioned(
          top: widget.isFullScreen
              ? _changeTooltipIconPosition.dy +
                  _changeTooltipIconRenderBox.size.height
              : _changeTooltipIconPosition.dy - 70,
          left: _changeTooltipIconPosition.dx - 150,
          right: MediaQuery.of(context).size.width -
              _changeTooltipIconPosition.dx +
              (_changeTooltipIconRenderBox.size.width) -
              43,
          child: GestureDetector(
            onTap: () => _removeTooltip(),
            child: ClipPath(
              clipper: RightTriangleBubbleClipper(),
              child: Container(
                padding: const EdgeInsets.only(
                  top: 25,
                  left: 18,
                  right: 18,
                  bottom: 10,
                ),
                color: MyColors.white,
                child: Text(
                  t.tooltip.address_change,
                  style: Styles.caption.merge(TextStyle(
                    height: 1.3,
                    fontFamily: CustomFonts.text.getFontFamily,
                    color: MyColors.darkgrey,
                  )),
                ),
              ),
            ),
          ));
    }
    return Container();
  }

  void _nextLoad() {
    if (!_isFirstLoadRunning &&
        !_isLoadMoreRunning &&
        _controller.position.extentAfter < 100) {
      setState(() {
        _isLoadMoreRunning = true;
      });

      try {
        final newAddresses = viewModel?.walletBase?.getAddressList(
            kFirstCount +
                (isReceivingSelected
                        ? _receivingAddressPage
                        : _changeAddressPage) *
                    _limit,
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
