import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/refactor/send_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/refactor/select_wallet_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/icon/wallet_item_icon.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SelectWalletWithOptionsBottomSheet extends StatefulWidget {
  final int selectedWalletId;
  final List<UtxoState> selectedUtxoList;
  final bool isUtxoSelectionAuto;
  final WalletInfoUpdateCallback onWalletInfoUpdated;

  const SelectWalletWithOptionsBottomSheet(
      {super.key,
      required this.selectedWalletId,
      required this.onWalletInfoUpdated,
      required this.isUtxoSelectionAuto,
      required this.selectedUtxoList});

  @override
  State<SelectWalletWithOptionsBottomSheet> createState() =>
      _SelectWalletWithOptionsBottomSheetState();
}

class _SelectWalletWithOptionsBottomSheetState extends State<SelectWalletWithOptionsBottomSheet> {
  late final WalletProvider _walletProvider;
  late final Map<int, Balance> _walletBalanceMap;

  WalletListItemBase? _selectedWalletItem;
  List<UtxoState> _selectedUtxoList = [];
  List<UtxoState> _confirmedUtxoList = [];
  int selectedUtxoAmountSum = 0;
  bool _isUtxoSelectionAuto = true;

  int get selectedWalletId => _selectedWalletItem != null ? _selectedWalletItem!.id : -1;

  int get selectedWalletBalance =>
      _selectedWalletItem != null ? _walletBalanceMap[_selectedWalletItem!.id]!.confirmed : 0;

  @override
  void initState() {
    super.initState();
    _walletProvider = context.read<WalletProvider>();
    _walletBalanceMap = _walletProvider.fetchWalletBalanceMap();
    _isUtxoSelectionAuto = widget.isUtxoSelectionAuto;
    _selectedUtxoList = widget.selectedUtxoList;
    selectedUtxoAmountSum =
        _selectedUtxoList.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);

    final selectedWalletItem =
        _walletProvider.walletItemList.where((e) => e.id == widget.selectedWalletId).firstOrNull;
    if (selectedWalletItem != null) {
      _selectedWalletItem = selectedWalletItem;
      initConfirmedUtxoList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: CoconutColors.gray900,
        body: Padding(
            padding: const EdgeInsets.symmetric(vertical: Sizes.size12, horizontal: Sizes.size20),
            child: Column(children: [
              _buildSelectedWalletWithOptions(context),
              const Spacer(),
              CoconutButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  final utxoList = _isUtxoSelectionAuto ? _confirmedUtxoList : _selectedUtxoList;
                  widget.onWalletInfoUpdated(_selectedWalletItem!, utxoList, _isUtxoSelectionAuto);
                },
                disabledBackgroundColor: CoconutColors.gray800,
                disabledForegroundColor: CoconutColors.gray700,
                isActive: _selectedWalletItem != null &&
                    (_isUtxoSelectionAuto || _selectedUtxoList.isNotEmpty),
                backgroundColor: CoconutColors.white,
                foregroundColor: CoconutColors.black,
                pressedTextColor: CoconutColors.black,
                text: t.complete,
              ),
            ])));
  }

  Widget _buildDivider() {
    return Container(color: CoconutColors.gray700, height: 1);
  }

  Widget _buildUtxoOption() {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => setUtxoSelectionAuto(!_isUtxoSelectionAuto),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t.select_wallet_with_options_bottom_sheet.select_utxo_auto,
                  style: CoconutTypography.body3_12),
              Text(
                  _isUtxoSelectionAuto
                      ? t.select_wallet_with_options_bottom_sheet
                          .select_utxo_auto_minimal_fee_description
                      : t.select_wallet_with_options_bottom_sheet
                          .select_utxo_auto_selected_utxo_description,
                  style: CoconutTypography.caption_10.setColor(CoconutColors.gray400)),
            ],
          ),
          const Spacer(),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: 36,
              height: 22,
              child: Transform.scale(
                  scale: 0.7,
                  child: CupertinoSwitch(
                      value: _isUtxoSelectionAuto,
                      activeColor: CoconutColors.gray100,
                      trackColor: CoconutColors.gray600,
                      thumbColor: CoconutColors.gray800,
                      onChanged: (isOn) => setUtxoSelectionAuto(isOn))),
            ),
          ),
          CoconutLayout.spacing_100w,
        ],
      ),
    );
  }

  Widget _buildSelectedWalletWithOptions(BuildContext context) {
    if (_selectedWalletItem == null) {
      return const SizedBox();
    }
    int balanceInt = _isUtxoSelectionAuto || _selectedUtxoList.isEmpty
        ? selectedWalletBalance
        : selectedUtxoAmountSum;
    String amountText = context
        .read<PreferenceProvider>()
        .currentUnit
        .displayBitcoinAmount(balanceInt, withUnit: true);
    if (!_isUtxoSelectionAuto && _selectedUtxoList.isNotEmpty) {
      amountText +=
          t.select_wallet_with_options_bottom_sheet.n_utxos(count: _selectedUtxoList.length);
    }
    return Column(
      children: [
        Row(
          children: [
            WalletItemIcon(
                walletImportSource: _selectedWalletItem!.walletImportSource,
                iconIndex: _selectedWalletItem!.iconIndex,
                colorIndex: _selectedWalletItem!.colorIndex),
            CoconutLayout.spacing_150w,
            GestureDetector(
              onTap: () {
                CommonBottomSheets.showDraggableBottomSheet(
                    context: context,
                    childBuilder: (scrollController) => SelectWalletBottomSheet(
                          scrollController: scrollController,
                          onWalletChanged: (index) {
                            selectWalletItem(index);
                            Navigator.pop(context);
                          },
                        ));
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _selectedWalletItem!.name,
                        style: CoconutTypography.body3_12,
                      ),
                      CoconutLayout.spacing_50w,
                      const Icon(Icons.keyboard_arrow_down_sharp,
                          color: CoconutColors.white, size: Sizes.size16),
                    ],
                  ),
                  SizedBox(
                    height: 20,
                    child: Text(
                      amountText,
                      style: CoconutTypography.body2_14_Number,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            IgnorePointer(
              ignoring: _isUtxoSelectionAuto,
              child: Opacity(
                opacity: !_isUtxoSelectionAuto ? 1.0 : 0.0,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, "/refactor-utxo-selection", arguments: {
                          "selectedUtxoList": _selectedUtxoList,
                        }).then((utxoList) {
                          if (utxoList != null) {
                            setSelectedUtxoList(utxoList as List<UtxoState>);
                          }
                        });
                      },
                      child: Container(
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            border: Border.all(color: CoconutColors.gray400, width: 1),
                            borderRadius: const BorderRadius.all(Radius.circular(8)),
                            color: CoconutColors.gray900,
                          ),
                          child: Text(t.select_wallet_with_options_bottom_sheet.select_utxo,
                              style: CoconutTypography.caption_10)),
                    ),
                    CoconutLayout.spacing_100h,
                  ],
                ),
              ),
            )
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: Sizes.size36),
          child: Column(
            children: [
              CoconutLayout.spacing_300h,
              _buildDivider(),
              CoconutLayout.spacing_300h,
              _buildUtxoOption(),
            ],
          ),
        ),
      ],
    );
  }

  void initConfirmedUtxoList() {
    if (_selectedWalletItem == null) return;
    _confirmedUtxoList = _walletProvider
        .getUtxoList(selectedWalletId)
        .where((e) => e.status == UtxoStatus.unspent)
        .toList();
  }

  void selectWalletItem(int index) {
    final newWalletItem = _walletProvider.walletItemList[index];
    if (_selectedWalletItem != null && _selectedWalletItem!.id == newWalletItem.id) return;
    _selectedWalletItem = _walletProvider.walletItemList[index];
    _selectedUtxoList = [];
    selectedUtxoAmountSum = 0;
    initConfirmedUtxoList();
    setState(() {});
  }

  void setUtxoSelectionAuto(bool isEnabled) {
    if (_isUtxoSelectionAuto == isEnabled) return;
    _isUtxoSelectionAuto = isEnabled;
    if (!_isUtxoSelectionAuto) {
      setSelectedUtxoList([]);
    }
    setState(() {});
  }

  void setSelectedUtxoList(List<UtxoState> utxoList) {
    _selectedUtxoList = utxoList;
    selectedUtxoAmountSum = utxoList.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);
    setState(() {});
  }
}
