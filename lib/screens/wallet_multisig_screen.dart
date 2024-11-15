import 'dart:async';

import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/icons_util.dart';
import 'package:coconut_wallet/widgets/bubble_clipper.dart';
import 'package:coconut_wallet/widgets/button/tooltip_button.dart';
import 'package:coconut_wallet/widgets/infomation_row_item.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WalletMultisigScreen extends StatefulWidget {
  final int id;
  const WalletMultisigScreen({super.key, required this.id});

  @override
  State<WalletMultisigScreen> createState() => _WalletMultisigScreenState();
}

class _WalletMultisigScreenState extends State<WalletMultisigScreen> {
  final GlobalKey _walletTooltipKey = GlobalKey();

  Timer? _tooltipTimer;
  int _tooltipRemainingTime = 0;

  // TODO: TEST
  String _address = '';
  String _masterFingerPrint = '';
  int _requiredSignatureCount = 0;

  final TestMultiSig testWallet = TestMultiSig(
    id: 5,
    name: '다중지갑',
    colorIndex: 4,
    iconIndex: 4,
    balance: 0,
    descriptor: '',
  );

  final testMultisigList = [
    TestMultiSig(
      id: 1,
      name: 'qwer',
      colorIndex: 0,
      iconIndex: 0,
      balance: 0,
      descriptor: '',
    ),
    TestMultiSig(
      id: 2,
      name: '외부지갑',
      colorIndex: 0,
      iconIndex: 0,
      balance: 0,
      descriptor: '',
    ),
    TestMultiSig(
      id: 3,
      name: 'go',
      colorIndex: 4,
      iconIndex: 4,
      balance: 0,
      descriptor: '',
    ),
  ];

  // TODO: 외부 지갑 구분에 따른 로직 수정 필요함
  List<Color> getGradientColors(List<TestMultiSig> list) {
    // 빈 리스트 처리
    if (list.isEmpty) {
      return [MyColors.borderLightgrey];
    }

    // 색상 가져오는 헬퍼 함수
    Color getColor(TestMultiSig item) {
      return item.name != '외부지갑'
          ? CustomColorHelper.getColorByIndex(item.colorIndex)
          : MyColors.white;
    }

    // 1개인 경우
    if (list.length == 1) {
      final color = getColor(testMultisigList[0]);
      return [color, MyColors.white, color];
    }

    // 2개인 경우
    if (testMultisigList.length == 2) {
      return [
        getColor(testMultisigList[0]),
        MyColors.white,
        getColor(testMultisigList[1]),
      ];
    }

    // 3개 이상인 경우
    return [
      getColor(testMultisigList[0]),
      getColor(testMultisigList[1]),
      getColor(testMultisigList[2]),
    ];
  }

  @override
  void initState() {
    super.initState();
    _address = '다중 서명 주소';
    _masterFingerPrint = 'MFP000';
    _requiredSignatureCount = 2;
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
    final tooltipTop = MediaQuery.of(context).padding.top + 38;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
        backgroundColor: MyColors.black,
        appBar: CustomAppBar.build(
          title: '${testWallet.name} 정보',
          context: context,
          hasRightIcon: false,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // 다중 지갑
                    Container(
                      margin:
                          const EdgeInsets.only(top: 20, left: 16, right: 16),
                      decoration: BoxDecoration(
                        color: MyColors.black,
                        borderRadius: BorderRadius.circular(30),
                        gradient: LinearGradient(
                          colors: getGradientColors(testMultisigList),
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 20),
                        decoration: BoxDecoration(
                          color: MyColors.black,
                          borderRadius: BorderRadius.circular(28),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 아이콘
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: BackgroundColorPalette[
                                    testWallet.colorIndex],
                                borderRadius: BorderRadius.circular(18.0),
                              ),
                              child: SvgPicture.asset(
                                CustomIcons.getPathByIndex(
                                    testWallet.iconIndex),
                                colorFilter: ColorFilter.mode(
                                  ColorPalette[testWallet.colorIndex],
                                  BlendMode.srcIn,
                                ),
                                width: 24.0,
                              ),
                            ),
                            const SizedBox(width: 8.0),
                            // 이름
                            Expanded(
                              child: Text(
                                testWallet.name,
                                style: Styles.h3,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(
                              width: 8,
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _masterFingerPrint,
                                  style: Styles.h3.merge(TextStyle(
                                      fontFamily:
                                          CustomFonts.number.getFontFamily)),
                                ),
                                TooltipButton(
                                  isSelected: false,
                                  text:
                                      '$_requiredSignatureCount/${testMultisigList.length}',
                                  isLeft: true,
                                  iconKey: _walletTooltipKey,
                                  containerMargin: EdgeInsets.zero,
                                  containerPadding: EdgeInsets.zero,
                                  iconPadding: const EdgeInsets.only(left: 10),
                                  onTap: () {},
                                  onTapDown: (details) {
                                    _showTooltip(context);
                                  },
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                    // 상세 지갑 리스트
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 32),
                      child: ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: testMultisigList.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final item = testMultisigList[index];
                          // TODO: 외부, 내부 지갑 구분값 적용
                          final isVaultKey = item.name != '외부지갑';

                          return GestureDetector(
                            onTap: () {
                              // _selectedKeyBottomSheet(item);
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
                                            fontFamily: CustomFonts
                                                .number.getFontFamily),
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
                                        borderRadius: BorderRadius.circular(17),
                                        border: Border.all(
                                            color: MyColors.borderLightgrey),
                                      ),
                                      child: Row(
                                        children: [
                                          // 아이콘
                                          Container(
                                              padding: EdgeInsets.all(
                                                  isVaultKey ? 8 : 10),
                                              decoration: BoxDecoration(
                                                color: isVaultKey
                                                    ? BackgroundColorPalette[
                                                        item.colorIndex]
                                                    : BackgroundColorPalette[8],
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: SvgPicture.asset(
                                                isVaultKey
                                                    ? CustomIcons
                                                        .getPathByIndex(
                                                            item.iconIndex)
                                                    : 'assets/svg/download.svg',
                                                colorFilter: ColorFilter.mode(
                                                  isVaultKey
                                                      ? ColorPalette[
                                                          item.colorIndex]
                                                      : ColorPalette[8],
                                                  BlendMode.srcIn,
                                                ),
                                                width: isVaultKey ? 20 : 15,
                                              )),

                                          const SizedBox(width: 12),

                                          // 이름
                                          Expanded(
                                            child: Text(
                                              item.name,
                                              style: Styles.body2,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),

                                          // MFP 텍스트
                                          // TODO: MFP 가져오기 변경
                                          Text(
                                            'MFP${index + 1}',
                                            style: Styles.body1.copyWith(
                                                color: MyColors.white),
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
                    ),
                    // 잔액 상세 보기, 전체 주소 보기
                    Container(
                      margin: const EdgeInsets.only(bottom: 32),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        decoration: BoxDecorations.boxDecoration,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            children: [
                              InformationRowItem(
                                label: '잔액 상세 보기',
                                showIcon: true,
                                onPressed: () {
                                  // TODO:
                                },
                              ),
                              const Divider(
                                  color: MyColors.transparentWhite_12,
                                  height: 1),
                              InformationRowItem(
                                label: '전체 주소 보기',
                                showIcon: true,
                                onPressed: () {
                                  // TODO:
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // 삭제 하기
                    Padding(
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
                                onPressed: () {
                                  // TODO:
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Visibility(
                  visible: _tooltipRemainingTime > 0,
                  child: Positioned(
                    top: tooltipTop,
                    right: 16,
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
                          color: MyColors.darkgrey,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${testMultisigList.length}개의 키 중 $_requiredSignatureCount개로 서명해야 하는\n다중 서명 지갑이예요.',
                                style: Styles.caption.merge(TextStyle(
                                  height: 1.3,
                                  fontFamily: CustomFonts.text.getFontFamily,
                                  color: MyColors.white,
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

  @override
  void dispose() {
    _tooltipTimer?.cancel();
    super.dispose();
  }
}

// TODO: 개발 완료후 삭제
class TestMultiSig {
  final int id;
  final String name;
  final int colorIndex;
  final int iconIndex;
  final String descriptor;
  int? balance;
  int? txCount;

  TestMultiSig(
      {required this.id,
      required this.name,
      required this.colorIndex,
      required this.iconIndex,
      required this.descriptor,
      this.balance,
      this.txCount});
}
