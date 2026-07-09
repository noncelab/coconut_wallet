import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/wallet_util.dart';
import 'package:coconut_wallet/widgets/card/wallet_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

enum BalanceMode {
  includingPending,
  onlyUnspent, // UtxoStatus.unspent (UtxoStatus.locked 제외)
}

Map<int, int> _buildBalanceMapIncludingPending(BuildContext context) {
  final walletProvider = context.read<WalletProvider>();
  return walletProvider.fetchWalletBalanceMap().map((key, Balance value) {
    return MapEntry(key, value.total);
  });
}

Map<int, int> _buildBalanceMapOnlyUnspent(BuildContext context, List<WalletItemBase> walletList) {
  final walletProvider = context.read<WalletProvider>();
  Map<int, int> balanceMap = {};
  for (var wallet in walletList) {
    balanceMap[wallet.id] = _getUnspentUtxoSum(walletProvider.getUtxoList(wallet.id));
  }

  return balanceMap;
}

int _getUnspentUtxoSum(List<UtxoState> utxos) {
  return utxos.fold(0, (accu, utxo) {
    if (utxo.status == UtxoStatus.unspent) {
      return accu + utxo.amount;
    }
    return accu;
  });
}

class SelectWalletBottomSheet extends StatefulWidget {
  final Function(int) onWalletChanged;
  final ScrollController? scrollController;
  final int walletId;
  final BitcoinUnit currentUnit;
  final bool showOnlyMfpWallets;
  final BalanceMode balanceMode;

  const SelectWalletBottomSheet({
    super.key,
    required this.walletId,
    required this.onWalletChanged,
    required this.currentUnit,
    required this.showOnlyMfpWallets,
    this.scrollController,
    this.balanceMode = BalanceMode.includingPending,
  });

  @override
  State<SelectWalletBottomSheet> createState() => _SelectWalletBottomSheetState();
}

class _SelectWalletBottomSheetState extends State<SelectWalletBottomSheet> {
  late List<WalletItemBase> _walletList;
  late final Map<int, int> _walletBalanceMap;
  int _selectedWalletId = -1;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = context.coconutColors.surfaceBottomSheet;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: CoconutAppBar.build(
        title: t.send_screen.select_wallet,
        context: context,
        backgroundColor: backgroundColor,
        onBackPressed: null,
        isBottom: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: widget.scrollController,
                child: Column(
                  children: List.generate(_walletList.length, (index) {
                    int walletId = _walletList[index].id;
                    final wallet = _walletList[index];
                    bool isChecked = _selectedWalletId == walletId;
                    return WalletItemCard(
                      walletItem: wallet,
                      animatedBalanceData: AnimatedBalanceData(
                        _walletBalanceMap[walletId] ?? 0,
                        _walletBalanceMap[walletId] ?? 0,
                      ),
                      isLastItem: index == _walletList.length - 1,
                      currentUnit: widget.currentUnit,
                      backgroundColor: backgroundColor,
                      rightWidget:
                          isChecked
                              ? SvgPicture.asset(
                                'assets/svg/check.svg',
                                colorFilter: ColorFilter.mode(context.coconutColors.iconDefault, BlendMode.srcIn),
                              )
                              : Container(),
                      onPressed: () => setState(() => _selectedWalletId = walletId),
                    );
                  }),
                ),
              ),
            ),
            CoconutLayout.spacing_800h,
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16),
              child: CoconutButton(
                onPressed: () => widget.onWalletChanged(_selectedWalletId),
                disabledBackgroundColor: context.coconutColors.surfaceDisabled,
                disabledForegroundColor: context.coconutColors.tertiaryText,
                isActive: _selectedWalletId != widget.walletId,
                backgroundColor: context.coconutColors.primaryButtonBackground,
                foregroundColor: context.coconutColors.primaryButtonText,
                pressedBackgroundColor: context.coconutColors.primaryButtonPressed,
                pressedTextColor: context.coconutColors.primaryButtonText,
                text: t.select,
              ),
            ),
            CoconutLayout.spacing_800h,
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final walletProvider = context.read<WalletProvider>();
    final preferenceProvider = context.read<PreferenceProvider>();

    _walletList = walletProvider.walletItemList;
    if (preferenceProvider.walletOrder.isNotEmpty) {
      final walletMap = {for (var wallet in _walletList) wallet.id: wallet};
      var orderedList = preferenceProvider.walletOrder.map((id) => walletMap[id]).whereType<WalletItemBase>().toList();
      _walletList = orderedList;
    }

    if (widget.showOnlyMfpWallets) {
      _walletList = _walletList.where((wallet) => !isWalletWithoutMfp(wallet)).toList();
    }
    _walletBalanceMap = _initBalanceMap();
    _selectedWalletId = widget.walletId;
  }

  Map<int, int> _initBalanceMap() {
    switch (widget.balanceMode) {
      case BalanceMode.includingPending:
        return _buildBalanceMapIncludingPending(context);
      case BalanceMode.onlyUnspent:
        return _buildBalanceMapOnlyUnspent(context, _walletList);
    }
  }
}

class P2PSelectWalletBottomSheet extends StatefulWidget {
  final Function(int) onWalletSelected;
  final ScrollController? scrollController;
  final BitcoinUnit currentUnit;
  final bool showOnlyMfpWallets;
  final BalanceMode balanceMode;

  const P2PSelectWalletBottomSheet({
    super.key,
    required this.onWalletSelected,
    required this.currentUnit,
    required this.showOnlyMfpWallets,
    this.scrollController,
    this.balanceMode = BalanceMode.includingPending,
  });

  @override
  State<P2PSelectWalletBottomSheet> createState() => _P2PSelectWalletBottomSheetState();
}

class _P2PSelectWalletBottomSheetState extends State<P2PSelectWalletBottomSheet> {
  late List<WalletItemBase> _walletList;
  late final Map<int, int> _walletBalanceMap;

  @override
  void initState() {
    super.initState();
    final walletProvider = context.read<WalletProvider>();
    final preferenceProvider = context.read<PreferenceProvider>();

    _walletList = walletProvider.walletItemList;
    if (preferenceProvider.walletOrder.isNotEmpty) {
      final walletMap = {for (var wallet in _walletList) wallet.id: wallet};
      var orderedList = preferenceProvider.walletOrder.map((id) => walletMap[id]).whereType<WalletItemBase>().toList();
      _walletList = orderedList;
    }

    if (widget.showOnlyMfpWallets) {
      _walletList = _walletList.where((wallet) => !isWalletWithoutMfp(wallet)).toList();
    }
    _walletBalanceMap = _initBalanceMap();
  }

  Map<int, int> _initBalanceMap() {
    switch (widget.balanceMode) {
      case BalanceMode.includingPending:
        return _buildBalanceMapIncludingPending(context);
      case BalanceMode.onlyUnspent:
        return _buildBalanceMapOnlyUnspent(context, _walletList);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = context.coconutColors.surfaceBottomSheet;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: CoconutAppBar.build(
        title: t.send_screen.select_wallet,
        context: context,
        backgroundColor: backgroundColor,
        onBackPressed: null,
        isBottom: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: widget.scrollController,
                child: Column(
                  children: List.generate(_walletList.length, (index) {
                    int walletId = _walletList[index].id;
                    final wallet = _walletList[index];
                    return WalletItemCard(
                      walletItem: wallet,
                      animatedBalanceData: AnimatedBalanceData(
                        _walletBalanceMap[walletId] ?? 0,
                        _walletBalanceMap[walletId] ?? 0,
                      ),
                      isLastItem: index == _walletList.length - 1,
                      currentUnit: widget.currentUnit,
                      backgroundColor: context.coconutColors.surfaceBottomSheet,
                      pressedColor: context.coconutColors.surfaceSectionBreak,
                      rightWidget: Container(),
                      onPressed: () => widget.onWalletSelected(walletId),
                    );
                  }),
                ),
              ),
            ),
            CoconutLayout.spacing_800h,
          ],
        ),
      ),
    );
  }
}
