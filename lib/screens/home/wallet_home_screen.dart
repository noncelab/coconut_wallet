import 'dart:async';
import 'dart:io';

import 'package:carousel_slider/carousel_slider.dart';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/preference/home_feature.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/screens/home/analysis_period_bottom_sheet.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/visibility_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_home_edit_bottom_sheet.dart';
import 'package:coconut_wallet/screens/home/wallet_list_user_experience_survey_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_receive_address_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info_screen.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/uri_launcher.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/card/wallet_list_add_guide_card.dart';
import 'package:coconut_wallet/widgets/contents/fiat_price.dart';
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
import 'package:coconut_wallet/providers/view_model/home/wallet_home_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/settings_screen.dart';
import 'package:coconut_wallet/widgets/card/wallet_item_card.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/screens/home/wallet_list_glossary_bottom_sheet.dart';
import 'package:shimmer/shimmer.dart';
import 'package:tuple/tuple.dart';
import 'package:collection/collection.dart';

class WalletHomeScreen extends StatefulWidget {
  const WalletHomeScreen({super.key});

  @override
  State<WalletHomeScreen> createState() => _WalletHomeScreenState();
}

class _WalletHomeScreenState extends State<WalletHomeScreen> with TickerProviderStateMixin {
  final GlobalKey _dropdownButtonKey = GlobalKey();
  Size _dropdownButtonSize = const Size(0, 0);
  Offset _dropdownButtonPosition = Offset.zero;
  bool _isDropdownMenuVisible = false;
  late ScrollController _scrollController;
  late CarouselSliderController _carouselController;

  DateTime? _lastPressedAt;
  ResultOfSyncFromVault? _resultOfSyncFromVault;

  late List<WalletListItemBase> _previousWalletList = [];
  final GlobalKey<SliverAnimatedListState> _walletListKey = GlobalKey<SliverAnimatedListState>();
  final Duration _duration = const Duration(milliseconds: 1200);

  double? itemCardWidth;
  double? itemCardHeight;
  late WalletHomeViewModel _viewModel;
  late final List<Future<Object?> Function()> _dropdownActions;

  bool _isFirstLoad = true;
  bool _isWalletListLoading = false;

  int _recentTransactionCurrentPage = 0;
  late ScrollController _pageIndicatorController;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider4<WalletProvider, PreferenceProvider, VisibilityProvider,
        ConnectivityProvider, WalletHomeViewModel>(
      create: (_) => _createViewModel(),
      update: (BuildContext context,
          WalletProvider walletProvider,
          PreferenceProvider preferenceProvider,
          VisibilityProvider visibilityProvider,
          ConnectivityProvider connectivityProvider,
          WalletHomeViewModel? previous) {
        previous ??= _createViewModel();

        previous.onPreferenceProviderUpdated();

        if (previous.isNetworkOn != connectivityProvider.isNetworkOn) {
          previous.updateIsNetworkOn(connectivityProvider.isNetworkOn);
        }

        // FIXME: 다른 provider의 변경에 의해서도 항상 호출됨
        return previous..onWalletProviderUpdated(walletProvider);
      },
      child: Selector<
          WalletHomeViewModel,
          Tuple7<List<WalletListItemBase>, List<WalletListItemBase>, bool, bool,
              Map<int, AnimatedBalanceData>, List<HomeFeature>, Tuple2<int?, Map<int, dynamic>>>>(
        selector: (_, vm) => Tuple7(
          vm.walletItemList,
          vm.favoriteWallets,
          vm.isBalanceHidden,
          vm.shouldShowLoadingIndicator,
          vm.walletBalanceMap,
          vm.homeFeatures,
          Tuple2(vm.fakeBalanceTotalAmount, vm.fakeBalanceMap),
        ),
        builder: (context, data, child) {
          final viewModel = Provider.of<WalletHomeViewModel>(context, listen: false);

          final walletItem = data.item1;
          final favoriteWallets = data.item2;
          final isBalanceHidden = data.item3;
          final shouldShowLoadingIndicator = data.item4;
          final walletBalanceMap = data.item5;
          final homeFeatures = data.item6;

          if (viewModel.isWalletListChanged(_previousWalletList, walletItem, walletBalanceMap)) {
            _handleWalletListUpdate(walletItem);
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
                      semanticChildCount: walletItem.length,
                      slivers: <Widget>[
                        _buildAppBar(viewModel),
                        // pull to refresh시 로딩 인디케이터를 보이기 위함
                        CupertinoSliverRefreshControl(
                          onRefresh: viewModel.updateWalletBalancesAndRecentTxs,
                        ),
                        _buildLoadingIndicator(viewModel),
                        _buildHeader(isBalanceHidden, viewModel.getFakeTotalBalance(),
                            shouldShowLoadingIndicator, viewModel.walletItemList.isEmpty),
                        if (!shouldShowLoadingIndicator)
                          SliverToBoxAdapter(
                              child: Column(
                            children: [
                              if (walletItem.isEmpty) ...[
                                CoconutLayout.spacing_600h,
                                WalletAdditionGuideCard(onPressed: _onAddWalletPressed)
                              ]
                            ],
                          )),
                        if (shouldShowLoadingIndicator && walletItem.isEmpty) ...[
                          // 처음 로딩시 스켈레톤
                          _buildBodySkeleton(),
                        ],
                        if (walletItem.isNotEmpty) ...[
                          // 지갑 리스트가 비어있지 않을 때

                          // 전체보기 위젯
                          _buildViewAll(walletItem.length),

                          if (favoriteWallets.isNotEmpty)
                            // 즐겨찾기된 지갑 목록
                            _buildWalletList(
                              walletItem,
                              favoriteWallets,
                              walletBalanceMap,
                              isBalanceHidden,
                              (id) => viewModel.getFakeBalance(id),
                            ),
                          if (homeFeatures.isNotEmpty) ...[
                            // 최근 트랜잭션 섹션: 로딩 중이면 스켈레톤, 아니면 컨텐츠
                            buildFeatureSectionIfEnabled(
                              HomeFeatureType.recentTransaction,
                              () => viewModel.isFetchingLatestTx
                                  ? _buildRecentTransactionsSkeleton()
                                  : _buildRecentTransactions(),
                            ),
                            // 분석 섹션: 로딩 중이면 스켈레톤, 아니면 컨텐츠
                            buildFeatureSectionIfEnabled(
                              HomeFeatureType.analysis,
                              () => viewModel.isLatestTxAnalysisRunning
                                  ? _buildAnalysisSkeleton()
                                  : _buildAnalysis(),
                            ),
                          ],
                        ],
                        if (walletItem.isNotEmpty) _buildHomeEditButton(),
                      ],
                    ),
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

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();
    _carouselController = CarouselSliderController();
    _pageIndicatorController = ScrollController();

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
    _pageIndicatorController.dispose();
    super.dispose();
  }

  WalletHomeViewModel _createViewModel() {
    _viewModel = WalletHomeViewModel(
      Provider.of<WalletProvider>(context, listen: false),
      Provider.of<PreferenceProvider>(context, listen: false),
      Provider.of<VisibilityProvider>(context, listen: false),
      Provider.of<ConnectivityProvider>(context, listen: false),
      Provider.of<NodeProvider>(context, listen: false).syncStateStream,
      Provider.of<NodeProvider>(context, listen: false).currentBlockStream,
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
        _viewModel.updateWalletBalancesAndRecentTxs();
      });
    } finally {
      _isWalletListLoading = false;
    }
  }

  Widget _buildHeader(bool isBalanceHidden, int? fakeBalanceTotalAmount,
      bool shouldShowLoadingIndicator, bool isWalletListEmpty) {
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
                  Text(
                    '',
                    style: CoconutTypography.body3_12_Bold.setColor(CoconutColors.gray350),
                  ),
                  Shimmer.fromColors(
                    baseColor: CoconutColors.gray800,
                    highlightColor: CoconutColors.gray750,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(CoconutStyles.radius_100),
                        color: CoconutColors.gray800,
                      ),
                      child: Text(
                        '0.0000 0000 BTC',
                        style: CoconutTypography.heading3_21_NumberBold,
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
            const Divider(
              thickness: 12,
              color: CoconutColors.gray900,
            ),
          ],
        ),
      );
    }
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 5, bottom: 20, left: 20, right: 20),
            color: CoconutColors.black,
            child: Column(
              children: [
                Visibility(
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  visible: (!isBalanceHidden || _viewModel.fakeBalanceTotalAmount != null) &&
                      _viewModel.walletItemList.isNotEmpty,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Selector<WalletHomeViewModel, List<int>>(
                        selector: (_, viewModel) => viewModel.excludedFromTotalBalanceWalletIds,
                        builder: (context, excludedIds, child) {
                          final balance = _viewModel.fakeBalanceTotalAmount != null
                              ? _viewModel.fakeBalanceTotalAmount!
                              : Map.fromEntries(
                                  _viewModel.walletBalanceMap.entries.where(
                                    (entry) => !excludedIds.contains(entry.key),
                                  ),
                                )
                                  .values
                                  .map((e) => e.current)
                                  .fold(0, (current, element) => current + element);
                          return FiatPrice(
                            satoshiAmount: balance,
                            textStyle:
                                CoconutTypography.body3_12_Number.setColor(CoconutColors.gray350),
                          );
                        },
                      )
                    ],
                  ),
                ),
                Selector<PreferenceProvider, bool>(
                  selector: (_, viewModel) => viewModel.isBtcUnit,
                  builder: (context, isBtcUnit, child) {
                    return Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                children: [
                                  isBalanceHidden
                                      ? fakeBalanceTotalAmount != null
                                          ? Text(
                                              isBtcUnit
                                                  ? BitcoinUnit.btc.displayBitcoinAmount(
                                                      fakeBalanceTotalAmount.toInt())
                                                  : BitcoinUnit.sats.displayBitcoinAmount(
                                                      fakeBalanceTotalAmount.toInt()),
                                              style: CoconutTypography.heading3_21_NumberBold
                                                  .copyWith(height: 1.2),
                                            )
                                          : Text(
                                              t.view_balance,
                                              style: CoconutTypography.heading3_21_NumberBold
                                                  .setColor(
                                                    CoconutColors.gray600,
                                                  )
                                                  .copyWith(height: 1.2),
                                            )
                                      : Selector<WalletHomeViewModel, List<int>>(
                                          selector: (_, viewModel) =>
                                              viewModel.excludedFromTotalBalanceWalletIds,
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
                                            return FittedBox(
                                              child: AnimatedBalance(
                                                prevValue: prevValue,
                                                value: currentValue,
                                                currentUnit:
                                                    isBtcUnit ? BitcoinUnit.btc : BitcoinUnit.sats,
                                                textStyle: CoconutTypography.heading3_21_NumberBold
                                                    .copyWith(height: 1.2),
                                              ),
                                            );
                                          },
                                        ),
                                  const SizedBox(width: 4.0),
                                  if (!isBalanceHidden || fakeBalanceTotalAmount != null)
                                    Text(
                                      isBtcUnit ? t.btc : t.sats,
                                      style: CoconutTypography.heading3_21_NumberBold
                                          .copyWith(height: 1.2),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        ShrinkAnimationButton(
                          borderRadius: CoconutStyles.radius_100,
                          defaultColor: CoconutColors.gray800,
                          pressedColor: CoconutColors.gray750,
                          onPressed: () {
                            if (fakeBalanceTotalAmount != null) {
                              _viewModel.clearFakeBlanceTotalAmount();
                              _viewModel.setIsBalanceHidden(true);
                              return;
                            }
                            _viewModel.setIsBalanceHidden(!isBalanceHidden);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: Text(
                              _viewModel.isBalanceHidden && fakeBalanceTotalAmount == null
                                  ? t.show
                                  : t.hide,
                              style: CoconutTypography.body3_12,
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
          const Divider(
            thickness: 12,
            color: CoconutColors.gray900,
          ),
        ],
      ),
    );
  }

  Widget _buildBodySkeleton() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            CoconutLayout.spacing_500h,
            Shimmer.fromColors(
              baseColor: CoconutColors.gray800,
              highlightColor: CoconutColors.gray750,
              child: Container(
                width: MediaQuery.sizeOf(context).width,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: CoconutColors.gray800,
                  borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
                ),
                child: const Text(
                  '',
                  style: CoconutTypography.body2_14,
                ),
              ),
            ),
            CoconutLayout.spacing_300h,
            Shimmer.fromColors(
              baseColor: CoconutColors.gray800,
              highlightColor: CoconutColors.gray750,
              child: Container(
                decoration: BoxDecoration(
                  color: CoconutColors.gray800,
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
        return Row(
          children: [
            Expanded(
              child: isActive
                  ? ShrinkAnimationButton(
                      onPressed: () {
                        _onTapReceive(walletOrder);
                      },
                      borderRadius: CoconutStyles.radius_100,
                      defaultColor: CoconutColors.gray800,
                      pressedColor: CoconutColors.gray750,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            t.receive,
                            style: CoconutTypography.body2_14,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: CoconutColors.gray800,
                        borderRadius: BorderRadius.circular(CoconutStyles.radius_100),
                      ),
                      child: Center(
                        child: Text(
                          t.receive,
                          style: CoconutTypography.body3_12.setColor(
                            CoconutColors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
            ),
            CoconutLayout.spacing_200w,
            Expanded(
              child: isActive
                  ? ShrinkAnimationButton(
                      onPressed: () {
                        _onTapSend(walletOrder);
                      },
                      borderRadius: CoconutStyles.radius_100,
                      defaultColor: CoconutColors.gray800,
                      pressedColor: CoconutColors.gray750,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            t.send,
                            style: CoconutTypography.body2_14,
                          ),
                        ),
                      ),
                    )
                  : Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: CoconutColors.gray800,
                        borderRadius: BorderRadius.circular(CoconutStyles.radius_100),
                      ),
                      child: Center(
                        child: Text(
                          t.send,
                          style: CoconutTypography.body3_12.setColor(
                            CoconutColors.white.withOpacity(0.3),
                          ),
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
      CoconutToast.showToast(
          isVisibleIcon: true, context: context, text: t.toast.fetching_onchain_data);
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
          text: t.can_use_after_add_wallet);
      return;
    }

    // walletOrder에 있는 순서대로 매칭된 첫 번째 지갑의 id
    final targetId = walletOrder.firstWhere(
      (id) => id == firstWallet.id,
      orElse: () => firstWallet.id,
    );

    _viewModel.setReceiveAddress(targetId);

    CommonBottomSheets.showBottomSheet_90(
      context: context,
      child: ChangeNotifierProvider.value(
        value: _viewModel,
        child: ReceiveAddressBottomSheet(
          id: targetId,
          derivationPath: _viewModel.derivationPath,
          receiveAddress: _viewModel.receiveAddress,
          receiveAddressIndex: _viewModel.receiveAddressIndex,
        ),
      ),
    );
  }

  void _onTapSend(List<int> walletOrder) {
    final firstWallet = _viewModel.walletItemList.firstOrNull;
    if (firstWallet == null) {
      context.read<SendInfoProvider>().clear();
      Navigator.pushNamed(context, '/send', arguments: {'id': null});
      return;
    }

    // walletOrder에 있는 순서대로 매칭된 첫 번째 지갑의 id
    final targetId = walletOrder.firstWhere(
      (id) => id == firstWallet.id,
      orElse: () => firstWallet.id,
    );

    final wallet = _viewModel.getWalletById(targetId);
    if (wallet is! MultisigWalletListItem &&
        (wallet.walletBase as SingleSignatureWallet).keyStore.masterFingerprint ==
            WalletAddService.masterFingerprintPlaceholder) {
      CoconutToast.showToast(
          isVisibleIcon: true,
          context: context,
          text: t.wallet_detail_screen.toast.no_mfp_wallet_cant_send);
      return;
    }

    if (!_checkStateAndShowToast(targetId)) return;
    context.read<SendInfoProvider>().clear();
    Navigator.pushNamed(context, '/send', arguments: {'walletId': targetId});
  }

  Widget _buildHomeEditButton() {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          CoconutLayout.spacing_800h,
          CoconutUnderlinedButton(
            padding: const EdgeInsets.all(8),
            onTap: () => CommonBottomSheets.showBottomSheet_100(
                context: context,
                isScrollControlled: true,
                // controller: _draggableController,
                isDismissible: false,
                enableDrag: true,
                child: const WalletHomeEditBottomSheet()),
            text: t.wallet_home_screen.edit_home_screen,
            textStyle: CoconutTypography.body3_12,
          ),
          CoconutLayout.spacing_1600h,
        ],
      ),
    );
  }

  Widget _buildViewAll(int walletCount) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          CoconutLayout.spacing_500h,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ShrinkAnimationButton(
              defaultColor: CoconutColors.gray800,
              pressedColor: CoconutColors.gray750,
              onPressed: () {
                Navigator.pushNamed(context, '/wallet-list');
              },
              borderRadius: CoconutStyles.radius_200,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t.wallet_home_screen.view_all_wallets,
                      style: CoconutTypography.body2_14,
                    ),
                    Row(
                      children: [
                        Text(
                          t.wallet_list.wallet_count(count: walletCount),
                          style: CoconutTypography.body3_12,
                        ),
                        CoconutLayout.spacing_200w,
                        Padding(
                          padding: const EdgeInsets.only(right: 9),
                          child: SvgPicture.asset(
                            'assets/svg/arrow-right.svg',
                            width: 6,
                            height: 10,
                            colorFilter: const ColorFilter.mode(
                              CoconutColors.gray400,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildWalletList(
    List<WalletListItemBase> walletList,
    List<WalletListItemBase> favoriteWalletList,
    Map<int, AnimatedBalanceData> walletBalanceMap,
    bool isBalanceHidden,
    FakeBalanceGetter getFakeBalance,
  ) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(top: 12, left: 20, right: 20),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: CoconutColors.gray800,
        ),
        child: Column(
          children: List.generate(walletList.length, (index) {
            final wallet = walletList[index];
            final isFavorite = favoriteWalletList.any((w) => w.id == wallet.id);

            if (isFavorite) {
              return _buildWalletItem(
                wallet,
                kAlwaysCompleteAnimation,
                walletBalanceMap[wallet.id] ?? AnimatedBalanceData(0, 0),
                isBalanceHidden,
                getFakeBalance(wallet.id),
                index == walletList.length - 1,
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
      WalletListItemBase wallet,
      Animation<double> animation,
      AnimatedBalanceData animatedBalanceData,
      bool isBalanceHidden,
      int? fakeBalance,
      bool isLastItem) {
    return _getWalletRowItem(
      Key(wallet.id.toString()),
      wallet,
      animatedBalanceData,
      isBalanceHidden,
      fakeBalance,
      isLastItem,
    );
  }

  Widget _getWalletRowItem(
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
            currentUnit: isBtcUnit ? BitcoinUnit.btc : BitcoinUnit.sats,
            entryPoint: kEntryPointWalletHome,
          );
        });
  }

  Widget buildFeatureSectionIfEnabled(
    HomeFeatureType type,
    Widget Function() builder,
  ) {
    final feature = _viewModel.homeFeatures.firstWhereOrNull(
      (f) => f.homeFeatureTypeString == type.name,
    );
    if (feature != null && feature.isEnabled) {
      return builder();
    }

    return SliverToBoxAdapter(child: Container());
  }

  Widget _buildRecentTransactions() {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(
              top: 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: CoconutColors.black,
            ),
            child: Center(
              child: Selector<PreferenceProvider, bool>(
                selector: (_, viewModel) => viewModel.isBtcUnit,
                builder: (context, isBtcUnit, child) {
                  // 정렬된 트랜잭션 플랫 리스트
                  final ordered = _getOrderedRecentTransactions();

                  if (ordered.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildEmptyRecentTransactions(),
                    );
                  }

                  return ordered.length == 1
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildRecentTransactionCard(
                              ordered.first.item1, ordered.first.item2, isBtcUnit),
                        )
                      : CarouselSlider(
                          carouselController: _carouselController,
                          options: CarouselOptions(
                            autoPlay: false,
                            height: 90,
                            viewportFraction: 0.82,
                            enlargeCenterPage: true,
                            enlargeFactor: 0.25,
                            enableInfiniteScroll: false,
                            onPageChanged: (index, reason) {
                              setState(() {
                                _recentTransactionCurrentPage = index;
                              });
                              // 인디케이터 자동 스크롤
                              _scrollToIndicator(index);
                            },
                          ),
                          items: ordered.map((t) {
                            return _buildRecentTransactionCard(t.item1, t.item2, isBtcUnit);
                          }).toList(),
                        );
                },
              ),
            ),
          ),
          // 페이지 인디케이터 (트랜잭션 단위, 2개 이상일 때만 표시)
          Builder(builder: (context) {
            final totalCount = _getOrderedRecentTransactions().length;

            if (totalCount <= 1) return Container();

            return Container(
              margin: const EdgeInsets.only(top: 16, left: 50, right: 50),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                controller: _pageIndicatorController,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(totalCount, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      margin: EdgeInsets.symmetric(
                          horizontal: _recentTransactionCurrentPage == index ? 2 : 4),
                      width: _recentTransactionCurrentPage == index ? 12 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _recentTransactionCurrentPage == index
                            ? CoconutColors.gray400
                            : CoconutColors.gray800,
                      ),
                    );
                  }),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecentTransactionCard(int walletId, TransactionRecord transaction, bool isBtcUnit) {
    final walletName = _viewModel.getWalletById(walletId).name;

    Widget buildTxRow(TransactionRecord transaction) {
      final bool isReceived = transaction.transactionType == TransactionType.received;
      final DateTime txDate = transaction.getDateTimeToDisplay()!.toLocal();
      final List<String> transactionTimeStamp = DateTimeUtil.formatTimestamp(txDate);
      final String amountString = isBtcUnit
          ? BitcoinUnit.btc.displayBitcoinAmount(transaction.amount, withUnit: true)
          : BitcoinUnit.sats.displayBitcoinAmount(transaction.amount, withUnit: true);
      final String prefix = isReceived ? '+' : '';
      final status = TransactionUtil.getStatus(transaction);
      final String iconSource = switch (status) {
        TransactionStatus.received => 'assets/svg/tx-received.svg',
        TransactionStatus.receiving => 'assets/svg/tx-receiving.svg',
        TransactionStatus.sent => 'assets/svg/tx-sent.svg',
        TransactionStatus.sending => 'assets/svg/tx-sending.svg',
        TransactionStatus.self => 'assets/svg/tx-self.svg',
        TransactionStatus.selfsending => 'assets/svg/tx-self-sending.svg',
        _ => 'assets/svg/tx-receiving.svg',
      };

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                iconSource,
                fit: BoxFit.fill,
                width: 24,
                height: 24,
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
                        style: CoconutTypography.body3_12.setColor(
                          CoconutColors.gray400,
                        ),
                      ),
                      CoconutLayout.spacing_50w,
                      Text(
                        '|',
                        style: CoconutTypography.body3_12.setColor(
                          CoconutColors.gray400,
                        ),
                      ),
                      CoconutLayout.spacing_50w,
                      Text(
                        transactionTimeStamp[1],
                        style: CoconutTypography.body3_12.setColor(
                          CoconutColors.gray400,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    walletName,
                    style: CoconutTypography.body3_12.setColor(
                      CoconutColors.gray400,
                    ),
                  ),
                ],
              )
            ],
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                (() {
                  final now = DateTime.now();
                  final diffDays = now.difference(txDate).inDays;
                  return t.relative_time.days_ago(n: diffDays);
                })(),
                style: CoconutTypography.body3_12,
              ),
              Text(
                '$prefix $amountString',
                style: CoconutTypography.body2_14_Number,
              ),
            ],
          )
        ],
      );
    }

    return ShrinkAnimationButton(
      pressedColor: CoconutColors.gray750,
      onPressed: () => Navigator.pushNamed(
        context,
        '/transaction-detail',
        arguments: {
          'id': walletId,
          'txHash': transaction.transactionHash,
        },
      ),
      child: Container(
        padding: const EdgeInsets.only(left: 20, right: 14, top: 20, bottom: 20),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(
            Radius.circular(12),
          ),
        ),
        child: buildTxRow(transaction),
      ),
    );
  }

  Widget _buildRecentTransactionsSkeleton() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(
          top: 12,
          left: 20,
          right: 20,
        ),
        child: Shimmer.fromColors(
          baseColor: CoconutColors.gray800,
          highlightColor: CoconutColors.gray750,
          child: Container(
            width: MediaQuery.sizeOf(context).width,
            height: 90,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
              color: CoconutColors.gray800,
            ),
            child: const Text(
              '',
              style: CoconutTypography.body2_14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyRecentTransactions() {
    return Container(
      padding: const EdgeInsets.only(left: 20, right: 14, top: 20, bottom: 20),
      decoration: const BoxDecoration(
        color: CoconutColors.gray800,
        borderRadius: BorderRadius.all(
          Radius.circular(12),
        ),
      ),
      child: Center(
        child: Text(
          t.wallet_home_screen.empty_recent_transaction,
          style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
        ),
      ),
    );
  }

  // 최근 트랜잭션을 플랫하고 정렬(pending 최신순 → confirmed 최신순)하여 반환
  List<Tuple2<int, TransactionRecord>> _getOrderedRecentTransactions() {
    final flatTxs = _viewModel.recentTransactions.entries
        .expand((entry) => entry.value.map((tx) => Tuple2(entry.key, tx)))
        .toList();

    final pendingStatuses = {
      TransactionStatus.receiving,
      TransactionStatus.sending,
      TransactionStatus.selfsending,
    };
    final confirmedStatuses = {
      TransactionStatus.received,
      TransactionStatus.sent,
      TransactionStatus.self,
    };

    final pending = flatTxs
        .where((t) => pendingStatuses.contains(TransactionUtil.getStatus(t.item2)))
        .toList()
      ..sort((a, b) => b.item2.timestamp.compareTo(a.item2.timestamp));
    final confirmed = flatTxs
        .where((t) => confirmedStatuses.contains(TransactionUtil.getStatus(t.item2)))
        .toList()
      ..sort((a, b) => b.item2.timestamp.compareTo(a.item2.timestamp));

    return [...pending, ...confirmed];
  }

  Widget _buildAnalysis() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(top: 36, left: 20, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShrinkAnimationButton(
              defaultColor: CoconutColors.black,
              onPressed: () {
                CommonBottomSheets.showBottomSheet_50(
                  context: context,
                  child: AnalysisPeriodBottomSheet(
                    onSelected: (days) {
                      _viewModel.setAnalysisPeriod(days);
                    },
                    onTransactionTypeSelected: (analysisTransactionType) {
                      _viewModel.setAnalysisTransactionType(analysisTransactionType);
                    },
                    initialPeriodPreset: _viewModel.analysisPeriod,
                    initialAnalysisTransactionType: _viewModel.selectedAnalysisTransactionType,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _viewModel.analysisPeriod != 0
                          ? t.wallet_home_screen.analysis_period(
                              days: _viewModel.analysisPeriod.toString(),
                              transaction_type: _viewModel.selectedAnalysisTransactionTypeName)
                          : t.wallet_home_screen.analysis_period_cutsom(
                              transaction_type: _viewModel.selectedAnalysisTransactionTypeName),
                      style: CoconutTypography.body3_12.setColor(
                        CoconutColors.gray400,
                      ),
                    ),
                    CoconutLayout.spacing_100w,
                    SvgPicture.asset(
                      'assets/svg/caret-down.svg',
                      colorFilter: const ColorFilter.mode(CoconutColors.gray400, BlendMode.srcIn),
                    ),
                  ],
                ),
              ),
            ),
            if (_viewModel.recentTransactionAnalysis?.isEmpty == true ||
                _viewModel.recentTransactionAnalysis == null) ...[
              // 분석에 필요한 거래가 없을 때
              Container(
                padding: const EdgeInsets.only(left: 20, right: 14, top: 20, bottom: 20),
                decoration: const BoxDecoration(
                  color: CoconutColors.gray800,
                  borderRadius: BorderRadius.all(
                    Radius.circular(12),
                  ),
                ),
                child: Center(
                  child: Text(
                    t.wallet_home_screen.empty_analysis_result,
                    style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                  ),
                ),
              )
            ] else if (_viewModel.recentTransactionAnalysis?.isEmpty == false) ...[
              Selector<PreferenceProvider, bool>(
                  selector: (_, viewModel) => viewModel.isBtcUnit,
                  builder: (context, isBtcUnit, child) {
                    return Container(
                      width: MediaQuery.sizeOf(context).width,
                      padding: const EdgeInsets.only(top: 24, left: 16, right: 20, bottom: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: CoconutColors.gray800,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                _viewModel.recentTransactionAnalysis!.titleString,
                                style: CoconutTypography.body2_14_NumberBold,
                              ),
                              Text(
                                _viewModel.recentTransactionAnalysis!.totalAmountResult,
                                style: CoconutTypography.body2_14,
                              ),
                            ],
                          ),
                          CoconutLayout.spacing_300h,
                          Text(
                            _viewModel.recentTransactionAnalysis!.subtitleString,
                            style: CoconutTypography.body3_12.setColor(
                              CoconutColors.gray400,
                            ),
                          ),
                          if (_viewModel.recentTransactionAnalysis!.receivedTxs.isNotEmpty &&
                              _viewModel.selectedAnalysisTransactionType !=
                                  AnalysisTransactionType.onlySent) ...[
                            _buildAnalysisTransactionRow(
                              'assets/svg/tx-received.svg',
                              _viewModel.recentTransactionAnalysis!.receivedTxs.length,
                              _viewModel.recentTransactionAnalysis!.receivedAmount,
                              TransactionType.received,
                              isBtcUnit,
                            ),
                          ],
                          if (_viewModel.recentTransactionAnalysis!.sentTxs.isNotEmpty &&
                              _viewModel.selectedAnalysisTransactionType !=
                                  AnalysisTransactionType.onlyReceived) ...[
                            _buildAnalysisTransactionRow(
                              'assets/svg/tx-sent.svg',
                              _viewModel.recentTransactionAnalysis!.sentTxs.length,
                              _viewModel.recentTransactionAnalysis!.sentAmount,
                              TransactionType.sent,
                              isBtcUnit,
                            ),
                          ],
                          if (_viewModel.recentTransactionAnalysis!.selfTxs.isNotEmpty &&
                              _viewModel.selectedAnalysisTransactionType !=
                                  AnalysisTransactionType.onlyReceived) ...[
                            _buildAnalysisTransactionRow(
                              'assets/svg/tx-self.svg',
                              _viewModel.recentTransactionAnalysis!.selfTxs.length,
                              _viewModel.recentTransactionAnalysis!.selfAmount,
                              TransactionType.self,
                              isBtcUnit,
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisTransactionRow(
      String assetPath, int count, int amount, TransactionType type, bool isBtcUnit) {
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

    final String amountString = isBtcUnit
        ? BitcoinUnit.btc.displayBitcoinAmount(amount, withUnit: true)
        : BitcoinUnit.sats.displayBitcoinAmount(amount, withUnit: true);
    final bool isReceived = type == TransactionType.received;
    final String prefix = isReceived ? '+' : '';
    return Column(
      children: [
        if (type != TransactionType.self) ...[
          CoconutLayout.spacing_400h,
        ] else ...[
          CoconutLayout.spacing_200h,
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                SvgPicture.asset(getIconPath(), fit: BoxFit.fill, width: 24, height: 24),
                CoconutLayout.spacing_100w,
                Text(
                  t.wallet_home_screen.count(count: count.toString()),
                  style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                ),
              ],
            ),
            if (type == TransactionType.self) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$prefix$amountString', style: CoconutTypography.body2_14_Number),
                  Text(
                    t.fee,
                    style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                  ),
                ],
              ),
            ] else ...[
              Text('$prefix$amountString', style: CoconutTypography.body2_14_Number),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildAnalysisSkeleton() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(top: 36, left: 20, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Shimmer.fromColors(
              baseColor: CoconutColors.gray800,
              highlightColor: CoconutColors.gray750,
              child: Container(
                margin: const EdgeInsets.only(top: 8, left: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
                  color: CoconutColors.gray800,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '최근 30일 • 보내기',
                      style: CoconutTypography.body3_12.setColor(
                        CoconutColors.gray400,
                      ),
                    ),
                    CoconutLayout.spacing_100w,
                    SvgPicture.asset(
                      'assets/svg/caret-down.svg',
                      colorFilter: const ColorFilter.mode(CoconutColors.gray400, BlendMode.srcIn),
                    ),
                  ],
                ),
              ),
            ),
            Shimmer.fromColors(
              baseColor: CoconutColors.gray800,
              highlightColor: CoconutColors.gray750,
              child: Container(
                width: MediaQuery.sizeOf(context).width,
                margin: const EdgeInsets.only(top: 8),
                height: 90,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
                  color: CoconutColors.gray800,
                ),
                child: const Text(
                  '',
                  style: CoconutTypography.body2_14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _goToScannerScreen(WalletImportSource walletImportSource) async {
    Navigator.pop(context);
    final ResultOfSyncFromVault? scanResult =
        (await Navigator.pushNamed(context, '/wallet-add-scanner', arguments: {
      'walletImportSource': walletImportSource,
      'onNewWalletAdded': (scanResult) {
        setState(() {
          _resultOfSyncFromVault = scanResult;
        });
      }
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

  SliverAppBar _buildAppBar(WalletHomeViewModel viewModel) {
    return CoconutAppBar.buildHomeAppbar(
      context: context,
      leadingSvgAsset: (viewModel.isNetworkOn ?? false)
          ? Container()
          : Row(
              children: [
                SvgPicture.asset('assets/svg/cloud-disconnected.svg'),
                CoconutLayout.spacing_100w,
                Text(
                  t.errors.network_disconnected,
                  style: CoconutTypography.body3_12_Bold.setColor(
                    CoconutColors.hotPink,
                  ),
                )
              ],
            ),
      appTitle: '',
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

  Widget _buildLoadingIndicator(WalletHomeViewModel viewModel) {
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
                  CoconutPulldownMenuItem(title: t.glossary),
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
              NetworkType.currentNetworkType.isTestnet ? 2 : 1,
            ],
            onSelected: ((index, selectedText) {
              // 메인넷의 경우 튜토리얼 항목을 넘어간다.
              if (!NetworkType.currentNetworkType.isTestnet && index >= 2) {
                ++index;
              }

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
      pressedColor: CoconutColors.gray750,
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
