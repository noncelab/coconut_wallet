import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/widgets/icon/wallet_item_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class SelectWalletBottomSheet extends StatefulWidget {
  final Function(int) onWalletChanged;
  final ScrollController? scrollController;
  final int walletId;
  final BitcoinUnit currentUnit;

  const SelectWalletBottomSheet(
      {super.key,
      required this.walletId,
      required this.onWalletChanged,
      required this.currentUnit,
      this.scrollController});

  @override
  State<SelectWalletBottomSheet> createState() => _SelectWalletBottomSheetState();
}

class _SelectWalletBottomSheetState extends State<SelectWalletBottomSheet> {
  late final List<WalletListItemBase> _walletList;
  late final Map<int, Balance> _walletBalanceMap;
  int _selectedWalletId = -1;

  @override
  void initState() {
    super.initState();
    final walletProvider = context.read<WalletProvider>();
    _walletList = walletProvider.walletItemList;
    _walletBalanceMap = walletProvider.fetchWalletBalanceMap();
    _selectedWalletId = widget.walletId;
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
        body: Column(
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
                        child: _buildWalletItem(_walletList[index], _walletBalanceMap[walletId],
                            _selectedWalletId == walletId),
                      ),
                    ),
                  );
                })),
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
                text: t.complete,
              ),
            ),
            CoconutLayout.spacing_800h,
          ],
        ));
  }

  Widget _buildWalletItem(WalletListItemBase walletBase, Balance? balance, bool isChecked) {
    int balanceInt = balance != null ? balance.confirmed : 0;
    String amountText = widget.currentUnit.displayBitcoinAmount(balanceInt, withUnit: true);
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
