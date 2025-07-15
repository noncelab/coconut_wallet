import 'dart:async';
import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_list_user_experience_survey_bottom_sheet.dart';
import 'package:coconut_wallet/utils/amimation_util.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/card/donation_banner_card.dart';
import 'package:coconut_wallet/widgets/label_testnet.dart';
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
import 'package:coconut_wallet/widgets/card/wallet_list_glossary_shortcut_card.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/home/wallet_list_glossary_bottom_sheet.dart';
import 'package:tuple/tuple.dart';

class WalletListScreen extends StatefulWidget {
  const WalletListScreen({super.key});

  @override
  State<WalletListScreen> createState() => _WalletListScreenState();
}

class _WalletListScreenState extends State<WalletListScreen> with TickerProviderStateMixin {
  final kOfflineWarningBarHeight = 32.0;
  final kOfflineWarningBarDuration = const Duration(milliseconds: 500);

  final GlobalKey _dropdownButtonKey = GlobalKey();
  Size _dropdownButtonSize = const Size(0, 0);
  Offset _dropdownButtonPosition = Offset.zero;
  bool _isDropdownMenuVisible = false;
  late ScrollController _scrollController;

  DateTime? _lastPressedAt;
  ResultOfSyncFromVault? _resultOfSyncFromVault;

  late List<WalletListItemBase> _previousWalletList = [];
  final GlobalKey<SliverAnimatedListState> _walletListKey = GlobalKey<SliverAnimatedListState>();
  final Duration _duration = const Duration(milliseconds: 1200);

  double? itemCardWidth;
  double? itemCardHeight;
  late WalletListViewModel _viewModel;
  late final List<Future<Object?> Function()> _dropdownActions;

  bool _isFirstLoad = true;
  bool _isWalletListLoading = false;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider4<WalletProvider, PreferenceProvider, VisibilityProvider,
        ConnectivityProvider, WalletListViewModel>(
      create: (_) => _createViewModel(),
      update: (BuildContext context,
          WalletProvider walletProvider,
          PreferenceProvider preferenceProvider,
          VisibilityProvider visibilityProvider,
          ConnectivityProvider connectivityProvider,
          WalletListViewModel? previous) {
        previous ??= _createViewModel();

        previous.onPreferenceProviderUpdated();

        if (previous.isNetworkOn != connectivityProvider.isNetworkOn) {
          previous.updateIsNetworkOn(connectivityProvider.isNetworkOn);
        }

        // FIXME: 다른 provider의 변경에 의해서도 항상 호출됨
        return previous..onWalletProviderUpdated(walletProvider);
      },
      child: Selector<
          WalletListViewModel,
          Tuple7<List<WalletListItemBase>, bool, bool, bool, bool, Map<int, AnimatedBalanceData>,
              Tuple2<int?, Map<int, dynamic>>>>(
        selector: (_, vm) => Tuple7(
            vm.walletItemList,
            vm.isNetworkOn ?? false,
            vm.isBalanceHidden,
            vm.shouldShowLoadingIndicator,
            vm.isTermsShortcutVisible,
            vm.walletBalanceMap,
            Tuple2(vm.fakeBalanceTotalAmount, vm.fakeBalanceMap)),
        builder: (context, data, child) {
          final viewModel = Provider.of<WalletListViewModel>(context, listen: false);

          final walletListItem = data.item1;
          final isOffline = !data.item2;
          final isBalanceHidden = data.item3;
          final shouldShowLoadingIndicator = data.item4;
          final isTermsShortcutVisible = data.item5;
          final walletBalanceMap = data.item6;

          if (viewModel.isWalletListChanged(
              _previousWalletList, walletListItem, walletBalanceMap)) {
            _handleWalletListUpdate(walletListItem);
          }

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: onPopInvoked,
            child: Scaffold(
              backgroundColor: CoconutColors.black,
              extendBodyBehindAppBar: true,
              body: SafeArea(
                top: false,
                bottom: false,
                child: Stack(
                  children: [
                    CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        semanticChildCount: walletListItem.length,
                        slivers: <Widget>[
                          _buildAppBar(viewModel),
                          // pull to refresh시 로딩 인디케이터를 보이기 위함
                          CupertinoSliverRefreshControl(
                            onRefresh: viewModel.updateWalletBalances,
                          ),
                          _buildLoadingIndicator(viewModel),
                          _buildPadding(isOffline),
                          if (NetworkType.currentNetworkType == NetworkType.mainnet)
                            _buildDonationBanner(),
                          if (!shouldShowLoadingIndicator)
                            SliverToBoxAdapter(
                                child: Column(
                              children: [
                                if (isTermsShortcutVisible && _isKoreanLanguage())
                                  GlossaryShortcutCard(
                                    onTap: () {
                                      CommonBottomSheets.showBottomSheet_90(
                                          context: context, child: const GlossaryBottomSheet());
                                    },
                                    onCloseTap: viewModel.hideTermsShortcut,
                                  ),
                                if (walletListItem.isEmpty)
                                  WalletAdditionGuideCard(onPressed: _onAddWalletPressed)
                              ],
                            )),
                          // 지갑 목록
                          _buildSliverAnimatedList(walletListItem, walletBalanceMap,
                              isBalanceHidden, (id) => viewModel.getFakeBalance(id)),
                        ]),
                    _buildOfflineWarningBar(context, isOffline),
                    _buildDropdownBackdrop(),
                    _buildDropdownMenu(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isKoreanLanguage() {
    final preferenceProvider = Provider.of<PreferenceProvider>(context, listen: false);
    return preferenceProvider.language == 'kr';
  }

  Positioned _buildOfflineWarningBar(BuildContext context, bool isOffline) {
    return Positioned(
      top: kToolbarHeight + MediaQuery.of(context).padding.top,
      left: 0,
      right: 0,
      child: AnimatedContainer(
        duration: kOfflineWarningBarDuration,
        curve: Curves.easeOut,
        height: isOffline ? kOfflineWarningBarHeight : 0.0,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: CoconutColors.hotPink,
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
    );
  }

  Widget _buildDonationBanner() {
    return SliverToBoxAdapter(
      child: DonationBannerCard(
        walletListLength: _viewModel.walletItemList.length,
      ),
    );
  }

  Widget _buildPadding(bool isOffline) {
    const kDefaultPadding = Sizes.size12;
    return SliverToBoxAdapter(
        child: AnimatedContainer(
            duration: kOfflineWarningBarDuration,
            height: isOffline ? kOfflineWarningBarHeight + kDefaultPadding : kDefaultPadding,
            curve: Curves.easeInOut,
            child: const SizedBox()));
  }

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();

    _dropdownActions = [
      () => CommonBottomSheets.showBottomSheet_90(
          context: context, child: const GlossaryBottomSheet()),
      () => Navigator.pushNamed(context, '/mnemonic-word-list'),
      () => showDialog(
            context: context,
            builder: (BuildContext context) {
              return CoconutPopup(
                title: t.alert.tutorial.title,
                description: t.alert.tutorial.description,
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
                rightButtonText: t.alert.tutorial.btn_view,
                rightButtonColor: CoconutColors.cyan,
                leftButtonText: t.close,
              );
            },
          ),
      () => CommonBottomSheets.showBottomSheet_90(context: context, child: const SettingsScreen()),
      () => Navigator.pushNamed(context, '/app-info'),
    ];

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_dropdownButtonKey.currentContext != null) {
        final faucetRenderBox = _dropdownButtonKey.currentContext?.findRenderObject() as RenderBox;
        _dropdownButtonPosition = faucetRenderBox.localToGlobal(Offset.zero);
        _dropdownButtonSize = faucetRenderBox.size;
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  WalletListViewModel _createViewModel() {
    _viewModel = WalletListViewModel(
      Provider.of<WalletProvider>(context, listen: false),
      Provider.of<PreferenceProvider>(context, listen: false),
      Provider.of<VisibilityProvider>(context, listen: false),
      Provider.of<ConnectivityProvider>(context, listen: false),
      Provider.of<NodeProvider>(context, listen: false).syncStateStream,
    );
    return _viewModel;
  }

  void onPopInvoked(didPop, _) async {
    if (Platform.isAndroid) {
      final now = DateTime.now();
      if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 3)) {
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
  }

  void _handleWalletListUpdate(List<WalletListItemBase> walletList) async {
    if (_isWalletListLoading) return;
    _isWalletListLoading = true;
    try {
      final oldWallets = {for (var walletItem in _previousWalletList) walletItem.id: walletItem};

      final List<int> insertedIndexes = [];
      for (int i = 0; i < walletList.length; i++) {
        if (!oldWallets.containsKey(walletList[i].id)) {
          insertedIndexes.add(i);
        }
      }

      if (insertedIndexes.isNotEmpty) {
        if (_previousWalletList.isEmpty && _isFirstLoad) {
          // 첫 로딩시에는 애니메이션 없이 리스트 갱신
          for (var i = 0; i < insertedIndexes.length; i++) {
            _walletListKey.currentState?.insertItem(insertedIndexes[i], duration: Duration.zero);
          }
          _isFirstLoad = false;
        } else {
          for (var i = 0; i < insertedIndexes.length; i++) {
            await Future.delayed(Duration(milliseconds: 100 * i), () {
              _walletListKey.currentState?.insertItem(insertedIndexes[i], duration: _duration);
            });
          }
        }
      }

      _previousWalletList = List.from(walletList);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _viewModel.updateWalletBalances();
      });
    } finally {
      _isWalletListLoading = false;
    }
  }

  Widget _buildSliverAnimatedList(
      List<WalletListItemBase> walletList,
      Map<int, AnimatedBalanceData> walletBalanceMap,
      bool isBalanceHidden,
      FakeBalanceGetter getFakeBalance) {
    return SliverAnimatedList(
      key: _walletListKey,
      initialItemCount: walletList.length,
      itemBuilder: (context, index, animation) {
        if (index < walletList.length) {
          return _buildWalletItem(
              walletList[index],
              animation,
              walletBalanceMap[walletList[index].id] ?? AnimatedBalanceData(0, 0),
              isBalanceHidden,
              getFakeBalance(walletList[index].id),
              index == walletList.length - 1);
        }
        return Container();
      },
    );
  }

  Widget _buildWalletItem(
      WalletListItemBase wallet,
      Animation<double> animation,
      AnimatedBalanceData animatedBalanceData,
      bool isBalanceHidden,
      int? fakeBalance,
      bool isLastItem) {
    var offsetAnimation = AnimationUtil.buildSlideInAnimation(animation);

    return Column(
      children: [
        SlideTransition(
          position: offsetAnimation,
          child: _getWalletRowItem(
            Key(wallet.id.toString()),
            wallet,
            animatedBalanceData,
            isBalanceHidden,
            fakeBalance,
            isLastItem,
          ),
        ),
        isLastItem ? CoconutLayout.spacing_1000h : CoconutLayout.spacing_200h,
      ],
    );
  }

  Widget? _getWalletRowItem(
      Key key,
      WalletListItemBase walletItem,
      AnimatedBalanceData animatedBalanceData,
      bool isBalanceHidden,
      int? fakeBalance,
      bool isLastItem) {
    final WalletListItemBase(
      id: id,
      name: name,
      iconIndex: iconIndex,
      colorIndex: colorIndex,
      walletImportSource: walletImportSource,
    ) = walletItem;
    List<MultisigSigner>? signers;
    if (walletItem.walletType == WalletType.multiSignature) {
      signers = (walletItem as MultisigWalletListItem).signers;
    }

    return Selector<PreferenceProvider, bool>(
        selector: (_, viewModel) => viewModel.isBtcUnit,
        builder: (context, isBtcUnit, child) {
          return WalletItemCard(
              key: key,
              id: id,
              name: name,
              animatedBalanceData: animatedBalanceData,
              iconIndex: iconIndex,
              colorIndex: colorIndex,
              isLastItem: isLastItem,
              isBalanceHidden: isBalanceHidden,
              fakeBalance: fakeBalance,
              signers: signers,
              walletImportSource: walletImportSource,
              currentUnit: isBtcUnit ? BitcoinUnit.btc : BitcoinUnit.sats);
        });
  }

  void _goToScannerScreen(WalletImportSource walletImportSource) async {
    Navigator.pop(context);
    final ResultOfSyncFromVault? scanResult =
        (await Navigator.pushNamed(context, '/wallet-add-scanner', arguments: {
      'walletImportSource': walletImportSource,
    }) as ResultOfSyncFromVault?);

    setState(() {
      _resultOfSyncFromVault = scanResult;
    });

    if (_resultOfSyncFromVault == null) return;
  }

  void _goToManualInputScreen() {
    Navigator.pop(context);
    Navigator.pushNamed(context, "/wallet-add-input");
  }

  void _onAddWalletPressed() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: CoconutColors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        final offsetTween = Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        );
        final slideDownAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);

        return Stack(
          children: [
            // 슬라이드되는 다이얼로그
            Positioned(
              top: kToolbarHeight + MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: offsetTween.animate(slideDownAnimation),
                child: Material(
                  elevation: 4,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  color: CoconutColors.black,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                              child: _buildWalletIconShrinkButton(
                                () => _goToScannerScreen(WalletImportSource.coconutVault),
                                WalletImportSource.coconutVault,
                              ),
                            ),
                            Expanded(
                              child: _buildWalletIconShrinkButton(
                                () => _goToScannerScreen(WalletImportSource.keystone),
                                WalletImportSource.keystone,
                              ),
                            ),
                            Expanded(
                              child: _buildWalletIconShrinkButton(
                                () => _goToScannerScreen(WalletImportSource.seedSigner),
                                WalletImportSource.seedSigner,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _buildWalletIconShrinkButton(
                                () => _goToScannerScreen(WalletImportSource.jade),
                                WalletImportSource.jade,
                              ),
                            ),
                            const Expanded(
                              child: SizedBox(),
                            ),
                            const Expanded(
                              child: SizedBox(),
                            ),
                          ],
                        ),
                        CoconutLayout.spacing_400h,
                        SizedBox(
                          width: MediaQuery.sizeOf(context).width,
                          child: _buildWalletIconShrinkButton(
                            () => _goToManualInputScreen(),
                            WalletImportSource.extendedPublicKey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Container(
                    height: MediaQuery.of(context).padding.top,
                    color: CoconutColors.black,
                  ),
                  Container(
                    width: MediaQuery.sizeOf(context).width,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    height: kToolbarHeight,
                    color: CoconutColors.black,
                    child: Row(children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          highlightColor: CoconutColors.gray800,
                          splashRadius: 20,
                          padding: EdgeInsets.zero,
                          icon: SvgPicture.asset(
                            'assets/svg/close-bold.svg',
                            colorFilter: ColorFilter.mode(
                              CoconutColors.onPrimary(Brightness.dark),
                              BlendMode.srcIn,
                            ),
                            width: 14,
                            height: 14,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        t.wallet_add_scanner_screen.add_wallet,
                        style: CoconutTypography.heading4_18,
                      ),
                      const Spacer(),
                      const SizedBox(width: 40)
                    ]),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return child;
      },
    );
  }

  SliverAppBar _buildAppBar(WalletListViewModel viewModel) {
    return CoconutAppBar.buildHomeAppbar(
      context: context,
      leadingSvgAsset: SvgPicture.asset(
          'assets/svg/coconut-${NetworkType.currentNetworkType.isTestnet ? "regtest" : "mainnet"}.svg',
          colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
          width: 24),
      appTitle: t.wallet,
      subLabel: NetworkType.currentNetworkType.isTestnet ? const TestnetLabelWidget() : null,
      actionButtonList: [
        // 보기 전용 지갑 추가하기
        _buildAppBarIconButton(
          key: GlobalKey(),
          icon: SvgPicture.asset('assets/svg/wallet-eyes.svg'),
          onPressed: () {
            _onAddWalletPressed();
          },
        ),
        // 더보기(풀다운 메뉴 열림)
        _buildAppBarIconButton(
          key: _dropdownButtonKey,
          icon: SvgPicture.asset('assets/svg/kebab.svg'),
          onPressed: () {
            _setPulldownMenuVisiblility(true);
          },
        ),
      ],
    );
  }

  Widget _buildAppBarIconButton({required Widget icon, required VoidCallback onPressed, Key? key}) {
    return SizedBox(
      key: key,
      height: 40,
      width: 40,
      child: IconButton(
        icon: icon,
        onPressed: onPressed,
        color: CoconutColors.white,
      ),
    );
  }

  Widget _buildLoadingIndicator(WalletListViewModel viewModel) {
    return SliverToBoxAdapter(
        child: AnimatedSwitcher(
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          child: child,
        ),
      ),
      duration: const Duration(milliseconds: 300),
      child: viewModel.shouldShowLoadingIndicator && viewModel.walletItemList.isNotEmpty
          ? const Center(
              child: Padding(
                key: ValueKey("loading"),
                padding: EdgeInsets.only(bottom: 20.0),
                child: LoadingIndicator(),
              ),
            )
          : null,
    ));
  }

  Widget _buildDropdownBackdrop() {
    return _isDropdownMenuVisible
        ? Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                _setPulldownMenuVisiblility(false);
              },
            ),
          )
        : Container();
  }

  Widget _buildDropdownMenu() {
    final bool showGlossary = _isKoreanLanguage();

    return Positioned(
        top: _dropdownButtonPosition.dy + _dropdownButtonSize.height,
        right: 20,
        child: Visibility(
          visible: _isDropdownMenuVisible,
          child: CoconutPulldownMenu(
            shadowColor: CoconutColors.gray800,
            dividerColor: CoconutColors.gray800,
            entries: [
              CoconutPulldownMenuGroup(
                groupTitle: t.tool,
                items: [
                  if (showGlossary) CoconutPulldownMenuItem(title: t.glossary),
                  CoconutPulldownMenuItem(title: t.mnemonic_wordlist),
                  if (NetworkType.currentNetworkType.isTestnet)
                    CoconutPulldownMenuItem(title: t.tutorial),
                ],
              ),
              CoconutPulldownMenuItem(title: t.settings),
              CoconutPulldownMenuItem(title: t.view_app_info),
            ],
            dividerHeight: 1,
            thickDividerHeight: 3,
            thickDividerIndexList: [
              _getThickDividerIndex(showGlossary),
            ],
            onSelected: ((index, selectedText) {
              _setPulldownMenuVisiblility(false);
              _handleDropdownSelection(index, showGlossary);
            }),
          ),
        ));
  }

  /// 용어집 표시 여부에 따른 Thick Divider 인덱스 계산
  int _getThickDividerIndex(bool showGlossary) {
    if (NetworkType.currentNetworkType.isTestnet) {
      // 테스트넷: 용어집, 니모닉, 튜토리얼 → 인덱스 2
      // 테스트넷 (용어집 없음): 니모닉, 튜토리얼 → 인덱스 1
      return showGlossary ? 2 : 1;
    } else {
      // 메인넷: 용어집, 니모닉 → 인덱스 1
      // 메인넷 (용어집 없음): 니모닉 → 인덱스 0
      return showGlossary ? 1 : 0;
    }
  }

  /// 드롭다운 선택 처리 (인덱스 조정 포함)
  void _handleDropdownSelection(int index, bool showGlossary) {
    int adjustedIndex = index;

    // 용어집이 없는 경우 인덱스 조정
    if (!showGlossary) {
      adjustedIndex++;
    }

    // 메인넷에서 튜토리얼 항목이 없는 경우 추가 조정
    if (!NetworkType.currentNetworkType.isTestnet && adjustedIndex >= 2) {
      adjustedIndex++;
    }

    _dropdownActions[adjustedIndex].call();
  }

  Widget _buildWalletIconShrinkButton(
    VoidCallback onPressed,
    WalletImportSource scanType,
  ) {
    String svgPath;
    String scanText;

    switch (scanType) {
      case WalletImportSource.coconutVault:
        svgPath =
            'assets/svg/coconut-vault-${NetworkType.currentNetworkType.isTestnet ? "regtest" : "mainnet"}.svg';
        scanText = t.wallet_add_scanner_screen.vault;
        break;
      case WalletImportSource.keystone:
        svgPath = kKeystoneIconPath;
        scanText = t.wallet_add_scanner_screen.keystone;
        break;
      case WalletImportSource.jade:
        svgPath = kJadeIconPath;
        scanText = t.wallet_add_scanner_screen.jade;
        break;
      case WalletImportSource.seedSigner:
        svgPath = kSeedSignerIconPath;
        scanText = t.wallet_add_scanner_screen.seed_signer;
        break;
      case WalletImportSource.extendedPublicKey:
        svgPath = kZpubIconPath;
        scanText = t.wallet_add_scanner_screen.self;
        break;
    }
    return ShrinkAnimationButton(
      defaultColor: CoconutColors.black,
      pressedColor: CoconutColors.gray800,
      onPressed: () => onPressed(),
      child: scanType == WalletImportSource.extendedPublicKey
          ? Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 8,
              ),
              child: Row(
                children: [
                  SvgPicture.asset(svgPath),
                  CoconutLayout.spacing_400w,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(scanText, style: CoconutTypography.body2_14),
                      CoconutLayout.spacing_50h,
                      Text(t.wallet_add_scanner_screen.self_description,
                          style: CoconutTypography.body3_12),
                    ],
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 8,
              ),
              child: Column(
                children: [
                  SvgPicture.asset(svgPath),
                  CoconutLayout.spacing_100h,
                  Text(
                    scanText,
                    style: CoconutTypography.body2_14,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }

  void _setPulldownMenuVisiblility(bool value) {
    setState(() {
      _isDropdownMenuVisible = value;
    });
  }
}
