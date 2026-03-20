import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/text_field_filter_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';

class ReceiveAmountBottomSheet extends StatefulWidget {
  const ReceiveAmountBottomSheet({super.key, required this.currentUnit});

  final BitcoinUnit currentUnit;

  static void show({required BuildContext context, required BitcoinUnit currentUnit}) {
    CommonBottomSheets.showBottomSheet(
      title: t.address_list_screen.set_amount,
      context: context,
      isCloseButton: true,
      showDragHandle: true,
      child: ReceiveAmountBottomSheet(currentUnit: currentUnit),
    );
  }

  @override
  State<ReceiveAmountBottomSheet> createState() => _ReceiveAmountBottomSheetState();
}

class _ReceiveAmountBottomSheetState extends State<ReceiveAmountBottomSheet> {
  final TextEditingController _amountController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onFieldChanged);
    _amountFocusNode.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _amountController.removeListener(_onFieldChanged);
    _amountFocusNode.removeListener(_onFieldChanged);
    _amountController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Widget? _buildAmountPrefix() {
    if (widget.currentUnit.isBip177Unit) {
      return Padding(
        padding: const EdgeInsets.only(left: 12, right: 6),
        child: Text(widget.currentUnit.symbol, style: CoconutTypography.body2_14_Bold),
      );
    }
    return null;
  }

  Widget? _buildAmountSuffix() {
    final showClearButton = _amountFocusNode.hasFocus;
    final showUnitSuffix = widget.currentUnit.isBtcUnit || widget.currentUnit.isSatsUnit;

    if (!showUnitSuffix && !showClearButton) return null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showUnitSuffix)
          Padding(
            padding: EdgeInsets.only(left: 8.0, right: showClearButton ? 0.0 : 4.0),
            child: Text(widget.currentUnit.symbol, style: CoconutTypography.body2_14_Bold),
          ),
        if (!showClearButton) CoconutLayout.spacing_400w,
        if (showClearButton)
          IconButton(
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            splashRadius: 12,
            onPressed: _amountController.clear,
            icon: SvgPicture.asset(
              'assets/svg/text-field-clear.svg',
              colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
            ),
          ),
      ],
    );
  }

  List<TextInputFormatter> _buildInputFormatters() {
    if (widget.currentUnit.isBtcUnit) {
      return [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
        _SingleDotInputFormatter(),
        const BtcAmountInputFormatter(),
      ];
    }

    return [FilteringTextInputFormatter.digitsOnly, const SatoshiAmountInputFormatter()];
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final minVisibleHeight =
        FixedBottomButton.fixedBottomButtonDefaultHeight +
        FixedBottomButton.fixedBottomButtonDefaultBottomPadding +
        bottomPadding +
        120;

    return SizedBox(
      height: keyboardInset > 0 ? minVisibleHeight : 240,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CoconutTextField(
              controller: _amountController,
              focusNode: _amountFocusNode,
              onChanged: (value) {},
              textInputType:
                  widget.currentUnit.isBtcUnit
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
              textInputFormatter: _buildInputFormatters(),
              prefix: _buildAmountPrefix(),
              suffix: _buildAmountSuffix(),
              placeholderText: t.address_list_screen.enter_receive_amount,
            ),
          ),
          FixedBottomButton(
            backgroundColor: CoconutColors.white,
            isVisibleAboveKeyboard: false,
            onButtonClicked: () {},
            text: t.complete,
          ),
        ],
      ),
    );
  }
}

class _SingleDotInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if ('.'.allMatches(newValue.text).length > 1) {
      return oldValue;
    }

    return newValue;
  }
}
