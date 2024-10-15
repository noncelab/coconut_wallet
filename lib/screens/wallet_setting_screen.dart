import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/providers/app_sub_state_model.dart';
import 'package:coconut_wallet/screens/pin_check_screen.dart';
import 'package:coconut_wallet/screens/qrcode_bottom_sheet_screen.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/widgets/bottom_sheet.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/button/tooltip_button.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:provider/provider.dart';

import '../styles.dart';
import '../widgets/appbar/custom_appbar.dart';
import '../widgets/custom_dialogs.dart';
import '../widgets/infomation_row_item.dart';

class WalletSettingScreen extends StatefulWidget {
  const WalletSettingScreen({super.key, required this.id});

  final int id;

  @override
  State<WalletSettingScreen> createState() => _WalletSettingScreenState();
}

class _WalletSettingScreenState extends State<WalletSettingScreen> {
  OverlayEntry? _overlayEntry;
  late AppSubStateModel _subModel;
  final GlobalKey _walletTooltipKey = GlobalKey();
  late RenderBox _walletTooltipIconRenderBox;
  late Offset _walletTooltipIconPosition;
  Timer? _tooltipTimer;
  int _tooltipRemainingTime = 5;
  int? removedWalletId;

  @override
  void initState() {
    super.initState();
    _subModel = Provider.of<AppSubStateModel>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _walletTooltipIconRenderBox =
          _walletTooltipKey.currentContext?.findRenderObject() as RenderBox;
      _walletTooltipIconPosition =
          _walletTooltipIconRenderBox.localToGlobal(Offset.zero);
    });
  }

  @override
  void dispose() {
    _removeTooltip();
    super.dispose();
  }

  void _showTooltip(BuildContext context, Offset position, String tip) {
    _removeTooltip();

    _tooltipRemainingTime = 5;
    _tooltipTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_tooltipRemainingTime > 0) {
          _tooltipRemainingTime--;
        } else {
          _removeTooltip();
          timer.cancel();
        }
      });
    });

    final overlay = Overlay.of(context);
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
          top: position.dy + 16,
          right: MediaQuery.of(context).size.width - position.dx - 48,
          child: GestureDetector(
            onTap: () => _removeTooltip(),
            child: ClipPath(
              clipper: RightTriangleBubbleClipper(),
              child: Container(
                padding: const EdgeInsets.only(
                  top: 25,
                  left: 10,
                  right: 10,
                  bottom: 10,
                ),
                color: MyColors.white,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tip,
                      style: Styles.caption.merge(TextStyle(
                        height: 1.3,
                        fontFamily: CustomFonts.text.getFontFamily,
                        color: MyColors.darkgrey,
                      )),
                    ),
                  ],
                ),
              ),
            ),
          )),
    );

    overlay.insert(_overlayEntry!);
  }

  void _removeTooltip() {
    if (_overlayEntry != null) {
      if (_tooltipTimer != null) {
        _tooltipTimer!.cancel();
      }
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (removedWalletId != null) {
      return const Scaffold(
        body: Center(child: Text('지갑을 찾을 수 없습니다.')),
      );
    }
    final model = Provider.of<AppStateModel>(context, listen: false);
    final wallet = model.getWalletById(widget.id);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        _removeTooltip();
      },
      child: Scaffold(
          backgroundColor: MyColors.black,
          appBar: CustomAppBar.build(
            title: '지갑 정보',
            context: context,
            hasRightIcon: false,
          ),
          body: SafeArea(
              child: SingleChildScrollView(
                  child: Container(
                      margin: const EdgeInsets.only(top: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 24, vertical: 20),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(28),
                                    border: Border.all(
                                        color: MyColors.borderLightgrey,
                                        width: 0.5)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: BackgroundColorPalette[
                                              wallet.colorIndex],
                                          borderRadius:
                                              BorderRadius.circular(18.0),
                                        ),
                                        child: SvgPicture.asset(
                                            CustomIcons.getPathByIndex(
                                                wallet.iconIndex),
                                            colorFilter: ColorFilter.mode(
                                                ColorPalette[wallet.colorIndex],
                                                BlendMode.srcIn),
                                            width: 24.0)),
                                    const SizedBox(width: 8.0),
                                    Expanded(
                                        child: Text(
                                      wallet.name,
                                      style: Styles.h3,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )),
                                    const SizedBox(
                                      width: 8,
                                    ),
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          wallet.coconutWallet.keyStore
                                              .fingerprint,
                                          style: Styles.h3.merge(TextStyle(
                                              fontFamily: CustomFonts
                                                  .number.getFontFamily)),
                                        ),
                                        TooltipButton(
                                          isSelected: false,
                                          text: '지갑 ID',
                                          isLeft: true,
                                          iconKey: _walletTooltipKey,
                                          containerMargin: EdgeInsets.zero,
                                          containerPadding: EdgeInsets.zero,
                                          iconPadding:
                                              const EdgeInsets.only(left: 10),
                                          onTap: () {},
                                          onTapDown: (details) {
                                            _showTooltip(
                                              context,
                                              _walletTooltipIconPosition,
                                              '지갑의 고유 값이에요.\n마스터 핑거프린트(MFP)라고도 해요.',
                                            );
                                          },
                                        ),
                                      ],
                                    )
                                  ],
                                )),
                          ),
                          const SizedBox(height: 32),
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                  decoration: BoxDecorations.boxDecoration,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24),
                                    child: Column(
                                      children: [
                                        InformationRowItem(
                                          label: '잔액 상세 보기',
                                          showIcon: true,
                                          onPressed: () {
                                            if (model.walletInitState ==
                                                WalletInitState.processing) {
                                              CustomToast.showToast(
                                                  context: context,
                                                  text:
                                                      "최신 데이터를 가져오는 중입니다. 잠시만 기다려주세요.");
                                              return;
                                            }
                                            _removeTooltip();
                                            Navigator.pushNamed(
                                                context, '/utxo-list',
                                                arguments: {'id': widget.id});
                                          },
                                        ),
                                        const Divider(
                                            color: MyColors.transparentWhite_12,
                                            height: 1),
                                        InformationRowItem(
                                          label: '전체 주소 보기',
                                          showIcon: true,
                                          onPressed: () {
                                            if (model.walletInitState ==
                                                WalletInitState.processing) {
                                              CustomToast.showToast(
                                                  context: context,
                                                  text:
                                                      "최신 데이터를 가져오는 중입니다. 잠시만 기다려주세요.");
                                              return;
                                            }
                                            _removeTooltip();
                                            Navigator.pushNamed(
                                                context, '/address-list',
                                                arguments: {'id': widget.id});
                                          },
                                        ),
                                        const Divider(
                                            color: MyColors.transparentWhite_12,
                                            height: 1),
                                        InformationRowItem(
                                          label: '확장 공개키 보기',
                                          showIcon: true,
                                          onPressed: () async {
                                            _removeTooltip();
                                            if (_subModel.isSetPin) {
                                              _subModel.shuffleNumbers();
                                              await MyBottomSheet
                                                  .showBottomSheet_90(
                                                      context: context,
                                                      child:
                                                          CustomLoadingOverlay(
                                                              child:
                                                                  PinCheckScreen(
                                                        onComplete: () {
                                                          MyBottomSheet.showBottomSheet_90(
                                                              context: context,
                                                              child: QrcodeBottomSheetScreen(
                                                                  qrData: wallet
                                                                      .coconutWallet
                                                                      .keyStore
                                                                      .extendedPublicKey
                                                                      .serialize(),
                                                                  title:
                                                                      '확장 공개키'));
                                                        },
                                                      )));
                                            } else {
                                              MyBottomSheet.showBottomSheet_90(
                                                  context: context,
                                                  child:
                                                      QrcodeBottomSheetScreen(
                                                          qrData: wallet
                                                              .coconutWallet
                                                              .keyStore
                                                              .extendedPublicKey
                                                              .serialize(),
                                                          title: '확장 공개키'));
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ))),
                          const SizedBox(height: 32),
                          Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Container(
                                  decoration: BoxDecorations.boxDecoration,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24),
                                    child: Column(
                                      children: [
                                        InformationRowItem(
                                          showIcon: true,
                                          label: '삭제하기',
                                          rightIcon: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                  color: MyColors
                                                      .defaultBackground,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10)),
                                              child: SvgPicture.asset(
                                                  'assets/svg/trash.svg',
                                                  width: 16,
                                                  colorFilter:
                                                      const ColorFilter.mode(
                                                          MyColors.warningRed,
                                                          BlendMode.srcIn))),
                                          onPressed: () {
                                            if (model.walletInitState ==
                                                WalletInitState.processing) {
                                              CustomToast.showToast(
                                                  context: context,
                                                  text:
                                                      "최신 데이터를 가져오는 중입니다. 잠시만 기다려주세요.");
                                              return;
                                            }
                                            _removeTooltip();
                                            CustomDialogs.showCustomAlertDialog(
                                                context,
                                                title: '지갑 삭제',
                                                message: '지갑을 정말 삭제하시겠어요?',
                                                onConfirm: () async {
                                              if (_subModel.isSetPin) {
                                                await MyBottomSheet
                                                    .showBottomSheet_90(
                                                        context: context,
                                                        child:
                                                            CustomLoadingOverlay(
                                                          child: PinCheckScreen(
                                                            onComplete:
                                                                () async {
                                                              await model
                                                                  .deleteWallet(
                                                                      widget
                                                                          .id);
                                                              Repository()
                                                                  .resetObjectBoxWallet(
                                                                      wallet
                                                                          .coconutWallet);
                                                              removedWalletId =
                                                                  widget.id;
                                                              Navigator.popUntil(
                                                                  context,
                                                                  (route) => route
                                                                      .isFirst);
                                                            },
                                                          ),
                                                        ));
                                              } else {
                                                await model
                                                    .deleteWallet(widget.id);
                                                Repository()
                                                    .resetObjectBoxWallet(
                                                        wallet.coconutWallet);

                                                removedWalletId = widget.id;
                                                Navigator.popUntil(context,
                                                    (route) => route.isFirst);
                                              }
                                            }, onCancel: () {
                                              Navigator.of(context).pop();
                                            },
                                                confirmButtonText: '삭제',
                                                confirmButtonColor:
                                                    MyColors.warningRed);
                                          },
                                        ),
                                      ],
                                    ),
                                  ))),
                        ],
                      ))))),
    );
  }
}
