import 'dart:io';

import 'package:coconut_wallet/widgets/overlays/user_experience_survey_bottom_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/app/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/app/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/app/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_list_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/settings_screen.dart';
import 'package:coconut_wallet/widgets/appbar/frosted_appbar.dart';
import 'package:coconut_wallet/widgets/custom_toast.dart';
import 'package:coconut_wallet/widgets/card/wallet_item_card.dart';
import 'package:coconut_wallet/widgets/card/wallet_list_add_guide_card.dart';
import 'package:coconut_wallet/widgets/card/wallet_list_terms_shortcut_card.dart';
import 'package:coconut_wallet/widgets/overlays/onboarding_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/overlays/security_self_check_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/overlays/terms_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/dropdown/custom_dropdown.dart';
import 'package:coconut_wallet/widgets/wallet_init_status_indicator.dart';
import 'package:coconut_wallet/utils/logger.dart';

class WalletListScreen extends StatefulWidget {
  const WalletListScreen({super.key});

  @override
  State<WalletListScreen> createState() => _WalletListScreenState();
}

class _WalletListScreenState extends State<WalletListScreen>
    with TickerProviderStateMixin {
  // WalletInitState가 finished가 되고 몇 초 후에 일시를 보여줄지 여부
  bool _isLastUpdateTimeVisible = false;
  bool _isDropdownMenuVisible = false;

  DateTime? _lastPressedAt;

  ResultOfSyncFromVault? _resultOfSyncFromVault;

  late ScrollController _scrollController;
  List<GlobalKey> _itemKeys = [];

  AnimationController? _slideAnimationController;
  AnimationController? _blinkAnimationController;
  Animation<Offset>? _slideAnimation;
  Animation<Color?>? _blinkAnimation;
  double? itemCardWidth;
  double? itemCardHeight;
  late WalletListViewModel _viewModel;

  final List<String> _dropdownButtons = [
    '용어집',
    '니모닉 문구 단어집',
    '셀프 보안 점검',
    '설정',
    '앱 정보 보기'
  ];
  late final List<Future<Object?> Function()> _dropdownActions;

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
                          _isDropdownMenuVisible = true;
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
                          _isLastUpdateTimeVisible = false;
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
                                _displayLastUpdateTimeAfterFourSeconds();
                              } else {
                                setState(
                                    () => _isLastUpdateTimeVisible = false);
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
                                isLastUpdateTimeVisible:
                                    _isLastUpdateTimeVisible,
                                lastUpdateTime: viewModel.lastUpdateTime),
                          );
                        },
                      ),
                    ),
                    // 용어집, 바로 추가하기, loading indicator
                    SliverToBoxAdapter(
                        child: Column(
                      children: [
                        if (!viewModel.isWalletsLoadedFromDb) ...{
                          const Padding(
                            padding: EdgeInsets.only(top: 40.0),
                            child: CupertinoActivityIndicator(
                              color: MyColors.white,
                              radius: 20,
                            ),
                          ),
                        } else ...{
                          if (viewModel.isTermsShortcutVisible)
                            WalletListTermsShortcutCard(
                              onTap: () {
                                CommonBottomSheets.showBottomSheet_90(
                                    context: context,
                                    child: const TermsBottomSheet());
                              },
                              onCloseTap: viewModel.hideTermsShortcut,
                            ),
                          if (viewModel.walletItemList.isEmpty)
                            WalletListAddGuideCard(
                                onPressed: _onAddScannerPressed)
                        },
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
                  visible: _isDropdownMenuVisible,
                  child: Stack(
                    children: [
                      GestureDetector(
                        onTapDown: (details) {
                          setState(() {
                            _isDropdownMenuVisible = false;
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
                          buttons: _dropdownButtons,
                          dividerIndex: 3,
                          onTapButton: (index) {
                            setState(() {
                              _isDropdownMenuVisible = false;
                            });
                            _dropdownActions[index].call();
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
    _scrollController.dispose();
    _slideAnimationController?.dispose();
    _blinkAnimationController?.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _viewModel = Provider.of<WalletListViewModel>(context, listen: false);

    _scrollController = ScrollController();

    _dropdownActions = [
      () => CommonBottomSheets.showBottomSheet_90(
          context: context, child: const TermsBottomSheet()),
      () => Navigator.pushNamed(context, '/mnemonic-word-list'),
      () => CommonBottomSheets.showBottomSheet_90(
          context: context, child: const SecuritySelfCheckBottomSheet()),
      () => CommonBottomSheets.showBottomSheet_90(
          context: context, child: const SettingsScreen()),
      () => Navigator.pushNamed(context, '/app-info'),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_viewModel.isOnBoardingVisible) {
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

      if (_viewModel.isReviewScreenVisible) {
        var animationController = BottomSheet.createAnimationController(this)
          ..duration = const Duration(seconds: 2);
        await CommonBottomSheets.showBottomSheet_100(
            context: context,
            child: const UserExperienceSurveyBottomSheet(),
            enableDrag: false,
            backgroundColor: MyColors.nero,
            isDismissible: false,
            isScrollControlled: true,
            useSafeArea: false,
            animationController: animationController);

        Future.delayed(const Duration(seconds: 5), () {
          animationController.dispose();
          _viewModel.updateAppReviewRequestCondition();
        });
      }
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

        _initializeLeftSlideAnimationController();
        return SlideTransition(
          position: _slideAnimation!,
          child: WalletItemCard(
            key: _itemKeys[index],
            id: id,
            name: name,
            balance: balance,
            iconIndex: iconIndex,
            colorIndex: colorIndex,
            isLastItem: index == viewModel.walletItemList.length - 1,
            isBalanceHidden: viewModel.isBalanceHidden,
            signers: signers,
          ),
        );
      }
      if (_resultOfSyncFromVault?.result ==
              WalletSyncResult.existingWalletUpdated &&
          viewModel.walletItemList[index].id ==
              _resultOfSyncFromVault?.walletId!) {
        _initializeBlinkAnimationController();

        Logger.log('** $index: existingWalletUpdated');
        return Stack(
          children: [
            WalletItemCard(
              key: _itemKeys[index],
              id: id,
              name: name,
              balance: balance,
              iconIndex: iconIndex,
              colorIndex: colorIndex,
              isLastItem: index == viewModel.walletItemList.length - 1,
              isBalanceHidden: viewModel.isBalanceHidden,
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

      return WalletItemCard(
        id: id,
        name: name,
        balance: balance,
        iconIndex: iconIndex,
        colorIndex: colorIndex,
        isLastItem: index == viewModel.walletItemList.length - 1,
        isBalanceHidden: viewModel.isBalanceHidden,
        signers: signers,
      );
    }
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

  /// WalletInitState.finished 이후 4초 뒤 마지막 업데이트 시간을 보여줌
  Future _displayLastUpdateTimeAfterFourSeconds() async {
    if (_isLastUpdateTimeVisible) return;
    await Future.delayed(const Duration(seconds: 4));
    if (mounted) {
      setState(() {
        _isLastUpdateTimeVisible = true;
      });
    }
  }
}
