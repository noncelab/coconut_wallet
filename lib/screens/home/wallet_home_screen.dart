import 'dart:async';
import 'dart:io';

import 'package:coconut_wallet/analytics/wallet_add_analytics.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutPulldownMenu,
        CoconutPulldownMenuItem,
        CoconutPulldownMenuGroup,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup;
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_pulldown_menu.dart';
import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/open_store/coconut_open_store_content.dart';
import 'package:coconut_wallet/ccos/open_store/coconut_open_store_navigation.dart';
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
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_list_user_experience_survey_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/common/amount/animated_balance.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:coconut_wallet/widgets/common/text/animated_dots_text.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/features/ccos/card/coconut_open_store_intro_card.dart';
import 'package:coconut_wallet/widgets/common/card/notice_card.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_list_add_guide_card.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:coconut_wallet/widgets/common/icon/transaction_status_gradient_mask.dart';
import 'package:coconut_wallet/widgets/common/loading/loading_indicator.dart';
import 'package:coconut_wallet/widgets/features/wallet/menu/long_pressed_menu_widget.dart';
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
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_item_card.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/settings/tools/glossary_bottom_sheet.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tuple/tuple.dart';
import 'package:collection/collection.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  /// P2P 등 외부에서 홈의 "지갑 추가" 바텀시트를 띄울 때 호출.
  static void openAddWalletIfActive() => _currentState?._onAddWalletPressed();

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

  DateTime? _lastPressedAt;
  ResultOfSyncFromVault? _resultOfSyncFromVault;

  late List<WalletItemBase> _previousWalletList = [];
  final GlobalKey<SliverAnimatedListState> _walletListKey = GlobalKey<SliverAnimatedListState>();
  final Duration _duration = const Duration(milliseconds: 1200);

  // 화면 콘텐츠의 좌우 여백을 한 곳에서 동일하게 관리
  static const double _horizontalPadding = 16;
  // 섹션 라벨(예: "지난 24시간 거래", "최근 N일 · 전체")이 _horizontalPadding보다 추가로 더 들여지는 간격
  static const double _sectionLabelExtraPadding = 4;
  // FiatPrice가 네트워크/설정 상태에 따라 비어도
  // 아래 잔액 영역의 Y 위치가 흔들리지 않도록 유지하는 높이
  static const double _fiatPriceSlotHeight = 17;

  double? itemCardWidth;
  double? itemCardHeight;

  double? _recentTxCardHeight;
  final GlobalKey _recentTxCardMeasureKey = GlobalKey();

  void _measureRecentTxCardHeightIfNeeded() {
    final renderObject = _recentTxCardMeasureKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) return;

    final measuredHeight = renderObject.size.height;
    if (_recentTxCardHeight != measuredHeight) {
      setState(() {
        _recentTxCardHeight = measuredHeight;
      });
    }
  }

  Future<void> _hideHomeFeature(HomeFeatureType type, {bool keepEditMode = false}) async {
    bool? result = await showDialog<bool>(
      context: context,
      builder:
          (context) => CoconutPopup(
            languageCode: context.read<PreferenceProvider>().language,
            title: t.long_pressed_menu.hide_home_widget_title(widgetName: _getWidgetName(type)),
            description: t.long_pressed_menu.hide_home_widget_description,
            leftButtonText: t.cancel,
            rightButtonText: t.OK,
            onTapLeft: () => Navigator.pop(context, false),
            onTapRight: () => Navigator.pop(context, true),
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
  final Set<int> _dismissedBackupUpdateWalletIds = <int>{};
  Set<int>? _initialBackupUpdateWalletIds;

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
          Tuple2<NetworkStatus, String>
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
              Tuple2(vm.networkStatus, vm.unacknowledgedOlderToAfterBackupUpdateWalletIdsSignature),
            ),
        builder: (context, data, child) {
          final viewModel = Provider.of<WalletHomeViewModel>(context, listen: false);
          final shouldShowOpenStoreIntroCard = context.select<PreferenceProvider, bool>(
            (provider) => provider.shouldShowOpenStoreIntroCard,
          );
          final openStoreFeatureStatusLabel = context.select<PreferenceProvider, String?>(
            (provider) => provider.getCcosFeatureStatusLabel(CcosFeatureRegistrySource.featuredListing.id),
          );

          final walletItem = data.item1;
          final favoriteWallets = data.item2;
          final balanceVisibilityData = data.item3;
          final shouldShowLoadingIndicator = data.item4;
          final walletBalanceMap = data.item5;
          final fakeBalanceData = data.item6;
          final networkStatus = data.item7.item1;
          final homeFeatures = viewModel.homeFeatures;
          final hasEnabledHomeFeature = homeFeatures.any((feature) => feature.isEnabled);

          if (_initialBackupUpdateWalletIds == null && !shouldShowLoadingIndicator) {
            _initialBackupUpdateWalletIds = Set<int>.from(
              viewModel.walletIdsWithUnacknowledgedOlderToAfterBackupUpdate,
            );
          }

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
                          _buildBackupUpdateNotice(viewModel, walletItem),
                          _buildLoadingIndicator(context, viewModel),
                          _buildHeader(
                            balanceVisibilityData.item1,
                            balanceVisibilityData.item2,
                            fakeBalanceData.item1,
                            shouldShowLoadingIndicator,
                            walletItem.isEmpty,
                          ),
                          if (!shouldShowLoadingIndicator)
                            SliverToBoxAdapter(
                              child: Column(
                                children: [
                                  if (walletItem.isEmpty) ...[
                                    _buildOpenStoreIntroCard(
                                      visible: shouldShowOpenStoreIntroCard,
                                      leading: CoconutLayout.spacing_400h,
                                    ),
                                    CoconutLayout.spacing_400h,
                                    WalletAdditionGuideCard(onPressed: _onAddWalletPressed),
                                  ],
                                ],
                              ),
                            ),
                          if (shouldShowLoadingIndicator && walletItem.isEmpty) ...[
                            // 처음 로딩시 스켈레톤
                            _buildBodySkeleton(),
                          ],
                          if (walletItem.isNotEmpty) ...[
                            // 지갑 리스트가 비어있지 않을 때

                            // 전체보기 위젯
                            _buildViewAllWallets(
                              walletItem.length,
                              shouldShowOpenStoreIntroCard,
                              openStoreFeatureStatusLabel,
                            ),

                            if (favoriteWallets.isNotEmpty)
                              // 즐겨찾기된 지갑 목록
                              _buildFavoriteWalletList(
                                walletItem,
                                favoriteWallets,
                                walletBalanceMap,
                                balanceVisibilityData.item1,
                                (id) => viewModel.getFakeBalance(id),
                              ),
                            if (hasEnabledHomeFeature) ...[
                              SliverToBoxAdapter(
                                child: Column(
                                  children: [
                                    CoconutLayout.spacing_600h,
                                    Divider(thickness: 12, color: context.coconutColors.divider),
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
                leftButtonText: t.close,
                rightButtonText: t.alert.tutorial.btn_view,
                onTapLeft: () {
                  Navigator.of(context).pop();
                },
                onTapRight: () async {
                  launchURL(TUTORIAL_URL, defaultMode: false);
                  Navigator.of(context).pop();
                },
                rightButtonColor: context.coconutColors.success,
              );
            },
          ),
      'open_store': () => openCoconutOpenStoreIntroScreen(context),
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

  Widget _buildBackupUpdateNotice(WalletHomeViewModel viewModel, List<WalletItemBase> walletItems) {
    final unacknowledgedWalletIds = viewModel.walletIdsWithUnacknowledgedOlderToAfterBackupUpdate;
    final pendingWallet =
        walletItems
            .where(
              (item) => unacknowledgedWalletIds.contains(item.id) && !_dismissedBackupUpdateWalletIds.contains(item.id),
            )
            .firstOrNull;
    final wallet = pendingWallet;
    if (wallet == null) return const SliverToBoxAdapter(child: SizedBox.shrink());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: NoticeCard(
          title: t.wallet_home_screen.backup_update_notice.title,
          description: t.wallet_home_screen.backup_update_notice.description,
          actionLabel: t.wallet_home_screen.backup_update_notice_action,
          onDismiss: () {
            setState(() {
              _dismissedBackupUpdateWalletIds.addAll(_initialBackupUpdateWalletIds ?? {wallet.id});
            });
          },
          onDetails: () {
            Navigator.pushNamed(
              context,
              '/wallet-info',
              arguments: {
                'id': wallet.id,
                'walletType': wallet.walletType,
                'entryPoint': kEntryPointWalletHome,
                'showMfpInput': false,
              },
            );
          },
        ),
      ),
    );
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
              padding: const EdgeInsets.only(left: _horizontalPadding, top: 5),
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
              padding: const EdgeInsets.only(left: _horizontalPadding, right: _horizontalPadding, bottom: 20),
              child: _buildHeaderActions(isActive: false),
            ),
            Divider(thickness: 12, color: context.coconutColors.divider),
          ],
        ),
      );
    }
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 4, bottom: 20, left: _horizontalPadding, right: _horizontalPadding),
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
                          return SizedBox(
                            height: _fiatPriceSlotHeight,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Visibility(
                                maintainSize: true,
                                maintainAnimation: true,
                                maintainState: true,
                                visible: !isFiatBalanceHidden,
                                child: FiatPrice(
                                  satoshiAmount: balance,
                                  textStyle: CoconutTypography.body3_12_Number.setColor(
                                    context.coconutColors.tertiaryText,
                                  ),
                                ),
                              ),
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
                                            .setColor(context.coconutColors.mutedText)
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
                          defaultColor: context.coconutColors.homeSurface,
                          pressedOverlayColor: context.coconutColors.homeSurfacePressOverlay,
                          pressedOverlayOpacity: context.coconutColors.homeSurfacePressOverlayOpacity,
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
          Divider(thickness: 12, color: context.coconutColors.divider),
        ],
      ),
    );
  }

  Widget _buildBodySkeleton() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
        child: Column(
          children: [
            CoconutLayout.spacing_500h,
            Shimmer.fromColors(
              baseColor: context.coconutColors.surfaceSkeletonBase,
              highlightColor: context.coconutColors.surfaceSkeletonHighlight,
              child: Container(
                width: MediaQuery.sizeOf(context).width,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: context.coconutColors.surfaceSkeletonBase,
                  borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
                ),
                child: Text('', style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText)),
              ),
            ),
            CoconutLayout.spacing_300h,
            Shimmer.fromColors(
              baseColor: context.coconutColors.surfaceSkeletonBase,
              highlightColor: context.coconutColors.surfaceSkeletonHighlight,
              child: Container(
                decoration: BoxDecoration(
                  color: context.coconutColors.surfaceSkeletonBase,
                  borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
                ),
                width: MediaQuery.sizeOf(context).width,
                height: 200,
              ),
            ),
          ],
        ),
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
                        defaultColor: context.coconutColors.homeSurface,
                        pressedOverlayColor: context.coconutColors.homeSurfacePressOverlay,
                        pressedOverlayOpacity: context.coconutColors.homeSurfacePressOverlayOpacity,
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
                          color: context.coconutColors.homeSurface,
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
                        defaultColor: context.coconutColors.homeSurface,
                        pressedOverlayColor: context.coconutColors.homeSurfacePressOverlay,
                        pressedOverlayOpacity: context.coconutColors.homeSurfacePressOverlayOpacity,
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
                          color: context.coconutColors.homeSurface,
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
        iconPath: CommonStateIconPath.circleInfo,
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

  Widget _buildViewAllWallets(int walletCount, bool showOpenStoreIntroCard, String? openStoreFeatureStatusLabel) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          CoconutLayout.spacing_500h,
          _buildOpenStoreIntroCard(visible: showOpenStoreIntroCard, trailing: const SizedBox(height: 12)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
            child: ShrinkAnimationButton(
              defaultColor: context.coconutColors.homeSurface,
              pressedOverlayColor: context.coconutColors.homeSurfacePressOverlay,
              pressedOverlayOpacity: context.coconutColors.homeSurfacePressOverlayOpacity,
              onPressed: () {
                Navigator.pushNamed(context, '/wallet-list');
              },
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
                    Row(
                      children: [
                        CoconutLayout.spacing_200w,
                        Text(
                          t.wallet_list.wallet_count(count: walletCount),
                          style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText),
                        ),
                        CoconutLayout.spacing_200w,
                        SvgPicture.asset(
                          CommonNavigationIconPath.arrowRight,
                          width: 6,
                          height: 10,
                          colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
                        ),
                      ],
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

  Widget _buildOpenStoreIntroCard({required bool visible, Widget? leading, Widget? trailing}) {
    const duration = Duration(milliseconds: 500);
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: visible ? 1 : 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedOpacity(
              duration: duration,
              curve: Curves.easeOut,
              opacity: visible ? 1 : 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
                child: Column(
                  children: [
                    if (leading != null) leading,
                    CoconutOpenStoreIntroCard(
                      intro: CcosOpenStoreContentSource.intro,
                      onTap: () => openCoconutOpenStoreIntroScreen(context),
                      onDismiss: () => _handleDismissOpenStoreIntroCard(context),
                    ),
                    if (trailing != null) trailing,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleDismissOpenStoreIntroCard(BuildContext context) async {
    await context.read<PreferenceProvider>().hideOpenStoreIntroCardForOneMonth();
    if (!context.mounted) return;
    CoconutToast.showToast(
      context: context,
      text: t.ccos.intro_card.dismissed_toast,
      isVisibleIcon: true,
      iconPath: CommonStateIconPath.circleInfo,
      seconds: 5,
    );
  }

  Widget _buildFavoriteWalletList(
    List<WalletItemBase> walletList,
    List<WalletItemBase> favoriteWalletList,
    Map<int, AnimatedBalanceData> walletBalanceMap,
    bool isBalanceHidden,
    FakeBalanceGetter getFakeBalance,
  ) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(top: 12, left: _horizontalPadding, right: _horizontalPadding),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: context.coconutColors.homeSurface),
        child: Column(
          children: List.generate(walletList.length, (index) {
            final wallet = walletList[index];
            final isFavorite = favoriteWalletList.any((w) => w.id == wallet.id);

            if (isFavorite) {
              return _buildWalletItem(
                wallet,
                kAlwaysCompleteAnimation,
                walletBalanceMap[wallet.id] ?? AnimatedBalanceData(0, 0),
                getFakeBalance(wallet.id),
                index == walletList.length - 1,
                context.coconutColors.homeSurface,
              );
            } else {
              return Container();
            }
          }),
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
        return WalletItemCard(
          key: key,
          walletItem: walletItem,
          animatedBalanceData: animatedBalanceData,
          isLastItem: isLastItem,
          isBalanceHidden: isBalanceHidden,
          fakeBalance: fakeBalance,
          currentUnit: currentUnit,
          backgroundColor: backgroundColor,
          pressedOverlayColor: context.coconutColors.homeSurfacePressOverlay,
          pressedOverlayOpacity: context.coconutColors.homeSurfacePressOverlayOpacity,
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/wallet-detail',
              arguments: {'id': walletItem.id, 'entryPoint': kEntryPointWalletHome},
            );
          },
          rightWidget: SvgPicture.asset(
            CommonNavigationIconPath.arrowRight,
            width: 6,
            height: 10,
            colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
          ),
        );
      },
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
              iconPath: FeatureSettingsIconPath.settings,
              onSelected: _navigateToWalletHomeEdit,
            ),
            LongPressedMenuItem(
              title: t.long_pressed_menu.edit_home_widget,
              iconPath: FeatureSettingsIconPath.widget,
              onSelected: () {
                _viewModel.setEditWidgetMode(true);
              },
            ),
          ],
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding + _sectionLabelExtraPadding),
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
                          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
                          child: _buildEmptyRecentTransactions(
                            (_viewModel.shouldShowLoadingIndicator && _viewModel.walletItemList.isNotEmpty) ||
                                showRecentInitialLoading,
                          ),
                        );
                      }

                      final screenWidth = MediaQuery.sizeOf(context).width;
                      final carouselViewportFraction = 1 - (2 * _horizontalPadding / screenWidth);

                      if (ordered.length == 1) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
                          child: _buildRecentTransactionCard(ordered.first.item1, ordered.first.item2, currentUnit),
                        );
                      }

                      if (_recentTxCardHeight == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) => _measureRecentTxCardHeightIfNeeded());
                      }

                      return Stack(
                        children: [
                          if (_recentTxCardHeight == null)
                            Offstage(
                              offstage: true,
                              child: Padding(
                                key: _recentTxCardMeasureKey,
                                padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
                                child: _buildRecentTransactionCard(
                                  ordered.first.item1,
                                  ordered.first.item2,
                                  currentUnit,
                                ),
                              ),
                            ),
                          CarouselSlider(
                            carouselController: _carouselController,
                            options: CarouselOptions(
                              autoPlay: false,
                              height: _recentTxCardHeight ?? 90,
                              viewportFraction: carouselViewportFraction,
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
                          ),
                        ],
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
                    margin: const EdgeInsets.only(top: 12, left: 50, right: 50),
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
    const padding = 20.0;

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
        _ => context.coconutColors.iconPrimary,
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
                      width: 30, // wallet item card와 동일한 사이즈로 맞춰 정렬
                      height: 30,
                      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    ),
                  ),
                  CoconutLayout.spacing_200w, // wallet item card와 동일한 사이즈로 맞춰 정렬
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
        padding: const EdgeInsets.all(padding),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.coconutColors.homeSurface),
          color: context.coconutColors.homeSurface,
        ),
        child: buildTxRow(transaction),
      );
    }

    return ShrinkAnimationButton(
      borderRadius: CoconutStyles.radius_200,
      defaultColor: context.coconutColors.homeSurface,
      pressedOverlayColor: context.coconutColors.homeSurfacePressOverlay,
      onPressed: () {
        Navigator.pushNamed(
          context,
          '/transaction-detail',
          arguments: {'id': walletId, 'txHash': transaction.transactionHash},
        );
      },
      child: Container(padding: const EdgeInsets.all(padding), child: buildTxRow(transaction)),
    );
  }

  Widget _buildRecentTransactionsSkeleton() {
    return Container(
      margin: const EdgeInsets.only(top: 12, left: _horizontalPadding, right: _horizontalPadding),
      child: Shimmer.fromColors(
        baseColor: context.coconutColors.surfaceSkeletonBase,
        highlightColor: context.coconutColors.surfaceSkeletonHighlight,
        child: Container(
          width: MediaQuery.sizeOf(context).width,
          height: 90,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
            color: context.coconutColors.homeSurface,
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
      padding: const EdgeInsets.only(left: _horizontalPadding, right: _horizontalPadding, top: 28, bottom: 28),
      decoration: BoxDecoration(
        color: context.coconutColors.homeSurface,
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
                    SvgPicture.asset(
                      CommonStateIconPath.searchNotFound,
                      width: 16,
                      height: 16,
                      colorFilter: ColorFilter.mode(textColor, BlendMode.srcIn),
                    ),
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
              iconPath: FeatureSettingsIconPath.settings,
              onSelected: _navigateToWalletHomeEdit,
            ),
            LongPressedMenuItem(
              title: t.long_pressed_menu.edit_home_widget,
              iconPath: FeatureSettingsIconPath.widget,
              onSelected: () {
                _viewModel.setEditWidgetMode(true);
              },
            ),
          ],
          child: Container(
            margin: const EdgeInsets.only(top: 0, left: _horizontalPadding, right: _horizontalPadding),
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
                      color: context.coconutColors.homeSurface,
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
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: context.coconutColors.homeSurface,
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
    final iconColor = context.coconutColors.iconSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _sectionLabelExtraPadding, vertical: 8),
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
                : t.wallet_home_screen.analysis_period_custom(
                  transaction_type: _viewModel.selectedAnalysisTransactionTypeName,
                ),
            style: CoconutTypography.body3_12.setColor(textColor),
          ),
          CoconutLayout.spacing_150w,
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: SvgPicture.asset(
              CommonNavigationIconPath.caretDown,
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
          return FeatureTransactionIconPath.txReceived;
        case TransactionType.sent:
          return FeatureTransactionIconPath.txSent;
        case TransactionType.self:
          return FeatureTransactionIconPath.txSelf;
        default:
          return FeatureTransactionIconPath.txReceived;
      }
    }

    final bool isReceived = type == TransactionType.received;
    final String formattedAmount = currentUnit.formatAmountWithSign(amount, isPositive: isReceived);
    final iconColor = switch (type) {
      TransactionType.sent => context.coconutColors.sendingColor,
      TransactionType.received => context.coconutColors.receivingColor,
      _ => context.coconutColors.iconPrimary,
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
                width: 30,
                height: 30,
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
      margin: const EdgeInsets.only(top: 36, left: _horizontalPadding, right: _horizontalPadding),
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
                    CommonNavigationIconPath.caretDown,
                    colorFilter: ColorFilter.mode(context.coconutColors.iconSecondary, BlendMode.srcIn),
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
    context.read<AnalyticsService>().logWalletAddScreenEntered(walletImportSource);
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
    context.read<AnalyticsService>().logWalletAddScreenEntered(WalletImportSource.bitbox02);
    Navigator.pop(context);
    Navigator.pushNamed(context, '/bitbox02-connect', arguments: {'walletImportSource': WalletImportSource.bitbox02});
  }

  void _goToTrezorScreen() {
    context.read<AnalyticsService>().logWalletAddScreenEntered(WalletImportSource.trezor);
    Navigator.pop(context);
    if (Platform.isAndroid) {
      Navigator.pushNamed(context, '/trezor-transport-select');
    } else {
      Navigator.pushNamed(context, '/trezor-ble-connect', arguments: {'walletImportSource': WalletImportSource.trezor});
    }
  }

  void _onAddWalletPressed() {
    final topSheetWalletOptions = [
      WalletImportSource.coconutVault,
      WalletImportSource.keystone,
      WalletImportSource.seedSigner,
      WalletImportSource.jade,
      WalletImportSource.coldCard,
      WalletImportSource.krux,
      WalletImportSource.passport,
      WalletImportSource.trezor,
      WalletImportSource.bitbox02,
    ];

    context.read<AnalyticsService>().logWalletAddButtonClicked();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dismiss",
      barrierColor: context.coconutColors.surface.withValues(alpha: 0.5),
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
                child: Container(
                  decoration: BoxDecoration(
                    color: context.coconutColors.homeBackground,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                    boxShadow: [
                      BoxShadow(
                        color: context.coconutColors.shadowDefault,
                        blurRadius: 12,
                        spreadRadius: 0,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: topSheetWalletOptions.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 0,
                            crossAxisSpacing: 0,
                            childAspectRatio: 1.2,
                          ),
                          itemBuilder: (context, index) {
                            if (index >= topSheetWalletOptions.length) {
                              return const SizedBox.expand();
                            }

                            final scanType = topSheetWalletOptions[index];
                            final onPressed =
                                scanType == WalletImportSource.bitbox02
                                    ? _goToBitBox02Screen
                                    : scanType == WalletImportSource.trezor
                                    ? _goToTrezorScreen
                                    : () => _goToScannerScreen(scanType);

                            return _buildWalletIconShrinkButton(onPressed, scanType);
                          },
                        ),
                        CoconutLayout.spacing_200h,
                        Row(
                          children: [
                            Expanded(
                              child: _buildWalletIconShrinkButton(
                                () => _goToScannerScreen(WalletImportSource.extendedPublicKey),
                                WalletImportSource.extendedPublicKey,
                                isWide: true,
                              ),
                            ),
                          ],
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
                            // TODO: light 모드에서 iconButtonHighlight가 회색임....
                            highlightColor: context.coconutColors.iconButtonHighlight,
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                            icon: SvgPicture.asset(
                              CommonActionIconPath.closeBold,
                              colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
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

  SliverAppBar _buildAppBar(NetworkStatus networkStatus) {
    final shouldShow = networkStatus != NetworkStatus.online;

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
      leadingSvgAsset: Transform.translate(
        // HACK: 임시 오프셋
        // CDS 내 buildHomeAppbar 좌우 padding 16, leading widget에 자체 horizontal padding 8
        // CDS에서 leadingPadding 또는 appBarInnerMargin을 받도록 수정하는 것이 구조적 해결이지만
        // OTransform.translate으로 앱 내에서 해결함.
        offset: const Offset(-8, 2),
        child: AnimatedSwitcher(
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
                      SvgPicture.asset(FeatureConnectivityIconPath.cloudDisconnected, width: 16),
                      CoconutLayout.spacing_150w,
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
      ),
      appTitle: '',
      actionButtonList: [
        // 보기 전용 지갑 추가하기
        _buildAppBarIconButton(
          key: GlobalKey(),
          icon: SvgPicture.asset(
            FeatureWalletIconPath.walletEyes,
            colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
          ),
          onPressed: () {
            _onAddWalletPressed();
          },
        ),
        // 더보기(풀다운 메뉴 열림)
        _buildAppBarIconButton(
          key: _dropdownButtonKey,
          icon: SvgPicture.asset(
            CommonMenuIconPath.kebab,
            colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
          ),
          onPressed: () {
            _setDropdownMenuVisiblility(true);
          },
        ),
      ],
    );
  }

  Widget _buildAppBarIconButton({required Widget icon, required VoidCallback onPressed, Key? key}) {
    return CoconutAppBarActionButton(
      buttonKey: key,
      icon: icon,
      onPressed: onPressed,
      color: context.coconutColors.iconPrimary,
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
                    child: InlineLoadingIndicator(),
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
              shadowColor: context.coconutColors.shadowDefault,
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
                CoconutPulldownMenuItem(title: t.ccos.menu_item_title),
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
    if (selectedText == t.utility.p2p_calculator.calculator) {
      return 'p2p_calculator';
    }
    if (selectedText == t.mnemonic_wordlist) return 'mnemonic_wordlist';
    if (selectedText == t.tutorial) return 'tutorial';
    if (selectedText == t.ccos.menu_item_title) return 'open_store';
    if (selectedText == t.home_screen_settings) return 'home_screen_settings';
    if (selectedText == t.app_settings) return 'app_settings';
    return '';
  }

  Widget _buildWalletIconShrinkButton(VoidCallback onPressed, WalletImportSource scanType, {bool isWide = false}) {
    return ShrinkAnimationButton(
      // top sheet의 background 색상과 동일하게 homeBackground로 지정
      defaultColor: context.coconutColors.homeBackground,
      pressedOverlayColor: context.coconutColors.homeSurfacePressOverlay,
      pressedOverlayOpacity: context.coconutColors.homeSurfacePressOverlayOpacity,
      onPressed: () => onPressed(),
      borderRadius: isWide ? 12 : 24,
      child:
          isWide
              ? Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: context.coconutColors.border.withAlpha(60)),
                        borderRadius: const BorderRadius.all(Radius.circular(6.0)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: SvgPicture.asset(
                          scanType.externalWalletIconPath,
                          width: 20,
                          height: 20,
                          colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
                        ),
                      ),
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
                padding: const EdgeInsets.all(8),
                child: SizedBox.expand(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        scanType.externalWalletIconPath,
                        colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
                      ),
                      CoconutLayout.spacing_100h,
                      Text(
                        scanType.displayName,
                        style: CoconutTypography.body2_14.setColor(context.coconutColors.primaryText),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
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
