import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/wallet_add_scanner_view_model.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_item_setting_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info_screen.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/loading_indicator/loading_indicator.dart';
import 'package:coconut_wallet/widgets/overlays/coconut_loading_overlay.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
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

        if (previous.isNetworkOn != connectivityProvider.isNetworkOn) {
          previous.updateIsNetworkOn(connectivityProvider.isNetworkOn);
        }

        previous.onPreferenceProviderUpdated();

        // FIXME: 다른 provider의 변경에 의해서도 항상 호출됨
        return previous..onWalletProviderUpdated(walletProvider);
      },
      child: Selector<
        WalletListViewModel,
        Tuple7<List<WalletListItemBase>, bool, Map<int, AnimatedBalanceData>, List<int>, List<int>, bool, List<int>>
      >(
        selector:
            (_, vm) => Tuple7(
              vm.walletItemList,
              vm.isNetworkOn ?? false,
              vm.walletBalanceMap,
              vm.tempFavoriteWalletIds,
              vm.tempWalletOrder,
              vm.isEditMode,
              vm.walletOrder,
            ),
        builder: (context, data, child) {
          final viewModel = Provider.of<WalletListViewModel>(context, listen: false);

          final walletListItem = data.item1;
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
              Navigator.popUntil(context, (route) {
                return route.settings.name == '/';
              });
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
                  backgroundColor: CoconutColors.black,
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
                                    await viewModel.applyTempDatasToWallets();
                                  },
                                  isActive: viewModel.hasFavoriteChanged || viewModel.hasWalletOrderChanged,
                                  backgroundColor: CoconutColors.white,
                                  text: t.complete,
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
                                    semanticChildCount: walletListItem.length,
                                    slivers: <Widget>[
                                      // pull to refresh시 로딩 인디케이터를 보이기 위함
                                      CupertinoSliverRefreshControl(onRefresh: viewModel.updateWalletBalances),
                                      _buildLoadingIndicator(viewModel),
                                      // _buildPadding(isOffline),
                                      _buildTotalAmount(walletBalanceMap),
                                      // 지갑 목록
                                      _buildWalletList(walletListItem, walletBalanceMap, walletOrder),
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
  }

  @override
  void dispose() {
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

  Widget _buildEditModeHeader() {
    SvgPicture starIcon = SvgPicture.asset('assets/svg/star-small.svg', width: 16, height: 16);
    SvgPicture hamburgerIcon = SvgPicture.asset('assets/svg/hamburger.svg', width: 16, height: 16);
    return Container(
      width: MediaQuery.sizeOf(context).width,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: CoconutColors.gray800,
        borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
      ),
      child: Column(
        children: [
          _buildEditModeHeaderLine([
            if (_viewModel.isEnglishOrSpanish) ...[
              TextSpan(text: '${t.select} '),
              WidgetSpan(alignment: PlaceholderAlignment.top, child: starIcon),
              const TextSpan(text: ' '),
            ] else ...[
              WidgetSpan(alignment: PlaceholderAlignment.top, child: starIcon),
              TextSpan(text: t.wallet_list.edit.star_description),
            ],
          ]),
          CoconutLayout.spacing_100h,
          _buildEditModeHeaderLine([
            if (_viewModel.isEnglishOrSpanish) ...[
              TextSpan(text: '${t.tap} '),
              WidgetSpan(alignment: PlaceholderAlignment.top, child: hamburgerIcon),
              const TextSpan(text: ' '),
            ] else ...[
              WidgetSpan(alignment: PlaceholderAlignment.top, child: hamburgerIcon),
              TextSpan(text: t.wallet_list.edit.order_description),
            ],
          ]),
          CoconutLayout.spacing_100h,
          _buildEditModeHeaderLine([TextSpan(text: t.wallet_list.edit.delete_description)]),
        ],
      ),
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
          decoration: const BoxDecoration(color: CoconutColors.gray400, shape: BoxShape.circle),
        ),
        Expanded(
          child: RichText(
            text: TextSpan(style: CoconutTypography.body2_14.setColor(CoconutColors.gray400), children: inlineSpan),
            overflow: TextOverflow.visible,
            softWrap: true,
          ),
        ),
      ],
    );
  }

  Widget _buildTotalAmount(Map<int, AnimatedBalanceData> walletBalanceMap) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(color: CoconutColors.gray900, borderRadius: BorderRadius.circular(12)),
          child: Selector<PreferenceProvider, Tuple3<bool, List<int>, List<int>>>(
            selector:
                (_, viewModel) => Tuple3(
                  viewModel.isBtcUnit,
                  viewModel.excludedFromTotalBalanceWalletIds,
                  viewModel.favoriteWalletIds,
                ),
            builder: (context, data, child) {
              final isBtcUnit = data.item1;
              final excludedIds = data.item2;
              final favoriteIds = data.item3;

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
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AnimatedBalance(
                            prevValue: prevTotalBalance,
                            value: totalBalance,
                            currentUnit: isBtcUnit ? BitcoinUnit.btc : BitcoinUnit.sats,
                            textStyle: CoconutTypography.heading4_18_NumberBold,
                          ),
                        ),
                      ),
                      CoconutLayout.spacing_100w,
                      Text(isBtcUnit ? t.btc : t.sats, style: CoconutTypography.heading4_18_NumberBold),
                    ],
                  ),
                  // 전체 총액 - Fiat Price
                  Text(
                    _viewModel.getBitcoinPrice(totalBalance),
                    style: CoconutTypography.body2_14_Number.setColor(CoconutColors.gray500),
                  ),

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
                                  isBtcUnit: isBtcUnit,
                                ),
                                CoconutLayout.spacing_200h,
                                _buildBalanceRow(
                                  label: t.wallet_list.excluded_balance,
                                  amount: excludedBalance,
                                  isBtcUnit: isBtcUnit,
                                ),
                              ],
                            )
                            : const SizedBox.shrink(key: ValueKey('balance_empty')),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceRow({required String label, required int amount, required bool isBtcUnit}) {
    return Column(
      children: [
        Row(
          children: [
            Text(label, style: CoconutTypography.body3_12.setColor(CoconutColors.gray400)),
            const Spacer(),
            Text(
              isBtcUnit ? BitcoinUnit.btc.displayBitcoinAmount(amount) : BitcoinUnit.sats.displayBitcoinAmount(amount),
              style: CoconutTypography.body2_14_Number.setColor(CoconutColors.gray300),
            ),
            CoconutLayout.spacing_100w,
            Text(isBtcUnit ? t.btc : t.sats, style: CoconutTypography.body2_14_Number.setColor(CoconutColors.gray300)),
          ],
        ),
        // Fiat price
        Row(
          children: [
            const Spacer(),
            Text(
              _viewModel.getBitcoinPrice(amount),
              style: CoconutTypography.body3_12_Number.setColor(CoconutColors.gray500),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWalletList(
    List<WalletListItemBase> walletList,
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
            index == 0,
          );
        }
        return null;
      }, childCount: walletList.length),
    );
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
            color: CoconutColors.gray900,
            borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
            boxShadow: const [BoxShadow(color: CoconutColors.black, blurRadius: 8, spreadRadius: 0.5)],
          ),
          child: child,
        );
      },
      itemCount: _viewModel.tempWalletOrder.length,
      onReorder: (oldIndex, newIndex) {
        _viewModel.reorderTempWalletOrder(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        WalletListItemBase wallet = _viewModel.walletItemList.firstWhere(
          (w) => w.id == _viewModel.tempWalletOrder[index],
        );
        return Dismissible(
          key: ValueKey(wallet.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: CoconutColors.hotPink,
            child: SvgPicture.asset(
              'assets/svg/trash.svg',
              width: 16,
              colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
            ),
          ),
          onDismissed: (direction) {
            _viewModel.removeTempWalletOrderByWalletId(wallet.id);
          },
          child: KeyedSubtree(
            key: ValueKey(_viewModel.tempWalletOrder[index]),
            child: _buildWalletItem(
              wallet,
              walletBalanceMap[_viewModel.tempWalletOrder[index]] ?? AnimatedBalanceData(0, 0),
              false,
              index == 0,
              isEditMode: true,
              isFavorite: _viewModel.tempFavoriteWalletIds.contains(wallet.id),
              index: index,
            ),
          ),
        );
      },
    );
  }

  Widget _buildWalletItem(
    WalletListItemBase wallet,
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
    WalletListItemBase walletItem,
    AnimatedBalanceData animatedBalanceData,
    bool isLastItem,
    bool isFirstItem,
    bool isEditMode,
    bool isFavorite, {
    int? index,
  }) {
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
    return Selector<PreferenceProvider, Tuple2<bool, List<int>>>(
      selector: (_, viewModel) => Tuple2(viewModel.isBtcUnit, viewModel.excludedFromTotalBalanceWalletIds),
      builder: (context, data, child) {
        bool isBtcUnit = data.item1;
        bool isExludedFromTotalBalance = data.item2.contains(id);

        return WalletItemCard(
          key: key,
          id: id,
          name: name,
          animatedBalanceData: animatedBalanceData,
          iconIndex: iconIndex,
          colorIndex: colorIndex,
          isLastItem: isLastItem,
          isBalanceHidden: false,
          signers: signers,
          walletImportSource: walletImportSource,
          currentUnit: isBtcUnit ? BitcoinUnit.btc : BitcoinUnit.sats,
          backgroundColor: CoconutColors.black,
          isPrimaryWallet: isFirstItem,
          isExcludeFromTotalBalance: isExludedFromTotalBalance,
          isEditMode: isEditMode,
          isFavorite: isFavorite,
          isStarVisible: isFavorite || _viewModel.tempFavoriteWalletIds.length < kMaxStarLenght, // 즐겨찾기 제한 만큼 설정
          onTapStar: (pair) {
            // pair: (bool isFavorite, int walletId)
            vibrateExtraLight();
            _viewModel.toggleTempFavorite(pair.$2);
          },
          index: index,
          entryPoint: kEntryPointWalletList,
          onLongPressed: () {
            vibrateExtraLight();
            CommonBottomSheets.showBottomSheet(
              title: '',
              titlePadding: EdgeInsets.zero,
              context: context,
              child: WalletItemSettingBottomSheet(id: id),
            );
          },
        );
      },
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    bool isEditMode = _viewModel.isEditMode;
    bool hasFavoriteChanged = _viewModel.hasFavoriteChanged;
    bool hasWalletOrderChanged = _viewModel.hasWalletOrderChanged;
    return CoconutAppBar.build(
      title: isEditMode ? t.wallet_list.edit.wallet_list : '',
      context: context,
      onBackPressed: () {
        if (isEditMode) {
          if (hasFavoriteChanged || hasWalletOrderChanged) {
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
          }
        } else {
          Navigator.pop(context);
        }
      },
      actionButtonList: [
        if (!isEditMode) ...[
          CoconutUnderlinedButton(
            text: t.edit,
            textStyle: CoconutTypography.body2_14,
            onTap: () {
              _viewModel.setEditMode(true);
            },
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
