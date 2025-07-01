import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/widgets/loading_indicator/loading_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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
      child: Selector<WalletListViewModel,
          Tuple3<List<WalletListItemBase>, bool, Map<int, AnimatedBalanceData>>>(
        selector: (_, vm) => Tuple3(
          vm.walletItemList,
          vm.isNetworkOn ?? false,
          vm.walletBalanceMap,
        ),
        builder: (context, data, child) {
          final viewModel = Provider.of<WalletListViewModel>(context, listen: false);

          final walletListItem = data.item1;
          final isOffline = !data.item2;
          final walletBalanceMap = data.item3;

          return PopScope(
            canPop: true,
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
                child: Stack(
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
    );
    return _viewModel;
  }

  Widget _buildWalletList(
      List<WalletListItemBase> walletList, Map<int, AnimatedBalanceData> walletBalanceMap) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          if (index < walletList.length) {
            return _buildWalletItem(
                walletList[index],
                walletBalanceMap[walletList[index].id] ?? AnimatedBalanceData(0, 0),
                index == walletList.length - 1);
          }
          return null;
        },
        childCount: walletList.length,
      ),
    );
  }

  Widget _buildWalletItem(
      WalletListItemBase wallet, AnimatedBalanceData animatedBalanceData, bool isLastItem) {
    return Column(
      children: [
        _getWalletRowItem(
          Key(wallet.id.toString()),
          wallet,
          animatedBalanceData,
          isLastItem,
        ),
        isLastItem ? CoconutLayout.spacing_1000h : CoconutLayout.spacing_200h,
      ],
    );
  }

  Widget _getWalletRowItem(Key key, WalletListItemBase walletItem,
      AnimatedBalanceData animatedBalanceData, bool isLastItem) {
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
              isBalanceHidden: false,
              signers: signers,
              walletImportSource: walletImportSource,
              currentUnit: isBtcUnit ? BitcoinUnit.btc : BitcoinUnit.sats);
        });
  }

  AppBar _buildAppBar(BuildContext context) {
    return CoconutAppBar.buildWithNext(
        title: '', context: context, onNextPressed: () {}, nextButtonTitle: t.edit);
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
