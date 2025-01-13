import 'dart:async';
import 'dart:ui';

import 'package:coconut_lib/coconut_lib.dart' as coconut;
import 'package:coconut_wallet/model/data/wallet_list_item_base.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/screens/bottom_sheet/qrcode_bottom_sheet_screen.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/bottom_sheet.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/button/tooltip_button.dart';
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
  static const int FIRST_COUNT = 20;
  int _receivingAddressPage = 0;
  int _changeAddressPage = 0;
  final int _limit = 5;
  bool _isFirstLoadRunning = true;
  bool _isLoadMoreRunning = false;
  List<coconut.Address> _receivingAddressList = [];
  List<coconut.Address> _changeAddressList = [];
  late ScrollController _controller;
  late coconut.WalletBase _walletBase;
  late WalletListItemBase _walletBaseItem;
  bool isReceivingSelected = true;
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
  double topPadding = 0;
  final bool _isScrollOverTitleHeight = false;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController()..addListener(_nextLoad);
    final model = Provider.of<AppStateModel>(context, listen: false);

    _walletBaseItem = model.getWalletById(widget.id);
    _walletBase = _walletBaseItem.walletBase;
    _receivingAddressList = _walletBase.getAddressList(0, FIRST_COUNT, false);
    _changeAddressList = _walletBase.getAddressList(0, FIRST_COUNT, true);
    _isFirstLoadRunning = false;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _depositTooltipIconRenderBox =
          _depositTooltipKey.currentContext!.findRenderObject() as RenderBox;
      _depositTooltipIconPosition =
          _depositTooltipIconRenderBox.localToGlobal(Offset.zero);

      _changeTooltipIconRenderBox =
          _changeTooltipKey.currentContext!.findRenderObject() as RenderBox;
      _changeTooltipIconPosition =
          _changeTooltipIconRenderBox.localToGlobal(Offset.zero);
    });
  }

  void _nextLoad() {
    if (!_isFirstLoadRunning &&
        !_isLoadMoreRunning &&
        _controller.position.extentAfter < 100) {
      setState(() {
        _isLoadMoreRunning = true;
      });

      try {
        final newAddresses = _walletBase.getAddressList(
            FIRST_COUNT +
                (isReceivingSelected
                        ? _receivingAddressPage
                        : _changeAddressPage) *
                    _limit,
            _limit,
            !isReceivingSelected);
        setState(() {
          if (isReceivingSelected) {
            _receivingAddressList.addAll(newAddresses);
            _receivingAddressPage += 1;
          } else {
            _changeAddressList.addAll(newAddresses);
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

  void scrollToTop() {
    _controller.animateTo(0,
        duration: const Duration(milliseconds: 500), curve: Curves.decelerate);
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

  @override
  Widget build(BuildContext context) {
    List<coconut.Address> addressList =
        isReceivingSelected ? _receivingAddressList : _changeAddressList;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        _removeTooltip();
      },
      child: Stack(
        children: [
          Scaffold(
              extendBodyBehindAppBar: true,
              backgroundColor: MyColors.black,
              appBar: AppBar(
                scrolledUnderElevation: 0,
                backgroundColor: _isScrollOverTitleHeight
                    ? MyColors.transparentBlack_50
                    : MyColors.black,
                toolbarHeight: kToolbarHeight + 30,
                leading: IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: SvgPicture.asset('assets/svg/back.svg',
                        width: 24,
                        colorFilter: const ColorFilter.mode(
                            MyColors.white, BlendMode.srcIn))),
                flexibleSpace: _isScrollOverTitleHeight
                    ? ClipRect(
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            color: MyColors.transparentWhite_06,
                          ),
                        ),
                      )
                    : null,
                title: Text(
                  '${_walletBaseItem.name}의 주소',
                  style: Styles.appbarTitle,
                ),
                centerTitle: true,
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(50.0),
                  child: toolbarWidget(),
                ),
              ),
              body: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                ),
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
                                  itemBuilder: (context, index) => AddressCard(
                                    onPressed: () {
                                      _removeTooltip();
                                      MyBottomSheet.showBottomSheet_90(
                                          context: context,
                                          child: QrcodeBottomSheetScreen(
                                              qrcodeTopWidget: Text(
                                                addressList[index]
                                                    .derivationPath,
                                                style: Styles.body2.merge(
                                                    const TextStyle(
                                                        color: MyColors
                                                            .transparentWhite_70)),
                                              ),
                                              qrData:
                                                  addressList[index].address,
                                              title: '주소 - $index'));
                                    },
                                    address: addressList[index].address,
                                    derivationPath:
                                        addressList[index].derivationPath,
                                    isUsed: addressList[index].isUsed,
                                    balanceInSats: addressList[index].amount,
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
                                            color: MyColors.white),
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
          left: _depositTooltipIconPosition.dx - 30,
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
                  '비트코인을 받을 때 사용하는 주소예요. 영어로 Receiving 또는 External이라 해요.',
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
              46,
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
                  '다른 사람에게 비트코인을 보내고 남은 비트코인을 거슬러 받는 주소예요. 영어로 Change라 해요.',
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

  Widget toolbarWidget() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 10,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: MyColors.transparentWhite_15,
        ),
        child: Row(
          children: [
            Expanded(
                child: TooltipButton(
              isSelected: isReceivingSelected,
              text: '입금',
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
              text: '잔돈',
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
}

class AddressCard extends StatelessWidget {
  const AddressCard(
      {super.key,
      required this.onPressed,
      required this.address,
      required this.derivationPath,
      required this.isUsed,
      this.balanceInSats});

  final VoidCallback onPressed;
  final String address;
  final String derivationPath;
  final bool isUsed;
  final int? balanceInSats;

  @override
  Widget build(BuildContext context) {
    var path = derivationPath.split('/');
    var index = path[path.length - 1];

    return CupertinoButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: MyBorder.defaultRadius,
          color: MyColors.transparentWhite_15,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        margin: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: MyColors.transparentBlack_50),
                child: Text(index, style: Styles.caption)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${address.substring(0, 10)}...${address.substring(address.length - 10, address.length)}',
                  style: Styles.body1Number,
                ),
                const SizedBox(height: 4),
                Text(
                    balanceInSats == null
                        ? ''
                        : '${satoshiToBitcoinString(balanceInSats!)} BTC',
                    style: Styles.label.merge(TextStyle(
                        fontFamily: CustomFonts.number.getFontFamily,
                        fontWeight: FontWeight.normal,
                        color: MyColors.transparentWhite_50)))
              ],
            ),
            const Spacer(),
            Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: MyColors.transparentWhite_15),
                child: Text(isUsed ? '사용됨' : '사용 전',
                    style: TextStyle(
                        color: isUsed
                            ? MyColors.primary
                            : MyColors.transparentWhite_70,
                        fontSize: 10,
                        fontFamily: CustomFonts.text.getFontFamily)))
          ],
        ),
      ),
    );
  }
}
