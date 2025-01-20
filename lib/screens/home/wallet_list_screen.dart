import 'dart:io';

import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/app/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/app/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/app_sub_state_model.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_list_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/settings_screen.dart';
import 'package:coconut_wallet/services/app_review_service.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/appbar/frosted_appbar.dart';
import 'package:coconut_wallet/widgets/custom_dropdown.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/overlays/onboarding_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/overlays/security_self_check_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/overlays/terms_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/wallet_init_status_indicator.dart';
import 'package:coconut_wallet/widgets/wallet_row_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lottie/lottie.dart';
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
  bool _isSeeMoreDropdown = false;
  bool _isTapped = false; // 용어집 유도 카드

  DateTime? _lastPressedAt;

  ResultOfSyncFromVault? _resultOfSyncFromVault;

  late AppSubStateModel _subModel;

  late AnimationController _animationController;
  late ScrollController _scrollController;
  List<GlobalKey> _itemKeys = [];

  AnimationController? _slideAnimationController;
  AnimationController? _blinkAnimationController;
  Animation<Offset>? _slideAnimation;
  Animation<Color?>? _blinkAnimation;
  double? itemCardWidth;
  double? itemCardHeight;
  late WalletListViewModel _viewModel;

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
      child: Consumer<WalletListViewModel>(
        builder: (context, viewModel, child) {
          _itemKeys = List.generate(
              viewModel.walletItemList.length, (index) => GlobalKey());
          return Scaffold(
            backgroundColor: MyColors.black,
            body: Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  semanticChildCount: viewModel.walletItemList.length,
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
                        Logger.log(
                            '--> currentContext: ${_itemKeys[0].currentContext}');
                        setState(() {
                          isShowLastUpdateTime = false;
                        });
                        if (viewModel.walletItemList.isNotEmpty) {
                          viewModel.initWallet().catchError((_) {
                            Logger.log('--> error catch');
                          }).whenComplete(() {
                            Logger.log(
                                '---> wallet stateu: ${viewModel.walletInitState}');
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (viewModel.walletInitState ==
                                  WalletInitState.error) {
                                CustomToast.showWarningToast(
                                    context: context,
                                    text: viewModel.walletInitErrorMessage!,
                                    seconds: 7);
                              }
                              if (viewModel.walletInitState ==
                                  WalletInitState.finished) {
                                _showLastUpdateTimeAfterFewSeconds();
                              } else {
                                setState(() => isShowLastUpdateTime = false);
                              }
                            });
                          });
                        }
                      },
                    ),
                    // Update Status, update indicator
                    SliverToBoxAdapter(
                      child: Selector<WalletListViewModel, WalletInitState>(
                        selector: (_, selectorModel) =>
                            selectorModel.walletInitState,
                        builder: (context, state, child) {
                          return Visibility(
                            visible: viewModel.walletItemList.isNotEmpty,
                            child: WalletInitStatusIndicator(
                                state: state,
                                onTap: viewModel.initWallet,
                                isShowLastUpdateTime: isShowLastUpdateTime,
                                lastUpdateTime: viewModel.lastUpdateTime),
                          );
                        },
                      ),
                    ),
                    // 용어집, 바로 추가하기, loading indicator
                    SliverToBoxAdapter(
                        child: Column(
                      children: [
                        // 용어집
                        Visibility(
                          visible: !_subModel.isOpenTermsScreen &&
                              viewModel.fastLoadDone,
                          child: GestureDetector(
                            onTap: () {
                              CommonBottomSheets.showBottomSheet_90(
                                  context: context,
                                  child: const TermsBottomSheet());
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
                                crossAxisAlignment: CrossAxisAlignment.center,
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
                                        width:
                                            MediaQuery.sizeOf(context).width -
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
                        // 바로 추가하기
                        Visibility(
                          visible: viewModel.fastLoadDone &&
                              viewModel.walletItemList.isEmpty,
                          child: Container(
                            width: double.maxFinite,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: MyColors.transparentWhite_12),
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            padding: const EdgeInsets.only(
                                top: 26, bottom: 24, left: 26, right: 26),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                          visible: !viewModel.fastLoadDone,
                          child: const Padding(
                            padding: EdgeInsets.only(top: 40.0),
                            child: CupertinoActivityIndicator(
                              color: MyColors.white,
                              radius: 20,
                            ),
                          ),
                        ),
                      ],
                    )),
                    // 지갑 목록
                    SliverSafeArea(
                      top: false,
                      minimum: const EdgeInsets.symmetric(horizontal: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                            childCount: viewModel.walletItemList.length,
                            (ctx, index) {
                          return _getWalletRowItem(index, viewModel);
                        }),
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
                                CommonBottomSheets.showBottomSheet_90(
                                    context: context,
                                    child: const TermsBottomSheet());
                                break;
                              case 1: // 니모닉 문구 단어집
                                Navigator.pushNamed(
                                    context, '/mnemonic-word-list');
                                break;
                              case 2: // 셀프 보안 점검
                                CommonBottomSheets.showBottomSheet_90(
                                    context: context,
                                    child:
                                        const SecuritySelfCheckBottomSheet());
                                break;
                              case 3: // 설정
                                CommonBottomSheets.showBottomSheet_90(
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
    _slideAnimationController?.dispose();
    _blinkAnimationController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _viewModel = Provider.of<WalletListViewModel>(context, listen: false);

    _subModel = Provider.of<AppSubStateModel>(context, listen: false);

    _animationController = BottomSheet.createAnimationController(this);
    _animationController.duration = const Duration(seconds: 2);

    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_viewModel.showOnBoarding) {
        Future.delayed(const Duration(milliseconds: 1000)).then((_) {
          CommonBottomSheets.showBottomSheet_100(
            context: context,
            child: const OnboardingBottomSheet(),
            enableDrag: false,
            backgroundColor: MyColors.nero,
            isDismissible: false,
            isScrollControlled: true,
            useSafeArea: false,
          );
        });
      }

      // TODO:
      AppReviewService.showReviewScreenIfEligible(context,
          animationController: _animationController);
    });
  }

  Future _animateWalletBlink() async {
    /// 변경사항이 업데이트된 경우 해당 카드에 깜빡임 효과를 부여합니다.
    final int walletId = _resultOfSyncFromVault!.walletId!;
    final int index = _viewModel.walletItemList
        .indexWhere((element) => element.id == walletId);

    if (index == -1) return;

    await Future.delayed(const Duration(milliseconds: 600));
    _scrollToItem(index);
    await Future.delayed(const Duration(milliseconds: 1000));

    itemCardWidth =
        (_itemKeys[index].currentContext!.findRenderObject() as RenderBox)
                .size
                .width +
            20;
    itemCardHeight =
        (_itemKeys[index].currentContext!.findRenderObject() as RenderBox)
                .size
                .height -
            (index != _viewModel.walletItemList.length - 1 ? 10 : 0);

    await _blinkAnimationController!.forward();
    await _blinkAnimationController!.reverse();

    _blinkAnimationController!.reset();
  }

  Future _animateWalletSlideLeft() async {
    await Future.delayed(const Duration(milliseconds: 1000));
    _scrollToBottom();
    await Future.delayed(const Duration(milliseconds: 500));
    _slideAnimationController!.forward();
  }

  Widget? _getWalletRowItem(int index, WalletListViewModel viewModel) {
    if (index < viewModel.walletItemList.length) {
      final WalletListItemBase(
        id: id,
        name: name,
        balance: balance,
        iconIndex: iconIndex,
        colorIndex: colorIndex
      ) = viewModel.walletItemList[index];

      final base = viewModel.walletItemList[index];
      List<MultisigSigner>? signers;
      if (base.walletType == WalletType.multiSignature) {
        signers = (base as MultisigWalletListItem).signers;
      }
      if (_resultOfSyncFromVault?.result == WalletSyncResult.newWalletAdded &&
          index == viewModel.walletItemList.length - 1) {
        Logger.log('** $index: newWalletAdded');

        // TODO: _slideAnimation initialization
        _initializeLeftSlideAnimationController();
        return SlideTransition(
          position: _slideAnimation!,
          child: WalletRowItem(
            key: _itemKeys[index],
            id: id,
            name: name,
            balance: balance,
            iconIndex: iconIndex,
            colorIndex: colorIndex,
            isLastItem: index == viewModel.walletItemList.length - 1,
            isBalanceHidden: _subModel.isBalanceHidden,
            signers: signers,
          ),
        );
      }
      if (_resultOfSyncFromVault?.result ==
              WalletSyncResult.existingWalletUpdated &&
          viewModel.walletItemList[index].id ==
              _resultOfSyncFromVault?.walletId!) {
        // TODO: blinkAnimation initialization
        _initializeBlinkAnimationController();

        Logger.log('** $index: existingWalletUpdated');
        return Stack(
          children: [
            WalletRowItem(
              key: _itemKeys[index],
              id: id,
              name: name,
              balance: balance,
              iconIndex: iconIndex,
              colorIndex: colorIndex,
              isLastItem: index == viewModel.walletItemList.length - 1,
              isBalanceHidden: _subModel.isBalanceHidden,
              signers: signers,
            ),
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _blinkAnimation!,
                builder: (context, child) {
                  return Container(
                    decoration: BoxDecoration(
                        color: _blinkAnimation!.value,
                        borderRadius: BorderRadius.circular(28)),
                    width: itemCardWidth,
                    height: itemCardHeight,
                  );
                },
              ),
            )
          ],
        );
      }

      return WalletRowItem(
        id: id,
        name: name,
        balance: balance,
        iconIndex: iconIndex,
        colorIndex: colorIndex,
        isLastItem: index == viewModel.walletItemList.length - 1,
        isBalanceHidden: _subModel.isBalanceHidden,
        signers: signers,
      );
    }
    Logger.log('** $index: return null');
    return null;
  }

  void _initializeBlinkAnimationController() {
    if (_blinkAnimationController != null && _blinkAnimation != null) {
      return;
    }

    _blinkAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
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
    ).animate(_blinkAnimationController!);
  }

  void _initializeLeftSlideAnimationController() {
    if (_slideAnimationController != null && _slideAnimation != null) {
      return;
    }

    _slideAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideAnimationController!,
        curve: Curves.easeInOut,
      ),
    );
  }

  void _onAddScannerPressed() async {
    final ResultOfSyncFromVault? scanResult =
        (await Navigator.pushNamed(context, '/wallet-add-scanner')
            as ResultOfSyncFromVault?);

    setState(() {
      _resultOfSyncFromVault = scanResult;
    });

    if (_resultOfSyncFromVault == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_resultOfSyncFromVault!.result == WalletSyncResult.newWalletAdded) {
        await _animateWalletSlideLeft();
      } else {
        await _animateWalletBlink();
      }

      _resultOfSyncFromVault = null;
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

  void _scrollToItem(int index) {
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

  /// WalletInitState.finished 이후 3초뒤 변경 메소드
  Future _showLastUpdateTimeAfterFewSeconds({int duration = 4}) async {
    if (isShowLastUpdateTime) return;
    await Future.delayed(Duration(seconds: duration));
    if (mounted) {
      setState(() {
        isShowLastUpdateTime = true;
      });
    }
  }
}
