import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/data/multisig_signer.dart';
import 'package:coconut_wallet/model/data/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/providers/app_sub_state_model.dart';
import 'package:coconut_wallet/screens/pin_check_screen.dart';
import 'package:coconut_wallet/screens/qrcode_bottom_sheet_screen.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/infomation_row_item.dart';
import 'package:coconut_wallet/widgets/wallet_item_card.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../widgets/bottom_sheet.dart';
import '../widgets/custom_dialogs.dart';
import '../widgets/custom_loading_overlay.dart';
import '../widgets/custom_toast.dart';

class WalletMultisigScreen extends StatefulWidget {
  final int id;
  const WalletMultisigScreen({super.key, required this.id});

  @override
  State<WalletMultisigScreen> createState() => _WalletMultisigScreenState();
}

class _WalletMultisigScreenState extends State<WalletMultisigScreen> {
  final GlobalKey _walletTooltipKey = GlobalKey();
  RenderBox? _walletTooltipIconRenderBox;
  Offset _walletTooltipIconPosition = Offset.zero;
  double _tooltipTopPadding = 0;

  Timer? _tooltipTimer;
  int _tooltipRemainingTime = 0;
  int? removedWalletId;

  late AppStateModel _appStateModel;
  late AppSubStateModel _subModel;
  late MultisigWalletListItem _multiWallet;
  late List<KeyStore> _keystoreList;

  // TODO: AppStateModel 분리 후 제거
  Object? _navigatorPopResult;

  @override
  void initState() {
    super.initState();
    _appStateModel = Provider.of<AppStateModel>(context, listen: false);
    _subModel = Provider.of<AppSubStateModel>(context, listen: false);
    _updateMultiWalletListItem();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _walletTooltipIconRenderBox =
          _walletTooltipKey.currentContext?.findRenderObject() as RenderBox;
      _walletTooltipIconPosition =
          _walletTooltipIconRenderBox!.localToGlobal(Offset.zero);
      _tooltipTopPadding =
          MediaQuery.paddingOf(context).top + kToolbarHeight - 8;
    });
  }

  _updateMultiWalletListItem() {
    final walletBaseItem = _appStateModel.getWalletById(widget.id);
    _multiWallet = walletBaseItem as MultisigWalletListItem;

    final multisigWallet = _multiWallet.walletBase as MultisignatureWallet;
    _keystoreList = multisigWallet.keyStoreList;
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

  _removeWallet() {
    if (_appStateModel.walletInitState == WalletInitState.processing) {
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
          await MyBottomSheet.showBottomSheet_90(
            context: context,
            child: CustomLoadingOverlay(
              child: PinCheckScreen(
                onComplete: () async {
                  await _appStateModel.deleteWallet(widget.id);
                  removedWalletId = widget.id;
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
              ),
            ),
          );
        } else {
          await _appStateModel.deleteWallet(widget.id);
          removedWalletId = widget.id;
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      },
      onCancel: () {
        Navigator.of(context).pop();
      },
      confirmButtonText: '삭제',
      confirmButtonColor: MyColors.warningRed,
    );
  }

  _moveToAddress() {
    if (_appStateModel.walletInitState == WalletInitState.processing) {
      CustomToast.showToast(
        context: context,
        text: "최신 데이터를 가져오는 중입니다. 잠시만 기다려주세요.",
      );
      return;
    }
    _removeTooltip();
    Navigator.pushNamed(context, '/address-list', arguments: {'id': widget.id});
  }

  _moveToUtxoTag() async {
    _removeTooltip();
    _navigatorPopResult = await Navigator.pushNamed(context, '/utxo-tag',
        arguments: {'id': widget.id});
  }

  _showXPubBottomSheet(String qrData) async {
    _removeTooltip();
    if (_subModel.isSetPin) {
      _subModel.shuffleNumbers();
      await MyBottomSheet.showBottomSheet_90(
        context: context,
        child: CustomLoadingOverlay(
          child: PinCheckScreen(
            onComplete: () {
              _qrCodeBottomSheet(qrData);
            },
          ),
        ),
      );
    } else {
      _qrCodeBottomSheet(qrData);
    }
  }

  _qrCodeBottomSheet(String qrData) {
    MyBottomSheet.showBottomSheet_90(
      context: context,
      child: QrcodeBottomSheetScreen(
        qrData: qrData,
        title: '다중 서명용 확장 공개키',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: MyColors.black,
        appBar: CustomAppBar.build(
            title: '${_multiWallet.name} 정보',
            context: context,
            hasRightIcon: false,
            onBackPressed: () {
              Navigator.pop(context, _navigatorPopResult);
            }),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 다중 지갑
                    _multisigWallet(),
                    // 상세 지갑 리스트
                    _signerList(),
                    // 잔액 상세 보기, 전체 주소 보기, 태그 관리
                    _buttons(),
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
                    // 삭제 하기
                    _deleteButton(),
                  ],
                ),
                Visibility(
                  visible: _tooltipRemainingTime > 0,
                  child: Positioned(
                    top: _walletTooltipIconPosition.dy - _tooltipTopPadding,
                    right: MediaQuery.of(context).size.width -
                        _walletTooltipIconPosition.dx +
                        5,
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
                                '${_multiWallet.signers.length}개의 키 중 ${_multiWallet.requiredSignatureCount}개로 서명해야 하는\n다중 서명 지갑이예요.',
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

  Widget _multisigWallet() => Padding(
        padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
        child: WalletItemCard(
            walletItem: _multiWallet,
            onTooltipClicked: () => _showTooltip(context),
            tooltipKey: _walletTooltipKey),
      );

  Widget _signerList() => Container(
        margin: const EdgeInsets.only(top: 8, bottom: 32),
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _multiWallet.signers.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = _multiWallet.signers[index];
            final isInnerWallet = item.innerVaultId != null;
            final name = item.name ?? '';
            final colorIndex = item.colorIndex ?? 0;
            final iconIndex = item.iconIndex ?? 0;
            final memo = item.memo ?? '';

            return GestureDetector(
              onTap: () {
                //_selectedKeyBottomSheet(item, _keystoreList[index]);
              },
              child: Container(
                color: Colors.transparent,
                child: Row(
                  children: [
                    // 왼쪽 인덱스 번호
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${index + 1}',
                        textAlign: TextAlign.center,
                        style: Styles.body2.merge(
                          TextStyle(
                            fontSize: 16,
                            fontFamily: CustomFonts.number.getFontFamily,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12), // 간격

                    // 카드 영역
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: MyColors.black,
                          borderRadius: MyBorder.boxDecorationRadius,
                          border: Border.all(color: MyColors.borderLightgrey),
                        ),
                        child: Row(
                          children: [
                            // 아이콘
                            Container(
                                padding: EdgeInsets.all(isInnerWallet ? 8 : 10),
                                decoration: BoxDecoration(
                                  color: isInnerWallet
                                      ? BackgroundColorPalette[colorIndex]
                                      : BackgroundColorPalette[8],
                                  borderRadius: BorderRadius.circular(14.0),
                                ),
                                child: SvgPicture.asset(
                                  isInnerWallet
                                      ? CustomIcons.getPathByIndex(iconIndex)
                                      : 'assets/svg/download.svg',
                                  colorFilter: ColorFilter.mode(
                                    isInnerWallet
                                        ? ColorPalette[colorIndex]
                                        : ColorPalette[8],
                                    BlendMode.srcIn,
                                  ),
                                  width: isInnerWallet ? 20 : 15,
                                )),

                            const SizedBox(width: 12),

                            // 이름, 메모
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    TextUtils.ellipsisIfLonger(name),
                                    style: Styles.body2,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Visibility(
                                    visible: memo.isNotEmpty,
                                    child: Text(
                                      memo,
                                      style: Styles.caption2,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // MFP 텍스트
                            Text(
                              _keystoreList[index].masterFingerprint,
                              style: Styles.mfpH3,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );

  Future _selectedKeyBottomSheet(
      MultisigSigner signer, KeyStore keystore) async {
    final name = signer.name ?? '';

    MyBottomSheet.showBottomSheet(
      context: context,
      title: TextUtils.ellipsisIfLonger(name, maxLength: 15),
      titleTextStyle: Styles.body1.copyWith(
        fontSize: 18,
      ),
      isCloseButton: true,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.only(bottom: 84),
        child: _bottomSheetButton(
          '다중 서명용 확장 공개키 보기',
          onPressed: () {
            _showXPubBottomSheet(keystore.extendedPublicKey.serialize());
          },
        ),
      ),
    );
  }

  Widget _bottomSheetButton(String title, {required VoidCallback onPressed}) {
    return GestureDetector(
      onTap: () {
        onPressed.call();
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.only(
          top: 30,
          bottom: 30,
          left: 8,
        ),
        width: double.infinity,
        child: Text(
          title,
          style: Styles.body1Bold,
          textAlign: TextAlign.left, // 텍스트 왼쪽 정렬
        ),
      ),
    );
  }

  Widget _buttons() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecorations.boxDecoration,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                InformationRowItem(
                  label: '전체 주소 보기',
                  showIcon: true,
                  onPressed: _moveToAddress,
                ),
                const Divider(color: MyColors.transparentWhite_12, height: 1),
                InformationRowItem(
                  label: '태그 관리',
                  showIcon: true,
                  onPressed: _moveToUtxoTag,
                ),
              ],
            ),
          ),
        ),
      );

  Widget _deleteButton() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecorations.boxDecoration,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                InformationRowItem(
                  showIcon: true,
                  label: '삭제하기',
                  rightIcon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: MyColors.defaultBackground,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: SvgPicture.asset(
                      'assets/svg/trash.svg',
                      width: 16,
                      colorFilter: const ColorFilter.mode(
                        MyColors.warningRed,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  onPressed: _removeWallet,
                ),
              ],
            ),
          ),
        ),
      );

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    super.dispose();
  }
}
