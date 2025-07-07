import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/animated_balance.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/loading_indicator/loading_indicator.dart';
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
    return ChangeNotifierProxyProvider2<WalletProvider, ConnectivityProvider, WalletListViewModel>(
      create: (_) => _createViewModel(),
      update: (BuildContext context, WalletProvider walletProvider,
          ConnectivityProvider connectivityProvider, WalletListViewModel? previous) {
        previous ??= _createViewModel();

        if (previous.isNetworkOn != connectivityProvider.isNetworkOn) {
          previous.updateIsNetworkOn(connectivityProvider.isNetworkOn);
        }

        // FIXME: 다른 provider의 변경에 의해서도 항상 호출됨
        return previous..onWalletProviderUpdated(walletProvider);
      },
      child: Selector<
          WalletListViewModel,
          Tuple6<List<WalletListItemBase>, bool, Map<int, AnimatedBalanceData>, List<int>,
              List<int>, bool>>(
        selector: (_, vm) => Tuple6(
          vm.walletItemList,
          vm.isNetworkOn ?? false,
          vm.walletBalanceMap,
          vm.tempStarredWalletIds,
          vm.tempWalletOrder,
          vm.isEditMode,
        ),
        builder: (context, data, child) {
          final viewModel = Provider.of<WalletListViewModel>(context, listen: false);

          final walletListItem = data.item1;
          final walletBalanceMap = data.item3;
          final isEditMode = data.item6;
          debugPrint(
              'hasStarredChanged: ${viewModel.hasStarredChanged} hasORderChanged: ${viewModel.hasWalletOrderChanged}');
          return PopScope(
            canPop: isEditMode,
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
                top: true,
                bottom: false,
                child: isEditMode
                    // 편집 모드
                    ? Stack(
                        children: [
                          _buildEditableWalletList(walletBalanceMap),
                          FixedBottomButton(
                            onButtonClicked: () async {
                              await viewModel.applyTempDatasToWallets();
                              viewModel.setEditMode(false);
                            },
                            isActive:
                                viewModel.hasStarredChanged || viewModel.hasWalletOrderChanged,
                            backgroundColor: CoconutColors.white,
                            text: t.complete,
                          )
                        ],
                      )
                    // 일반 모드
                    : Stack(
                        children: [
                          CustomScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              semanticChildCount: walletListItem.length,
                              slivers: <Widget>[
                                // pull to refresh시 로딩 인디케이터를 보이기 위함
                                CupertinoSliverRefreshControl(
                                  onRefresh: viewModel.updateWalletBalances,
                                ),
                                _buildLoadingIndicator(viewModel),
                                // _buildPadding(isOffline),
                                _buildTotalAmount(walletBalanceMap),
                                // 지갑 목록
                                _buildWalletList(walletListItem, walletBalanceMap),
                              ]),
                          // _buildOfflineWarningBar(context, isOffline)
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  // Positioned _buildOfflineWarningBar(BuildContext context, bool isOffline) {
  //   return Positioned(
  //     top: MediaQuery.of(context).padding.top,
  //     left: 0,
  //     right: 0,
  //     child: AnimatedContainer(
  //       duration: kOfflineWarningBarDuration,
  //       curve: Curves.easeOut,
  //       height: isOffline ? kOfflineWarningBarHeight : 0.0,
  //       width: double.infinity,
  //       padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
  //       color: CoconutColors.hotPink,
  //       child: Row(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         children: [
  //           SvgPicture.asset('assets/svg/triangle-warning.svg'),
  //           CoconutLayout.spacing_100w,
  //           Text(
  //             t.errors.network_not_found,
  //             style: CoconutTypography.body3_12,
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildPadding(bool isOffline) {
  //   const kDefaultPadding = Sizes.size12;
  //   return SliverToBoxAdapter(
  //       child: AnimatedContainer(
  //           duration: kOfflineWarningBarDuration,
  //           height: isOffline ? kOfflineWarningBarHeight + kDefaultPadding : kDefaultPadding,
  //           curve: Curves.easeInOut,
  //           child: const SizedBox()));
  // }

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
      Provider.of<NodeProvider>(context, listen: false).syncStateStream,
      Provider.of<PreferenceProvider>(context, listen: false),
    );
    return _viewModel;
  }

  Widget _buildEditModeHeader() {
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(
                  vertical: 7.2,
                  horizontal: 6,
                ),
                height: 2.5,
                width: 2.5,
                decoration:
                    const BoxDecoration(color: CoconutColors.gray400, shape: BoxShape.circle),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.top,
                        child: SvgPicture.asset(
                          'assets/svg/star-small.svg',
                          width: 12,
                          height: 12,
                        ),
                      ),
                      TextSpan(text: t.wallet_list.edit.star_description),
                    ],
                  ),
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
            ],
          ),
          CoconutLayout.spacing_100h,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(
                  vertical: 7.2,
                  horizontal: 6,
                ),
                height: 2.5,
                width: 2.5,
                decoration:
                    const BoxDecoration(color: CoconutColors.gray400, shape: BoxShape.circle),
              ),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment.top,
                        child: SvgPicture.asset(
                          'assets/svg/hamburger.svg',
                          width: 12,
                          height: 12,
                        ),
                      ),
                      TextSpan(text: t.wallet_list.edit.order_description),
                    ],
                  ),
                  overflow: TextOverflow.visible,
                  softWrap: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTotalAmount(Map<int, AnimatedBalanceData> walletBalanceMap) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 35, bottom: 24, left: 20, right: 20),
            child: Selector<PreferenceProvider, bool>(
              selector: (_, viewModel) => viewModel.isBtcUnit,
              builder: (context, isBtcUnit, child) {
                return Row(
                  children: [
                    AnimatedBalance(
                        prevValue:
                            walletBalanceMap.values.map((e) => e.previous).fold(0, (a, b) => a + b),
                        value:
                            walletBalanceMap.values.map((e) => e.current).fold(0, (a, b) => a + b),
                        currentUnit: isBtcUnit ? BitcoinUnit.btc : BitcoinUnit.sats,
                        textStyle: CoconutTypography.heading3_21_NumberBold),
                    CoconutLayout.spacing_100w,
                    Text(
                      isBtcUnit ? t.btc : t.sats,
                      style: CoconutTypography.heading3_21_NumberBold,
                    ),
                  ],
                );
              },
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            color: CoconutColors.gray700,
          ),
          CoconutLayout.spacing_300h,
        ],
      ),
    );
  }

  Widget _buildWalletList(
      List<WalletListItemBase> walletList, Map<int, AnimatedBalanceData> walletBalanceMap) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index < walletList.length) {
            debugPrint(
                '1111 walletList[index].id: ${walletList[index].id}, name: ${walletList[index].name}');
            return _buildWalletItem(
              walletList[index],
              walletBalanceMap[walletList[index].id] ?? AnimatedBalanceData(0, 0),
              index == walletList.length - 1,
              index == 0,
            );
          }
          return null;
        },
        childCount: walletList.length,
      ),
    );
  }

  Widget _buildEditableWalletList(Map<int, AnimatedBalanceData> walletBalanceMap) {
    if (_viewModel.tempWalletOrder.isEmpty) {
      _viewModel.tempWalletOrder = List.from(_viewModel.walletItemList);
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      primary: false,
      physics: const NeverScrollableScrollPhysics(),
      header: _buildEditModeHeader(),
      footer: const Padding(
        padding: EdgeInsets.all(60.0),
      ),
      proxyDecorator: (child, index, animation) {
        return Container(
          decoration: BoxDecoration(
            color: CoconutColors.gray900,
            borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
            boxShadow: const [
              BoxShadow(color: CoconutColors.black, blurRadius: 8, spreadRadius: 0.5)
            ],
          ),
          child: child,
        );
      },
      itemCount: _viewModel.tempWalletOrder.length,
      onReorder: (oldIndex, newIndex) {
        _viewModel.reorderTempWalletOrder(oldIndex, newIndex);
      },
      itemBuilder: (context, index) {
        debugPrint(
            'index::: $index, walletId: ${_viewModel.tempWalletOrder[index]} _viewModel.starredWalletIds.contains(walletList[index].id) ${_viewModel.starredWalletIds.contains(_viewModel.tempWalletOrder[index])}');
        debugPrint('_viewModel.tempWalletOrder[index],: ${_viewModel.tempWalletOrder[index]}');
        WalletListItemBase wallet = _viewModel.walletItemList.firstWhere(
          (w) => w.id == _viewModel.tempWalletOrder[index],
        );
        return KeyedSubtree(
          key: ValueKey(_viewModel.tempWalletOrder[index]),
          child: _buildWalletItem(
            wallet,
            walletBalanceMap[_viewModel.tempWalletOrder[index]] ?? AnimatedBalanceData(0, 0),
            false,
            index == 0,
            isEditMode: true,
            isStarred: _viewModel.tempStarredWalletIds.contains(wallet.id),
            index: index,
          ),
        );
      },
    );
  }

  Widget _buildWalletItem(WalletListItemBase wallet, AnimatedBalanceData animatedBalanceData,
      bool isLastItem, bool isFirstItem,
      {bool isEditMode = false, bool isStarred = false, int? index}) {
    debugPrint('_buildWalletItem isStarred: $isStarred, id: ${wallet.id}, name: ${wallet.name}');
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
          isStarred,
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
    bool isStarred, {
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
    debugPrint('isStared ::: $isStarred, id: $id, name: $name');
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
            isBalanceHidden: false,
            signers: signers,
            walletImportSource: walletImportSource,
            currentUnit: isBtcUnit ? BitcoinUnit.btc : BitcoinUnit.sats,
            backgroundColor: CoconutColors.black,
            isPrimaryWallet: isFirstItem,
            isExcludeFromTotalAmount: true,
            isEditMode: isEditMode,
            isStarred: isStarred,
            onPrimaryWalletChanged: (pair) {
              // pair: (bool isStarred, int walletId)
              vibrateExtraLight();
              debugPrint('${pair.$1}, ${pair.$2}');
              _viewModel.toggleTempStarred(pair.$2);
            },
            index: index,
          );
        });
  }

  AppBar _buildAppBar(BuildContext context) {
    bool isEditMode = _viewModel.isEditMode;
    return CoconutAppBar.build(
      title: isEditMode ? t.wallet_list.edit.wallet_list : '',
      context: context,
      onBackPressed: () {
        if (isEditMode) {
          _viewModel.setEditMode(false);
        } else {
          Navigator.pop(context);
        }
      },
      actionButtonList: [
        if (!isEditMode)
          CoconutUnderlinedButton(
            text: t.edit,
            textStyle: CoconutTypography.body2_14,
            onTap: () {
              _viewModel.setEditMode(true);
            },
          ),
      ],
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
}
