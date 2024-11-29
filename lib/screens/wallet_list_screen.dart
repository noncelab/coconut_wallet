import 'dart:io';

import 'package:coconut_wallet/model/data/multisig_signer.dart';
import 'package:coconut_wallet/model/data/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/data/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/data/wallet_type.dart';
import 'package:coconut_wallet/screens/settings/security_self_check_screen.dart';
import 'package:coconut_wallet/screens/settings/settings_screen.dart';
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
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/widgets/appbar/frosted_appbar.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
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
  bool _isTapped = false; // 용어집 유도 카드

  DateTime? _lastPressedAt;

  /// WalletInitState.finished 이후 3초뒤 변경 메소드
  Future showLastUpdateTimeAfterFewSeconds({int duration = 4}) async {
    if (isShowLastUpdateTime) return;
    await Future.delayed(Duration(seconds: duration));
    if (mounted) {
      setState(() {
        isShowLastUpdateTime = true;
      });
    }
  }

  late AppStateModel _model;
  late AppSubStateModel _subModel;
  late AnimationController _animationController;
  late ScrollController _scrollController;

  late AnimationController _newWalletAddAnimcontroller;
  late Animation<Offset> _newWalletAddanimation;

  @override
  void initState() {
    super.initState();
    _subModel = Provider.of<AppSubStateModel>(context, listen: false);
    _model = Provider.of<AppStateModel>(context, listen: false);

    _animationController = BottomSheet.createAnimationController(this);
    _animationController.duration = const Duration(seconds: 2);

    initializeAnimationController();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
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

  void _onAddScannerPressed() async {
    final bool result =
        (await Navigator.pushNamed(context, '/wallet-add-scanner') as bool?) ??
            false;
    if (result) {
      if (_model.animatedWalletFlags.isNotEmpty &&
          _model.animatedWalletFlags.last) {
        initializeAnimationController();

        /// 리스트에 추가되는 애니메이션 보여줍니다.
        /// TODO: 최적화 필요, 현재는 build 함수 내 Selector 로 인해 수십번 rebuild 되기 때문에(원인 발견 못함) model의 _animatedWalletFlags를 통해 관리합니다.
        /// animatedWalletFlags의 last가 가장 최근에 추가된 항목이며, 이는 model의 syncFromVault에서 case1 일 때 적용됩니다.
        /// 애니메이션을 보여준 뒤에는 setAnimatedWalletFlags()를 실행해서 animatedWalletFlags를 모두 false로 설정해야 합니다.
        await Future.delayed(const Duration(milliseconds: 1000));
        _scrollToBottom();
        await Future.delayed(const Duration(milliseconds: 500));
        _newWalletAddAnimcontroller.forward();
        _model.setAnimatedWalletFlags();
      }
    }
  }

  void initializeAnimationController() {
    _scrollController = ScrollController();
    _newWalletAddAnimcontroller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _newWalletAddanimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _newWalletAddAnimcontroller,
        curve: Curves.easeOut,
      ),
    );
  }

  void _scrollToBottom() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
      child: Selector<AppStateModel, List<WalletListItemBase>>(
        shouldRebuild: (previous, next) => true,
        selector: (_, selectorModel) => selectorModel.walletBaseItemList,
        builder: (context, wallets, child) {
          return Scaffold(
            backgroundColor: MyColors.black,
            body: Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  semanticChildCount: wallets.length,
                  slivers: <Widget>[
                    FrostedAppBar(
                      onTapSeeMore: () {
                        setState(() {
                          _isSeeMoreDropdown = true;
                        });
                      },
                      onTapAddScanner: () async {
                        _onAddScannerPressed();
                      },
                    ),
                    CupertinoSliverRefreshControl(
                      onRefresh: () async {
                        setState(() {
                          isShowLastUpdateTime = false;
                        });
                        if (wallets.isNotEmpty) {
                          _model.initWallet();
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
                                    text: _model.walletInitError!.message,
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
                                      _model.initWallet();
                                    }
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.only(
                                    right: 28, top: 4, bottom: 16),
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
                    if (!_subModel.isOpenTermsScreen)
                      SliverToBoxAdapter(
                        child: GestureDetector(
                          onTap: () {
                            MyBottomSheet.showBottomSheet_90(
                                context: context, child: const TermsScreen());
                          },
                          onTapDown: (_) {
                            setState(() {
                              _isTapped = true;
                            });
                          },
                          onTapUp: (_) {
                            setState(() {
                              _isTapped = false;
                            });
                          },
                          onTapCancel: () {
                            setState(() {
                              _isTapped = false;
                            });
                          },
                          child: Container(
                            width: double.maxFinite,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: _isTapped
                                    ? MyColors.transparentWhite_20
                                    : MyColors.transparentWhite_12),
                            margin: const EdgeInsets.only(
                                left: 8, right: 8, bottom: 16),
                            padding: const EdgeInsets.only(
                                left: 26, top: 16, bottom: 16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('모르는 용어가 있으신가요?',
                                        style: Styles.body1.merge(
                                            const TextStyle(
                                                fontWeight: FontWeight.w600))),
                                    SizedBox(
                                      width: MediaQuery.sizeOf(context).width -
                                          100,
                                      child: Text.rich(
                                        TextSpan(
                                          children: [
                                            const TextSpan(
                                              text: '오른쪽 위 ',
                                              style: Styles.label,
                                            ),
                                            TextSpan(
                                              text: '•••',
                                              style: Styles.label.merge(
                                                  const TextStyle(
                                                      letterSpacing: -2.0)),
                                            ),
                                            const TextSpan(
                                              text: ' - 용어집 또는 여기를 눌러 바로가기',
                                              style: Styles.label,
                                            ),
                                          ],
                                        ),
                                        maxLines: 2,
                                      ),
                                    )
                                  ],
                                ),
                                GestureDetector(
                                  onTap: _subModel.setIsOpenTermsScreen,
                                  child: Container(
                                    color: Colors.transparent,
                                    padding: const EdgeInsets.all(16),
                                    child: SvgPicture.asset(
                                        'assets/svg/close.svg',
                                        width: 10,
                                        height: 10,
                                        colorFilter: const ColorFilter.mode(
                                            MyColors.white, BlendMode.srcIn)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    SliverSafeArea(
                      top: false,
                      minimum: const EdgeInsets.symmetric(horizontal: 8),
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
                                final WalletListItemBase(
                                  id: id,
                                  name: name,
                                  balance: balance,
                                  iconIndex: iconIndex,
                                  colorIndex: colorIndex
                                ) = wallets[index];

                                final base = wallets[index];
                                List<MultisigSigner>? signers;
                                if (base.walletType ==
                                    WalletType.multiSignature) {
                                  signers =
                                      (base as MultisigWalletListItem).signers;
                                }
                                return _model.animatedWalletFlags[index]
                                    ? SlideTransition(
                                        position: _newWalletAddanimation,
                                        child: WalletRowItem(
                                          id: id,
                                          name: name,
                                          balance: balance,
                                          iconIndex: iconIndex,
                                          colorIndex: colorIndex,
                                          isLastItem:
                                              index == wallets.length - 1,
                                          isBalanceHidden:
                                              _subModel.isBalanceHidden,
                                          signers: signers,
                                        ),
                                      )
                                    : WalletRowItem(
                                        id: id,
                                        name: name,
                                        balance: balance,
                                        iconIndex: iconIndex,
                                        colorIndex: colorIndex,
                                        isLastItem: index == wallets.length - 1,
                                        isBalanceHidden:
                                            _subModel.isBalanceHidden,
                                        signers: signers,
                                      );
                              }

                              if (index == wallets.length && wallets.isEmpty) {
                                return Container(
                                  width: double.maxFinite,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: MyColors.transparentWhite_12),
                                  padding: const EdgeInsets.only(
                                      top: 26, bottom: 24, left: 26, right: 26),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        '보기 전용 지갑을 추가해 주세요',
                                        style: Styles.title5,
                                      ),
                                      const Text(
                                        '오른쪽 위 + 버튼을 눌러도 추가할 수 있어요',
                                        style: Styles.label,
                                      ),
                                      const SizedBox(height: 16),
                                      CupertinoButton(
                                        onPressed: () async {
                                          _onAddScannerPressed();
                                        },
                                        borderRadius: BorderRadius.circular(10),
                                        padding: EdgeInsets.zero,
                                        color: MyColors.primary,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 28,
                                            vertical: 12,
                                          ),
                                          child: Text(
                                            '바로 추가하기',
                                            style: Styles.label.merge(
                                              const TextStyle(
                                                color: MyColors.black,
                                                fontWeight: FontWeight.w700,
                                                // fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
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
                                MyBottomSheet.showBottomSheet_90(
                                    context: context,
                                    child: const TermsScreen());
                                break;
                              case 1: // 니모닉 문구 단어집
                                Navigator.pushNamed(
                                    context, '/mnemonic-word-list');
                                break;
                              case 2: // 셀프 보안 점검
                                MyBottomSheet.showBottomSheet_90(
                                    context: context,
                                    child: const SecuritySelfCheckScreen());
                                break;
                              case 3: // 설정
                                MyBottomSheet.showBottomSheet_90(
                                    context: context,
                                    child: const SettingsScreen());
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
    _scrollController.dispose();
    _newWalletAddAnimcontroller.dispose();
    super.dispose();
  }
}
