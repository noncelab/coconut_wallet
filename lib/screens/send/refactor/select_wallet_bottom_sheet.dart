import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/multisig_signer.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/wallet_util.dart';
import 'package:coconut_wallet/widgets/icon/wallet_icon.dart';
import 'package:coconut_wallet/widgets/icon/wallet_icon_small.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

enum BalanceMode {
  includingPending,
  onlyUnspent, // UtxoStatus.unspent (UtxoStatus.locked 제외)
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
  late List<WalletListItemBase> _walletList;
  late final Map<int, int> _walletBalanceMap;
  int _selectedWalletId = -1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.gray900,
      appBar: CoconutAppBar.build(
        title: t.send_screen.select_wallet,
        context: context,
        onBackPressed: null,
        isBottom: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            CoconutLayout.spacing_500h,
            Expanded(
              child: SingleChildScrollView(
                controller: widget.scrollController,
                child: Column(
                  children: List.generate(_walletList.length, (index) {
                    int walletId = _walletList[index].id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: Sizes.size24, left: 14, right: 22),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () {
                          _selectedWalletId = walletId;
                          setState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: Sizes.size8),
                          child: _buildWalletItem(
                            _walletList[index],
                            _walletBalanceMap[walletId],
                            _selectedWalletId == walletId,
                          ),
                        ),
                      ),
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
                disabledBackgroundColor: CoconutColors.gray800,
                disabledForegroundColor: CoconutColors.gray700,
                isActive: _selectedWalletId != widget.walletId,
                backgroundColor: CoconutColors.white,
                foregroundColor: CoconutColors.black,
                pressedTextColor: CoconutColors.black,
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
      var orderedList =
          preferenceProvider.walletOrder.map((id) => walletMap[id]).whereType<WalletListItemBase>().toList();
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
        return _initBalanceMapIncludingPendingMode();
      case BalanceMode.onlyUnspent:
        return _initBalanceMapOnlyUnspent();
    }
  }

  Map<int, int> _initBalanceMapIncludingPendingMode() {
    final walletProvider = context.read<WalletProvider>();
    return walletProvider.fetchWalletBalanceMap().map((key, Balance value) {
      return MapEntry(key, value.total);
    });
  }

  Map<int, int> _initBalanceMapOnlyUnspent() {
    final walletProvider = context.read<WalletProvider>();
    Map<int, int> balanceMap = {};
    for (var wallet in _walletList) {
      balanceMap[wallet.id] = getUnspentUtxoSum(walletProvider.getUtxoList(wallet.id));
    }

    return balanceMap;
  }

  int getUnspentUtxoSum(List<UtxoState> utxos) {
    return utxos.fold(0, (accu, utxo) {
      if (utxo.status == UtxoStatus.unspent) {
        return accu + utxo.amount;
      }
      return accu;
    });
  }

  Widget _buildWalletItem(WalletListItemBase walletBase, int? balance, bool isChecked) {
    String amountText = widget.currentUnit.displayBitcoinAmount(balance ?? 0, withUnit: true);
    List<MultisigSigner>? signer;
    if (walletBase.walletType == WalletType.multiSignature) {
      signer = (walletBase as MultisigWalletListItem).signers;
    }
    return Row(
      children: [
        SizedBox(
          width: Sizes.size32,
          height: Sizes.size32,
          child: WalletIconSmall(
            walletImportSource: walletBase.walletImportSource,
            iconIndex: walletBase.iconIndex,
            colorIndex: walletBase.colorIndex,
            gradientColors: signer != null ? ColorUtil.getGradientColors(signer) : null,
          ),
        ),
        CoconutLayout.spacing_300w,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(amountText, style: CoconutTypography.body2_14_Number),
            Text(walletBase.name, style: CoconutTypography.body3_12.setColor(CoconutColors.gray400)),
          ],
        ),
        if (isChecked) ...{const Spacer(), SvgPicture.asset('assets/svg/check.svg')},
      ],
    );
  }
}
