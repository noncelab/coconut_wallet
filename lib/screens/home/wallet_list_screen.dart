import 'dart:async';
import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_list_user_experience_survey_bottom_sheet.dart';
import 'package:coconut_wallet/utils/amimation_util.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/loading_indicator/loading_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_list_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/settings_screen.dart';
import 'package:coconut_wallet/widgets/card/wallet_item_card.dart';
import 'package:coconut_wallet/widgets/card/wallet_list_add_guide_card.dart';
import 'package:coconut_wallet/widgets/card/wallet_list_terms_shortcut_card.dart';
import 'package:coconut_wallet/screens/home/wallet_list_onboarding_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/home/wallet_list_security_self_check_bottom_sheet.dart';
import 'package:coconut_wallet/screens/home/wallet_list_terms_bottom_sheet.dart';

class WalletListScreen extends StatefulWidget {
  const WalletListScreen({super.key});

  @override
  State<WalletListScreen> createState() => _WalletListScreenState();
}

class _WalletListScreenState extends State<WalletListScreen>
    with TickerProviderStateMixin {
  final GlobalKey _dropdownButtonKey = GlobalKey();
  Size _dropdownButtonSize = const Size(0, 0);
  Offset _dropdownButtonPosition = Offset.zero;

  final kTargetHeight = 30.0;
  bool _isDropdownMenuVisible = false;

  DateTime? _lastPressedAt;

  ResultOfSyncFromVault? _resultOfSyncFromVault;

  late ScrollController _scrollController;
  List<GlobalKey> _itemKeys = [];

  late List<WalletListItemBase> _previousWalletList = [];
  final GlobalKey<SliverAnimatedListState> _walletListKey =
      GlobalKey<SliverAnimatedListState>();
  final Duration _duration = const Duration(milliseconds: 1200);

  double? itemCardWidth;
  double? itemCardHeight;
  late WalletListViewModel _viewModel;

  final List<String> _dropdownButtons = [
    t.glossary,
    t.mnemonic_wordlist,
    t.self_security_check,
    t.settings,
    t.view_app_info,
  ];
  late final List<Future<Object?> Function()> _dropdownActions;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider4<WalletProvider, PreferenceProvider,
        VisibilityProvider, ConnectivityProvider, WalletListViewModel>(
      create: (_) => _viewModel,
      update: (BuildContext context,
          WalletProvider walletProvider,
          PreferenceProvider preferenceProvider,
          VisibilityProvider visibilityProvider,
          ConnectivityProvider connectivityProvider,
          WalletListViewModel? previous) {
        if (previous!.isBalanceHidden != preferenceProvider.isBalanceHidden) {
          previous.setIsBalanceHidden(preferenceProvider.isBalanceHidden);
        }

        if (previous.isNetworkOn != connectivityProvider.isNetworkOn) {
          previous.updateIsNetworkOn(connectivityProvider.isNetworkOn);
        }
        debugPrint('update!!!!!!!!!!!!');
        // FIXME: 다른 provider의 변경에 의해서도 항상 호출됨
        return previous..onWalletProviderUpdated(walletProvider);
      },
      child: Consumer<WalletListViewModel>(
        builder: (context, viewModel, child) {
          debugPrint('builder!!!!!!!!!!!');
          _itemKeys = List.generate(
              viewModel.walletItemList.length, (index) => GlobalKey());
          _handleTransactionListUpdate(
            viewModel.walletItemList,
            (id) => viewModel.getWalletBalance(id),
            viewModel.isBalanceHidden,
          );
          return PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) async {
              if (Platform.isAndroid) {
                final now = DateTime.now();
                if (_lastPressedAt == null ||
                    now.difference(_lastPressedAt!) >
                        const Duration(seconds: 3)) {
                  _lastPressedAt = now;
                  Fluttertoast.showToast(
                    backgroundColor: CoconutColors.gray800,
                    msg: t.toast.back_exit,
                    toastLength: Toast.LENGTH_SHORT,
                  );
                } else {
                  SystemNavigator.pop();
                }
              }
            },
            child: Scaffold(
              backgroundColor: CoconutColors.black,
              extendBodyBehindAppBar: true,
              body: SafeArea(
                top: false,
                bottom: false,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    setState(() {
                      _isDropdownMenuVisible = false;
                    });
                  },
                  child: Stack(
                    children: [
                      CustomScrollView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          semanticChildCount: viewModel.walletItemList.length,
                          slivers: <Widget>[
                            // Appbar
                            CoconutAppBar.buildHomeAppbar(
                              context: context,
                              leadingSvgAsset: SvgPicture.asset(
                                  'assets/svg/coconut.svg',
                                  colorFilter: const ColorFilter.mode(
                                      CoconutColors.white, BlendMode.srcIn),
                                  width: 24),
                              appTitle: t.wallet,
                              actionButtonList: [
                                Container(
                                  height: 40,
                                  width: 40,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: IconButton(
                                    icon: SvgPicture.asset(
                                      'assets/svg/book.svg',
                                      width: 18,
                                      height: 18,
                                      colorFilter: const ColorFilter.mode(
                                          CoconutColors.white, BlendMode.srcIn),
                                    ),
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return CoconutPopup(
                                            title: t.alert.tutorial.title,
                                            description:
                                                t.alert.tutorial.description,
                                            onTapRight: () async {
                                              launchURL(
                                                TUTORIAL_URL,
                                                defaultMode: false,
                                              );
                                              Navigator.of(context).pop();
                                            },
                                            onTapLeft: () {
                                              Navigator.of(context).pop();
                                            },
                                            rightButtonText:
                                                t.alert.tutorial.btn_view,
                                            rightButtonColor:
                                                CoconutColors.cyan,
                                            leftButtonText: t.close,
                                          );
                                        },
                                      );
                                    },
                                    color: CoconutColors.white,
                                  ),
                                ),
                                SizedBox(
                                  height: 40,
                                  width: 40,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.add_rounded,
                                    ),
                                    onPressed: () {
                                      _onAddScannerPressed();
                                    },
                                    color: CoconutColors.white,
                                  ),
                                ),
                                SizedBox(
                                  key: _dropdownButtonKey,
                                  height: 40,
                                  width: 40,
                                  child: IconButton(
                                    icon: const Icon(CupertinoIcons.ellipsis,
                                        size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _isDropdownMenuVisible = true;
                                      });
                                    },
                                    color: CoconutColors.white,
                                  ),
                                ),
                              ],
                              bottomWidget: PreferredSize(
                                preferredSize: const Size.fromHeight(20),
                                child: _topNetworkAlertWidget(
                                    isNetworkOn:
                                        viewModel.isNetworkOn == null ||
                                            viewModel.isNetworkOn == true),
                              ),
                              appBarInnerMargin: viewModel.isNetworkOn == false
                                  ? const EdgeInsets.symmetric(
                                      vertical: 30,
                                    )
                                  : const EdgeInsets.only(
                                      top: 30,
                                    ),
                            ),
                            CupertinoSliverRefreshControl(
                              onRefresh: viewModel.refreshWallets,
                            ),
                            // loading indicator with animation
                            SliverToBoxAdapter(
                                child: AnimatedSwitcher(
                              transitionBuilder: (child, animation) =>
                                  FadeTransition(
                                opacity: animation,
                                child: SizeTransition(
                                  sizeFactor: animation,
                                  child: child,
                                ),
                              ),
                              duration: const Duration(milliseconds: 300),
                              child: viewModel.shouldShowLoadingIndicator
                                  ? const Center(
                                      child: Padding(
                                        key: ValueKey("loading"),
                                        padding: EdgeInsets.only(bottom: 20.0),
                                        child: LoadingIndicator(),
                                      ),
                                    )
                                  : null,
                            )),
                            // 용어집, 바로 추가하기
                            SliverToBoxAdapter(
                                child: Column(
                              children: [
                                if (!viewModel.shouldShowLoadingIndicator) ...{
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
                            // SliverSafeArea(
                            //   top: false,
                            //   minimum: const EdgeInsets.symmetric(horizontal: 8),
                            //   sliver: SliverList(
                            //     delegate: SliverChildBuilderDelegate(
                            //         childCount: viewModel.walletItemList.length,
                            //         (ctx, index) {
                            //       return _getWalletRowItem(index, viewModel);
                            //     }),
                            //   ),
                            // ),
                            _buildSliverAnimatedList(
                                viewModel.walletItemList,
                                (id) => viewModel.getWalletBalance(id),
                                viewModel.isBalanceHidden),
                          ]),
                      Positioned(
                        top: _dropdownButtonPosition.dy +
                            _dropdownButtonSize.height,
                        right: 20,
                        child: Visibility(
                          visible: _isDropdownMenuVisible,
                          child: CoconutPulldownMenu(
                            shadowColor: CoconutColors.gray800,
                            dividerColor: CoconutColors.gray800,
                            buttons: _dropdownButtons,
                            dividerHeight: 1,
                            onTap: ((index) {
                              setState(() {
                                _isDropdownMenuVisible = false;
                              });
                              _dropdownActions[index].call();
                            }),
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _handleTransactionListUpdate(List<WalletListItemBase> walletList,
      Function(int) getWalletBalance, bool isBalanceHidden) {
    final oldTxMap = {
      for (var walletItem in _previousWalletList) walletItem.id: walletItem
    };

    final newTxMap = {
      for (var walletItem in walletList) walletItem.id: walletItem
    };

    final List<int> insertedIndexes = [];
    int removedIndex = -1;

    for (int i = 0; i < walletList.length; i++) {
      if (!oldTxMap.containsKey(walletList[i].id)) {
        insertedIndexes.add(i);
      }
    }
    debugPrint('oldTxMap ${oldTxMap.keys}');
    debugPrint('newTxMap ${newTxMap.keys}');

    for (int i = 0; i < _previousWalletList.length; i++) {
      if (!newTxMap.containsKey(_previousWalletList[i].id)) {
        removedIndex = i;
        break;
      }
    }
    debugPrint('pid ${_previousWalletList.map(
      (e) => e.id,
    )}');

    // 삽입된 인덱스 순서대로 추가
    for (var index in insertedIndexes) {
      _walletListKey.currentState?.insertItem(index, duration: _duration);
    }

    if (removedIndex != -1) {
      _walletListKey.currentState?.removeItem(
        removedIndex,
        duration: _duration,
        (context, animation) {
          // 이미 삭제된 인덱스 무시
          if (removedIndex >= _previousWalletList.length) return Container();
          return _buildRemoveWalletItem(
            _previousWalletList[removedIndex],
            removedIndex,
            animation,
            walletList,
            getWalletBalance,
            isBalanceHidden,
          );
        },
      );
    }

    _previousWalletList = List.from(walletList);
  }

  Widget _buildSliverAnimatedList(List<WalletListItemBase> walletList,
      Function(int) getWalletBalance, bool isBalanceHidden) {
    return SliverAnimatedList(
      key: _walletListKey,
      initialItemCount: walletList.length,
      itemBuilder: (context, index, animation) {
        return _buildWalletItem(
            walletList, index, animation, getWalletBalance, isBalanceHidden);
      },
    );
  }

  Widget _buildWalletItem(
      List<WalletListItemBase> walletList,
      int index,
      Animation<double> animation,
      Function(int) getWalletBalance,
      bool isBalanceHidden) {
    var offsetAnimation = AnimationUtil.buildSlideInAnimation(animation);

    return Column(
      children: [
        SlideTransition(
            position: offsetAnimation,
            child: _getWalletRowItem(
                Key(walletList[index].id.toString()),
                walletList[index],
                getWalletBalance,
                isBalanceHidden,
                index == walletList.length - 1)),
        walletList.length - 1 == index
            ? CoconutLayout.spacing_1000h
            : CoconutLayout.spacing_200h,
      ],
    );
  }

  Widget _buildRemoveWalletItem(
      WalletListItemBase wallet,
      int index,
      Animation<double> animation,
      List<WalletListItemBase> walletList,
      Function(int) getWalletBalance,
      bool isBalanceHidden) {
    return Container(
      child: _getWalletRowItem(Key(wallet.id.toString()), walletList[index],
          getWalletBalance, isBalanceHidden, index == walletList.length - 1),
    );
  }

  PreferredSize _topNetworkAlertWidget({required bool isNetworkOn}) {
    double targetHeight = isNetworkOn ? 0 : kTargetHeight;

    return PreferredSize(
      preferredSize: Size.fromHeight(kTargetHeight),
      child: SizedBox(
        height: kTargetHeight,
        width: double.infinity,
        child: Stack(children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              height: targetHeight,
              child: Container(
                color: CoconutColors.hotPink,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset('assets/svg/triangle-warning.svg'),
                    CoconutLayout.spacing_100w,
                    Text(
                      t.errors.network_not_found,
                      style: CoconutTypography.body3_12,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _topLoadingIndicatorWidget() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Container(
        height: null,
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: const CupertinoActivityIndicator(
          color: CoconutColors.white,
          radius: 14,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _viewModel = WalletListViewModel(
      Provider.of<WalletProvider>(context, listen: false),
      Provider.of<VisibilityProvider>(context, listen: false),
      Provider.of<PreferenceProvider>(context, listen: false).isBalanceHidden,
      Provider.of<NodeProvider>(context, listen: false),
      Provider.of<TransactionProvider>(context, listen: false),
      Provider.of<ConnectivityProvider>(context, listen: false),
    );

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
      if (_dropdownButtonKey.currentContext != null) {
        final faucetRenderBox =
            _dropdownButtonKey.currentContext?.findRenderObject() as RenderBox;
        _dropdownButtonPosition = faucetRenderBox.localToGlobal(Offset.zero);
        _dropdownButtonSize = faucetRenderBox.size;
      }

      if (_viewModel.isOnBoardingVisible) {
        Future.delayed(const Duration(milliseconds: 1000)).then((_) {
          CommonBottomSheets.showBottomSheet_100(
            context: context,
            child: const OnboardingBottomSheet(),
            enableDrag: false,
            backgroundColor: CoconutColors.gray900,
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
            backgroundColor: CoconutColors.gray900,
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

  Widget? _getWalletRowItem(Key key, WalletListItemBase walletItem,
      Function(int) getWalletBalance, bool isBalanceHidden, bool isLastItem) {
    final WalletListItemBase(
      id: id,
      name: name,
      iconIndex: iconIndex,
      colorIndex: colorIndex,
    ) = walletItem;
    final int? balance = getWalletBalance(id);

    List<MultisigSigner>? signers;
    if (walletItem.walletType == WalletType.multiSignature) {
      signers = (walletItem as MultisigWalletListItem).signers;
    }

    final walletItemCard = WalletItemCard(
      key: key,
      id: id,
      name: name,
      balance: balance,
      iconIndex: iconIndex,
      colorIndex: colorIndex,
      isLastItem: isLastItem,
      isBalanceHidden: isBalanceHidden,
      signers: signers,
    );
    return walletItemCard;

    // switch (_resultOfSyncFromVault?.result) {
    // case WalletSyncResult.newWalletAdded:
    //   if (index == viewModel.walletItemList.length - 1) {
    //     // todo: balance 업데이트 함수 호출 필요
    //     Logger.log('newWalletAdded');
    //     _initializeLeftSlideAnimationController();
    //     return SlideTransition(
    //         position: _slideAnimation!, child: walletItemCard);
    //   }
    //   break;
    // case WalletSyncResult.existingWalletUpdated:
    // if (viewModel.walletItemList[index].id ==
    //     _resultOfSyncFromVault?.walletId!) {
    //   Logger.log('existingWalletUpdated');
    //   _initializeBlinkAnimationController();
    //   return Stack(
    //     children: [
    //       walletItemCard,
    //       IgnorePointer(
    //         child: AnimatedBuilder(
    //           animation: _blinkAnimation!,
    //           builder: (context, child) {
    //             return Container(
    //               decoration: BoxDecoration(
    //                   color: _blinkAnimation!.value,
    //                   borderRadius: BorderRadius.circular(28)),
    //               width: itemCardWidth,
    //               height: itemCardHeight,
    //             );
    //           },
    //         ),
    //       )
    //     ],
    //   );
    // }
    // break;
    //   default:
    //     return walletItemCard;
    // }
  }

  // void _initializeBlinkAnimationController() {
  //   if (_blinkAnimationController != null && _blinkAnimation != null) {
  //     return;
  //   }

  //   _blinkAnimationController = AnimationController(
  //     vsync: this,
  //     duration: const Duration(milliseconds: 500),
  //   );

  //   _blinkAnimation = TweenSequence<Color?>(
  //     [
  //       TweenSequenceItem(
  //         tween: ColorTween(
  //           begin: Colors.transparent,
  //           end: CoconutColors.white.withOpacity(0.2),
  //         ),
  //         weight: 50,
  //       ),
  //       TweenSequenceItem(
  //         tween: ColorTween(
  //           begin: CoconutColors.white.withOpacity(0.2),
  //           end: Colors.transparent,
  //         ),
  //         weight: 50,
  //       ),
  //     ],
  //   ).animate(_blinkAnimationController!);
  // }

  // void _initializeLeftSlideAnimationController() {
  //   if (_slideAnimationController != null && _slideAnimation != null) {
  //     return;
  //   }

  //   _slideAnimationController = AnimationController(
  //     vsync: this,
  //     duration: const Duration(milliseconds: 500),
  //   );

  //   _slideAnimation = Tween<Offset>(
  //     begin: const Offset(1.0, 0.0),
  //     end: Offset.zero,
  //   ).animate(
  //     CurvedAnimation(
  //       parent: _slideAnimationController!,
  //       curve: Curves.easeInOut,
  //     ),
  //   );
  // }

  void _onAddScannerPressed() async {
    final ResultOfSyncFromVault? scanResult =
        (await Navigator.pushNamed(context, '/wallet-add-scanner')
            as ResultOfSyncFromVault?);

    setState(() {
      _resultOfSyncFromVault = scanResult;
    });

    if (_resultOfSyncFromVault == null) return;
    // WidgetsBinding.instance.addPostFrameCallback((_) async {
    //   if (_resultOfSyncFromVault!.result == WalletSyncResult.newWalletAdded) {
    //     await _animateWalletSlideLeft();
    //   } else {
    //     await _animateWalletBlink();
    //   }

    //   _resultOfSyncFromVault = null;
    // });
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
}
