import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/icon/wallet_item_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class SelectWalletBottomSheet extends StatefulWidget {
  final Function(int) onWalletChanged;
  final ScrollController? scrollController;

  const SelectWalletBottomSheet({super.key, required this.onWalletChanged, this.scrollController});

  @override
  State<SelectWalletBottomSheet> createState() => _SelectWalletBottomSheetState();
}

class _SelectWalletBottomSheetState extends State<SelectWalletBottomSheet> {
  late final List<WalletListItemBase> _walletList;
  late final Map<int, Balance> _walletBalanceMap;
  int _selectedWalletIndex = -1;

  @override
  void initState() {
    super.initState();
    final walletProvider = context.read<WalletProvider>();
    _walletList = walletProvider.walletItemList;
    _walletBalanceMap = walletProvider.fetchWalletBalanceMap();
  }

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
        body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Sizes.size16, vertical: Sizes.size12),
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    controller: widget.scrollController,
                    child: Column(
                        children: List.generate(_walletList.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: Sizes.size24),
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            _selectedWalletIndex = index;
                            setState(() {});
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: Sizes.size8),
                            child: _buildWalletItem(
                                _walletList[index],
                                _walletBalanceMap[_walletList[index].id],
                                _selectedWalletIndex == index),
                          ),
                        ),
                      );
                    })),
                  ),
                ),
                CoconutLayout.spacing_400h,
                CoconutButton(
                  onPressed: () => widget.onWalletChanged(_selectedWalletIndex),
                  disabledBackgroundColor: CoconutColors.gray800,
                  disabledForegroundColor: CoconutColors.gray700,
                  isActive: _selectedWalletIndex != -1,
                  backgroundColor: CoconutColors.white,
                  foregroundColor: CoconutColors.black,
                  pressedTextColor: CoconutColors.black,
                  text: t.complete,
                ),
              ],
            )));
  }

  Widget _buildWalletItem(WalletListItemBase walletBase, Balance? balance, bool isChecked) {
    int balanceInt = balance != null ? balance.confirmed : 0;
    String amountText = context
        .read<PreferenceProvider>()
        .currentUnit
        .displayBitcoinAmount(balanceInt, withUnit: true);
    return Row(
      children: [
        SizedBox(
          width: Sizes.size32,
          height: Sizes.size32,
          child: WalletItemIcon(
              walletImportSource: walletBase.walletImportSource,
              iconIndex: walletBase.iconIndex,
              colorIndex: walletBase.colorIndex),
        ),
        CoconutLayout.spacing_300w,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              amountText,
              style: CoconutTypography.body2_14_Number,
            ),
            Text(
              walletBase.name,
              style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
            ),
          ],
        ),
        if (isChecked) ...{
          const Spacer(),
          SvgPicture.asset('assets/svg/check.svg'),
        }
      ],
    );
  }
}
