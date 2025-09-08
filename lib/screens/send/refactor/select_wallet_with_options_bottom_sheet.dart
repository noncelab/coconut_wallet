import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/view_model/send/refactor/send_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/refactor/select_wallet_bottom_sheet.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/utils/wallet_util.dart';
import 'package:coconut_wallet/widgets/icon/wallet_item_icon.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SelectWalletWithOptionsBottomSheet extends StatefulWidget {
  final int selectedWalletId;
  final List<UtxoState> selectedUtxoList;
  final bool isUtxoSelectionAuto;
  final WalletInfoUpdateCallback onWalletInfoUpdated;
  final BitcoinUnit currentUnit;

  const SelectWalletWithOptionsBottomSheet(
      {super.key,
      required this.currentUnit,
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

  WalletListItemBase? _selectedWalletItem;
  List<UtxoState> _selectedUtxoList = [];
  List<UtxoState> _unspentUtxoList = [];
  int _unspentUtxoAmountSum = 0;
  int selectedUtxoAmountSum = 0;
  bool _isUtxoSelectionAuto = true;

  // 초기 상태 저장
  late final int _initialSelectedWalletId;
  late final bool _initialIsUtxoSelectionAuto;
  late final List<UtxoState> _initialSelectedUtxoList;

  int get selectedWalletId => _selectedWalletItem != null ? _selectedWalletItem!.id : -1;

  int get selectedWalletBalance => _selectedWalletItem != null ? _unspentUtxoAmountSum : 0;

  /// 변경사항이 있는지 확인
  bool get hasChanges {
    // 선택된 지갑이 없으면 비활성화
    if (_selectedWalletItem == null) return false;

    // 지갑 변경 확인
    if (_selectedWalletItem!.id != _initialSelectedWalletId) return true;

    // UTXO 선택 모드 변경 확인
    if (_isUtxoSelectionAuto != _initialIsUtxoSelectionAuto) return true;

    // 수동 모드일 때 UTXO 선택 변경 확인
    if (!_isUtxoSelectionAuto) {
      if (_selectedUtxoList.length != _initialSelectedUtxoList.length) return true;

      for (final utxo in _selectedUtxoList) {
        if (!_initialSelectedUtxoList.any((initial) => initial.utxoId == utxo.utxoId)) {
          return true;
        }
      }
    }

    return false;
  }

  /// 변경사항이 있고 처리 가능한지 확인
  bool get isButtonActive {
    return hasChanges &&
        _selectedWalletItem != null &&
        (_isUtxoSelectionAuto || _selectedUtxoList.isNotEmpty);
  }

  @override
  void initState() {
    super.initState();
    _walletProvider = context.read<WalletProvider>();
    _isUtxoSelectionAuto = widget.isUtxoSelectionAuto;
    _selectedUtxoList = widget.selectedUtxoList;
    selectedUtxoAmountSum =
        _selectedUtxoList.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);

    final selectedWalletItem =
        _walletProvider.walletItemList.where((e) => e.id == widget.selectedWalletId).firstOrNull;
    if (selectedWalletItem != null) {
      _selectedWalletItem = selectedWalletItem;
      _initConfirmedUtxoListAndAmountSum();
    }

    // 초기 상태 저장
    _initialSelectedWalletId = widget.selectedWalletId;
    _initialIsUtxoSelectionAuto = widget.isUtxoSelectionAuto;
    _initialSelectedUtxoList = List.from(widget.selectedUtxoList);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: CoconutColors.gray900,
        body: Column(children: [
          _buildSelectedWalletWithOptions(context),
          const Spacer(),
          _buildCompleteButton(),
          CoconutLayout.spacing_800h,
        ]));
  }

  Widget _buildCompleteButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16),
      child: CoconutButton(
        onPressed: () {
          vibrateLight();
          Navigator.of(context).pop();
          final utxoList = _isUtxoSelectionAuto ? _unspentUtxoList : _selectedUtxoList;
          widget.onWalletInfoUpdated(_selectedWalletItem!, utxoList, _isUtxoSelectionAuto);
        },
        disabledBackgroundColor: CoconutColors.gray800,
        disabledForegroundColor: CoconutColors.gray700,
        isActive: isButtonActive,
        backgroundColor: CoconutColors.white,
        foregroundColor: CoconutColors.black,
        pressedTextColor: CoconutColors.black,
        text: t.complete,
      ),
    );
  }

  Widget _buildUtxoOption() {
    bool isNonMpfWallet = isWalletWithoutMfp(_selectedWalletItem);
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (isNonMpfWallet) return;
        _setUtxoSelectionAuto(!_isUtxoSelectionAuto);
      },
      child: Row(
        children: [
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.select_wallet_with_options_bottom_sheet.select_utxo_auto,
                      style: CoconutTypography.body2_14),
                  Text(
                      _isUtxoSelectionAuto
                          ? t.select_wallet_with_options_bottom_sheet
                              .select_utxo_auto_minimal_fee_description
                          : t.select_wallet_with_options_bottom_sheet
                              .select_utxo_auto_selected_utxo_description,
                      style: CoconutTypography.body3_12.setColor(CoconutColors.gray400)),
                ],
              ),
            ),
          ),
          CoconutLayout.spacing_300w,
          Align(
              alignment: Alignment.centerRight,
              child: CoconutSwitch(
                  scale: 0.7,
                  isOn: _isUtxoSelectionAuto,
                  activeColor: CoconutColors.gray100.withOpacity(isNonMpfWallet ? 0.3 : 1.0),
                  trackColor: CoconutColors.gray600,
                  thumbColor: CoconutColors.gray800,
                  onChanged: (isOn) {
                    if (isNonMpfWallet) return;
                    _setUtxoSelectionAuto(isOn);
                  })),
          CoconutLayout.spacing_100w,
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(color: CoconutColors.gray700, height: 1);
  }

  Widget _buildSelectUtxoButton() {
    return IgnorePointer(
      ignoring: _isUtxoSelectionAuto,
      child: Opacity(
        opacity: !_isUtxoSelectionAuto ? 1.0 : 0.0,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CoconutButton(
              onPressed: () {
                Navigator.pushNamed(context, "/utxo-selection", arguments: {
                  "selectedUtxoList": _selectedUtxoList,
                  "walletId": _selectedWalletItem!.id,
                  "currentUnit": widget.currentUnit,
                }).then((utxoList) {
                  if (utxoList != null) {
                    _setSelectedUtxoList(utxoList as List<UtxoState>);
                  }
                });
              },
              disabledBackgroundColor: CoconutColors.gray800,
              disabledForegroundColor: CoconutColors.gray700,
              backgroundColor: CoconutColors.white,
              buttonType: CoconutButtonType.outlined,
              borderRadius: 8,
              isActive: _selectedWalletItem != null,
              text: t.select_wallet_with_options_bottom_sheet.select_utxo,
              textStyle: CoconutTypography.caption_10,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            ),
            CoconutLayout.spacing_100h,
          ],
        ),
      ),
    );
  }

  Widget _buildWalletIcon() {
    return SizedBox(
      width: 30,
      height: 30,
      child: WalletItemIcon(
          walletImportSource:
              _selectedWalletItem?.walletImportSource ?? WalletImportSource.coconutVault,
          iconIndex: _selectedWalletItem?.iconIndex ?? 0,
          colorIndex: _selectedWalletItem?.colorIndex ?? 0),
    );
  }

  Widget _buildWalletInfo(String amountText) {
    return GestureDetector(
      onTap: () {
        // MFP를 가진 월렛이 존재하지 않는다면 바텀시트를 출력하지 않는다
        if (!hasMfpWallet(_walletProvider.walletItemList)) return;
        CommonBottomSheets.showDraggableBottomSheetWithAppGuard(
            context: context,
            childBuilder: (scrollController) => SelectWalletBottomSheet(
                  showOnlyMfpWallets: true,
                  scrollController: scrollController,
                  currentUnit: widget.currentUnit,
                  walletId: selectedWalletId,
                  onWalletChanged: (id) {
                    _selectWalletItem(id);
                    Navigator.pop(context);
                  },
                  balanceMode: BalanceMode.onlyUnspent,
                ));
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isWalletWithoutMfp(_selectedWalletItem)
                    ? '-'
                    : _selectedWalletItem?.name ?? t.send_screen.select_wallet,
                style: CoconutTypography.body2_14_Bold,
              ),
              CoconutLayout.spacing_50w,
              const Icon(Icons.keyboard_arrow_down_sharp,
                  color: CoconutColors.white, size: Sizes.size20),
            ],
          ),
          FittedBox(
            child: Text(
              amountText,
              style: CoconutTypography.body2_14_Number,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedWalletWithOptions(BuildContext context) {
    int balanceInt = _isUtxoSelectionAuto || _selectedUtxoList.isEmpty
        ? selectedWalletBalance
        : selectedUtxoAmountSum;
    String amountText = widget.currentUnit.displayBitcoinAmount(balanceInt, withUnit: true);
    if (!_isUtxoSelectionAuto && _selectedUtxoList.isNotEmpty) {
      amountText +=
          t.select_wallet_with_options_bottom_sheet.n_utxos(count: _selectedUtxoList.length);
    }
    return Padding(
      padding: const EdgeInsets.only(left: 22, top: 27, right: 22),
      child: Column(
        children: [
          Row(
            children: [
              _buildWalletIcon(),
              CoconutLayout.spacing_200w,
              Expanded(child: _buildWalletInfo(amountText)),
              CoconutLayout.spacing_200w,
              _buildSelectUtxoButton(),
            ],
          ),
          Column(
            children: [
              CoconutLayout.spacing_400h,
              _buildDivider(),
              CoconutLayout.spacing_400h,
              _buildUtxoOption(),
            ],
          ),
        ],
      ),
    );
  }

  void _initConfirmedUtxoListAndAmountSum() {
    if (_selectedWalletItem == null) return;

    int sum = 0;
    final List<UtxoState> unspentUtxos = [];
    _walletProvider.getUtxoList(selectedWalletId).forEach((utxo) {
      if (utxo.status == UtxoStatus.unspent) {
        unspentUtxos.add(utxo);
        sum += utxo.amount;
      }
    });

    _unspentUtxoList = unspentUtxos;
    _unspentUtxoAmountSum = sum;
  }

  void _selectWalletItem(int walletId) {
    if (_selectedWalletItem != null && _selectedWalletItem!.id == walletId) return;
    _selectedWalletItem = _walletProvider.walletItemList.firstWhere((e) => e.id == walletId);
    _selectedUtxoList = [];
    selectedUtxoAmountSum = 0;
    _initConfirmedUtxoListAndAmountSum();
    setState(() {});
  }

  void _setUtxoSelectionAuto(bool isEnabled) {
    if (_isUtxoSelectionAuto == isEnabled) return;
    _isUtxoSelectionAuto = isEnabled;
    if (!_isUtxoSelectionAuto) {
      _setSelectedUtxoList([]);
    }
    setState(() {});
  }

  void _setSelectedUtxoList(List<UtxoState> utxoList) {
    _selectedUtxoList = utxoList;
    selectedUtxoAmountSum = utxoList.fold<int>(0, (totalAmount, utxo) => totalAmount + utxo.amount);
    setState(() {});
  }
}
