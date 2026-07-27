import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:carousel_slider/carousel_slider.dart';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/app_language.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/preference/home_feature.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/screens/home/analysis_period_bottom_sheet.dart';
import 'package:coconut_wallet/screens/send/utxo_selection_screen.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_list_user_experience_survey_bottom_sheet.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_edit_bottom_sheet.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:coconut_wallet/widgets/animated_dots_text.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/contents/fiat_price.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/icon/transaction_status_gradient_mask.dart';
import 'package:coconut_wallet/widgets/loading_indicator/loading_indicator.dart';
import 'package:coconut_wallet/widgets/long_pressed_menu_widget.dart';
import 'package:coconut_wallet/widgets/dialog.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_home_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/app_settings/app_settings_screen.dart';
import 'package:coconut_wallet/widgets/card/wallet_item_card.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/settings/tools/glossary_bottom_sheet.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tuple/tuple.dart';
import 'package:collection/collection.dart';

enum _AddWalletMenuMode { walletType, watchOnlySource, hotWalletAction }

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  /// P2P 등 외부에서 홈의 "지갑 추가" 바텀시트를 띄울 때 호출.
  static void openAddWalletIfActive() => _currentState?._showAddWalletMenu(_AddWalletMenuMode.walletType);

  static _WalletHomeScreenState? _currentState;

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> with TickerProviderStateMixin {
  final GlobalKey _dropdownButtonKey = GlobalKey();
  Size _dropdownButtonSize = const Size(0, 0);
  Offset _dropdownButtonPosition = Offset.zero;
  final ValueNotifier<bool> _isDropdownMenuVisible = ValueNotifier(false);
  bool _showEmptyRecentTransactionWidget = true;
  Timer? _recentTransactionBannerTimer;
  late ScrollController _scrollController;
  late CarouselSliderController _carouselController;
  Offset? _lastPointerDownPosition;
  bool _didDragSincePointerDown = false;
  WalletFilter _walletFilter = WalletFilter.all;
  late PageController _walletPageController;

  DateTime? _lastPressedAt;
  ResultOfSyncFromVault? _resultOfSyncFromVault;

  late List<WalletItemBase> _previousWalletList = [];
  final GlobalKey<SliverAnimatedListState> _walletListKey = GlobalKey<SliverAnimatedListState>();
  final Duration _duration = const Duration(milliseconds: 1200);

  double? itemCardWidth;
  double? itemCardHeight;

  Future<void> _hideHomeFeature(HomeFeatureType type, {bool keepEditMode = false}) async {
    bool? result = await showDialog<bool>(
      context: context,
      builder:
          (context) => CoconutPopup(
            languageCode: context.read<PreferenceProvider>().language,
            backgroundColor: context.coconutColors.popupBackground,
            title: t.long_pressed_menu.hide_home_widget_title(widgetName: _getWidgetName(type)),
            description: t.long_pressed_menu.hide_home_widget_description,
            rightButtonText: t.OK,
            onTapRight: () => Navigator.pop(context, true),
            onTapLeft: () => Navigator.pop(context, false),
            leftButtonText: t.cancel,
            titlePadding: const EdgeInsets.only(top: 24, bottom: 12, left: 16, right: 16),
          ),
    );

    if (result == true) {
      await _viewModel.hideHomeFeature(type);
    }
    if (keepEditMode) {
      _viewModel.setEditWidgetMode(true);
    }
  }

  String _getWidgetName(HomeFeatureType type) {
    switch (type) {
      case HomeFeatureType.recentTransaction:
        return t.wallet_home_screen.edit.category.recent_transactions;
      case HomeFeatureType.analysis:
        return t.wallet_home_screen.edit.category.analysis;
      default:
        return '';
    }
  }

  late WalletHomeViewModel _viewModel;
  late final Map<String, VoidCallback> _dropdownActions;

  bool _isFirstLoad = true;
  bool _isWalletListLoading = false;

  int _recentTransactionCurrentPage = 0;
  late ScrollController _pageIndicatorController;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider4<
      WalletProvider,
      PreferenceProvider,
      VisibilityProvider,
      ConnectivityProvider,
      WalletHomeViewModel
    >(
      create: (_) => _createViewModel(),
      update: (
        BuildContext context,
        WalletProvider walletProvider,
        PreferenceProvider preferenceProvider,
        VisibilityProvider visibilityProvider,
        ConnectivityProvider connectivityProvider,
        WalletHomeViewModel? previous,
      ) {
        previous ??= _createViewModel();
        previous.onPreferenceProviderUpdated();

        // FIXME: 다른 provider의 변경에 의해서도 항상 호출됨
        return previous..onWalletProviderUpdated(walletProvider);
      },
      child: Selector<
        WalletHomeViewModel,
        Tuple7<
          List<WalletItemBase>,
          List<WalletItemBase>,
          Tuple2<bool, bool>,
          bool,
          Map<int, AnimatedBalanceData>,
          Tuple2<int?, Map<int, dynamic>>,
          NetworkStatus
        >
      >(
        selector:
            (_, vm) => Tuple7(
              vm.walletItemList,
              vm.favoriteWallets,
              Tuple2(vm.isBalanceHidden, vm.isBalanceHidden),
              vm.shouldShowLoadingIndicator,
              vm.walletBalanceMap,
              Tuple2(vm.fakeBalanceTotalAmount, vm.fakeBalanceMap),
              vm.networkStatus,
            ),
        builder: (context, data, child) {
          final viewModel = Provider.of<WalletHomeViewModel>(context, listen: false);

          final walletItem = data.item1;
          final favoriteWallets = data.item2;
          final balanceVisibilityData = data.item3;
          final shouldShowLoadingIndicator = data.item4;
          final walletBalanceMap = data.item5;
          final fakeBalanceData = data.item6;
          final networkStatus = data.item7;
          final homeFeatures = viewModel.homeFeatures;
          final hasEnabledHomeFeature = homeFeatures.any((feature) => feature.isEnabled);

          if (viewModel.isWalletListChanged(_previousWalletList, walletItem, walletBalanceMap)) {
            _handleWalletListUpdate(walletItem);
          }

          return PopScope(
            canPop: false,
            onPopInvokedWithResult: onPopInvoked,
            child: Scaffold(
              backgroundColor: context.coconutColors.homeBackground,
              extendBodyBehindAppBar: true,
              body: SafeArea(
                top: false,
                bottom: false,
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (event) {
                    _lastPointerDownPosition = event.position;
                    _didDragSincePointerDown = false;
                  },
                  onPointerMove: (event) {
                    if (_lastPointerDownPosition != null && !_didDragSincePointerDown) {
                      final delta = (event.position - _lastPointerDownPosition!).distance;
                      if (delta > 5.0) {
                        _didDragSincePointerDown = true;
                      }
                    }
                  },
                  onPointerUp: (_) {
                    if (!_didDragSincePointerDown && _viewModel.isEditWidgetMode) {
                      _viewModel.setEditWidgetMode(false);
                    }
                  },
                  child: Stack(
                    children: [
                      CustomScrollView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        semanticChildCount: walletItem.length,
                        slivers: <Widget>[
                          _buildAppBar(networkStatus),
                          // pull to refresh시 로딩 인디케이터를 보이기 위함
                          CupertinoSliverRefreshControl(onRefresh: viewModel.onRefresh),
                          _buildLoadingIndicator(context, viewModel),
                          _buildHeader(
                            balanceVisibilityData.item1,
                            balanceVisibilityData.item2,
                            fakeBalanceData.item1,
                            shouldShowLoadingIndicator,
                            walletItem.isEmpty,
                          ),
                          if (walletItem.isNotEmpty) _buildViewAllWallets(walletItem.length),
                          _buildWalletOverview(
                            favoriteWallets,
                            walletBalanceMap,
                            (id) => viewModel.getFakeBalance(id),
                            isLoading: shouldShowLoadingIndicator && walletItem.isEmpty,
                          ),
                          if (walletItem.isNotEmpty) ...[
                            if (hasEnabledHomeFeature) ...[
                              SliverToBoxAdapter(
                                child: Column(
                                  children: [
                                    CoconutLayout.spacing_600h,
                                    Divider(thickness: 12, color: context.coconutColors.surfaceSectionBreak),
                                    CoconutLayout.spacing_600h,
                                  ],
                                ),
                              ),
                              // 최근 트랜잭션 섹션: 로딩 중이면 스켈레톤, 아니면 컨텐츠
                              _buildFeatureSectionIfEnabled(
                                HomeFeatureType.recentTransaction,
                                () =>
                                    viewModel.isFetchingLatestTx
                                        ? _buildRecentTransactionsSkeleton()
                                        : _buildRecentTransactions(),
                              ),
                              // 분석 섹션: 로딩 중이면서 기존 데이터가 없으면 스켈레톤, 아니면 컨텐츠 (기존 데이터 있으면 보여줌)
                              _buildFeatureSectionIfEnabled(
                                HomeFeatureType.analysis,
                                () =>
                                    viewModel.isLatestTxAnalysisRunning && viewModel.recentTransactionAnalysis == null
                                        ? _buildAnalysisSkeleton()
                                        : _buildAnalysis(),
                              ),
                            ],
                          ],
                          if (walletItem.isNotEmpty) ...[
                            // _buildHomeEditButton(), // 홈 화면 편집 버튼 dropdown menu로 이동
                            const SliverToBoxAdapter(child: CoconutLayout.spacing_2500h),
                          ],
                        ],
                      ),
                      _buildDropdownBackdrop(),
                      _buildDropdownMenu(),
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

  Future<void> _navigateToWalletHomeEdit() async {
    _viewModel.captureEnabledFeaturesSnapshot();
    await Navigator.pushNamed(context, '/wallet-home-edit');
    if (context.mounted) {
      _viewModel.refreshEnabledFeaturesData();
    }
  }

  @override
  void initState() {
    super.initState();
    WalletHomeScreen._currentState = this;

    _scrollController = ScrollController();
    _carouselController = CarouselSliderController();
    _walletPageController = PageController();
    _pageIndicatorController = ScrollController();

    _dropdownActions = {
      'transaction_draft': () => Navigator.pushNamed(context, '/transaction-draft'),
      'glossary':
          () => CommonBottomSheets.showCustomHeightBottomSheet(
            context: context,
            child: const GlossaryBottomSheet(),
            heightRatio: 0.9,
          ),
      'p2p_calculator': () => Navigator.pushNamed(context, '/p2p-calculator'),
      'mnemonic_wordlist': () => Navigator.pushNamed(context, '/mnemonic-word-list'),
      'tutorial':
          () => showDialog(
            context: context,
            builder: (BuildContext context) {
              return CoconutPopup(
                languageCode: context.read<PreferenceProvider>().language,
                title: t.alert.tutorial.title,
                description: t.alert.tutorial.description,
                onTapRight: () async {
                  launchURL(TUTORIAL_URL, defaultMode: false);
                  Navigator.of(context).pop();
                },
                onTapLeft: () {
                  Navigator.of(context).pop();
                },
                rightButtonText: t.alert.tutorial.btn_view,
                rightButtonColor: context.coconutColors.success,
                leftButtonText: t.close,
              );
            },
          ),
      'home_screen_settings': _navigateToWalletHomeEdit,
      'app_settings':
          () => CommonBottomSheets.showCustomHeightBottomSheet(
            context: context,
            child: const AppSettingsScreen(),
            heightRatio: 0.9,
          ),
    };

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_dropdownButtonKey.currentContext != null) {
        final faucetRenderBox = _dropdownButtonKey.currentContext?.findRenderObject() as RenderBox;
        _dropdownButtonPosition = faucetRenderBox.localToGlobal(Offset.zero);
        _dropdownButtonSize = faucetRenderBox.size;
      }

      if (!context.mounted) return;

      if (_viewModel.isReviewScreenVisible) {
        var animationController = BottomSheet.createAnimationController(this)..duration = const Duration(seconds: 2);
        await CommonBottomSheets.showBottomSheet_100(
          context: context,
          child: const UserExperienceSurveyBottomSheet(),
          enableDrag: false,
          backgroundColor: context.coconutColors.surfaceBottomSheet,
          isDismissible: false,
          isScrollControlled: true,
          useSafeArea: false,
          animationController: animationController,
        );

        Future.delayed(const Duration(seconds: 5), () {
          animationController.dispose();
          _viewModel.updateAppReviewRequestCondition();
        });
      }
    });
  }

  @override
  void dispose() {
    if (WalletHomeScreen._currentState == this) {
      WalletHomeScreen._currentState = null;
    }
    _recentTransactionBannerTimer?.cancel();
    _scrollController.dispose();
    _walletPageController.dispose();
    _pageIndicatorController.dispose();
    super.dispose();
  }

  WalletHomeViewModel _createViewModel() {
    _viewModel = WalletHomeViewModel(
      Provider.of<WalletProvider>(context, listen: false),
      Provider.of<PreferenceProvider>(context, listen: false),
      Provider.of<ConnectivityProvider>(context, listen: false),
      Provider.of<NodeProvider>(context, listen: false),
    );
    return _viewModel;
  }

  void onPopInvoked(didPop, _) async {
    if (Platform.isAndroid) {
      final now = DateTime.now();
      if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 3)) {
        _lastPressedAt = now;
        CoconutToast.showBottomToast(context: context, text: t.toast.back_exit, seconds: 1);
      } else {
        SystemNavigator.pop();
      }
    }
  }

  void _handleWalletListUpdate(List<WalletItemBase> walletList) async {
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
        _viewModel.updateWalletBalancesAndRecentTxs();
      });
    } finally {
      _isWalletListLoading = false;
    }
  }

  Widget _buildHeader(
    bool isBalanceHidden,
    bool isFiatBalanceHidden,
    int? fakeBalanceTotalAmount,
    bool shouldShowLoadingIndicator,
    bool isWalletListEmpty,
  ) {
    // 처음 로딩시 스켈레톤
    if (shouldShowLoadingIndicator && _viewModel.walletItemList.isEmpty) {
      return SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.only(left: 20, top: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(''),
                  Shimmer.fromColors(
                    baseColor: context.coconutColors.surfaceSkeletonBase,
                    highlightColor: context.coconutColors.surfaceSkeletonHighlight,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(CoconutStyles.radius_100),
                        color: context.coconutColors.surfaceSkeletonBase,
                      ),
                      child: Text(
                        '0.0000 0000 BTC',
                        style: CoconutTypography.heading3_21_NumberBold.setColor(context.coconutColors.primaryText),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            CoconutLayout.spacing_500h,
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
              child: _buildHeaderActions(isActive: false),
            ),
            Divider(thickness: 12, color: context.coconutColors.surfaceSectionBreak),
          ],
        ),
      );
    }
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 5, bottom: 20, left: 20, right: 20),
            color: context.coconutColors.homeBackground,
            child: Column(
              children: [
                Visibility(
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  visible: (!isBalanceHidden) && _viewModel.walletItemList.isNotEmpty,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Selector<WalletHomeViewModel, Tuple2<List<int>, bool>>(
                        selector:
                            (_, viewModel) =>
                                Tuple2(viewModel.excludedFromTotalBalanceWalletIds, viewModel.isFiatBalanceHidden),
                        builder: (context, data, child) {
                          final excludedIds = data.item1;
                          final isFiatBalanceHidden = data.item2;
                          final balance =
                              _viewModel.fakeBalanceTotalAmount != null
                                  ? _viewModel.fakeBalanceMap.entries
                                      .where((entry) => !excludedIds.contains(entry.key))
                                      .map((entry) => entry.value as int)
                                      .fold<int>(0, (current, element) => current + element)
                                  : Map.fromEntries(
                                    _viewModel.walletBalanceMap.entries.where(
                                      (entry) => !excludedIds.contains(entry.key),
                                    ),
                                  ).values.map((e) => e.current).fold(0, (current, element) => current + element);
                          return Visibility(
                            maintainSize: true,
                            maintainAnimation: true,
                            maintainState: true,
                            visible: !isFiatBalanceHidden,
                            child: FiatPrice(
                              satoshiAmount: balance,
                              textStyle: CoconutTypography.body3_12_Number.setColor(context.coconutColors.tertiaryText),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Selector<PreferenceProvider, BitcoinUnit>(
                  selector: (_, viewModel) => viewModel.currentUnit,
                  builder: (context, currentUnit, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Expanded(
                          child: FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: Row(
                              children: [
                                if (!isBalanceHidden && fakeBalanceTotalAmount == null && currentUnit.isBip177Unit) ...[
                                  Text(
                                    currentUnit.symbol,
                                    style: CoconutTypography.heading3_21_NumberBold.setColor(
                                      context.coconutColors.primaryText,
                                    ),
                                  ),
                                  CoconutLayout.spacing_50w,
                                ],
                                isBalanceHidden
                                    ? FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        t.view_balance,
                                        style: CoconutTypography.heading3_21_NumberBold
                                            .setColor(context.coconutColors.tertiaryText)
                                            .merge(const TextStyle(height: 1.3)),
                                      ),
                                    )
                                    : fakeBalanceTotalAmount != null
                                    ? FittedBox(
                                      child: Text(
                                        currentUnit.displayBitcoinAmount(
                                          _viewModel.getHomeFakeBalanceTotal().toInt(),
                                          withUnit: true,
                                        ),
                                        style: CoconutTypography.heading3_21_NumberBold
                                            .setColor(context.coconutColors.primaryText)
                                            .merge(const TextStyle(height: 1.4)),
                                        maxLines: 1,
                                      ),
                                    )
                                    : FittedBox(
                                      alignment: Alignment.centerLeft,
                                      child: Selector<WalletHomeViewModel, List<int>>(
                                        selector: (_, viewModel) => viewModel.excludedFromTotalBalanceWalletIds,
                                        builder: (context, excludedIds, child) {
                                          // 총 잔액에서 숨기기 설정된 지갑 ID는 합에서 제외
                                          final filteredBalanceMap = Map.fromEntries(
                                            _viewModel.walletBalanceMap.entries.where(
                                              (entry) => !excludedIds.contains(entry.key),
                                            ),
                                          );

                                          final prevValue = filteredBalanceMap.values
                                              .map((e) => e.previous)
                                              .fold(0, (prev, element) => prev + element);

                                          final currentValue = filteredBalanceMap.values
                                              .map((e) => e.current)
                                              .fold(0, (current, element) => current + element);
                                          return AnimatedBalance(
                                            prevValue: prevValue,
                                            value: currentValue,
                                            currentUnit: currentUnit,
                                            textStyle: CoconutTypography.heading3_21_NumberBold
                                                .setColor(context.coconutColors.primaryText)
                                                .merge(const TextStyle(height: 1.4)),
                                          );
                                        },
                                      ),
                                    ),
                                if (!isBalanceHidden &&
                                    fakeBalanceTotalAmount == null &&
                                    !currentUnit.isBip177Unit) ...[
                                  CoconutLayout.spacing_50w,
                                  Text(
                                    currentUnit.symbol,
                                    style: CoconutTypography.heading3_21_NumberBold.setColor(
                                      context.coconutColors.primaryText,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        CoconutLayout.spacing_200w,
                        ShrinkAnimationButton(
                          borderRadius: CoconutStyles.radius_100,
                          defaultColor: context.coconutColors.homeSurfaceCard,
                          pressedColor: context.coconutColors.homeSurfaceCardPressed,
                          onPressed: () {
                            // if (fakeBalanceTotalAmount != null) {
                            //   _viewModel.clearFakeBlanceTotalAmount();
                            //   _viewModel.setIsBalanceHidden(true);
                            //   return;
                            // }
                            _viewModel.setIsBalanceHidden(!isBalanceHidden);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Text(
                              _viewModel.isBalanceHidden ? t.show : t.hide,
                              style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                CoconutLayout.spacing_500h,
                _buildHeaderActions(),
              ],
            ),
          ),
          Divider(thickness: 12, color: context.coconutColors.surfaceSectionBreak),
        ],
      ),
    );
  }

  Widget _buildHeaderActions({bool isActive = true}) {
    return Selector<PreferenceProvider, List<int>>(
      selector: (_, viewModel) => viewModel.walletOrder,
      builder: (context, walletOrder, child) {
        final labelColor = context.coconutColors.primaryText;
        return Row(
          children: [
            Expanded(
              child:
                  isActive
                      ? ShrinkAnimationButton(
                        onPressed: () {
                          _onTapReceive(walletOrder);
                        },
                        borderRadius: CoconutStyles.radius_100,
                        defaultColor: context.coconutColors.homeSurfaceCard,
                        pressedColor: context.coconutColors.homeSurfaceCardPressed,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(t.receive, style: CoconutTypography.body2_14.setColor(labelColor)),
                          ),
                        ),
                      )
                      : Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: context.coconutColors.homeSurfaceCard,
                          borderRadius: BorderRadius.circular(CoconutStyles.radius_100),
                        ),
                        child: Center(
                          child: Text(
                            t.receive,
                            style: CoconutTypography.body3_12.setColor(labelColor.withValues(alpha: 0.3)),
                          ),
                        ),
                      ),
            ),
            CoconutLayout.spacing_200w,
            Expanded(
              child:
                  isActive
                      ? ShrinkAnimationButton(
                        onPressed: () {
                          _onTapSend(walletOrder);
                        },
                        borderRadius: CoconutStyles.radius_100,
                        defaultColor: context.coconutColors.homeSurfaceCard,
                        pressedColor: context.coconutColors.homeSurfaceCardPressed,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(t.send, style: CoconutTypography.body2_14.setColor(labelColor)),
                          ),
                        ),
                      )
                      : Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: context.coconutColors.homeSurfaceCard,
                          borderRadius: BorderRadius.circular(CoconutStyles.radius_100),
                        ),
                        child: Center(
                          child: Text(
                            t.send,
                            style: CoconutTypography.body3_12.setColor(labelColor.withValues(alpha: 0.3)),
                          ),
                        ),
                      ),
            ),
          ],
        );
      },
    );
  }

  bool _checkStateAndShowToast(int id) {
    // if (_viewModel.isNetworkOn != true) {
    //   CoconutToast.showWarningToast(context: context, text: ErrorCodes.networkError.message);
    //   return false;
    // }
    final walletUpdateInfo = WalletUpdateInfo(id);
    // TODO: 실제 특정 id(대표지갑)의 SyncState와 연동-> 대표지갑 sync가 충족되지 않으면 [보내기] 불가하도록 개선, 아래 조건문도 변경이 필요함
    if (walletUpdateInfo.balance == WalletSyncState.completed &&
        walletUpdateInfo.transaction == WalletSyncState.completed) {
      CoconutToast.showToast(isVisibleIcon: true, context: context, text: t.toast.fetching_onchain_data);
      return false;
    }

    return true;
  }

  void _onTapReceive(List<int> walletOrder) {
    final firstWallet = _viewModel.walletItemList.firstOrNull;
    if (firstWallet == null) {
      // 추가된 지갑이 없음
      CoconutToast.showToast(
        context: context,
        isVisibleIcon: true,
        iconPath: 'assets/svg/circle-info.svg',
        text: t.can_use_after_add_wallet,
      );
      return;
    }

    // walletOrder에 있는 순서대로 매칭된 첫 번째 지갑의 id
    final targetId = walletOrder.firstWhere((id) => id == firstWallet.id, orElse: () => firstWallet.id);

    Navigator.of(context).pushNamed("/receive-address", arguments: {"id": targetId});
  }

  Future<void> _onTapSend(List<int> walletOrder, {String? bitcoinUri, bool shouldBypassSyncCheck = false}) async {
    final firstWallet = _viewModel.walletItemList.firstOrNull;
    if (firstWallet == null) {
      await Navigator.pushNamed(
        context,
        '/send',
        arguments: {'walletId': null, 'sendEntryPoint': SendEntryPoint.home, 'initialBitcoinUri': bitcoinUri},
      );
      return;
    }

    // walletOrder에 있는 순서대로 매칭된 첫 번째 지갑의 id
    final targetId = walletOrder.firstWhere((id) => id == firstWallet.id, orElse: () => firstWallet.id);

    if (!shouldBypassSyncCheck && !_checkStateAndShowToast(targetId)) return;

    final isManualUtxoSelection = _viewModel.isManualUtxoSelectionMode;

    // 자동선택 모드인 경우 보내기 화면으로 이동
    if (!isManualUtxoSelection || bitcoinUri != null) {
      await Navigator.pushNamed(
        context,
        '/send',
        arguments: {'walletId': targetId, 'sendEntryPoint': SendEntryPoint.home, 'initialBitcoinUri': bitcoinUri},
      );
      return;
    }

    if (!mounted) return;
    // 수동선택 모드인 경우 UTXO 선택 화면으로 이동
    final result = await CommonBottomSheets.showDraggableBottomSheet<List<UtxoState>>(
      context: context,
      minChildSize: 0.6,
      maxChildSize: 0.9,
      initialChildSize: 0.9,
      childBuilder:
          (scrollController) => UtxoSelectionScreen(
            selectedUtxoList: const <UtxoState>[],
            walletId: targetId,
            currentUnit: context.read<PreferenceProvider>().currentUnit,
            scrollController: scrollController,
            showSkipButton: true,
          ),
    );

    if (!mounted || result == null) return;
    Navigator.pushNamed(
      context,
      '/send',
      arguments: {'walletId': targetId, 'sendEntryPoint': SendEntryPoint.home, 'selectedUtxoList': result},
    );
  }

  Widget _buildWalletOverview(
    List<WalletItemBase> wallets,
    Map<int, AnimatedBalanceData> walletBalanceMap,
    FakeBalanceGetter getFakeBalance, {
    required bool isLoading,
  }) {
    final preferenceProvider = context.watch<PreferenceProvider>();
    final hasFavoriteHotWallet = wallets.any((wallet) => wallet.hasLocalKey);
    final shouldUseSingleWalletView =
        !preferenceProvider.isWalletFilterVisible(WalletFilter.hot) && !hasFavoriteHotWallet;
    final walletFilterOrder =
        preferenceProvider.walletFilterOrder.where(preferenceProvider.isWalletFilterVisible).toList();
    if (shouldUseSingleWalletView || !walletFilterOrder.contains(_walletFilter)) {
      _walletFilter = WalletFilter.all;
    }
    final selectedPageIndex = walletFilterOrder.indexOf(_walletFilter);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (shouldUseSingleWalletView || !mounted || !_walletPageController.hasClients) return;
      final currentPage = _walletPageController.page?.round();
      if (currentPage != selectedPageIndex && !_walletPageController.position.isScrollingNotifier.value) {
        _walletPageController.jumpToPage(selectedPageIndex);
      }
    });
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: context.coconutColors.homeSurfaceCard,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              if (!shouldUseSingleWalletView) _buildWalletFilterTabs(walletFilterOrder),
              if (isLoading)
                _buildWalletOverviewSkeleton()
              else if (shouldUseSingleWalletView)
                _buildSingleWalletList(wallets, walletBalanceMap, getFakeBalance)
              else
                _buildSwipeableWalletList(walletFilterOrder, wallets, walletBalanceMap, getFakeBalance),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewAllWallets(int walletCount) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          CoconutLayout.spacing_500h,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ShrinkAnimationButton(
              defaultColor: context.coconutColors.homeSurfaceCard,
              pressedColor: context.coconutColors.homeSurfaceCardPressed,
              onPressed: () => Navigator.pushNamed(context, '/wallet-list'),
              borderRadius: CoconutStyles.radius_200,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          t.wallet_home_screen.view_all_wallets,
                          style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                        ),
                      ),
                    ),
                    CoconutLayout.spacing_200w,
                    Text(
                      t.wallet_list.wallet_count(count: walletCount),
                      style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
                    ),
                    CoconutLayout.spacing_200w,
                    SvgPicture.asset(
                      'assets/svg/arrow-right.svg',
                      width: 6,
                      height: 10,
                      colorFilter: ColorFilter.mode(context.coconutColors.iconSubDefault, BlendMode.srcIn),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWalletOverviewSkeleton() {
    return SizedBox(
      height: 208,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Shimmer.fromColors(
          baseColor: context.coconutColors.surfaceSkeletonBase,
          highlightColor: context.coconutColors.surfaceSkeletonHighlight,
          child: Column(
            children: List.generate(
              2,
              (index) => Padding(
                padding: EdgeInsets.only(bottom: index == 0 ? 16 : 0),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: context.coconutColors.surfaceSkeletonBase,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    CoconutLayout.spacing_300w,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 128,
                            height: 14,
                            decoration: BoxDecoration(
                              color: context.coconutColors.surfaceSkeletonBase,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          CoconutLayout.spacing_200h,
                          Container(
                            width: 80,
                            height: 12,
                            decoration: BoxDecoration(
                              color: context.coconutColors.surfaceSkeletonBase,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletFilterTabs(List<WalletFilter> filters) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1)),
        child: Row(
          children: [
            for (final filter in filters)
              SizedBox(
                width: 72,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _selectWalletFilter(filter, filters),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _getWalletFilterLabel(filter),
                            style:
                                _walletFilter == filter
                                    ? CoconutTypography.body3_12_Bold.setColor(context.coconutColors.primaryText)
                                    : CoconutTypography.body3_12.setColor(context.coconutColors.mutedText),
                          ),
                        ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        height: _walletFilter == filter ? 2 : 1,
                        color:
                            _walletFilter == filter ? context.coconutColors.primaryText : context.coconutColors.divider,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _getWalletFilterLabel(WalletFilter filter) {
    return switch (filter) {
      WalletFilter.all => t.wallet_home_screen.wallet_filter.all,
      WalletFilter.watchOnly => t.wallet_home_screen.wallet_filter.watch_only,
      WalletFilter.hot => t.wallet_home_screen.wallet_filter.hot,
    };
  }

  Widget _buildSwipeableWalletList(
    List<WalletFilter> filters,
    List<WalletItemBase> wallets,
    Map<int, AnimatedBalanceData> walletBalanceMap,
    FakeBalanceGetter getFakeBalance,
  ) {
    final selectedWallets = _filteredWallets(_walletFilter, wallets);
    final pageHeight = _walletListPageHeight(selectedWallets.length);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: pageHeight,
      child: PageView.builder(
        controller: _walletPageController,
        itemCount: filters.length,
        onPageChanged: (index) {
          final filter = filters[index];
          if (_walletFilter == filter) return;
          setState(() => _walletFilter = filter);
        },
        itemBuilder: (context, index) {
          final filter = filters[index];
          return _buildWalletListPage(filter, wallets, walletBalanceMap, getFakeBalance);
        },
      ),
    );
  }

  Widget _buildSingleWalletList(
    List<WalletItemBase> wallets,
    Map<int, AnimatedBalanceData> walletBalanceMap,
    FakeBalanceGetter getFakeBalance,
  ) {
    final pageHeight = _walletListPageHeight(wallets.length);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: pageHeight,
      child: _buildWalletListPage(WalletFilter.all, wallets, walletBalanceMap, getFakeBalance),
    );
  }

  double _walletListPageHeight(int walletCount) {
    if (walletCount == 0) return 132;

    final textScaler = MediaQuery.textScalerOf(context);
    final textDirection = Directionality.of(context);

    double scaledLineHeight(TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: '가', style: style),
        textScaler: textScaler,
        textDirection: textDirection,
        maxLines: 1,
      )..layout();
      return painter.height;
    }

    final balanceLineHeight = math.max(
      scaledLineHeight(CoconutTypography.body2_14_Bold),
      scaledLineHeight(CoconutTypography.body2_14_NumberBold),
    );
    final walletItemHeight =
        math.max(64.0, 24 + balanceLineHeight + scaledLineHeight(CoconutTypography.body3_12)).ceilToDouble();
    final addWalletRowHeight = math.max(58.0, 32 + scaledLineHeight(CoconutTypography.body2_14)).ceilToDouble();

    return 10 + (walletCount * walletItemHeight) + addWalletRowHeight;
  }

  Widget _buildWalletListPage(
    WalletFilter filter,
    List<WalletItemBase> wallets,
    Map<int, AnimatedBalanceData> walletBalanceMap,
    FakeBalanceGetter getFakeBalance,
  ) {
    final visibleWallets = _filteredWallets(filter, wallets);
    final pageContent =
        visibleWallets.isEmpty
            ? Padding(padding: const EdgeInsets.only(top: 2.0), child: _buildEmptyWalletOverview(filter))
            : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      for (var walletIndex = 0; walletIndex < visibleWallets.length; walletIndex++)
                        _buildWalletItem(
                          visibleWallets[walletIndex],
                          kAlwaysCompleteAnimation,
                          walletBalanceMap[visibleWallets[walletIndex].id] ?? AnimatedBalanceData(0, 0),
                          getFakeBalance(visibleWallets[walletIndex].id),
                          walletIndex == visibleWallets.length - 1,
                          context.coconutColors.homeSurfaceCard,
                        ),
                    ],
                  ),
                ),
                _buildAddWalletRow(filter),
              ],
            );
    return ClipRect(child: SingleChildScrollView(physics: const NeverScrollableScrollPhysics(), child: pageContent));
  }

  List<WalletItemBase> _filteredWallets(WalletFilter filter, List<WalletItemBase> wallets) {
    return switch (filter) {
      WalletFilter.all => wallets,
      WalletFilter.watchOnly => wallets.where((wallet) => !wallet.hasLocalKey).toList(),
      WalletFilter.hot => wallets.where((wallet) => wallet.hasLocalKey).toList(),
    };
  }

  void _selectWalletFilter(WalletFilter filter, List<WalletFilter> filters) {
    if (_walletFilter == filter) return;
    if (!_walletPageController.hasClients) {
      setState(() => _walletFilter = filter);
      return;
    }
    _walletPageController.animateToPage(
      filters.indexOf(filter),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildEmptyWalletOverview(WalletFilter filter) {
    final addWalletIconSrc = switch (filter) {
      WalletFilter.all => 'assets/svg/wallet-add-default.svg',
      WalletFilter.watchOnly => 'assets/svg/wallet-eyes.svg',
      WalletFilter.hot => 'assets/svg/wallet-add-hot.svg',
    };

    final addWalletTitle = switch (filter) {
      WalletFilter.all => t.wallet_home_screen.add_wallet_action,
      WalletFilter.watchOnly => t.wallet_home_screen.wallet_type_selection.watch_only.title,
      WalletFilter.hot => t.wallet_home_screen.wallet_type_selection.hot_wallet.title,
    };
    final addWalletDescription = switch (filter) {
      WalletFilter.all => null,
      WalletFilter.watchOnly => t.wallet_home_screen.wallet_type_selection.watch_only.description,
      WalletFilter.hot => t.wallet_home_screen.wallet_type_selection.hot_wallet.description,
    };

    return ShrinkAnimationButton(
      onPressed: () => _onAddWalletPressed(filter),
      defaultColor: context.coconutColors.homeSurfaceCard,
      pressedColor: context.coconutColors.surfacePressed,
      borderRadius: 12,
      child: SizedBox(
        height: 124,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                addWalletIconSrc,
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
              ),
              CoconutLayout.spacing_200w,
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (addWalletDescription != null)
                    Text(
                      addWalletDescription,
                      style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
                    ),
                  Text(
                    addWalletTitle,
                    style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddWalletRow(WalletFilter filter) {
    final iconPath = switch (filter) {
      WalletFilter.all => 'assets/svg/wallet-add-default.svg',
      WalletFilter.watchOnly => 'assets/svg/wallet-eyes.svg',
      WalletFilter.hot => 'assets/svg/wallet-add-hot.svg',
    };
    final title = switch (filter) {
      WalletFilter.all => t.wallet_home_screen.add_wallet_action,
      WalletFilter.watchOnly => t.wallet_home_screen.wallet_type_selection.watch_only.title,
      WalletFilter.hot => t.wallet_home_screen.wallet_type_selection.hot_wallet.title,
    };
    return ShrinkAnimationButton(
      defaultColor: context.coconutColors.homeSurfaceCard,
      pressedColor: context.coconutColors.surfacePressed,
      borderRadius: 12,
      onPressed: () => _onAddWalletPressed(filter),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 16, 20, 16),
        child: Row(
          children: [
            SvgPicture.asset(
              iconPath,
              width: 18,
              height: 18,
              colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
            ),
            CoconutLayout.spacing_200w,
            Text(title, style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText)),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletItem(
    WalletItemBase wallet,
    Animation<double> animation,
    AnimatedBalanceData animatedBalanceData,
    int? fakeBalance,
    bool isLastItem,
    Color backgroundColor,
  ) {
    return _getWalletRowItem(
      Key(wallet.id.toString()),
      wallet,
      animatedBalanceData,
      fakeBalance,
      isLastItem,
      backgroundColor,
    );
  }

  Widget _getWalletRowItem(
    Key key,
    WalletItemBase walletItem,
    AnimatedBalanceData animatedBalanceData,
    int? fakeBalance,
    bool isLastItem,
    Color backgroundColor,
  ) {
    return Selector2<PreferenceProvider, WalletHomeViewModel, Tuple2<BitcoinUnit, bool>>(
      selector: (_, preferenceProvider, viewModel) => Tuple2(preferenceProvider.currentUnit, viewModel.isBalanceHidden),
      builder: (context, data, child) {
        final currentUnit = data.item1;
        final isBalanceHidden = data.item2;
        return LongPressedMenuWidget(
          useGlassOverlay: true,
          alignMenuToChildRight: true,
          spacing: 16,
          menuBackgroundColor: context.coconutColors.surfacePressed,
          menuItems: _buildWalletMenuItems(walletItem),
          child: WalletItemCard(
            key: key,
            walletItem: walletItem,
            animatedBalanceData: animatedBalanceData,
            isLastItem: isLastItem,
            isBalanceHidden: isBalanceHidden,
            fakeBalance: fakeBalance,
            currentUnit: currentUnit,
            backgroundColor: backgroundColor,
            onPressed: () {
              Navigator.pushNamed(
                context,
                '/wallet-detail',
                arguments: {'id': walletItem.id, 'entryPoint': kEntryPointWalletHome},
              );
            },
            rightWidget: SvgPicture.asset(
              'assets/svg/arrow-right.svg',
              width: 6,
              height: 10,
              colorFilter: ColorFilter.mode(context.coconutColors.iconSubDefault, BlendMode.srcIn),
            ),
          ),
        );
      },
    );
  }

  List<LongPressedMenuItem> _buildWalletMenuItems(WalletItemBase walletItem) {
    final isManuallyImported =
        walletItem.walletImportSource == WalletImportSource.extendedPublicKey ||
        walletItem.walletImportSource == WalletImportSource.descriptor;

    return [
      if (isManuallyImported)
        LongPressedMenuItem(
          title: t.wallet_home_screen.wallet_menu.rename,
          iconPath: 'assets/svg/edit-outlined.svg',
          onSelected: () => _showWalletRenameBottomSheet(walletItem),
        ),
      if (walletItem.hasLocalKey)
        LongPressedMenuItem(
          title: t.wallet_home_screen.wallet_menu.backup,
          iconPath: 'assets/svg/download.svg',
          onSelected: () {
            // TODO: 핫월렛 백업 화면 연결
          },
        ),
      LongPressedMenuItem(
        title: t.wallet_home_screen.wallet_menu.wallet_info,
        iconPath: 'assets/svg/circle-info.svg',
        onSelected: () => _openWalletInfo(walletItem),
      ),
      LongPressedMenuItem(
        title: t.wallet_home_screen.wallet_menu.remove_from_home,
        iconPath: 'assets/svg/star-outlined-bold.svg',
        onSelected: () => _removeWalletFromHome(walletItem.id),
      ),
      LongPressedMenuItem(
        title: t.wallet_home_screen.wallet_menu.delete,
        iconPath: 'assets/svg/trash.svg',
        isDanger: true,
        onSelected: () => _showDeleteWalletDialog(walletItem.id),
      ),
    ];
  }

  void _showWalletRenameBottomSheet(WalletItemBase walletItem) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (_) => WalletInfoEditBottomSheet(
            id: walletItem.id,
            walletImportSource: walletItem.walletImportSource,
            isCustomAccount: false,
          ),
    );
  }

  void _openWalletInfo(WalletItemBase walletItem) {
    Navigator.pushNamed(
      context,
      '/wallet-info',
      arguments: {'id': walletItem.id, 'walletType': walletItem.walletType, 'entryPoint': kEntryPointWalletHome},
    );
  }

  Future<void> _removeWalletFromHome(int walletId) async {
    final preferenceProvider = context.read<PreferenceProvider>();
    await preferenceProvider.setFavoriteWalletIds(
      preferenceProvider.favoriteWalletIds.where((id) => id != walletId).toList(),
    );
  }

  void _showDeleteWalletDialog(int walletId) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => CoconutPopup(
            languageCode: context.read<PreferenceProvider>().language,
            title: t.alert.wallet_delete.confirm_delete,
            description: t.alert.wallet_delete.confirm_delete_description,
            leftButtonText: t.cancel,
            rightButtonText: t.delete,
            rightButtonColor: context.coconutColors.danger,
            onTapLeft: () => Navigator.pop(dialogContext),
            onTapRight: () => _authenticateBeforeWalletDeletion(dialogContext, walletId),
          ),
    );
  }

  Future<void> _authenticateBeforeWalletDeletion(BuildContext dialogContext, int walletId) async {
    final authProvider = context.read<AuthProvider>();
    final walletProvider = context.read<WalletProvider>();
    if (!authProvider.isAuthEnabled || await authProvider.isBiometricsAuthValid()) {
      if (dialogContext.mounted) Navigator.pop(dialogContext);
      await walletProvider.deleteWallet(walletId);
      return;
    }

    if (!mounted) return;
    await CommonBottomSheets.showCustomHeightBottomSheet(
      context: context,
      heightRatio: 0.9,
      child: CustomLoadingOverlay(
        child: PinCheckScreen(
          onComplete: () async {
            if (dialogContext.mounted) Navigator.pop(dialogContext);
            await walletProvider.deleteWallet(walletId);
          },
        ),
      ),
    );
  }

  Widget _buildFeatureSectionIfEnabled(HomeFeatureType type, Widget Function() builder) {
    if (_viewModel.isHomeFeatureEnabled(type)) {
      return SliverToBoxAdapter(child: Column(children: [builder(), CoconutLayout.spacing_400h]));
    }

    return SliverToBoxAdapter(child: Container());
  }

  Widget _buildRecentTransactions() {
    return Selector<WalletHomeViewModel, bool>(
      selector: (_, viewModel) => viewModel.isEditWidgetMode,
      builder: (context, isEditMode, child) {
        return LongPressedMenuWidget(
          onMenuOpen: () {
            _setDropdownMenuVisiblility(false);
          },
          isEditMode: isEditMode,
          onRemove: () {
            _hideHomeFeature(HomeFeatureType.recentTransaction, keepEditMode: true);
          },
          menuItems: [
            LongPressedMenuItem(
              title: t.long_pressed_menu.go_to_home_screen_settings,
              iconPath: 'assets/svg/settings.svg',
              onSelected: _navigateToWalletHomeEdit,
            ),
            LongPressedMenuItem(
              title: t.long_pressed_menu.edit_home_widget,
              iconPath: 'assets/svg/widget.svg',
              onSelected: () {
                _viewModel.setEditWidgetMode(true);
              },
            ),
          ],
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                width: MediaQuery.sizeOf(context).width,
                child: Text(
                  t.wallet_home_screen.last_24_hours_transactions,
                  style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                ),
              ),
              CoconutLayout.spacing_200h,
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: context.coconutColors.homeBackground,
                ),
                child: Center(
                  child: Selector2<
                    PreferenceProvider,
                    WalletHomeViewModel,
                    Tuple3<BitcoinUnit, bool, List<Tuple2<int, TransactionRecord>>>
                  >(
                    selector:
                        (_, prefProvider, homeViewModel) => Tuple3(
                          prefProvider.currentUnit,
                          homeViewModel.showRecentFeatureInitialLoading,
                          homeViewModel.orderedRecentTransactions,
                        ),
                    builder: (context, data, child) {
                      final currentUnit = data.item1;
                      final showRecentInitialLoading = data.item2;
                      final ordered = data.item3;

                      if (ordered.isEmpty || _viewModel.isBalanceHidden || _viewModel.fakeBalanceTotalAmount != null) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildEmptyRecentTransactions(
                            (_viewModel.shouldShowLoadingIndicator && _viewModel.walletItemList.isNotEmpty) ||
                                showRecentInitialLoading,
                          ),
                        );
                      }

                      return ordered.length == 1
                          ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: _buildRecentTransactionCard(ordered.first.item1, ordered.first.item2, currentUnit),
                          )
                          : CarouselSlider(
                            carouselController: _carouselController,
                            options: CarouselOptions(
                              autoPlay: false,
                              height: 90,
                              viewportFraction: 0.9,
                              enlargeCenterPage: true,
                              enlargeFactor: 0.2,
                              enableInfiniteScroll: false,
                              onPageChanged: (index, reason) {
                                setState(() {
                                  _recentTransactionCurrentPage = index;
                                });
                                _scrollToIndicator(index);
                              },
                            ),
                            items:
                                ordered.map((t) {
                                  return _buildRecentTransactionCard(t.item1, t.item2, currentUnit);
                                }).toList(),
                          );
                    },
                  ),
                ),
              ),
              // 페이지 인디케이터 (트랜잭션 단위, 2개 이상일 때만 표시)
              Selector<WalletHomeViewModel, int>(
                selector: (_, viewModel) => viewModel.orderedRecentTransactions.length,
                builder: (context, indicatorCount, child) {
                  if (indicatorCount <= 1 || _viewModel.isBalanceHidden || _viewModel.fakeBalanceTotalAmount != null) {
                    return Container();
                  }

                  return Container(
                    margin: const EdgeInsets.only(top: 16, left: 50, right: 50),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _pageIndicatorController,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(indicatorCount, (index) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                            margin: EdgeInsets.symmetric(horizontal: _recentTransactionCurrentPage == index ? 2 : 4),
                            width: _recentTransactionCurrentPage == index ? 12 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  _recentTransactionCurrentPage == index
                                      ? context.coconutColors.pageIndicatorActive
                                      : context.coconutColors.pageIndicatorInactive,
                            ),
                          );
                        }),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecentTransactionCard(int walletId, TransactionRecord transaction, BitcoinUnit currentUnit) {
    final walletName = _viewModel.getWalletById(walletId).name;

    Widget buildTxRow(TransactionRecord transaction) {
      final bool isReceived = transaction.transactionType == TransactionType.received;
      final DateTime txDate = transaction.getDateTimeToDisplay()!.toLocal();
      final List<String> transactionTimeStamp = DateTimeUtil.formatTimestamp(txDate);
      final String formattedAmount = currentUnit.formatAmountWithSign(transaction.amount, isPositive: isReceived);
      final status = TransactionUtil.getStatus(transaction);
      final String iconSource = TransactionUtil.getStatusIconAsset(status);
      final datetimeTextColor = context.coconutColors.tertiaryText;
      final walletNameTextColor = context.coconutColors.secondaryText;
      final iconColor = switch (status) {
        TransactionStatus.sent || TransactionStatus.sending => context.coconutColors.sendingColor,
        TransactionStatus.received || TransactionStatus.receiving => context.coconutColors.receivingColor,
        _ => context.coconutColors.iconDefault,
      };

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // FIXME: [ datetime - n {unit} ago ] vertical align center
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  TransactionStatusGradientMask(
                    enabled: status == TransactionStatus.self || status == TransactionStatus.selfsending,
                    child: SvgPicture.asset(
                      iconSource,
                      fit: BoxFit.fill,
                      width: 28,
                      height: 28,
                      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    ),
                  ),
                  CoconutLayout.spacing_300w,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            transactionTimeStamp[0],
                            style: CoconutTypography.body3_12_Number.setColor(datetimeTextColor),
                          ),
                          CoconutLayout.spacing_50w,
                          Text('|', style: CoconutTypography.caption_10.setColor(datetimeTextColor)),
                          CoconutLayout.spacing_50w,
                          Text(
                            transactionTimeStamp[1],
                            style: CoconutTypography.body3_12_Number.setColor(datetimeTextColor),
                          ),
                        ],
                      ),
                      Text(walletName, style: CoconutTypography.body3_12.setColor(walletNameTextColor)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    (() {
                      final now = DateTime.now();
                      final diff = now.difference(txDate);
                      final diffMinutes = diff.inMinutes;
                      final diffHours = diff.inHours;

                      if (diffMinutes < 1) {
                        return t.relative_time.just_now;
                      }
                      if (diffHours < 1) {
                        return t.relative_time.minutes_ago(n: diffMinutes);
                      }
                      return t.relative_time.hours_ago(n: diffHours);
                    })(),
                    style: CoconutTypography.caption_10.setColor(context.coconutColors.tertiaryText),
                  ),
                  Text(
                    formattedAmount,
                    style: CoconutTypography.body2_14_Number.setColor(context.coconutColors.primaryText),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    if (_viewModel.isEditWidgetMode) {
      return Container(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.coconutColors.homeSurfaceCard),
          color: context.coconutColors.homeSurfaceCard,
        ),
        child: buildTxRow(transaction),
      );
    }

    return ShrinkAnimationButton(
      borderRadius: CoconutStyles.radius_200,
      defaultColor: context.coconutColors.homeSurfaceCard,
      pressedColor: context.coconutColors.homeSurfaceCardPressed,
      onPressed: () {
        Navigator.pushNamed(
          context,
          '/transaction-detail',
          arguments: {'id': walletId, 'txHash': transaction.transactionHash},
        );
      },
      child: Container(
        padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 20),
        child: buildTxRow(transaction),
      ),
    );
  }

  Widget _buildRecentTransactionsSkeleton() {
    return Container(
      margin: const EdgeInsets.only(top: 12, left: 20, right: 20),
      child: Shimmer.fromColors(
        baseColor: context.coconutColors.surfaceSkeletonBase,
        highlightColor: context.coconutColors.surfaceSkeletonHighlight,
        child: Container(
          width: MediaQuery.sizeOf(context).width,
          height: 90,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
            color: context.coconutColors.homeSurfaceCard,
          ),
          child: Text('', style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText)),
        ),
      ),
    );
  }

  Widget _buildEmptyRecentTransactions(bool isSyncing) {
    if (isSyncing) {
      _recentTransactionBannerTimer?.cancel();
      _recentTransactionBannerTimer = null;
      _showEmptyRecentTransactionWidget = true;
    } else if (_showEmptyRecentTransactionWidget && _recentTransactionBannerTimer == null) {
      _recentTransactionBannerTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        setState(() {
          _showEmptyRecentTransactionWidget = false;
        });
        _recentTransactionBannerTimer = null;
      });
    }

    final textColor = context.coconutColors.secondaryText;
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 14, top: 28, bottom: 28),
      decoration: BoxDecoration(
        color: context.coconutColors.homeSurfaceCard,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Center(
        child:
            isSyncing
                ? AnimatedDotsText(
                  text: t.wallet_home_screen.syncing_recent_transaction,
                  style: CoconutTypography.body3_12.setColor(textColor),
                )
                : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset('assets/svg/search-not-found.svg', width: 16, height: 16),
                    CoconutLayout.spacing_200w,
                    Text(t.tx_not_found, style: CoconutTypography.body3_12.setColor(textColor)),
                  ],
                ),
      ),
    );
  }

  Widget _buildAnalysis() {
    String stayHumbleStackSats = "Stay humble, stack sats!";
    return Selector<WalletHomeViewModel, bool>(
      selector: (_, viewModel) => viewModel.isEditWidgetMode,
      builder: (context, isEditMode, child) {
        return LongPressedMenuWidget(
          isEditMode: isEditMode,
          onRemove: () {
            _hideHomeFeature(HomeFeatureType.analysis, keepEditMode: true);
          },
          menuItems: [
            LongPressedMenuItem(
              title: t.long_pressed_menu.go_to_home_screen_settings,
              iconPath: 'assets/svg/settings.svg',
              onSelected: _navigateToWalletHomeEdit,
            ),
            LongPressedMenuItem(
              title: t.long_pressed_menu.edit_home_widget,
              iconPath: 'assets/svg/widget.svg',
              onSelected: () {
                _viewModel.setEditWidgetMode(true);
              },
            ),
          ],
          child: Container(
            margin: const EdgeInsets.only(top: 0, left: 20, right: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_viewModel.isEditWidgetMode) ...[
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.transparent)),
                    child: _buildAnalysisFilterButton(),
                  ),
                ] else ...[
                  ShrinkAnimationButton(
                    defaultColor: context.coconutColors.homeBackground,
                    onPressed: () {
                      CommonBottomSheets.showCustomHeightBottomSheet(
                        context: context,
                        heightRatio: 0.55,
                        child: AnalysisPeriodBottomSheet(
                          onSelected: (days) {
                            _viewModel.updateAnalysisPeriod(days);
                          },
                          onTransactionTypeSelected: (analysisTransactionType) {
                            _viewModel.setAnalysisTransactionType(analysisTransactionType);
                          },
                          initialPeriodPreset: _viewModel.analysisPeriod,
                          initialAnalysisTransactionType: _viewModel.selectedAnalysisTransactionType,
                        ),
                      );
                    },
                    child: _buildAnalysisFilterButton(),
                  ),
                ],
                if (_viewModel.recentTransactionAnalysis?.isEmpty == true ||
                    _viewModel.recentTransactionAnalysis == null ||
                    _viewModel.isBalanceHidden ||
                    _viewModel.fakeBalanceTotalAmount != null) ...[
                  // 분석에 필요한 거래가 없거나 잔액 숨기기/가짜잔액 설정되었을 때
                  Container(
                    width: MediaQuery.sizeOf(context).width,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: context.coconutColors.homeSurfaceCard,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.wallet_home_screen.no_change_in_amount,
                          style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                        ),
                        CoconutLayout.spacing_1500h,
                        Center(
                          child: Text(
                            stayHumbleStackSats,
                            style: CoconutTypography.body1_16_NumberBold.setColor(context.coconutColors.tertiaryText),
                          ),
                        ),

                        CoconutLayout.spacing_2200h,
                      ],
                    ),
                  ),
                ] else if (_viewModel.recentTransactionAnalysis?.isEmpty == false) ...[
                  Selector<PreferenceProvider, BitcoinUnit>(
                    selector: (_, viewModel) => viewModel.currentUnit,
                    builder: (context, currentUnit, child) {
                      return Container(
                        width: MediaQuery.sizeOf(context).width,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: context.coconutColors.homeSurfaceCard,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Row(
                                      children: [
                                        if (_viewModel.recentTransactionAnalysis!.shouldShowTitleAmount)
                                          Text(
                                            _viewModel.recentTransactionAnalysis!.titleString,
                                            style: CoconutTypography.body2_14_NumberBold.setColor(
                                              context.coconutColors.primaryText,
                                            ),
                                          ),
                                        Text(
                                          _viewModel.recentTransactionAnalysis!.totalAmountResult,
                                          style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            CoconutLayout.spacing_200h,
                            Text(
                              _viewModel.recentTransactionAnalysis!.subtitleString,
                              style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                            ),
                            CoconutLayout.spacing_300h,
                            if (_viewModel.recentTransactionAnalysis!.receivedTxs.isNotEmpty &&
                                _viewModel.selectedAnalysisTransactionType != AnalysisTransactionType.onlySent) ...[
                              _buildAnalysisTransactionRow(
                                _viewModel.recentTransactionAnalysis!.receivedTxs.length,
                                _viewModel.recentTransactionAnalysis!.receivedAmount,
                                TransactionType.received,
                                currentUnit,
                              ),
                            ],
                            if (_viewModel.recentTransactionAnalysis!.sentTxs.isNotEmpty &&
                                _viewModel.selectedAnalysisTransactionType != AnalysisTransactionType.onlyReceived) ...[
                              _buildAnalysisTransactionRow(
                                _viewModel.recentTransactionAnalysis!.sentTxs.length,
                                _viewModel.recentTransactionAnalysis!.sentAmount,
                                TransactionType.sent,
                                currentUnit,
                              ),
                            ],
                            if (_viewModel.recentTransactionAnalysis!.selfTxs.isNotEmpty &&
                                _viewModel.selectedAnalysisTransactionType != AnalysisTransactionType.onlyReceived) ...[
                              _buildAnalysisTransactionRow(
                                _viewModel.recentTransactionAnalysis!.selfTxs.length,
                                _viewModel.recentTransactionAnalysis!.selfAmount,
                                TransactionType.self,
                                currentUnit,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalysisFilterButton() {
    final textColor = context.coconutColors.secondaryText;
    final iconColor = context.coconutColors.iconSubDefault;

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            _viewModel.analysisPeriod != 0
                ? t.wallet_home_screen.analysis_period(
                  days: _viewModel.analysisPeriod.toString(),
                  transaction_type: _viewModel.selectedAnalysisTransactionTypeName,
                )
                : t.wallet_home_screen.analysis_period_cutsom(
                  transaction_type: _viewModel.selectedAnalysisTransactionTypeName,
                ),
            style: CoconutTypography.body3_12.setColor(textColor),
          ),
          CoconutLayout.spacing_150w,
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: SvgPicture.asset(
              'assets/svg/caret-down.svg',
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisTransactionRow(int count, int amount, TransactionType type, BitcoinUnit currentUnit) {
    String getIconPath() {
      switch (type) {
        case TransactionType.received:
          return 'assets/svg/tx-received.svg';
        case TransactionType.sent:
          return 'assets/svg/tx-sent.svg';
        case TransactionType.self:
          return 'assets/svg/tx-self.svg';
        default:
          return 'assets/svg/tx-received.svg';
      }
    }

    final bool isReceived = type == TransactionType.received;
    final String formattedAmount = currentUnit.formatAmountWithSign(amount, isPositive: isReceived);
    final iconColor = switch (type) {
      TransactionType.sent => context.coconutColors.sendingColor,
      TransactionType.received => context.coconutColors.receivingColor,
      _ => context.coconutColors.iconDefault,
    };

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            TransactionStatusGradientMask(
              enabled: type == TransactionType.self,
              child: SvgPicture.asset(
                getIconPath(),
                fit: BoxFit.fill,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
            CoconutLayout.spacing_200w,
            Text(
              t.wallet_home_screen.count(count: count.toString()),
              style: CoconutTypography.body3_12.setColor(context.coconutColors.tertiaryText),
            ),

            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  formattedAmount,
                  style: CoconutTypography.body2_14_Number.setColor(context.coconutColors.primaryText),
                ),
              ),
            ),
          ],
        ),
        if (type == TransactionType.self) ...[
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              t.fee,
              style: CoconutTypography.caption_10.setColor(context.coconutColors.tertiaryText).copyWith(height: 1),
            ),
          ),
        ],
        CoconutLayout.spacing_400h,
      ],
    );
  }

  Widget _buildAnalysisSkeleton() {
    return Container(
      margin: const EdgeInsets.only(top: 36, left: 20, right: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Shimmer.fromColors(
            baseColor: context.coconutColors.surfaceSkeletonBase,
            highlightColor: context.coconutColors.surfaceSkeletonHighlight,
            child: Container(
              margin: const EdgeInsets.only(top: 8, left: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
                color: context.coconutColors.surfaceSkeletonBase,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // FIXME: embedded kr text
                  Text('최근 30일 • 보내기', style: CoconutTypography.body3_12.setColor(context.coconutColors.tertiaryText)),
                  CoconutLayout.spacing_100w,
                  SvgPicture.asset(
                    'assets/svg/caret-down.svg',
                    colorFilter: ColorFilter.mode(context.coconutColors.iconSubDefault, BlendMode.srcIn),
                  ),
                ],
              ),
            ),
          ),
          Shimmer.fromColors(
            baseColor: context.coconutColors.surfaceSkeletonBase,
            highlightColor: context.coconutColors.surfaceSkeletonHighlight,
            child: Container(
              width: MediaQuery.sizeOf(context).width,
              margin: const EdgeInsets.only(top: 8),
              height: 90,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
                color: context.coconutColors.surfaceSkeletonBase,
              ),
              child: Text('', style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText)),
            ),
          ),
        ],
      ),
    );
  }

  void _goToScannerScreen(WalletImportSource walletImportSource) async {
    Navigator.pop(context);
    final ResultOfSyncFromVault? scanResult =
        (await Navigator.pushNamed(
              context,
              '/wallet-add-scanner',
              arguments: {
                'walletImportSource': walletImportSource,
                'onNewWalletAdded': (scanResult) {
                  setState(() {
                    _resultOfSyncFromVault = scanResult;
                  });
                },
              },
            )
            as ResultOfSyncFromVault?);

    setState(() {
      _resultOfSyncFromVault = scanResult;
    });

    if (_resultOfSyncFromVault == null) return;
  }

  void _goToBitBox02Screen() async {
    Navigator.pop(context);
    Navigator.pushNamed(context, '/bitbox02-connect', arguments: {'walletImportSource': WalletImportSource.bitbox02});
  }

  void _onAddWalletPressed([WalletFilter? filter]) {
    switch (filter ?? _walletFilter) {
      case WalletFilter.all:
        _showAddWalletMenu(_AddWalletMenuMode.walletType);
      case WalletFilter.watchOnly:
        _showAddWalletMenu(_AddWalletMenuMode.watchOnlySource);
      case WalletFilter.hot:
        _showAddWalletMenu(_AddWalletMenuMode.hotWalletAction);
    }
  }

  void _onAppBarAddWalletPressed() {
    switch (context.read<PreferenceProvider>().homeAddWalletOption) {
      case HomeAddWalletOption.all:
        _showAddWalletMenu(_AddWalletMenuMode.walletType);
      case HomeAddWalletOption.watchOnly:
        _showAddWalletMenu(_AddWalletMenuMode.watchOnlySource);
      case HomeAddWalletOption.hotWallet:
        _showAddWalletMenu(_AddWalletMenuMode.hotWalletAction);
      case HomeAddWalletOption.hidden:
        break;
    }
  }

  void _showAddWalletMenu(_AddWalletMenuMode mode) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: context.coconutColors.homeBackground.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        final offsetTween = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero);
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
                  color: context.coconutColors.homeBackground,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (mode == _AddWalletMenuMode.walletType) ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildWalletTypeShrinkButton(
                                  iconPath: 'assets/svg/wallet-eyes.svg',
                                  title: t.wallet_home_screen.wallet_type_selection.watch_only.title,
                                  description: t.wallet_home_screen.wallet_type_selection.watch_only.description,
                                  descriptionFirst: true,
                                  onPressed: () {
                                    Navigator.pop(context);
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted) {
                                        _showAddWalletMenu(_AddWalletMenuMode.watchOnlySource);
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildWalletTypeShrinkButton(
                                  iconPath: 'assets/svg/wallet-add-hot.svg',
                                  title: t.wallet_home_screen.wallet_type_selection.hot_wallet.title,
                                  description: t.wallet_home_screen.wallet_type_selection.hot_wallet.description,
                                  descriptionFirst: true,
                                  onPressed: () {
                                    Navigator.pop(context);
                                    WidgetsBinding.instance.addPostFrameCallback((_) {
                                      if (mounted) {
                                        _showAddWalletMenu(_AddWalletMenuMode.hotWalletAction);
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ] else if (mode == _AddWalletMenuMode.watchOnlySource) ...[
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
                              Expanded(
                                child: _buildWalletIconShrinkButton(
                                  () => _goToScannerScreen(WalletImportSource.coldCard),
                                  WalletImportSource.coldCard,
                                ),
                              ),
                              Expanded(
                                child: _buildWalletIconShrinkButton(
                                  () => _goToScannerScreen(WalletImportSource.krux),
                                  WalletImportSource.krux,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildWalletIconShrinkButton(
                                  () => _goToScannerScreen(WalletImportSource.passport),
                                  WalletImportSource.passport,
                                ),
                              ),
                              Expanded(
                                child: _buildWalletIconShrinkButton(
                                  () => _goToBitBox02Screen(),
                                  WalletImportSource.bitbox02,
                                ),
                              ),
                              const Expanded(child: SizedBox()),
                            ],
                          ),
                          CoconutLayout.spacing_400h,
                          Row(
                            children: [
                              Expanded(
                                child: _buildWalletIconShrinkButton(
                                  () => _goToScannerScreen(WalletImportSource.extendedPublicKey),
                                  WalletImportSource.extendedPublicKey,
                                ),
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: _buildWalletTypeShrinkButton(
                                  iconPath: 'assets/svg/wallet-add-hot.svg',
                                  title: t.wallet_home_screen.hot_wallet_add.create.title,
                                  description: t.wallet_home_screen.hot_wallet_add.create.description,
                                  descriptionFirst: true,
                                  onPressed: _onCreateHotWalletPressed,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: _buildWalletTypeShrinkButton(
                                  iconPath: 'assets/svg/wallet-import-hot.svg',
                                  title: t.wallet_home_screen.hot_wallet_add.restore.title,
                                  description: t.wallet_home_screen.hot_wallet_add.restore.description,
                                  descriptionFirst: true,
                                  onPressed: _onRestoreHotWalletPressed,
                                ),
                              ),
                            ],
                          ),
                        ],
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
                  Container(height: MediaQuery.of(context).padding.top, color: context.coconutColors.homeBackground),
                  Container(
                    width: MediaQuery.sizeOf(context).width,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    height: kToolbarHeight,
                    color: context.coconutColors.homeBackground,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            onPressed: () => Navigator.pop(context),
                            // TODO: light 모드에서 iconHighlight가 회색임....
                            highlightColor: context.coconutColors.iconHighlight,
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                            icon: SvgPicture.asset(
                              'assets/svg/close-bold.svg',
                              colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
                              width: 14,
                              height: 14,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          t.wallet_add_scanner_screen.add_wallet,
                          style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
                        ),
                        const Spacer(),
                        const SizedBox(width: 40),
                      ],
                    ),
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

  Future<void> _onCreateHotWalletPressed() async {
    if (!await _ensureDevicePasscodeIsSet()) return;
    if (!mounted) return;

    Navigator.pop(context);
    Navigator.pushNamed(context, '/hot-wallet-create');
  }

  Future<void> _onRestoreHotWalletPressed() async {
    if (!await _ensureDevicePasscodeIsSet()) return;
    if (!mounted) return;

    Navigator.pop(context);
    // TODO: 핫월렛 니모닉 복원 화면 연결
  }

  Future<bool> _ensureDevicePasscodeIsSet() async {
    final isDevicePasscodeSet = await context.read<AuthProvider>().isDevicePasscodeSet();
    if (!mounted) return false;
    if (isDevicePasscodeSet) return true;

    await showConfirmDialog(
      context,
      context.read<PreferenceProvider>().language,
      t.wallet_home_screen.hot_wallet_add.device_passcode_required.title,
      t.wallet_home_screen.hot_wallet_add.device_passcode_required.description,
      leftButtonText: t.close,
      rightButtonText: t.go_to_settings,
      onTapLeft: () => Navigator.pop(context),
      onTapRight: () async {
        Navigator.pop(context);
        await context.read<AuthProvider>().openDeviceSecuritySettings();
      },
    );
    return false;
  }

  SliverAppBar _buildAppBar(NetworkStatus networkStatus) {
    final shouldShow = networkStatus != NetworkStatus.online;
    final addWalletIconPath = switch (context.read<PreferenceProvider>().homeAddWalletOption) {
      HomeAddWalletOption.all => 'assets/svg/wallet-add-default.svg',
      HomeAddWalletOption.watchOnly => 'assets/svg/wallet-eyes.svg',
      HomeAddWalletOption.hotWallet => 'assets/svg/wallet-add-hot.svg',
      HomeAddWalletOption.hidden => null,
    };

    String message;
    switch (networkStatus) {
      case NetworkStatus.offline:
        message = t.errors.network_disconnected;
        break;
      case NetworkStatus.connectionFailed:
        message = t.errors.electrum_connection_failed;
        break;
      case NetworkStatus.vpnBlocked:
        message = t.errors.vpn_connected;
        break;
      case NetworkStatus.online:
        message = '';
        break;
    }
    if (message.isNotEmpty) Logger.log('Error message: $message');

    return CoconutAppBar.buildHomeAppbar(
      context: context,
      leadingSvgAsset: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child:
            shouldShow
                ? Row(
                  key: const ValueKey('error_message'),
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    SvgPicture.asset('assets/svg/cloud-disconnected.svg', width: 16),
                    CoconutLayout.spacing_100w,
                    SizedBox(
                      width: MediaQuery.of(context).size.width - 160,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          message,
                          style: CoconutTypography.body3_12_Bold.setColor(context.coconutColors.danger),
                        ),
                      ),
                    ),
                  ],
                )
                : const SizedBox.shrink(key: ValueKey('empty')),
      ),
      appTitle: '',
      actionButtonList: [
        // 설정된 방식으로 지갑 추가하기
        if (addWalletIconPath != null)
          _buildAppBarIconButton(
            key: GlobalKey(),
            icon: SvgPicture.asset(
              addWalletIconPath,
              colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
            ),
            onPressed: () {
              _onAppBarAddWalletPressed();
            },
          ),
        // 더보기(풀다운 메뉴 열림)
        _buildAppBarIconButton(
          key: _dropdownButtonKey,
          icon: SvgPicture.asset(
            'assets/svg/kebab.svg',
            colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
          ),
          onPressed: () {
            _setDropdownMenuVisiblility(true);
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
      child: IconButton(icon: icon, onPressed: onPressed, color: context.coconutColors.iconDefault),
    );
  }

  Widget _buildLoadingIndicator(BuildContext context, WalletHomeViewModel viewModel) {
    return SliverToBoxAdapter(
      child: AnimatedSwitcher(
        transitionBuilder:
            (child, animation) =>
                FadeTransition(opacity: animation, child: SizeTransition(sizeFactor: animation, child: child)),
        duration: const Duration(milliseconds: 300),
        child:
            viewModel.shouldShowLoadingIndicator && viewModel.walletItemList.isNotEmpty
                ? const Center(
                  child: Padding(
                    key: ValueKey("loading"),
                    padding: EdgeInsets.only(bottom: 20.0),
                    child: LoadingIndicator(),
                  ),
                )
                : null,
      ),
    );
  }

  Widget _buildDropdownBackdrop() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isDropdownMenuVisible,
      builder: (context, isVisible, child) {
        return isVisible
            ? Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  _setDropdownMenuVisiblility(false);
                },
              ),
            )
            : Container();
      },
    );
  }

  Widget _buildDropdownMenu() {
    final bool showGlossary = AppLanguage.fromCode(context.read<PreferenceProvider>().language).supportsGlossary;
    return Positioned(
      top: _dropdownButtonPosition.dy + _dropdownButtonSize.height,
      right: 20,
      child: ValueListenableBuilder<bool>(
        valueListenable: _isDropdownMenuVisible,
        builder: (context, isVisible, child) {
          return Visibility(
            visible: isVisible,
            child: CoconutPulldownMenu(
              backgroundColor: context.coconutColors.pulldownMenuBackground,
              shadowColor: context.coconutColors.shadowDefault.withValues(alpha: 0.06),
              dividerColor: context.coconutColors.pulldownMenuDividerColor,
              splashColor: context.coconutColors.pulldownMenuPressedColor,
              entries: [
                CoconutPulldownMenuGroup(
                  groupTitle: t.tool,
                  items: [
                    CoconutPulldownMenuItem(title: t.transaction_draft.title),
                    if (showGlossary) CoconutPulldownMenuItem(title: t.glossary),
                    CoconutPulldownMenuItem(title: t.utility.p2p_calculator.calculator),
                    CoconutPulldownMenuItem(title: t.mnemonic_wordlist),
                    CoconutPulldownMenuItem(title: t.tutorial),
                  ],
                ),
                CoconutPulldownMenuItem(title: t.home_screen_settings),
                CoconutPulldownMenuItem(title: t.app_settings),
                // CoconutPulldownMenuItem(title: t.view_app_info),
              ],
              thickDividerIndexList: [_getThickDividerIndex(showGlossary)],
              onSelected: ((index, selectedText) {
                _setDropdownMenuVisiblility(false);
                _handleDropdownSelection(selectedText);
              }),
            ),
          );
        },
      ),
    );
  }

  /// 용어집 표시 여부에 따른 Thick Divider 인덱스 계산
  /// CoconutPulldownMenuGroup이 끝나는 지점의 인덱스를 반환
  int _getThickDividerIndex(bool showGlossary) {
    // 테스트넷/메인넷 공통: 임시저장(0) + 용어집(1) + P2P계산기(2) + 니모닉(3) + 튜토리얼(4) → 그룹 끝 인덱스 4
    // 테스트넷/메인넷 공통 (용어집 없음): 임시저장(0) + P2P계산기(1) + 니모닉(2) + 튜토리얼(3) → 그룹 끝 인덱스 3
    return showGlossary ? 4 : 3;
  }

  /// 드롭다운 선택 처리 (selectedText 기반)
  void _handleDropdownSelection(String selectedText) {
    String actionKey = _getActionKeyFromSelectedText(selectedText);
    final action = _dropdownActions[actionKey];
    if (action != null) {
      action();
    }
  }

  /// 선택된 텍스트에서 액션 키를 추출
  String _getActionKeyFromSelectedText(String selectedText) {
    if (selectedText == t.transaction_draft.title) return 'transaction_draft';
    if (selectedText == t.glossary) return 'glossary';
    if (selectedText == t.utility.p2p_calculator.calculator) return 'p2p_calculator';
    if (selectedText == t.mnemonic_wordlist) return 'mnemonic_wordlist';
    if (selectedText == t.tutorial) return 'tutorial';
    if (selectedText == t.home_screen_settings) return 'home_screen_settings';
    if (selectedText == t.app_settings) return 'app_settings';
    return '';
  }

  Widget _buildWalletIconShrinkButton(VoidCallback onPressed, WalletImportSource scanType) {
    return ShrinkAnimationButton(
      defaultColor: context.coconutColors.homeBackground,
      pressedColor: context.coconutColors.homeSurfaceCardPressed,
      onPressed: () => onPressed(),
      child:
          scanType == WalletImportSource.extendedPublicKey
              ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Row(
                  children: [
                    SvgPicture.asset(
                      scanType.externalWalletIconPath,
                      colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
                    ),
                    CoconutLayout.spacing_400w,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            scanType.displayName,
                            style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          CoconutLayout.spacing_50h,
                          Text(
                            t.wallet_add_scanner_screen.self_description,
                            style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
              : Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                child: Column(
                  children: [
                    SvgPicture.asset(
                      scanType.externalWalletIconPath,
                      colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
                    ),
                    CoconutLayout.spacing_100h,
                    Text(
                      scanType.displayName,
                      style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
    );
  }

  Widget _buildWalletTypeShrinkButton({
    required String iconPath,
    required String title,
    required String description,
    required VoidCallback onPressed,
    bool descriptionFirst = false,
  }) {
    return ShrinkAnimationButton(
      defaultColor: context.coconutColors.homeBackground,
      pressedColor: context.coconutColors.homeSurfaceCardPressed,
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            SvgPicture.asset(
              iconPath,
              width: 24,
              height: 19,
              colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
            ),
            CoconutLayout.spacing_400w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (descriptionFirst) ...[
                    Text(
                      description,
                      style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    CoconutLayout.spacing_50h,
                    Text(
                      title,
                      style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.primaryText),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ] else ...[
                    Text(
                      title,
                      style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    CoconutLayout.spacing_50h,
                    Text(
                      description,
                      style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setDropdownMenuVisiblility(bool value) {
    _isDropdownMenuVisible.value = value;
  }

  void _scrollToIndicator(int index) {
    if (!_pageIndicatorController.hasClients) return;

    // 실제 화면 너비를 기반으로 보이는 점 개수 계산
    final screenWidth = MediaQuery.of(context).size.width;
    const double dotWidth = 16.0; // 8px + 8px margin
    final int visibleDots = (screenWidth / dotWidth).floor();

    // 현재 페이지가 화면 중앙에 오도록 스크롤
    final double targetOffset = (index - visibleDots ~/ 2) * dotWidth;
    final double maxOffset = _pageIndicatorController.position.maxScrollExtent;
    final double minOffset = _pageIndicatorController.position.minScrollExtent;

    final double clampedOffset = targetOffset.clamp(minOffset, maxOffset);

    _pageIndicatorController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
