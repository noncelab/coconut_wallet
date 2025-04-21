import 'dart:async';
import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_list_user_experience_survey_bottom_sheet.dart';
import 'package:coconut_wallet/utils/amimation_util.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
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
import 'package:coconut_wallet/screens/home/wallet_list_security_self_check_bottom_sheet.dart';
import 'package:coconut_wallet/screens/home/wallet_list_glossary_bottom_sheet.dart';

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
  late Map<int, int> _previousWalletBalance = {};
  final GlobalKey<SliverAnimatedListState> _walletListKey = GlobalKey<SliverAnimatedListState>();
  final Duration _duration = const Duration(milliseconds: 1200);

  double? itemCardWidth;
  double? itemCardHeight;
  late WalletListViewModel _viewModel;

  final List<CoconutPulldownMenuEntry> _dropdownButtons = [
    CoconutPulldownMenuGroup(
      groupTitle: t.tool,
      items: [
        CoconutPulldownMenuItem(title: t.glossary),
        CoconutPulldownMenuItem(title: t.mnemonic_wordlist),
        CoconutPulldownMenuItem(title: t.tutorial),
      ],
    ),
    CoconutPulldownMenuItem(title: t.settings),
    CoconutPulldownMenuItem(title: t.view_app_info),
  ];
  late final List<Future<Object?> Function()> _dropdownActions;

  bool isWalletLoading = false;

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

        if (previous.isBalanceHidden != preferenceProvider.isBalanceHidden) {
          previous.setIsBalanceHidden(preferenceProvider.isBalanceHidden);
        }

        if (previous.isNetworkOn != connectivityProvider.isNetworkOn) {
          previous.updateIsNetworkOn(connectivityProvider.isNetworkOn);
        }

        // FIXME: 다른 provider의 변경에 의해서도 항상 호출됨
        return previous..onWalletProviderUpdated(walletProvider);
      },
      child: Consumer<WalletListViewModel>(
        builder: (context, viewModel, child) {
          final isOffline = viewModel.isNetworkOn == null ? false : !viewModel.isNetworkOn!;

          if (viewModel.isWalletListChanged(_previousWalletList, viewModel.walletItemList,
              _previousWalletBalance, (id) => viewModel.getWalletBalance(id).current)) {
            _handleWalletListUpdate(
              viewModel.walletItemList,
              (id) => viewModel.getWalletBalance(id),
              viewModel.isBalanceHidden,
            );
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
                        semanticChildCount: viewModel.walletItemList.length,
                        slivers: <Widget>[
                          _buildAppBar(viewModel),
                          // pull to refresh시 로딩 인디케이터를 보이기 위함
                          CupertinoSliverRefreshControl(
                            onRefresh: viewModel.refreshWallets,
                          ),
                          _buildLoadingIndicator(viewModel),
                          _buildPadding(isOffline),
                          if (!viewModel.shouldShowLoadingIndicator) ...{
                            SliverToBoxAdapter(
                                child: Column(
                              children: [
                                if (!viewModel.shouldShowLoadingIndicator)
                                  if (viewModel.isTermsShortcutVisible)
                                    GlossaryShortcutCard(
                                      onTap: () {
                                        CommonBottomSheets.showBottomSheet_90(
                                            context: context, child: const GlossaryBottomSheet());
                                      },
                                      onCloseTap: viewModel.hideTermsShortcut,
                                    ),
                                if (viewModel.walletItemList.isEmpty)
                                  WalletAdditionGuideCard(onPressed: _onAddScannerPressed)
                              ],
                            )),
                          },
                          // 지갑 목록
                          _buildSliverAnimatedList(viewModel.walletItemList,
                              (id) => viewModel.getWalletBalance(id), viewModel.isBalanceHidden),
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
      Provider.of<VisibilityProvider>(context, listen: false),
      Provider.of<PreferenceProvider>(context, listen: false).isBalanceHidden,
      Provider.of<ConnectivityProvider>(context, listen: false),
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

  void _handleWalletListUpdate(List<WalletListItemBase> walletList,
      AnimatedBalanceDataGetter getWalletBalance, bool isBalanceHidden) async {
    if (isWalletLoading) return;
    isWalletLoading = true;

    final oldWallets = {for (var walletItem in _previousWalletList) walletItem.id: walletItem};

    final List<int> insertedIndexes = [];
    for (int i = 0; i < walletList.length; i++) {
      if (!oldWallets.containsKey(walletList[i].id)) {
        insertedIndexes.add(i);
      }
    }

    for (var i = 0; i < insertedIndexes.length; i++) {
      await Future.delayed(Duration(milliseconds: 100 * i), () {
        _walletListKey.currentState?.insertItem(insertedIndexes[i], duration: _duration);
      });
    }

    _previousWalletList = List.from(walletList);
    _previousWalletBalance = {
      for (var walletId in walletList) walletId.id: getWalletBalance(walletId.id).previous
    };

    isWalletLoading = false;
  }

  Widget _buildSliverAnimatedList(List<WalletListItemBase> walletList,
      AnimatedBalanceDataGetter getWalletBalance, bool isBalanceHidden) {
    return SliverAnimatedList(
      key: _walletListKey,
      initialItemCount: walletList.length,
      itemBuilder: (context, index, animation) {
        if (index < walletList.length) {
          return _buildWalletItem(
              walletList[index],
              animation,
              getWalletBalance(walletList[index].id),
              isBalanceHidden,
              index == walletList.length - 1);
        }
        return Container();
      },
    );
  }

  Widget _buildWalletItem(WalletListItemBase wallet, Animation<double> animation,
      AnimatedBalanceData animatedBalanceData, bool isBalanceHidden, bool isLastItem) {
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
            isLastItem,
          ),
        ),
        isLastItem ? CoconutLayout.spacing_1000h : CoconutLayout.spacing_200h,
      ],
    );
  }

  Widget? _getWalletRowItem(Key key, WalletListItemBase walletItem,
      AnimatedBalanceData animatedBalanceData, bool isBalanceHidden, bool isLastItem) {
    final WalletListItemBase(
      id: id,
      name: name,
      iconIndex: iconIndex,
      colorIndex: colorIndex,
    ) = walletItem;
    List<MultisigSigner>? signers;
    if (walletItem.walletType == WalletType.multiSignature) {
      signers = (walletItem as MultisigWalletListItem).signers;
    }

    final walletItemCard = WalletItemCard(
      key: key,
      id: id,
      name: name,
      animatedBalanceData: animatedBalanceData,
      iconIndex: iconIndex,
      colorIndex: colorIndex,
      isLastItem: isLastItem,
      isBalanceHidden: isBalanceHidden,
      signers: signers,
    );
    return walletItemCard;
  }

  void _goToScannerScreen(WalletImportSource walletImportSource) async {
    final ResultOfSyncFromVault? scanResult =
        (await Navigator.pushNamed(context, '/wallet-add-scanner', arguments: {
      'walletImportSource': walletImportSource,
    }) as ResultOfSyncFromVault?);

    setState(() {
      _resultOfSyncFromVault = scanResult;
    });

    if (_resultOfSyncFromVault == null) return;
  }

  void _onAddScannerPressed() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: Colors.transparent, // 배경 흐림 없음 (필요시 조정)
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        final offsetTween = Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        );
        final slideDownAnimation = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);

        return Stack(
          children: [
            // 투명 배경 터치 감지
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: CoconutColors.black.withOpacity(0.5)),
            ),

            // 슬라이드되는 다이얼로그
            Positioned(
              top: kToolbarHeight + MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: offsetTween.animate(slideDownAnimation),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
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
                        CoconutLayout.spacing_400h,
                        SizedBox(
                          width: MediaQuery.sizeOf(context).width,
                          child: _buildWalletIconShrinkButton(
                            // TODO: 직접 입력 화면 연결 #176
                            () => debugPrint('클릭'),
                            WalletImportSource.zpub,
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
                    child: Stack(children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        bottom: 0,
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: SvgPicture.asset('assets/svg/close-bold.svg'),
                        ),
                      ),
                      Center(
                        child: Align(
                          alignment: Alignment.center,
                          child: Text(
                            t.wallet_add_scanner_screen.add_wallet,
                            style: CoconutTypography.body1_16,
                          ),
                        ),
                      ),
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
      leadingSvgAsset: SvgPicture.asset('assets/svg/coconut.svg',
          colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn), width: 24),
      appTitle: t.wallet,
      actionButtonList: [
        // 보기 전용 지갑 추가하기
        _buildAppBarIconButton(
          key: GlobalKey(),
          icon: SvgPicture.asset('assets/svg/wallet-eyes.svg'),
          onPressed: () {
            _onAddScannerPressed();
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
      child: viewModel.shouldShowLoadingIndicator
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
    return Positioned(
        top: _dropdownButtonPosition.dy + _dropdownButtonSize.height,
        right: 20,
        child: Visibility(
          visible: _isDropdownMenuVisible,
          child: CoconutPulldownMenu(
            shadowColor: CoconutColors.gray800,
            dividerColor: CoconutColors.gray800,
            entries: _dropdownButtons,
            dividerHeight: 1,
            thickDividerHeight: 3,
            thickDividerIndexList: const [
              2,
            ],
            onSelected: ((index, selectedText) {
              _setPulldownMenuVisiblility(false);
              _dropdownActions[index].call();
            }),
          ),
        ));
  }

  Widget _buildWalletIconShrinkButton(
    VoidCallback onPressed,
    WalletImportSource scanType,
  ) {
    String svgPath;
    String scanText;

    switch (scanType) {
      case WalletImportSource.coconutVault:
        svgPath = 'assets/svg/vault.svg';
        scanText = t.wallet_add_scanner_screen.vault;
        break;
      case WalletImportSource.keystone:
        svgPath = 'assets/svg/keystone.svg';
        scanText = t.wallet_add_scanner_screen.keystone;
        break;
      case WalletImportSource.seedSigner:
        svgPath = 'assets/svg/seed-signer.svg';
        scanText = t.wallet_add_scanner_screen.seed_signer;
        break;
      case WalletImportSource.zpub:
      case WalletImportSource.descriptor:
        svgPath = 'assets/svg/zpub.svg';
        scanText = t.wallet_add_scanner_screen.self;
    }
    return ShrinkAnimationButton(
      defaultColor: CoconutColors.black,
      pressedColor: CoconutColors.gray800,
      onPressed: () => onPressed(),
      child: scanType == WalletImportSource.zpub
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
                  Text(scanText, style: CoconutTypography.body2_14),
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
