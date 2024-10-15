import 'dart:io';

import 'package:coconut_wallet/screens/settings/bip39_list_screen.dart';
import 'package:coconut_wallet/screens/settings/security_self_check_screen.dart';
import 'package:coconut_wallet/screens/settings/terms_screen.dart';
import 'package:coconut_wallet/widgets/coconut_dropdown.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lottie/lottie.dart';
import 'package:coconut_wallet/providers/app_state_model.dart';
import 'package:coconut_wallet/providers/app_sub_state_model.dart';
import 'package:coconut_wallet/model/wallet_list_item.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/appbar/frosted_appbar.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:coconut_wallet/widgets/custom_tooltip.dart';
import 'package:coconut_wallet/widgets/wallet_row_item.dart';
import 'package:coconut_wallet/screens/onboarding_screen.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/bottom_sheet.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:provider/provider.dart';

class WalletListScreen extends StatefulWidget {
  const WalletListScreen({super.key});

  @override
  State<WalletListScreen> createState() => _WalletListScreenState();
}

class _WalletListScreenState extends State<WalletListScreen>
    with TickerProviderStateMixin {
  // WalletInitState가 finished가 되고 몇 초 후에 일시를 보여줄지 여부
  bool isShowLastUpdateTime = false;
  bool isShownErrorToast = false;
  bool _isSeeMoreDropdown = false;

  DateTime? _lastPressedAt;

  /// WalletInitState.finished 이후 3초뒤 변경 메소드
  Future showLastUpdateTimeAfterFewSeconds({int duration = 4}) async {
    if (isShowLastUpdateTime) return;
    await Future.delayed(Duration(seconds: duration));
    setState(() {
      isShowLastUpdateTime = true;
    });
  }

  late AppSubStateModel _subModel;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _subModel = Provider.of<AppSubStateModel>(context, listen: false);

    _animationController = BottomSheet.createAnimationController(this);
    _animationController.duration = const Duration(seconds: 2);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Logger.log('hasLaunchedBefore ? ${_subModel.hasLaunchedBefore}');

      if (!_subModel.hasLaunchedBefore) {
        Future.delayed(const Duration(milliseconds: 1000)).then((_) {
          MyBottomSheet.showBottomSheet_100(
            context: context,
            child: const OnboardingScreen(),
            enableDrag: false,
            backgroundColor: MyColors.nero,
            isDismissible: false,
            isScrollControlled: true,
            useSafeArea: false,
          );
        });
      }

      AppReviewService.showReviewScreenIfEligible(context,
          animationController: _animationController);
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = Provider.of<AppStateModel>(context, listen: false);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (Platform.isAndroid) {
          final now = DateTime.now();
          if (_lastPressedAt == null ||
              now.difference(_lastPressedAt!) > const Duration(seconds: 3)) {
            _lastPressedAt = now;
            Fluttertoast.showToast(
              backgroundColor: MyColors.grey,
              msg: "뒤로 가기 버튼을 한 번 더 누르면 종료됩니다.",
              toastLength: Toast.LENGTH_SHORT,
            );
          } else {
            SystemNavigator.pop();
          }
        }
      },
      child: Selector<AppStateModel, List<WalletListItem>>(
        shouldRebuild: (previous, next) => true,
        selector: (_, selectorModel) => selectorModel.walletList,
        builder: (context, wallets, child) {
          return Scaffold(
            backgroundColor: MyColors.black,
            body: Stack(
              children: [
                CustomScrollView(
                  semanticChildCount: wallets.length,
                  slivers: <Widget>[
                    FrostedAppBar(
                      onTapSeeMore: () {
                        setState(() {
                          _isSeeMoreDropdown = true;
                        });
                      },
                    ),
                    CupertinoSliverRefreshControl(
                      onRefresh: () async {
                        setState(() {
                          isShowLastUpdateTime = false;
                        });
                        if (wallets.isNotEmpty) {
                          model.initWallet();
                        }
                      },
                    ),
                    if (wallets.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Selector<AppStateModel, WalletInitState>(
                          selector: (_, selectorModel) =>
                              selectorModel.walletInitState,
                          builder: (context, state, child) {
                            // 지갑 정보 초기화 또는 갱신 중 에러가 발생했을 때 모두 toast로 알림
                            if (state == WalletInitState.error) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (isShownErrorToast) return;
                                isShownErrorToast = true;
                                CustomToast.showWarningToast(
                                    context: context,
                                    text: model.walletInitError!.message,
                                    seconds: 7);
                              });
                            } else {
                              isShownErrorToast = false;
                            }

                            String iconName = '';
                            String text = '';
                            Color color = MyColors.primary;

                            switch (state) {
                              case WalletInitState.impossible:
                                iconName = 'impossible';
                                text = '업데이트 불가';
                                color = MyColors.warningRed;
                              case WalletInitState.error:
                                iconName = 'failure';
                                text = '업데이트 실패';
                                color = MyColors.failedYellow;
                              case WalletInitState.finished:
                                iconName = 'complete';
                                text = '업데이트 완료';
                                color = MyColors.primary;
                              case WalletInitState.processing:
                                iconName = 'loading';
                                text = '업데이트 중';
                                color = MyColors.primary;
                              default:
                                iconName = 'complete';
                                text = '';
                                color = Colors.transparent;
                            }

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              state == WalletInitState.finished
                                  ? showLastUpdateTimeAfterFewSeconds()
                                  : setState(
                                      () => isShowLastUpdateTime = false);
                            });

                            if (isShowLastUpdateTime &&
                                _subModel.lastUpdateTime != 0) {
                              iconName = 'idle';
                              text =
                                  '마지막 업데이트 ${DateTimeUtil.formatLastUpdateTime(_subModel.lastUpdateTime)}';
                              color = MyColors.transparentWhite_50;
                            }

                            return GestureDetector(
                              onTap: isShowLastUpdateTime &&
                                      _subModel.lastUpdateTime != 0
                                  ? () {
                                      model.initWallet();
                                    }
                                  : null,
                              child: Container(
                                padding:
                                    const EdgeInsets.only(right: 28, top: 4),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Text(
                                      text,
                                      style: TextStyle(
                                        fontFamily:
                                            CustomFonts.text.getFontFamily,
                                        color: color,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        fontStyle: FontStyle.normal,
                                      ),
                                    ),
                                    const SizedBox(width: 8),

                                    /// Isolate - repository fetch를 메인 스레드에서 실행시 멈춤
                                    if (state ==
                                        WalletInitState.processing) ...{
                                      LottieBuilder.asset(
                                        'assets/files/status_loading.json',
                                        width: 20,
                                      ),
                                    } else ...{
                                      SvgPicture.asset(
                                          'assets/svg/status-$iconName.svg',
                                          width: 18,
                                          colorFilter: ColorFilter.mode(
                                              color, BlendMode.srcIn)),
                                    }
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    SliverSafeArea(
                      top: false,
                      minimum:
                          const EdgeInsets.only(top: 22, left: 8.0, right: 8.0),
                      sliver: Selector<AppStateModel, bool>(
                        selector: (_, selectorModel) =>
                            selectorModel.fastLoadDone,
                        builder: (context, fastLoadDone, child) {
                          return SliverList(
                            delegate: SliverChildBuilderDelegate((ctx, index) {
                              if (fastLoadDone == false) {
                                if (index == 0) {
                                  return const Padding(
                                    padding: EdgeInsets.only(top: 40.0),
                                    child: CupertinoActivityIndicator(
                                      color: MyColors.white,
                                      radius: 20,
                                    ),
                                  );
                                } else {
                                  return null;
                                }
                              }

                              if (index < wallets.length) {
                                final WalletListItem(
                                  id: id,
                                  name: name,
                                  balance: balance,
                                  iconIndex: iconIndex,
                                  colorIndex: colorIndex
                                ) = wallets[index];
                                return WalletRowItem(
                                  id: id,
                                  name: name,
                                  balance: balance,
                                  iconIndex: iconIndex,
                                  colorIndex: colorIndex,
                                  isLastItem: index == wallets.length - 1,
                                  isBalanceHidden: _subModel.isBalanceHidden,
                                );
                              }

                              if (index == wallets.length && wallets.isEmpty) {
                                return CustomTooltip(
                                    richText: RichText(
                                        text: TextSpan(
                                            text:
                                                '안녕하세요. 코코넛 월렛이에요!\n\n오른쪽 위 + 버튼을 눌러 보기 전용 지갑을 추가해 주세요.',
                                            style: Styles.subLabel.merge(
                                                TextStyle(
                                                    fontFamily: CustomFonts
                                                        .text.getFontFamily,
                                                    color: MyColors.white)))),
                                    showIcon: true,
                                    type: TooltipType.info);
                              }
                              return null;
                            }),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                Visibility(
                  visible: _isSeeMoreDropdown,
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTapDown: (details) {
                          setState(() {
                            _isSeeMoreDropdown = false;
                          });
                        },
                        child: Container(
                          width: double.maxFinite,
                          height: double.maxFinite,
                          color: Colors.transparent,
                        ),
                      ),
                      Align(
                        alignment: Alignment.topRight,
                        child: CoconutDropdown(
                          buttons: const [
                            '용어집',
                            '니모닉 문구 단어집',
                            '셀프 보안 점검',
                            '설정',
                            '앱 정보 보기'
                          ],
                          dividerIndex: 3,
                          onTapButton: (index) {
                            setState(() {
                              _isSeeMoreDropdown = false;
                            });
                            switch (index) {
                              case 0: // 용어집
                                MyBottomSheet.showBottomSheet_95(
                                    context: context,
                                    child: const TermsScreen());
                                break;
                              case 1: // 니모닉 문구 단어집
                                MyBottomSheet.showBottomSheet_95(
                                    context: context,
                                    child: const Bip39ListScreen());
                                break;
                              case 2: // 셀프 보안 점검
                                MyBottomSheet.showBottomSheet_95(
                                    context: context,
                                    child: const SecuritySelfCheckScreen());
                                break;
                              case 3: // 설정
                                Navigator.pushNamed(context, '/settings');
                                break;
                              case 4: // 앱 정보 보기
                                Navigator.pushNamed(context, '/app-info');
                                break;
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}
