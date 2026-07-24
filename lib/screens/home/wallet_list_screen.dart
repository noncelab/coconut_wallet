import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_item_setting_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:coconut_wallet/widgets/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/button/single_button.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/loading_indicator/loading_indicator.dart';
import 'package:coconut_wallet/widgets/overlays/coconut_loading_overlay.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/wallet_balance_history_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_list_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/card/wallet_item_card.dart';
import 'package:tuple/tuple.dart';

class WalletListScreen extends StatefulWidget {
  const WalletListScreen({super.key});

  @override
  State<WalletListScreen> createState() => _WalletListScreenState();
}

class _WalletListScreenState extends State<WalletListScreen> with TickerProviderStateMixin {
  late ScrollController _scrollController;

  double? itemCardWidth;
  double? itemCardHeight;
  late WalletListViewModel _viewModel;
  WalletFilter _walletFilter = WalletFilter.all;
  late List<WalletFilter> _walletFilterOrder;
  late List<WalletFilter> _savedWalletFilterOrder;
  double _walletFilterReorderDragDistance = 0;
  final Map<int, GlobalKey> _walletReorderItemKeys = {};
  final Map<int, double> _walletReorderItemTop = {};
  final Set<int> _movingWalletIds = {};
  final Map<int, int> _walletReorderStableFrameCounts = {};
  Ticker? _walletReorderPositionTicker;
  int? _draggedWalletId;
  late Set<WalletFilter> _savedVisibleWalletFilters;
  late Set<WalletFilter> _tempVisibleWalletFilters;

  bool get _hasWalletFilterVisibilityChanged =>
      !_savedVisibleWalletFilters.containsAll(_tempVisibleWalletFilters) ||
      !_tempVisibleWalletFilters.containsAll(_savedVisibleWalletFilters);
  bool get _hasWalletFilterOrderChanged =>
      _savedWalletFilterOrder.length != _walletFilterOrder.length ||
      List.generate(
        _walletFilterOrder.length,
        (index) => _savedWalletFilterOrder[index] != _walletFilterOrder[index],
      ).any((isDifferent) => isDifferent);

  // bool _isFirstLoad = true;
  // bool _isWalletListLoading = false;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider3<WalletProvider, ConnectivityProvider, PreferenceProvider, WalletListViewModel>(
      create: (_) => _createViewModel(),
      update: (
        BuildContext context,
        WalletProvider walletProvider,
        ConnectivityProvider connectivityProvider,
        PreferenceProvider preferenceProvider,
        WalletListViewModel? previous,
      ) {
        previous ??= _createViewModel();

        if (previous.isNetworkOn != connectivityProvider.isInternetOn) {
          previous.updateIsNetworkOn(connectivityProvider.isInternetOn);
        }

        previous.onPreferenceProviderUpdated();

        // FIXME: 다른 provider의 변경에 의해서도 항상 호출됨
        return previous..onWalletProviderUpdated(walletProvider);
      },
      child: Selector<
        WalletListViewModel,
        Tuple7<List<WalletItemBase>, bool, Map<int, AnimatedBalanceData>, List<int>, List<int>, bool, List<int>>
      >(
        selector:
            (_, vm) => Tuple7(
              vm.walletItemList,
              vm.isNetworkOn ?? false,
              vm.walletBalanceMap,
              vm.favoriteWalletIds,
              vm.tempWalletOrder,
              vm.isEditMode,
              vm.walletOrder,
            ),
        builder: (context, data, child) {
          final viewModel = Provider.of<WalletListViewModel>(context, listen: false);

          final walletListItem = data.item1;
          final filteredWalletList = _filterWalletList(walletListItem);
          final walletBalanceMap = data.item3;
          final isEditMode = data.item6;
          final walletOrder = data.item7;

          // Pin check 로직(편집모드에서 삭제 후 완료 버튼 클릭시 동작)
          if (viewModel.pinCheckNotifier.value == true) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              viewModel.pinCheckNotifier.value = false;
              await CommonBottomSheets.showCustomHeightBottomSheet(
                context: context,
                child: CustomLoadingOverlay(child: PinCheckScreen(onComplete: () => viewModel.handleAuthCompletion())),
                heightRatio: 0.9,
              );
            });
          }

          // 편집모드에서 모든 지갑을 다 삭제했을 때 홈화면으로 자동 전환
          if (walletListItem.isEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.popUntil(context, (route) => route.isFirst);
            });
          }

          return Stack(
            children: [
              PopScope(
                canPop: !isEditMode,
                onPopInvokedWithResult: (didPop, _) {
                  if (!didPop) {
                    Navigator.pop(context);
                  }
                },
                child: Scaffold(
                  backgroundColor: context.coconutColors.background,
                  extendBodyBehindAppBar: true,
                  appBar: _buildAppBar(context),
                  body: SafeArea(
                    child:
                        isEditMode
                            // 편집 모드
                            ? Stack(
                              children: [
                                SizedBox(
                                  height: MediaQuery.sizeOf(context).height,
                                  child: _buildEditableWalletList(walletBalanceMap),
                                ),
                                FixedBottomButton(
                                  onButtonClicked: () async {
                                    final preferenceProvider = context.read<PreferenceProvider>();
                                    final hasWalletChanges = viewModel.hasWalletOrderChanged;
                                    await viewModel.applyTempDatasToWallets();
                                    if (!mounted) return;
                                    await preferenceProvider.setVisibleWalletFilters(_tempVisibleWalletFilters);
                                    await preferenceProvider.setWalletFilterOrder(_walletFilterOrder);
                                    _savedVisibleWalletFilters = _tempVisibleWalletFilters.toSet();
                                    _savedWalletFilterOrder = _walletFilterOrder.toList();
                                    if (!hasWalletChanges) {
                                      viewModel.setEditMode(false);
                                    }
                                  },
                                  isActive:
                                      viewModel.hasWalletOrderChanged ||
                                      _hasWalletFilterVisibilityChanged ||
                                      _hasWalletFilterOrderChanged,
                                  text: t.done,
                                ),
                              ],
                            )
                            // 일반 모드
                            : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Stack(
                                children: [
                                  CustomScrollView(
                                    controller: _scrollController,
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    semanticChildCount: filteredWalletList.length,
                                    slivers: <Widget>[
                                      // pull to refresh시 로딩 인디케이터를 보이기 위함
                                      CupertinoSliverRefreshControl(onRefresh: viewModel.updateWalletBalances),
                                      _buildLoadingIndicator(viewModel),
                                      // _buildPadding(isOffline),
                                      _buildWalletListHeader(walletBalanceMap),
                                      SliverToBoxAdapter(
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                                          child: _buildWalletFilterChips(),
                                        ),
                                      ),
                                      // 지갑 목록
                                      if (filteredWalletList.isEmpty)
                                        _buildEmptyFilteredWalletList()
                                      else
                                        _buildWalletList(filteredWalletList, walletBalanceMap, walletOrder),
                                    ],
                                  ),
                                  // _buildOfflineWarningBar(context, isOffline)
                                ],
                              ),
                            ),
                  ),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: viewModel.loadingNotifier,
                builder: (context, isLoading, _) {
                  return isLoading ? const CoconutLoadingOverlay() : Container();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _scrollController = ScrollController();
    _resetWalletFilterTempState();
  }

  @override
  void dispose() {
    _walletReorderPositionTicker?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  WalletListViewModel _createViewModel() {
    _viewModel = WalletListViewModel(
      Provider.of<WalletProvider>(context, listen: false),
      Provider.of<ConnectivityProvider>(context, listen: false),
      Provider.of<AuthProvider>(context, listen: false),
      Provider.of<NodeProvider>(context, listen: false),
      Provider.of<PreferenceProvider>(context, listen: false),
      Provider.of<PriceProvider>(context, listen: false),
    );
    return _viewModel;
  }

  void onTogglePressed(FiatCode fiat) {
    final visibleFiats = List<FiatCode>.from(_viewModel.visibleFiats);
    if (visibleFiats.contains(fiat)) {
      visibleFiats.remove(fiat);
    } else {
      visibleFiats.add(fiat);
    }
    _viewModel.setVisibleFiats(visibleFiats);
  }

  void _showWalletListSettingsBottomSheet() {
    CommonBottomSheets.showBottomSheet(
      title: t.wallet_list.menu.display_settings,
      showCloseButton: true,
      showDragHandle: true,
      context: context,
      child: ListenableBuilder(
        listenable: _viewModel,
        builder:
            (context, _) => WalletListSettingsBottomSheet(
              viewModel: _viewModel,
              visibleFiats: _viewModel.visibleFiats,
              onTogglePressed: onTogglePressed,
            ),
      ),
    );
  }

  void _enterWalletOrderEditMode() {
    _resetWalletFilterTempState();
    _viewModel.setEditMode(true);
  }

  Widget _buildEditModeHeader() {
    SvgPicture hamburgerIcon = SvgPicture.asset(
      'assets/svg/hamburger.svg',
      width: 16,
      height: 16,
      colorFilter: ColorFilter.mode(context.coconutColors.secondaryText, BlendMode.srcIn),
    );
    SvgPicture tabOrderIcon = SvgPicture.asset(
      'assets/svg/arrow-top-down.svg',
      width: 16,
      height: 16,
      colorFilter: ColorFilter.mode(context.coconutColors.secondaryText, BlendMode.srcIn),
    );
    return Column(
      children: [
        Container(
          width: MediaQuery.sizeOf(context).width,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: context.coconutColors.surfaceCard,
            borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
          ),
          child: Column(
            children: [
              _buildEditModeHeaderLine([
                if (_viewModel.hasEnglishWordOrder) ...[
                  TextSpan(text: '${t.tap} '),
                  WidgetSpan(alignment: PlaceholderAlignment.top, child: hamburgerIcon),
                  const TextSpan(text: ' '),
                  TextSpan(text: t.wallet_list.edit.order_description),
                ] else ...[
                  WidgetSpan(alignment: PlaceholderAlignment.top, child: hamburgerIcon),
                  TextSpan(text: t.wallet_list.edit.order_description),
                ],
              ]),
              CoconutLayout.spacing_100h,
              _buildEditModeHeaderLine([
                if (_viewModel.hasEnglishWordOrder) ...[
                  TextSpan(text: '${t.tap} '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.top,
                    child: RotatedBox(quarterTurns: 1, child: tabOrderIcon),
                  ),
                  const TextSpan(text: ' '),
                  TextSpan(text: t.wallet_list.edit.tab_order_description),
                ] else ...[
                  WidgetSpan(
                    alignment: PlaceholderAlignment.top,
                    child: RotatedBox(quarterTurns: 1, child: tabOrderIcon),
                  ),
                  TextSpan(text: t.wallet_list.edit.tab_order_description),
                ],
              ]),
              CoconutLayout.spacing_100h,
              _buildEditModeHeaderLine([TextSpan(text: t.wallet_list.edit.delete_description)]),
            ],
          ),
        ),
        Padding(padding: const EdgeInsets.all(16), child: _buildWalletFilterChips(isEditMode: true)),
      ],
    );
  }

  Widget _buildEditModeHeaderLine(List<InlineSpan> inlineSpan) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 8.5, horizontal: 6),
          height: 3,
          width: 3,
          decoration: BoxDecoration(color: context.coconutColors.secondaryText, shape: BoxShape.circle),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
              children: inlineSpan,
            ),
            overflow: TextOverflow.visible,
            softWrap: true,
          ),
        ),
      ],
    );
  }

  Widget _buildWalletListHeader(Map<int, AnimatedBalanceData> walletBalanceMap) {
    return SliverToBoxAdapter(
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
          child: Stack(
            children: [
              Container(
                width: MediaQuery.sizeOf(context).width,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                decoration: BoxDecoration(
                  color: context.coconutColors.surfaceCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Selector<PreferenceProvider, Tuple6<BitcoinUnit, List<int>, List<int>, bool, bool, bool>>(
                  selector:
                      (_, viewModel) => Tuple6(
                        viewModel.currentUnit,
                        viewModel.excludedFromTotalBalanceWalletIds,
                        viewModel.favoriteWalletIds,
                        viewModel.isWalletListFiatVisible,
                        viewModel.isWalletListBitcoinPriceVisible,
                        viewModel.isWalletListBalanceChartVisible,
                      ),
                  builder: (context, data, child) {
                    final currentUnit = data.item1;
                    final excludedIds = data.item2;

                    // 전체 총액
                    final totalBalance = walletBalanceMap.values.map((e) => e.current).fold(0, (a, b) => a + b);
                    final prevTotalBalance = walletBalanceMap.values.map((e) => e.previous).fold(0, (a, b) => a + b);

                    // 제외 총액 (제외된 지갑들의 총액)
                    final excludedBalance = walletBalanceMap.entries
                        .where((entry) => excludedIds.contains(entry.key))
                        .map((entry) => entry.value.current)
                        .fold(0, (a, b) => a + b);

                    // 홈 화면 총액
                    final homeBalance = totalBalance - excludedBalance;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 전체 총액
                        _buildTotalAmountSection(currentUnit, prevTotalBalance, totalBalance),
                        // 전체 총액 - Fiat Price
                        _buildFiatPricesSection(totalBalance, homeBalance, excludedBalance, currentUnit, excludedIds),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalAmountSection(BitcoinUnit currentUnit, int prevTotalBalance, int totalBalance) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.wallet_list.header.total_amount,
                    style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText),
                  ),
                  CoconutLayout.spacing_100h,
                  BitcoinAmountUnit(
                    currentUnit: currentUnit,
                    unitStyle: CoconutTypography.heading3_21_NumberBold.setColor(context.coconutColors.primaryText),
                    spacing: CoconutLayout.spacing_100w,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: AnimatedBalance(
                        prevValue: prevTotalBalance,
                        value: totalBalance,
                        currentUnit: currentUnit,
                        textStyle: CoconutTypography.heading3_21_NumberBold.setColor(context.coconutColors.primaryText),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder:
                  (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.85, end: 1).animate(animation),
                      alignment: Alignment.centerRight,
                      child: child,
                    ),
                  ),
              child:
                  _viewModel.isWalletListBalanceChartVisible
                      ? SizedBox(
                        key: const ValueKey('wallet_balance_chart_visible'),
                        width: 116,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              t.wallet_list.header.balance_history,
                              maxLines: 1,
                              style: CoconutTypography.caption_10.setColor(context.coconutColors.mutedText),
                            ),
                            CoconutLayout.spacing_100h,
                            SizedBox(
                              height: 48,
                              width: 116,
                              child: WalletBalanceHistoryChart(
                                points: _viewModel.walletBalanceHistory,
                                revision: _viewModel.walletBalanceHistoryRevision,
                              ),
                            ),
                          ],
                        ),
                      )
                      : const SizedBox.shrink(key: ValueKey('wallet_balance_chart_hidden')),
            ),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder:
              (child, animation) => FadeTransition(
                opacity: animation,
                child: SizeTransition(sizeFactor: animation, axisAlignment: -1, child: child),
              ),
          child:
              _viewModel.isWalletListBitcoinPriceVisible
                  ? Column(
                    key: const ValueKey('bitcoin_price_info_visible'),
                    children: [
                      CoconutLayout.spacing_100h,
                      Row(
                        children: [
                          Text(
                            '1 BTC = ',
                            style: CoconutTypography.body2_14_Number.setColor(context.coconutColors.secondaryText),
                          ),
                          ListenableBuilder(
                            listenable: _viewModel,
                            builder: (context, _) {
                              final oneBtcFiatPrice = _viewModel.getBitcoinPrice(100000000, _viewModel.selectedFiat);
                              return Text(
                                oneBtcFiatPrice.isEmpty ? '-' : oneBtcFiatPrice,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: CoconutTypography.body2_14_Number.setColor(context.coconutColors.secondaryText),
                              );
                            },
                          ),
                          CoconutLayout.spacing_300w,
                          _HistoricalPriceChangeChip(viewModel: _viewModel),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _BitcoinPriceInfoButton(viewModel: _viewModel),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                  : const SizedBox.shrink(key: ValueKey('bitcoin_price_info_hidden')),
        ),
      ],
    );
  }

  Widget _buildFiatPricesSection(
    int totalBalance,
    int homeBalance,
    int excludedBalance,
    BitcoinUnit currentUnit,
    List<int> excludedIds,
  ) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },

      child:
          _viewModel.isWalletListFiatVisible
              ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_viewModel.visibleFiats.isNotEmpty) ...[
                    CoconutLayout.spacing_300h,
                    const Divider(height: 1),
                    CoconutLayout.spacing_300h,
                    Row(
                      children: [
                        Text(
                          t.wallet_list.header.converted_amount,
                          style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryTextStrong),
                        ),
                        const Spacer(),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder:
                              (child, animation) => FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(begin: 0.7, end: 1).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeOutBack,
                                      reverseCurve: Curves.easeInCubic,
                                    ),
                                  ),
                                  alignment: Alignment.center,
                                  child: child,
                                ),
                              ),
                          child:
                              _viewModel.isWalletListBitcoinPriceVisible
                                  ? const SizedBox.shrink(key: ValueKey('converted_amount_info_hidden'))
                                  : _BitcoinPriceInfoButton(
                                    key: const ValueKey('converted_amount_info_visible'),
                                    viewModel: _viewModel,
                                    fiatCodes: _viewModel.visibleFiats,
                                    showComparisonBasis: false,
                                  ),
                        ),
                      ],
                    ),
                    CoconutLayout.spacing_300h,
                    for (var fiat in _viewModel.visibleFiats)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(fiat.code, style: CoconutTypography.body2_14.setColor(context.coconutColors.mutedText)),
                          Text(
                            _viewModel.getBitcoinPrice(totalBalance, fiat),
                            style: CoconutTypography.body2_14_Number.setColor(context.coconutColors.primaryText),
                          ),
                        ],
                      ),
                  ],
                  // 홈 화면 총액 (애니메이션)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child:
                        excludedIds.isNotEmpty
                            ? Column(
                              key: const ValueKey('balance_details'),
                              children: [
                                CoconutLayout.spacing_300h,
                                _buildBalanceRow(
                                  label: t.wallet_list.home_balance,
                                  amount: homeBalance,
                                  currentUnit: currentUnit,
                                ),
                                CoconutLayout.spacing_200h,
                                _buildBalanceRow(
                                  label: t.wallet_list.excluded_balance,
                                  amount: excludedBalance,
                                  currentUnit: currentUnit,
                                ),
                              ],
                            )
                            : const SizedBox.shrink(key: ValueKey('balance_empty')),
                  ),
                ],
              )
              : const SizedBox.shrink(),
    );
  }

  Widget _buildBalanceRow({required String label, required int amount, required BitcoinUnit currentUnit}) {
    return Column(
      children: [
        Row(
          children: [
            Text(label, style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText)),
            const Spacer(),
            BitcoinAmountUnit(
              currentUnit: currentUnit,
              unitStyle: CoconutTypography.body2_14_Number.setColor(context.coconutColors.secondaryTextStrong),
              spacing: CoconutLayout.spacing_100w,
              child: Text(
                currentUnit.displayBitcoinAmount(amount),
                style: CoconutTypography.body2_14_Number.setColor(context.coconutColors.secondaryTextStrong),
              ),
            ),
          ],
        ),
        // Fiat price
        Row(
          children: [
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var fiat in _viewModel.visibleFiats) ...[
                  Text(
                    _viewModel.getBitcoinPrice(amount, fiat),
                    style: CoconutTypography.body3_12_Number.setColor(context.coconutColors.mutedText),
                  ),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWalletList(
    List<WalletItemBase> walletList,
    Map<int, AnimatedBalanceData> walletBalanceMap,
    List<int> walletOrder,
  ) {
    walletList.sort((a, b) => walletOrder.indexOf(a.id).compareTo(walletOrder.indexOf(b.id)));
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        if (index < walletList.length) {
          return _buildWalletItem(
            walletList[index],
            walletBalanceMap[walletList[index].id] ?? AnimatedBalanceData(0, 0),
            index == walletList.length - 1,
            walletOrder.isNotEmpty && walletList[index].id == walletOrder.first,
            isFavorite: _viewModel.favoriteWalletIds.contains(walletList[index].id),
          );
        }
        return null;
      }, childCount: walletList.length),
    );
  }

  Widget _buildEmptyFilteredWalletList() {
    final message = switch (_walletFilter) {
      WalletFilter.all => '',
      WalletFilter.watchOnly => t.wallet_list.empty_watch_only,
      WalletFilter.hot => t.wallet_list.empty_hot_wallet,
    };
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 80),
        child: Align(
          alignment: Alignment.topCenter,
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: CoconutTypography.body2_14.setColor(context.coconutColors.mutedText),
          ),
        ),
      ),
    );
  }

  List<WalletItemBase> _filterWalletList(List<WalletItemBase> wallets) {
    return switch (_walletFilter) {
      WalletFilter.all => wallets.toList(),
      WalletFilter.watchOnly => wallets.where((wallet) => !wallet.hasLocalKey).toList(),
      WalletFilter.hot => wallets.where((wallet) => wallet.hasLocalKey).toList(),
    };
  }

  Widget _buildWalletFilterChips({bool isEditMode = false}) {
    if (!isEditMode) {
      return Row(
        children: [
          for (var index = 0; index < _walletFilterOrder.length; index++) ...[
            _buildWalletFilterChip(_walletFilterOrder[index], _getWalletFilterLabel(_walletFilterOrder[index])),
            if (index < _walletFilterOrder.length - 1) CoconutLayout.spacing_100w,
          ],
        ],
      );
    }

    final movableFilters = _walletFilterOrder.where((filter) => filter != WalletFilter.all).toList();
    return SizedBox(
      height: 32,
      child: Row(
        children: [
          _buildWalletFilterChip(WalletFilter.all, _getWalletFilterLabel(WalletFilter.all), isEditMode: true),
          CoconutLayout.spacing_100w,
          for (var index = 0; index < movableFilters.length; index++) ...[
            KeyedSubtree(
              key: ValueKey(movableFilters[index]),
              child: _buildWalletFilterChip(
                movableFilters[index],
                _getWalletFilterLabel(movableFilters[index]),
                isEditMode: true,
                enableDragging: true,
              ),
            ),
            if (index < movableFilters.length - 1) CoconutLayout.spacing_100w,
          ],
        ],
      ),
    );
  }

  Widget _buildWalletFilterChip(
    WalletFilter filter,
    String label, {
    bool isEditMode = false,
    bool enableDragging = false,
    bool isDragging = false,
  }) {
    final isSelected = _walletFilter == filter;
    final isDisabled = isEditMode && filter == WalletFilter.all;
    final chipBackground =
        isDragging
            ? context.coconutColors.chipMovingBackground
            : isDisabled
            ? context.coconutColors.chipDisabledBackground
            : isEditMode
            ? context.coconutColors.chipEditModeBackground
            : isSelected
            ? context.coconutColors.chipSelectedBackground
            : context.coconutColors.chipUnselectedBackground;
    final chipTextColor =
        isDragging
            ? context.coconutColors.chipMovingText
            : isDisabled
            ? context.coconutColors.chipDisabledText
            : isEditMode
            ? context.coconutColors.chipEditModeText
            : isSelected
            ? context.coconutColors.chipSelectedText
            : context.coconutColors.chipUnselectedText;
    final chip = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap:
          isEditMode
              ? null
              : () {
                if (isSelected) return;
                setState(() => _walletFilter = filter);
              },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: chipBackground,
          borderRadius: BorderRadius.circular(20),
          border: isDragging ? Border.all(color: context.coconutColors.chipMovingBorder) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style:
                  isEditMode
                      ? CoconutTypography.body3_12.setColor(chipTextColor)
                      : isSelected
                      ? CoconutTypography.body3_12_Bold.setColor(chipTextColor)
                      : CoconutTypography.body3_12.setColor(chipTextColor),
            ),
            if (isEditMode) ...[
              CoconutLayout.spacing_100w,
              if (filter == WalletFilter.all)
                SvgPicture.asset(
                  'assets/svg/lock_simple.svg',
                  width: 16,
                  height: 16,
                  colorFilter: ColorFilter.mode(chipTextColor, BlendMode.srcIn),
                )
              else
                RotatedBox(
                  quarterTurns: 1,
                  child: SvgPicture.asset(
                    'assets/svg/arrow-top-down.svg',
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(chipTextColor, BlendMode.srcIn),
                  ),
                ),
            ],
          ],
        ),
      ),
    );

    if (!enableDragging) return chip;
    return Draggable<WalletFilter>(
      data: filter,
      axis: Axis.horizontal,
      onDragStarted: () => _walletFilterReorderDragDistance = 0,
      onDragUpdate: (details) => _handleWalletFilterReorderDrag(filter, details.delta.dx),
      onDragEnd: (_) => _walletFilterReorderDragDistance = 0,
      onDraggableCanceled: (_, _) => _walletFilterReorderDragDistance = 0,
      feedback: Material(
        color: Colors.transparent,
        child: _buildWalletFilterChip(filter, label, isEditMode: true, isDragging: true),
      ),
      childWhenDragging: Opacity(opacity: 0, child: chip),
      child: chip,
    );
  }

  String _getWalletFilterLabel(WalletFilter filter) {
    return switch (filter) {
      WalletFilter.all => t.wallet_home_screen.wallet_filter.all,
      WalletFilter.watchOnly => t.wallet_home_screen.wallet_filter.watch_only,
      WalletFilter.hot => t.wallet_home_screen.wallet_filter.hot,
    };
  }

  void _handleWalletFilterReorderDrag(WalletFilter filter, double deltaX) {
    const reorderThreshold = 32.0;
    final currentIndex = _walletFilterOrder.indexOf(filter);
    if (currentIndex < 1) return;

    if ((currentIndex == 1 && deltaX < 0) || (currentIndex == _walletFilterOrder.length - 1 && deltaX > 0)) {
      _walletFilterReorderDragDistance = 0;
      return;
    }

    _walletFilterReorderDragDistance += deltaX;
    final movingRight = _walletFilterReorderDragDistance >= reorderThreshold;
    final movingLeft = _walletFilterReorderDragDistance <= -reorderThreshold;
    if (!movingRight && !movingLeft) return;

    final targetIndex = currentIndex + (movingRight ? 1 : -1);
    if (targetIndex < 1 || targetIndex >= _walletFilterOrder.length) return;
    setState(() {
      final targetFilter = _walletFilterOrder[targetIndex];
      _walletFilterOrder[currentIndex] = targetFilter;
      _walletFilterOrder[targetIndex] = filter;
    });
    vibrateExtraLight();
    _walletFilterReorderDragDistance = 0;
  }

  void _resetWalletFilterTempState() {
    final preferenceProvider = context.read<PreferenceProvider>();
    _savedWalletFilterOrder = preferenceProvider.walletFilterOrder.toList();
    _walletFilterOrder = _savedWalletFilterOrder.toList();
    _savedVisibleWalletFilters = preferenceProvider.visibleWalletFilters.toSet();
    _tempVisibleWalletFilters = _savedVisibleWalletFilters.toSet();
  }

  Widget _buildEditableWalletList(Map<int, AnimatedBalanceData> walletBalanceMap) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      primary: false,
      physics: const AlwaysScrollableScrollPhysics(),
      header: _buildEditModeHeader(),
      footer: const Padding(padding: EdgeInsets.all(60.0)),
      proxyDecorator: (child, index, animation) {
        // 드래그 중인 항목의 외관 변경
        return Container(
          decoration: BoxDecoration(
            color: context.coconutColors.surfaceRaised,
            borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
            boxShadow: [
              BoxShadow(
                color: context.coconutColors.shadowSubtle,
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: child,
        );
      },
      itemCount: _viewModel.tempWalletOrder.length,
      onReorderStart: (index) {
        _draggedWalletId = _viewModel.tempWalletOrder[index];
        _startWalletReorderPositionTracking();
      },
      onReorderEnd: (_) => _stopWalletReorderPositionTracking(),
      onReorder: (oldIndex, newIndex) {
        _viewModel.reorderTempWalletOrder(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        WalletItemBase wallet = _viewModel.walletItemList.firstWhere((w) => w.id == _viewModel.tempWalletOrder[index]);
        return Dismissible(
          key: ValueKey(wallet.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: context.coconutColors.danger,
            child: SvgPicture.asset(
              'assets/svg/trash.svg',
              width: 16,
              colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
            ),
          ),
          onDismissed: (direction) {
            _viewModel.removeTempWalletOrderByWalletId(wallet.id);
          },
          child: KeyedSubtree(
            key: _walletReorderItemKeys.putIfAbsent(wallet.id, GlobalKey.new),
            child: _buildWalletItem(
              wallet,
              walletBalanceMap[_viewModel.tempWalletOrder[index]] ?? AnimatedBalanceData(0, 0),
              false,
              index == 0,
              isEditMode: true,
              isFavorite: _viewModel.favoriteWalletIds.contains(wallet.id),
              index: index,
            ),
          ),
        );
      },
    );
  }

  void _startWalletReorderPositionTracking() {
    _walletReorderItemTop.clear();
    _movingWalletIds.clear();
    _walletReorderStableFrameCounts.clear();
    _captureWalletReorderItemPositions();
    _walletReorderPositionTicker ??= createTicker(_trackWalletReorderItemMovement);
    if (!_walletReorderPositionTicker!.isActive) {
      _walletReorderPositionTicker!.start();
    }
  }

  void _stopWalletReorderPositionTracking() {
    _walletReorderPositionTicker?.stop();
    _draggedWalletId = null;
    _walletReorderItemTop.clear();
    _movingWalletIds.clear();
    _walletReorderStableFrameCounts.clear();
  }

  void _captureWalletReorderItemPositions() {
    for (final walletId in _viewModel.tempWalletOrder) {
      final renderObject = _walletReorderItemKeys[walletId]?.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;

      _walletReorderItemTop[walletId] = renderObject.localToGlobal(Offset.zero).dy;
    }
  }

  void _trackWalletReorderItemMovement(Duration _) {
    var hasMovementStarted = false;
    for (final walletId in _viewModel.tempWalletOrder) {
      if (walletId == _draggedWalletId) continue;
      final renderObject = _walletReorderItemKeys[walletId]?.currentContext?.findRenderObject();
      if (renderObject is! RenderBox || !renderObject.hasSize) continue;

      final currentTop = renderObject.localToGlobal(Offset.zero).dy;
      final previousTop = _walletReorderItemTop[walletId];
      _walletReorderItemTop[walletId] = currentTop;
      if (previousTop == null) continue;

      final isMoving = (currentTop - previousTop).abs() > 0.5;
      if (isMoving) {
        _walletReorderStableFrameCounts[walletId] = 0;
        if (_movingWalletIds.add(walletId)) {
          hasMovementStarted = true;
        }
        continue;
      }

      if (!_movingWalletIds.contains(walletId)) continue;
      final stableFrameCount = (_walletReorderStableFrameCounts[walletId] ?? 0) + 1;
      if (stableFrameCount >= 3) {
        _movingWalletIds.remove(walletId);
        _walletReorderStableFrameCounts.remove(walletId);
      } else {
        _walletReorderStableFrameCounts[walletId] = stableFrameCount;
      }
    }

    if (hasMovementStarted) {
      vibrateExtraLight();
    }
  }

  Widget _buildWalletItem(
    WalletItemBase wallet,
    AnimatedBalanceData animatedBalanceData,
    bool isLastItem,
    bool isFirstItem, {
    bool isEditMode = false,
    bool isFavorite = false,
    int? index,
  }) {
    return Column(
      children: [
        if (isEditMode) CoconutLayout.spacing_100h,
        _getWalletRowItem(
          Key(wallet.id.toString()),
          wallet,
          animatedBalanceData,
          isLastItem,
          isFirstItem,
          isEditMode,
          isFavorite,
          index: index,
        ),
        isEditMode
            ? CoconutLayout.spacing_100h
            : isLastItem
            ? CoconutLayout.spacing_1000h
            : CoconutLayout.spacing_200h,
      ],
    );
  }

  Widget _getWalletRowItem(
    Key key,
    WalletItemBase walletItem,
    AnimatedBalanceData animatedBalanceData,
    bool isLastItem,
    bool isFirstItem,
    bool isEditMode,
    bool isFavorite, {
    int? index,
  }) {
    return Selector<PreferenceProvider, Tuple2<BitcoinUnit, List<int>>>(
      selector: (_, viewModel) => Tuple2(viewModel.currentUnit, viewModel.excludedFromTotalBalanceWalletIds),
      builder: (context, data, child) {
        final currentUnit = data.item1;
        bool isExcludedFromTotalBalance = data.item2.contains(walletItem.id);

        return WalletItemCard(
          key: key,
          walletItem: walletItem,
          animatedBalanceData: animatedBalanceData,
          isLastItem: isLastItem,
          isBalanceHidden: false,
          currentUnit: currentUnit,
          backgroundColor: context.coconutColors.background,
          isPrimaryWallet: isFirstItem,
          isExcludeFromTotalBalance: isExcludedFromTotalBalance,
          isEditMode: isEditMode,
          isFavorite: isFavorite,
          isStarVisible: !isEditMode,
          onTapStar: (pair) {
            vibrateExtraLight();
            _viewModel.toggleFavorite(pair.$2);
          },
          index: index,
          onLongPressed: () {
            vibrateExtraLight();
            CommonBottomSheets.showBottomSheet(
              title: '',
              titlePadding: EdgeInsets.zero,
              context: context,
              child: WalletItemSettingBottomSheet(id: walletItem.id),
            );
          },
          onPressed: () {
            Navigator.pushNamed(
              context,
              '/wallet-detail',
              arguments: {'id': walletItem.id, 'entryPoint': kEntryPointWalletList},
            );
          },
          rightWidget: SvgPicture.asset(
            'assets/svg/arrow-right.svg',
            width: 6,
            height: 10,
            colorFilter: ColorFilter.mode(context.coconutColors.iconSubDefault, BlendMode.srcIn),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    bool isEditMode = _viewModel.isEditMode;
    bool hasWalletOrderChanged = _viewModel.hasWalletOrderChanged;
    return CoconutAppBar.build(
      title: isEditMode ? t.wallet_list.edit.order : t.wallet_home_screen.view_all_wallets,
      context: context,
      onBackPressed: () {
        if (isEditMode) {
          if (hasWalletOrderChanged || _hasWalletFilterVisibilityChanged || _hasWalletFilterOrderChanged) {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return CoconutPopup(
                  languageCode: context.read<PreferenceProvider>().language,
                  title: t.wallet_list.edit.finish,
                  description: t.wallet_list.edit.unsaved_changes_confirm_exit,
                  leftButtonText: t.no,
                  rightButtonText: t.yes,
                  onTapRight: () {
                    _viewModel.setEditMode(false);
                    _resetWalletFilterTempState();
                    Navigator.pop(context);
                  },
                  onTapLeft: () {
                    Navigator.pop(context);
                  },
                );
              },
            );
          } else {
            _viewModel.setEditMode(false);
            _resetWalletFilterTempState();
          }
        } else {
          Navigator.pop(context);
        }
      },
      actionButtonList: [
        if (!isEditMode) ...[
          _WalletListAppBarMenuButton(
            onEditOrder: _enterWalletOrderEditMode,
            onDisplaySettings: _showWalletListSettingsBottomSheet,
          ),
          CoconutLayout.spacing_200w,
        ],
      ],
    );
  }

  Widget _buildLoadingIndicator(WalletListViewModel viewModel) {
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
}

class _WalletListAppBarMenuButton extends StatefulWidget {
  final VoidCallback onEditOrder;
  final VoidCallback onDisplaySettings;

  const _WalletListAppBarMenuButton({required this.onEditOrder, required this.onDisplaySettings});

  @override
  State<_WalletListAppBarMenuButton> createState() => _WalletListAppBarMenuButtonState();
}

class _WalletListAppBarMenuButtonState extends State<_WalletListAppBarMenuButton> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _menuOverlayEntry;

  @override
  void dispose() {
    _removeMenu();
    super.dispose();
  }

  void _toggleMenu() {
    if (_menuOverlayEntry == null) {
      _showMenu();
    } else {
      _removeMenu();
    }
  }

  void _showMenu() {
    if (_menuOverlayEntry != null) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    _menuOverlayEntry = OverlayEntry(
      builder:
          (overlayContext) => Stack(
            children: [
              Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: _removeMenu)),
              CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                child: CoconutPulldownMenu(
                  backgroundColor: overlayContext.coconutColors.pulldownMenuBackground,
                  shadowColor: overlayContext.coconutColors.shadowDefault.withValues(alpha: 0.06),
                  dividerColor: overlayContext.coconutColors.pulldownMenuDividerColor,
                  splashColor: overlayContext.coconutColors.pulldownMenuPressedColor,
                  textColor: overlayContext.coconutColors.pulldownMenuTextColor,
                  entries: [
                    CoconutPulldownMenuItem(title: t.wallet_list.menu.edit_order),
                    CoconutPulldownMenuItem(title: t.wallet_list.menu.display_settings),
                  ],
                  onSelected: (index, _) {
                    _removeMenu();
                    if (index == 0) {
                      widget.onEditOrder();
                    } else if (index == 1) {
                      widget.onDisplaySettings();
                    }
                  },
                ),
              ),
            ],
          ),
    );
    overlay.insert(_menuOverlayEntry!);
  }

  void _removeMenu() {
    _menuOverlayEntry?.remove();
    _menuOverlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: SizedBox(
        width: 40,
        height: 40,
        child: IconButton(
          padding: EdgeInsets.zero,
          onPressed: _toggleMenu,
          icon: SvgPicture.asset(
            'assets/svg/kebab.svg',
            colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}

class _HistoricalPriceChangeChip extends StatefulWidget {
  final WalletListViewModel viewModel;

  const _HistoricalPriceChangeChip({required this.viewModel});

  @override
  State<_HistoricalPriceChangeChip> createState() => _HistoricalPriceChangeChipState();
}

class _HistoricalPriceChangeChipState extends State<_HistoricalPriceChangeChip> {
  static const _rotationDuration = Duration(seconds: 5);

  Timer? _rotationTimer;
  int _periodIndex = 0;
  int _slideDirection = 1;
  bool _isPointerDown = false;
  FiatCode? _lastFiatCode;

  bool get _hasPriceData =>
      widget.viewModel.supportsHistoricalBitcoinPrices &&
      widget.viewModel.historicalBitcoinPrices != null &&
      widget.viewModel.currentSelectedFiatBitcoinPrice != null;

  @override
  void initState() {
    super.initState();
    _lastFiatCode = widget.viewModel.selectedFiat;
    widget.viewModel.addListener(_onViewModelChanged);
    _syncRotationTimer();
  }

  @override
  void didUpdateWidget(covariant _HistoricalPriceChangeChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel == widget.viewModel) return;

    oldWidget.viewModel.removeListener(_onViewModelChanged);
    widget.viewModel.addListener(_onViewModelChanged);
    _lastFiatCode = widget.viewModel.selectedFiat;
    _periodIndex = 0;
    _syncRotationTimer();
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    widget.viewModel.removeListener(_onViewModelChanged);
    super.dispose();
  }

  void _onViewModelChanged() {
    if (!mounted) return;

    if (_lastFiatCode != widget.viewModel.selectedFiat) {
      _lastFiatCode = widget.viewModel.selectedFiat;
      _periodIndex = 0;
      _slideDirection = 1;
    }
    _syncRotationTimer();
    setState(() {});
  }

  void _syncRotationTimer() {
    if (!_hasPriceData || _isPointerDown) {
      _rotationTimer?.cancel();
      _rotationTimer = null;
      return;
    }
    if (_rotationTimer?.isActive ?? false) return;
    _scheduleNextRotation();
  }

  void _scheduleNextRotation() {
    _rotationTimer?.cancel();
    if (!_hasPriceData || _isPointerDown) {
      _rotationTimer = null;
      return;
    }

    _rotationTimer = Timer(_rotationDuration, () {
      if (!mounted || _isPointerDown || !_hasPriceData) return;
      _changePeriod(1, restartTimer: false);
      _scheduleNextRotation();
    });
  }

  void _changePeriod(int delta, {bool restartTimer = true}) {
    setState(() {
      _slideDirection = delta.isNegative ? -1 : 1;
      _periodIndex = (_periodIndex + delta) % 3;
    });
    if (restartTimer) _scheduleNextRotation();
  }

  void _pauseRotation() {
    _isPointerDown = true;
    _rotationTimer?.cancel();
    _rotationTimer = null;
  }

  void _resumeRotation() {
    _isPointerDown = false;
    _scheduleNextRotation();
  }

  @override
  Widget build(BuildContext context) {
    final historicalPrices = widget.viewModel.historicalBitcoinPrices;
    final currentPrice = widget.viewModel.currentSelectedFiatBitcoinPrice;
    if (!_hasPriceData || historicalPrices == null || currentPrice == null) {
      return const SizedBox.shrink();
    }

    final labels = [
      t.wallet_list.header.than_yesterday,
      t.wallet_list.header.than_a_week_ago,
      t.wallet_list.header.than_a_month_ago,
    ];
    final pastPrices = [
      historicalPrices.previousDayClose,
      historicalPrices.sevenDaysAgoClose,
      historicalPrices.thirtyDaysAgoClose,
    ];
    final changeRate = (currentPrice - pastPrices[_periodIndex]) / pastPrices[_periodIndex] * 100;
    final changeColor = changeRate >= 0 ? context.coconutColors.primary : context.coconutColors.warning;
    final changeRateText = '${changeRate >= 0 ? '+' : ''}${changeRate.toStringAsFixed(1)}%';

    return Listener(
      onPointerDown: (_) => _pauseRotation(),
      onPointerUp: (_) => _resumeRotation(),
      onPointerCancel: (_) => _resumeRotation(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onVerticalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (velocity.abs() < 50) return;
          _changePeriod(velocity < 0 ? 1 : -1);
        },
        child: ClipRect(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            layoutBuilder: (currentChild, previousChildren) {
              return Stack(
                alignment: Alignment.centerLeft,
                children: [...previousChildren, if (currentChild != null) currentChild],
              );
            },
            transitionBuilder: (child, animation) {
              final isOutgoing = animation.status == AnimationStatus.reverse;
              final offsetDirection = isOutgoing ? -_slideDirection.toDouble() : _slideDirection.toDouble();
              return SlideTransition(
                position: Tween<Offset>(
                  begin: Offset(0, offsetDirection),
                  end: Offset.zero,
                ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Container(
              key: ValueKey(_periodIndex),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: changeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${labels[_periodIndex]} $changeRateText',
                maxLines: 1,
                style: CoconutTypography.body3_12_Number.setColor(changeColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BitcoinPriceInfoButton extends StatefulWidget {
  final WalletListViewModel viewModel;
  final List<FiatCode>? fiatCodes;
  final bool showComparisonBasis;

  const _BitcoinPriceInfoButton({super.key, required this.viewModel, this.fiatCodes, this.showComparisonBasis = true});

  @override
  State<_BitcoinPriceInfoButton> createState() => _BitcoinPriceInfoButtonState();
}

class _BitcoinPriceInfoButtonState extends State<_BitcoinPriceInfoButton> with SingleTickerProviderStateMixin {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _tooltipOverlayEntry;
  late final AnimationController _tooltipAnimationController;
  late final Animation<double> _tooltipScaleAnimation;
  late final Animation<double> _tooltipOpacityAnimation;
  bool _isTooltipHiding = false;

  @override
  void initState() {
    super.initState();
    _tooltipAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
    );
    final curvedAnimation = CurvedAnimation(
      parent: _tooltipAnimationController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeInCubic,
    );
    _tooltipScaleAnimation = Tween<double>(begin: 0.85, end: 1).animate(curvedAnimation);
    _tooltipOpacityAnimation = CurvedAnimation(
      parent: _tooltipAnimationController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
  }

  @override
  void dispose() {
    _tooltipOverlayEntry?.remove();
    _tooltipOverlayEntry = null;
    _tooltipAnimationController.dispose();
    super.dispose();
  }

  void _toggleTooltip() {
    if (_tooltipOverlayEntry == null) {
      _showTooltip();
    } else {
      unawaited(_hideTooltip());
    }
  }

  void _showTooltip() {
    if (_tooltipOverlayEntry != null) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    final tooltipWidth = (MediaQuery.sizeOf(context).width - 32).clamp(0.0, 360.0);
    _isTooltipHiding = false;
    _tooltipOverlayEntry = OverlayEntry(
      builder:
          (overlayContext) => Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(behavior: HitTestBehavior.translucent, onTap: () => unawaited(_hideTooltip())),
              ),
              CompositedTransformFollower(
                link: _layerLink,
                showWhenUnlinked: false,
                targetAnchor: Alignment.bottomRight,
                followerAnchor: Alignment.topRight,
                offset: const Offset(10, -5),
                child: FadeTransition(
                  opacity: _tooltipOpacityAnimation,
                  child: ScaleTransition(
                    scale: _tooltipScaleAnimation,
                    alignment: Alignment.topRight,
                    child: Material(
                      color: Colors.transparent,
                      child: SizedBox(
                        width: tooltipWidth,
                        child: CoconutToolTip(
                          width: tooltipWidth,
                          padding: const EdgeInsets.only(top: 30, left: 20, right: 20, bottom: 20),
                          tooltipType: CoconutTooltipType.placement,
                          isBubbleClipperSideLeft: false,
                          isPlacementTooltipVisible: true,
                          backgroundColor: overlayContext.coconutColors.popoverBackground,
                          richText: _buildTooltipText(overlayContext),
                          onTapRemove: () => unawaited(_hideTooltip()),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
    overlay.insert(_tooltipOverlayEntry!);
    _tooltipAnimationController.forward(from: 0);
  }

  Future<void> _hideTooltip() async {
    if (_tooltipOverlayEntry == null || _isTooltipHiding) return;

    _isTooltipHiding = true;
    await _tooltipAnimationController.reverse();
    _tooltipOverlayEntry?.remove();
    _tooltipOverlayEntry = null;
    _isTooltipHiding = false;
  }

  RichText _buildTooltipText(BuildContext context) {
    final tooltip = t.wallet_list.header.tooltip;
    final fiatCodes = widget.fiatCodes ?? [widget.viewModel.selectedFiat];
    final isHistoricalPriceAvailable = widget.viewModel.selectedFiat != FiatCode.JPY;
    return RichText(
      text: TextSpan(
        style: CoconutTypography.body3_12.setColor(context.coconutColors.popoverText).copyWith(height: 1.45),
        children: [
          TextSpan(
            text: tooltip.title,
            style: CoconutTypography.body3_12_Bold.setColor(context.coconutColors.popoverText),
          ),
          if (widget.fiatCodes == null)
            TextSpan(text: '\n${tooltip.price_source(source: _getPriceSource(widget.viewModel.selectedFiat))}')
          else
            for (final fiatCode in fiatCodes)
              TextSpan(text: '\n${tooltip.fiat_price_source(fiat: fiatCode.code, source: _getPriceSource(fiatCode))}'),
          if (widget.showComparisonBasis && isHistoricalPriceAvailable) ...[
            TextSpan(text: '\n\n${tooltip.closing_time}'),
            TextSpan(text: '\n\n${tooltip.yesterday_basis}'),
            TextSpan(text: '\n${tooltip.week_basis}'),
            TextSpan(text: '\n${tooltip.month_basis}'),
          ] else if (widget.showComparisonBasis)
            TextSpan(text: '\n\n${tooltip.historical_price_unavailable}'),
        ],
      ),
    );
  }

  String _getPriceSource(FiatCode fiatCode) {
    return switch (fiatCode) {
      FiatCode.KRW => 'Upbit (KRW-BTC)',
      FiatCode.USD => 'Binance (BTCUSDT)',
      FiatCode.JPY => 'bitFlyer (BTC_JPY)',
      FiatCode.EUR => 'Binance (BTCEUR)',
    };
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleTooltip,
        child: SizedBox(
          width: 24,
          height: 24,
          child: Align(
            alignment: Alignment.centerRight,
            child: SvgPicture.asset(
              'assets/svg/circle-info.svg',
              width: 16,
              height: 16,
              colorFilter: ColorFilter.mode(context.coconutColors.iconSubDefault, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }
}

class WalletListSettingsBottomSheet extends StatefulWidget {
  final WalletListViewModel viewModel;
  final List<FiatCode> visibleFiats;
  final Function(FiatCode) onTogglePressed;

  const WalletListSettingsBottomSheet({
    super.key,
    required this.viewModel,
    required this.visibleFiats,
    required this.onTogglePressed,
  });

  @override
  State<WalletListSettingsBottomSheet> createState() => _WalletListSettingsBottomSheetState();
}

class _WalletListSettingsBottomSheetState extends State<WalletListSettingsBottomSheet> {
  int _selectedSegmentIndex = 0;

  WalletListViewModel get viewModel => widget.viewModel;
  List<FiatCode> get visibleFiats => widget.visibleFiats;
  Function(FiatCode) get onTogglePressed => widget.onTogglePressed;

  @override
  Widget build(BuildContext context) {
    final preferenceProvider = context.watch<PreferenceProvider>();
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: SafeArea(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Column(
              children: [
                CoconutSegmentedControl(
                  selectedColor: context.coconutColors.segmentedControlSelected,
                  segmentedControlContainerColor: context.coconutColors.segmentedControlBackground,
                  selectedTextColor: context.coconutColors.segmentedControlSelectedText,
                  unselectedTextColor: context.coconutColors.segmentedControlUnselectedText,
                  isSelected: [_selectedSegmentIndex == 0, _selectedSegmentIndex == 1],
                  onPressed: (index) {
                    if (_selectedSegmentIndex == index) return;
                    setState(() => _selectedSegmentIndex = index);
                    vibrateExtraLight();
                  },
                  children: [
                    Text(t.wallet_list.bottom_sheet.wallet_list_settings),
                    Text(t.wallet_list.bottom_sheet.home_screen_settings),
                  ],
                ),
                CoconutLayout.spacing_300h,
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  layoutBuilder:
                      (currentChild, previousChildren) => Stack(
                        alignment: Alignment.topCenter,
                        children: [...previousChildren, if (currentChild != null) currentChild],
                      ),
                  child:
                      _selectedSegmentIndex == 0
                          ? Column(
                            key: const ValueKey('wallet_list_display_settings'),
                            children: [
                              SingleButton(
                                customPadding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                                title: t.wallet_list.bottom_sheet.show_balance_chart,
                                subtitle: t.wallet_list.bottom_sheet.show_balance_chart_description,
                                isVerticalSubtitle: true,
                                backgroundColor: context.coconutColors.surfaceBottomSheet,
                                onPressed: () {
                                  viewModel.setWalletListBalanceChartVisible(
                                    !viewModel.isWalletListBalanceChartVisible,
                                  );
                                  vibrateExtraLight();
                                },
                                rightElement: CoconutSwitch(
                                  isOn: viewModel.isWalletListBalanceChartVisible,
                                  scale: 0.7,
                                  activeTrackColor: context.coconutColors.switchActiveTrack,
                                  activeThumbColor: context.coconutColors.switchActiveThumb,
                                  inactiveTrackColor: context.coconutColors.switchInactiveTrack,
                                  inactiveThumbColor: context.coconutColors.switchInactiveThumb,
                                  onChanged: (value) {
                                    viewModel.setWalletListBalanceChartVisible(value);
                                    vibrateExtraLight();
                                  },
                                ),
                              ),
                              CoconutLayout.spacing_200h,
                              SingleButton(
                                customPadding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                                title: t.wallet_list.bottom_sheet.show_bitcoin_price,
                                subtitle: t.wallet_list.bottom_sheet.show_bitcoin_price_description,
                                isVerticalSubtitle: true,
                                backgroundColor: context.coconutColors.surfaceBottomSheet,
                                onPressed: () {
                                  viewModel.setWalletListBitcoinPriceVisible(
                                    !viewModel.isWalletListBitcoinPriceVisible,
                                  );
                                  vibrateExtraLight();
                                },
                                rightElement: CoconutSwitch(
                                  isOn: viewModel.isWalletListBitcoinPriceVisible,
                                  scale: 0.7,
                                  activeTrackColor: context.coconutColors.switchActiveTrack,
                                  activeThumbColor: context.coconutColors.switchActiveThumb,
                                  inactiveTrackColor: context.coconutColors.switchInactiveTrack,
                                  inactiveThumbColor: context.coconutColors.switchInactiveThumb,
                                  onChanged: (value) {
                                    viewModel.setWalletListBitcoinPriceVisible(value);
                                    vibrateExtraLight();
                                  },
                                ),
                              ),
                              CoconutLayout.spacing_200h,
                              SingleButton(
                                customPadding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                                title: t.wallet_list.bottom_sheet.show_fiat_price,
                                subtitle: t.wallet_list.bottom_sheet.show_fiat_price_description,
                                isVerticalSubtitle: true,
                                backgroundColor: context.coconutColors.surfaceBottomSheet,
                                onPressed: () {
                                  viewModel.toggleWalletListFiatVisible();
                                  vibrateExtraLight();
                                },
                                rightElement: CoconutSwitch(
                                  isOn: viewModel.isWalletListFiatVisible,
                                  scale: 0.7,
                                  activeTrackColor: context.coconutColors.switchActiveTrack,
                                  activeThumbColor: context.coconutColors.switchActiveThumb,
                                  inactiveTrackColor: context.coconutColors.switchInactiveTrack,
                                  inactiveThumbColor: context.coconutColors.switchInactiveThumb,
                                  onChanged: (value) {
                                    viewModel.setWalletListFiatVisible(value);
                                    vibrateExtraLight();
                                  },
                                ),
                              ),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(opacity: animation, child: child);
                                },
                                child:
                                    viewModel.isWalletListFiatVisible
                                        ? Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            CoconutLayout.spacing_400h,
                                            Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 2),
                                              child: Column(
                                                children: [
                                                  for (var fiat in viewModel.orderedFiats) ...[
                                                    _buildFiatRow(
                                                      context,
                                                      fiat,
                                                      onTogglePressed,
                                                      viewModel.visibleFiats,
                                                    ),
                                                    CoconutLayout.spacing_400h,
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        )
                                        : const SizedBox.shrink(),
                              ),
                            ],
                          )
                          : _buildHomeScreenSettings(context, preferenceProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeScreenSettings(BuildContext context, PreferenceProvider preferenceProvider) {
    Widget buildTabSwitchButton({required WalletFilter filter, required String title, required String description}) {
      final isVisible = preferenceProvider.isWalletFilterVisible(filter);

      void updateVisibility(bool value) {
        preferenceProvider.setWalletFilterVisible(filter, value);
        vibrateExtraLight();
      }

      return SingleButton(
        title: title,
        subtitle: description,
        isVerticalSubtitle: true,
        customPadding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
        backgroundColor: context.coconutColors.surfaceBottomSheet,
        onPressed: () => updateVisibility(!isVisible),
        rightElement: CoconutSwitch(
          isOn: isVisible,
          scale: 0.7,
          activeTrackColor: context.coconutColors.switchActiveTrack,
          activeThumbColor: context.coconutColors.switchActiveThumb,
          inactiveTrackColor: context.coconutColors.switchInactiveTrack,
          inactiveThumbColor: context.coconutColors.switchInactiveThumb,
          onChanged: updateVisibility,
        ),
      );
    }

    return Column(
      key: const ValueKey('home_screen_display_settings'),
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        buildTabSwitchButton(
          filter: WalletFilter.hot,
          title: t.wallet_list.bottom_sheet.show_hot_wallet_tab,
          description: t.wallet_list.bottom_sheet.show_hot_wallet_tab_description,
        ),
      ],
    );
  }

  Widget _buildFiatRow(
    BuildContext context,
    FiatCode fiat,
    Function(FiatCode) onTogglePressed,
    List<FiatCode> currentVisibleFiats,
  ) {
    final isVisible = currentVisibleFiats.contains(fiat);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: context.coconutColors.surfaceCard,
                borderRadius: BorderRadius.circular(CoconutStyles.radius_50),
              ),
              width: 18,
              height: 18,
              child: Center(
                child: Text(
                  fiat.symbol,
                  style: CoconutTypography.body3_12_Number
                      .setColor(context.coconutColors.secondaryText)
                      .copyWith(height: 1.4),
                ),
              ),
            ),
            CoconutLayout.spacing_200w,
            Text(
              fiat.name,
              style: CoconutTypography.body3_12_Bold.setColor(context.coconutColors.primaryText).copyWith(height: 1.4),
            ),
            CoconutLayout.spacing_150w,
            AnimatedOpacity(
              opacity: isVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: Text(
                t.wallet_list.bottom_sheet.visible,
                style: CoconutTypography.caption_10.copyWith(height: 1.4, color: context.coconutColors.textHighlight),
              ),
            ),
          ],
        ),
        ShrinkAnimationButton(
          defaultColor: context.coconutColors.surface,
          pressedColor: context.coconutColors.surfacePressed,
          borderRadius: 8,
          child: Container(
            constraints: const BoxConstraints(minWidth: 52),
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              isVisible ? t.hide : t.show,
              textAlign: TextAlign.center,
              style: CoconutTypography.body3_12.setColor(context.coconutColors.primaryText).copyWith(height: 1.4),
            ),
          ),
          onPressed: () {
            onTogglePressed(fiat);
            vibrateExtraLight();
          },
        ),
      ],
    );
  }
}
