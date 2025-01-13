import 'dart:io';

import 'package:coconut_wallet/model/app/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/app/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/screens/settings/security_self_check_screen.dart';
import 'package:coconut_wallet/screens/settings/settings_screen.dart';
import 'package:coconut_wallet/screens/settings/terms_screen.dart';
import 'package:coconut_wallet/widgets/custom_dropdown.dart';
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
import 'package:coconut_wallet/screens/onboarding/onboarding_screen.dart';
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

  List<GlobalKey> _itemKeys = [];

  late AnimationController _slideAnimationController;
  late AnimationController _blinkAnimationController;
  late Animation<Offset> _slideAnimation;
  late Animation<Color?> _blinkAnimation;
  double? itemCardWidth;
  double? itemCardHeight;

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
    final Map<String, dynamic>? result =
        (await Navigator.pushNamed(context, '/wallet-add-scanner')
            as Map<String, dynamic>?);

    if (result == null) return;

    if (result['result'] as WalletSyncResult ==
        WalletSyncResult.newWalletAdded) {
      if (_model.animatedWalletFlags.isNotEmpty &&
          _model.animatedWalletFlags.last == WalletSyncResult.newWalletAdded) {
        initializeAnimationController();

        /// 리스트에 추가되는 애니메이션 보여줍니다.
        /// animatedWalletFlags의 last가 가장 최근에 추가된 항목이며, 이는 model의 syncFromVault에서 case1 일 때 적용됩니다.
        /// 애니메이션을 보여준 뒤에는 setAnimatedWalletFlags()를 실행해서 animatedWalletFlags를 모두 false로 설정해야 합니다.
        await Future.delayed(const Duration(milliseconds: 1000));
        _scrollToBottom();
        await Future.delayed(const Duration(milliseconds: 500));
        _slideAnimationController.forward();
        _model.setAnimatedWalletFlags();
      }
    } else if (result['result'] as WalletSyncResult ==
        WalletSyncResult.existingWalletUpdated) {
      /// 변경사항이 업데이트된 경우 해당 카드에 깜빡임 효과를 부여합니다.
      final int walletId = result['id'] as int;
      final int index =
          _model.walletItemList.indexWhere((element) => element.id == walletId);

      if (index == -1) return;
      if (_model.animatedWalletFlags.isNotEmpty &&
          _model.animatedWalletFlags[index] ==
              WalletSyncResult.existingWalletUpdated) {
        initializeAnimationController();
        await Future.delayed(const Duration(milliseconds: 600));
        scrollToItem(index);
        await Future.delayed(const Duration(milliseconds: 1000));

        itemCardWidth =
            (_itemKeys[index].currentContext!.findRenderObject() as RenderBox)
                    .size
                    .width +
                20;
        itemCardHeight =
            (_itemKeys[index].currentContext!.findRenderObject() as RenderBox)
                .size
                .height;

        // 마지막 아이템이 아닌 경우
        if (index != _model.walletItemList.length - 1) {
          itemCardHeight = itemCardHeight! - 10;
        }

        await _blinkAnimationController.forward();
        await _blinkAnimationController.reverse();

        _blinkAnimationController.reset();
        _model.setAnimatedWalletFlags();
      }
    }
  }

  void initializeAnimationController(
      {WalletSyncResult type = WalletSyncResult.newWalletAdded}) {
    _scrollController = ScrollController();

    // create 일 때: 슬라이드 애니메이션
    _slideAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    // update 일 때: 깜빡임 애니메이션
    _blinkAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _blinkAnimation = TweenSequence<Color?>(
      [
        TweenSequenceItem(
          tween: ColorTween(
            begin: Colors.transparent,
            end: MyColors.transparentWhite_20,
          ),
          weight: 50,
        ),
        TweenSequenceItem(
          tween: ColorTween(
            begin: MyColors.transparentWhite_20,
            end: Colors.transparent,
          ),
          weight: 50,
        ),
      ],
    ).animate(_blinkAnimationController);
  }

  void scrollToItem(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients && index < _itemKeys.length) {
        final context = _itemKeys[index].currentContext;
        if (context != null) {
          final box = context.findRenderObject() as RenderBox;
          var targetOffset = box.localToGlobal(Offset.zero).dy +
              _scrollController.offset -
              (MediaQuery.of(context).size.height / 2);

          if (targetOffset >= _scrollController.position.maxScrollExtent) {
            targetOffset = _scrollController.position.maxScrollExtent;
          }

          if (targetOffset < 0) {
            // 음수 값일 때는 스크롤 되면서 ptr 되므로 이를 방지
            _scrollController.animateTo(
              _scrollController.position.minScrollExtent,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );

            return;
          }

          _scrollController.animateTo(
            targetOffset,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          _scrollToBottom();
        }
      }
    });
  }

  void _scrollToBottom() async {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final maxScrollExtent = _scrollController.position.maxScrollExtent;

        if (maxScrollExtent > 0) {
          _scrollController.animateTo(
            maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        }
      }
    });
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
        selector: (_, selectorModel) => selectorModel.walletItemList,
        builder: (context, wallets, child) {
          _itemKeys = List.generate(wallets.length, (index) => GlobalKey());
          return Scaffold(
            backgroundColor: MyColors.black,
            body: Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  semanticChildCount: wallets.length,
                  slivers: <Widget>[
                    // Appbar
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
                    // Pull to refresh, refresh indicator(hide)
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
                    // Update Status, update indicator
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
                                : setState(() => isShowLastUpdateTime = false);
                          });

                          if (isShowLastUpdateTime &&
                              _subModel.lastUpdateTime != 0) {
                            iconName = 'idle';
                            text =
                                '마지막 업데이트 ${DateTimeUtil.formatLastUpdateTime(_subModel.lastUpdateTime)}';
                            color = MyColors.transparentWhite_50;
                          }

                          return Visibility(
                            visible: wallets.isNotEmpty,
                            child: GestureDetector(
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
                            ),
                          );
                        },
                      ),
                    ),
                    // 용어집, 바로 추가하기, loading indicator
                    SliverToBoxAdapter(
                      child: Selector<AppStateModel, bool>(
                        selector: (_, model) => model.fastLoadDone,
                        builder: (context, fastLoadDone, child) {
                          return Column(
                            children: [
                              // 용어집
                              Visibility(
                                visible: !_subModel.isOpenTermsScreen &&
                                    fastLoadDone,
                                child: GestureDetector(
                                  onTap: () {
                                    MyBottomSheet.showBottomSheet_90(
                                        context: context,
                                        child: const TermsScreen());
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text('모르는 용어가 있으신가요?',
                                                style: Styles.body1.merge(
                                                    const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600))),
                                            SizedBox(
                                              width: MediaQuery.sizeOf(context)
                                                      .width -
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
                                                              letterSpacing:
                                                                  -2.0)),
                                                    ),
                                                    const TextSpan(
                                                      text:
                                                          ' - 용어집 또는 여기를 눌러 바로가기',
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
                                                colorFilter:
                                                    const ColorFilter.mode(
                                                        MyColors.white,
                                                        BlendMode.srcIn)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // 바로 추가하기
                              Visibility(
                                visible: fastLoadDone && wallets.isEmpty,
                                child: Container(
                                  width: double.maxFinite,
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: MyColors.transparentWhite_12),
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 8),
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
                                ),
                              ),
                              // Indicator
                              Visibility(
                                visible: !fastLoadDone,
                                child: const Padding(
                                  padding: EdgeInsets.only(top: 40.0),
                                  child: CupertinoActivityIndicator(
                                    color: MyColors.white,
                                    radius: 20,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    // 지갑 목록
                    SliverSafeArea(
                      top: false,
                      minimum: const EdgeInsets.symmetric(horizontal: 8),
                      sliver: Selector<AppStateModel, bool>(
                        selector: (_, selectorModel) =>
                            selectorModel.fastLoadDone,
                        builder: (context, fastLoadDone, child) {
                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                                childCount: wallets.length, (ctx, index) {
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

                                WalletSyncResult? flag =
                                    _model.animatedWalletFlags[index];
                                return flag == WalletSyncResult.newWalletAdded
                                    ? SlideTransition(
                                        position: _slideAnimation,
                                        child: WalletRowItem(
                                          key: _itemKeys[index],
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
                                    : flag ==
                                            WalletSyncResult
                                                .existingWalletUpdated
                                        ? Stack(
                                            children: [
                                              WalletRowItem(
                                                key: _itemKeys[index],
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
                                              IgnorePointer(
                                                child: AnimatedBuilder(
                                                  animation: _blinkAnimation,
                                                  builder: (context, child) {
                                                    return Container(
                                                      decoration: BoxDecoration(
                                                          color: _blinkAnimation
                                                              .value,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      28)),
                                                      width: itemCardWidth,
                                                      height: itemCardHeight,
                                                    );
                                                  },
                                                ),
                                              )
                                            ],
                                          )
                                        : WalletRowItem(
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
                        child: CustomDropdown(
                          margin: EdgeInsets.only(
                              top: (84 + MediaQuery.of(context).padding.top) -
                                  (MediaQuery.of(context).padding.top / 2),
                              right: 20),
                          backgroundColor: MyColors.grey,
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
    _slideAnimationController.dispose();
    _blinkAnimationController.dispose();
    super.dispose();
  }
}
