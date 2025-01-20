import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/widgets/card/wallet_info_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/providers/app_sub_state_model.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/widgets/overlays/qrcode_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:provider/provider.dart';

import '../../styles.dart';
import '../../widgets/appbar/custom_appbar.dart';
import '../../widgets/custom_dialogs.dart';
import '../../widgets/card/information_item_card.dart';

class WalletSinglesigInfoScreen extends StatefulWidget {
  const WalletSinglesigInfoScreen({super.key, required this.id});

  final int id;

  @override
  State<WalletSinglesigInfoScreen> createState() =>
      _WalletSinglesigInfoScreenState();
}

class _WalletSinglesigInfoScreenState extends State<WalletSinglesigInfoScreen> {
  late AppSubStateModel _subModel;
  final GlobalKey _walletTooltipKey = GlobalKey();
  RenderBox? _walletTooltipIconRenderBox;
  Offset _walletTooltipIconPosition = Offset.zero;
  double _tooltipTopPadding = 0;
  Timer? _tooltipTimer;
  int _tooltipRemainingTime = 0;
  int? removedWalletId;

  @override
  void initState() {
    super.initState();
    _subModel = Provider.of<AppSubStateModel>(context, listen: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _walletTooltipIconRenderBox =
          _walletTooltipKey.currentContext?.findRenderObject() as RenderBox;
      _walletTooltipIconPosition =
          _walletTooltipIconRenderBox!.localToGlobal(Offset.zero);
      _tooltipTopPadding =
          MediaQuery.paddingOf(context).top + kToolbarHeight - 8;
    });
  }

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    super.dispose();
  }

  _showTooltip(BuildContext context) {
    _removeTooltip();

    setState(() {
      _tooltipRemainingTime = 5;
    });

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
  }

  _removeTooltip() {
    setState(() {
      _tooltipRemainingTime = 0;
    });
    _tooltipTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (removedWalletId != null) {
      return const Scaffold(
        body: Center(child: Text('지갑을 찾을 수 없습니다.')),
      );
    }
    final model = Provider.of<AppStateModel>(context, listen: false);
    final singlesigListItem = model.getWalletById(widget.id);

    final singlesigWallet =
        singlesigListItem.walletBase as SingleSignatureWallet;

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
            onBackPressed: () {
              Navigator.pop(context);
            }),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Stack(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: WalletInfoItemCard(
                            walletItem: singlesigListItem,
                            onTooltipClicked: () => _showTooltip(context),
                            tooltipKey: _walletTooltipKey),
                      ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecorations.boxDecoration,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                InformationItemCard(
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
                                InformationItemCard(
                                  label: '확장 공개키 보기',
                                  showIcon: true,
                                  onPressed: () async {
                                    _removeTooltip();
                                    if (_subModel.isSetPin) {
                                      _subModel.shuffleNumbers();
                                      await CommonBottomSheets
                                          .showBottomSheet_90(
                                              context: context,
                                              child: CustomLoadingOverlay(
                                                  child: PinCheckScreen(
                                                onComplete: () {
                                                  CommonBottomSheets.showBottomSheet_90(
                                                      context: context,
                                                      child: QrcodeBottomSheet(
                                                          qrData: singlesigWallet
                                                              .keyStore
                                                              .extendedPublicKey
                                                              .serialize(),
                                                          title: '확장 공개키'));
                                                },
                                              )));
                                    } else {
                                      CommonBottomSheets.showBottomSheet_90(
                                          context: context,
                                          child: QrcodeBottomSheet(
                                              qrData: singlesigWallet
                                                  .keyStore.extendedPublicKey
                                                  .serialize(),
                                              title: '확장 공개키'));
                                    }
                                  },
                                ),
                                const Divider(
                                    color: MyColors.transparentWhite_12,
                                    height: 1),
                                InformationItemCard(
                                  label: '태그 관리',
                                  showIcon: true,
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/utxo-tag',
                                        arguments: {'id': widget.id});
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 65,
                          height: 1,
                          margin: const EdgeInsets.symmetric(vertical: 20),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1),
                            color: MyColors.white,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          decoration: BoxDecorations.boxDecoration,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Column(
                              children: [
                                InformationItemCard(
                                  showIcon: true,
                                  label: '삭제하기',
                                  rightIcon: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: MyColors.defaultBackground,
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: SvgPicture.asset(
                                      'assets/svg/trash.svg',
                                      width: 16,
                                      colorFilter: const ColorFilter.mode(
                                        MyColors.warningRed,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                  onPressed: () {
                                    if (model.walletInitState ==
                                        WalletInitState.processing) {
                                      CustomToast.showToast(
                                        context: context,
                                        text: "최신 데이터를 가져오는 중입니다. 잠시만 기다려주세요.",
                                      );
                                      return;
                                    }
                                    _removeTooltip();
                                    CustomDialogs.showCustomAlertDialog(
                                      context,
                                      title: '지갑 삭제',
                                      message: '지갑을 정말 삭제하시겠어요?',
                                      onConfirm: () async {
                                        if (_subModel.isSetPin) {
                                          await CommonBottomSheets
                                              .showBottomSheet_90(
                                            context: context,
                                            child: CustomLoadingOverlay(
                                              child: PinCheckScreen(
                                                onComplete: () async {
                                                  await model
                                                      .deleteWallet(widget.id);
                                                  removedWalletId = widget.id;
                                                  Navigator.popUntil(context,
                                                      (route) => route.isFirst);
                                                },
                                              ),
                                            ),
                                          );
                                        } else {
                                          await model.deleteWallet(widget.id);
                                          removedWalletId = widget.id;
                                          Navigator.popUntil(context,
                                              (route) => route.isFirst);
                                        }
                                      },
                                      onCancel: () {
                                        Navigator.of(context).pop();
                                      },
                                      confirmButtonText: '삭제',
                                      confirmButtonColor: MyColors.warningRed,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Visibility(
                  visible: _tooltipRemainingTime > 0,
                  child: Positioned(
                    top: _walletTooltipIconPosition.dy - _tooltipTopPadding,
                    right: MediaQuery.of(context).size.width -
                        _walletTooltipIconPosition.dx -
                        (_walletTooltipIconRenderBox == null
                            ? 0
                            : _walletTooltipIconRenderBox!.size.width) -
                        10,
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
                                '지갑의 고유 값이에요.\n마스터 핑거프린트(MFP)라고도 해요.',
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
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
