import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutTextField;
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/numeric_input_formatters.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/single_field_fixed_bottom_sheet_body.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// [ReceiveAmountBottomSheet]에서 사용되는 결과 DTO
class ReceiveAmountBottomSheetResult {
  final bool didEdit;
  final int? amountInSats;
  final String memo;

  const ReceiveAmountBottomSheetResult({required this.didEdit, required this.amountInSats, this.memo = ''});
}

/// BIP21 금액 입력 BottomSheet 공통 호출 유틸
class ReceiveAmountBottomSheet {
  static Future<ReceiveAmountBottomSheetResult?> show({
    required BuildContext context,
    required BitcoinUnit currentUnit,
    required int? initialAmountSats,
    required String screenName,
    String? description,

    /// 값이 있으면 메모 입력란을 함께 보여 줌(라이트닝 인보이스 메모)
    String? initialMemo,
  }) {
    return CommonBottomSheets.showBottomSheet<ReceiveAmountBottomSheetResult>(
      context: context,
      title: t.address_list_screen.set_amount,
      screenName: screenName,
      showCloseButton: true,
      showDragHandle: true,
      keyboardBottomPadding: 0,
      titlePadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: _ReceiveAmountSheet(
        initialUnit: currentUnit,
        initialAmountSats: initialAmountSats,
        description: description,
        initialMemo: initialMemo,
      ),
    );
  }
}

class _ReceiveAmountSheet extends StatefulWidget {
  const _ReceiveAmountSheet({
    required this.initialUnit,
    required this.initialAmountSats,
    this.description,
    this.initialMemo,
  });

  final BitcoinUnit initialUnit;
  final int? initialAmountSats;
  final String? description;
  final String? initialMemo;

  @override
  State<_ReceiveAmountSheet> createState() => _ReceiveAmountSheetState();
}

class _ReceiveAmountSheetState extends State<_ReceiveAmountSheet> {
  late BitcoinUnit _unit = widget.initialUnit;
  late final TextEditingController _controller = TextEditingController(
    text: BalanceFormatUtil.formatSatsToBip21InputText(currentUnit: _unit, initialAmountSats: widget.initialAmountSats),
  );
  late final TextEditingController _memoController = TextEditingController(text: widget.initialMemo ?? '');
  final FocusNode _focusNode = FocusNode();
  final FocusNode _memoFocusNode = FocusNode();

  int? get _amountSats => BalanceFormatUtil.parseAmountTextToSats(currentUnit: _unit, inputText: _controller.text);
  String get _memo => _memoController.text.trim();
  bool get _hasMemo => widget.initialMemo != null;

  bool get _isChanged => _amountSats != widget.initialAmountSats || (_hasMemo && _memo != widget.initialMemo);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _memoController.dispose();
    _focusNode.dispose();
    _memoFocusNode.dispose();
    super.dispose();
  }

  /// BTC와 sats를 오가며 입력한 금액을 새 단위로 옮김
  void _toggleUnit() {
    final sats = _amountSats;
    setState(() {
      _unit = _unit.isBtcUnit ? BitcoinUnit.sats : BitcoinUnit.btc;
      _controller.text = BalanceFormatUtil.formatSatsToBip21InputText(currentUnit: _unit, initialAmountSats: sats);
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    });
    vibrateLight();
    if (!_focusNode.hasFocus) return;
    // 단위에 맞는 키보드로 바꾸려면 포커스를 다시 잡아야 함
    _focusNode.unfocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _onComplete() {
    FocusScope.of(context).unfocus();
    Navigator.pop(
      context,
      ReceiveAmountBottomSheetResult(didEdit: _isChanged, amountInSats: _amountSats, memo: _hasMemo ? _memo : ''),
    );
  }

  Widget _buildUnitButton() {
    return GestureDetector(
      onTap: _toggleUnit,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: context.coconutColors.surfaceButton, borderRadius: BorderRadius.circular(8)),
        child: Text(
          _unit.symbol,
          style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.surfaceButtonText),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final amountField = CoconutTextField(
      key: ValueKey(_unit),
      controller: _controller,
      focusNode: _focusNode,
      onChanged: (_) => setState(() {}),
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      textInputType: _unit.isBtcUnit ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.number,
      textInputFormatter: _unit.isBtcUnit ? [const BtcAmountInputFormatter()] : [const SatoshiAmountInputFormatter()],
      placeholderText: t.address_list_screen.enter_receive_amount,
      backgroundColor: context.coconutColors.surfaceBottomSheet,
      isLengthVisible: false,
      maxLength: 30,
      maxLines: 1,
      clearButtonVisibility: CoconutTextFieldClearButtonVisibility.always,
      onClear: () => setState(_controller.clear),
      suffix: _buildUnitButton(),
    );

    final content = Column(
      children: [
        amountField,
        if (_hasMemo) ...[
          CoconutLayout.spacing_200h,
          CoconutTextField(
            controller: _memoController,
            focusNode: _memoFocusNode,
            onChanged: (_) => setState(() {}),
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            placeholderText: t.ark.receive.memo_placeholder,
            backgroundColor: context.coconutColors.surfaceBottomSheet,
            isLengthVisible: false,
            maxLength: 100,
            maxLines: 1,
            enableSuggestions: isAndroid,
            clearButtonVisibility: CoconutTextFieldClearButtonVisibility.whenNotEmpty,
            onClear: () => setState(_memoController.clear),
          ),
        ],
        if (widget.description case final description?) ...[
          CoconutLayout.spacing_300h,
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(description, style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText)),
            ),
          ),
        ],
      ],
    );

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: SingleFieldFixedBottomSheetBody(
        collapsedHeight: (widget.description == null ? 240 : 280) + (_hasMemo ? 64 : 0),
        keyboardContentHeight: 120 + (_hasMemo ? 64 : 0),
        isCompleteEnabled: _isChanged,
        onComplete: _onComplete,
        completeLabel: t.done,
        textField: content,
      ),
    );
  }
}
