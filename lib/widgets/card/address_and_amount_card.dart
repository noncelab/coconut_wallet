import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class AddressAndAmountCard extends StatefulWidget {
  final String title;
  final String address;
  final String amount;
  final String? addressPlaceholder;
  final String? amountPlaceholder;
  final void Function() showAddressScanner;
  final void Function(String address) onAddressChanged;
  final void Function(String amount) onAmountChanged;
  final void Function(bool isContentEmpty) onDeleted;
  final bool isRemovable;
  final bool isAddressInvalid;
  final bool isAmountDust;

  const AddressAndAmountCard({
    super.key,
    required this.title,
    required this.address,
    required this.amount,
    required this.showAddressScanner,
    required this.onAddressChanged,
    required this.onAmountChanged,
    required this.onDeleted,
    required this.isRemovable,
    required this.isAddressInvalid,
    required this.isAmountDust,
    this.addressPlaceholder,
    this.amountPlaceholder,
  });

  @override
  State<AddressAndAmountCard> createState() => _AddressAndAmountCardState();
}

class _AddressAndAmountCardState extends State<AddressAndAmountCard> {
  late final TextEditingController _addressController;
  late final TextEditingController _amountController;
  final _addressFocusNode = FocusNode();
  final _quantityFocusNode = FocusNode();
  bool _isAmountEmpty = true;

  @override
  void initState() {
    super.initState();
    _addressController = TextEditingController(text: widget.address);
    _amountController = TextEditingController(text: widget.amount);
  }

  Widget _buildCoconutTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required ValueChanged<String> onChanged,
    Widget? suffix,
    TextInputType? textInputType,
    String? placeholderText,
    bool isError = false,
    String? errorText,
    EdgeInsets? padding,
  }) {
    return CoconutTextField(
      controller: controller,
      focusNode: focusNode,
      height: 52,
      padding: padding ??
          const EdgeInsets.only(
              left: CoconutLayout.defaultPadding,
              top: CoconutLayout.defaultPadding,
              bottom: CoconutLayout.defaultPadding),
      activeColor: CoconutColors.gray100,
      cursorColor: CoconutColors.gray100,
      placeholderColor: CoconutColors.gray600,
      backgroundColor: CoconutColors.black,
      errorColor: CoconutColors.hotPink,
      textInputType: textInputType,
      onChanged: onChanged,
      suffix: suffix,
      placeholderText: placeholderText,
      isError: isError,
      errorText: errorText,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
          color: CoconutColors.gray800,
          borderRadius: BorderRadius.circular(CoconutStyles.radius_200)),
      padding: const EdgeInsets.all(CoconutLayout.defaultPadding),
      child: Stack(children: [
        if (widget.isRemovable)
          Positioned(
            width: 14,
            height: 14,
            top: 0,
            right: 0,
            child: IconButton(
              iconSize: 14,
              padding: EdgeInsets.zero,
              onPressed: _onDeleted,
              icon: SvgPicture.asset('assets/svg/close-bold.svg',
                  colorFilter: const ColorFilter.mode(
                      CoconutColors.white, BlendMode.srcIn)),
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoconutLayout.spacing_200h,
            Text(widget.title, style: CoconutTypography.body2_14_Bold),
            CoconutLayout.spacing_200h,
            Text(t.address, style: CoconutTypography.body3_12),
            CoconutLayout.spacing_200h,
            _buildCoconutTextField(
                controller: _addressController,
                focusNode: _addressFocusNode,
                onChanged: _onAddressChanged,
                suffix: IconButton(
                  iconSize: 14,
                  padding: EdgeInsets.zero,
                  onPressed: () => _onAddressChanged(''),
                  icon: _addressController.text.isEmpty
                      ? SvgPicture.asset('assets/svg/scan.svg')
                      : SvgPicture.asset(
                          'assets/svg/text-field-clear.svg',
                          colorFilter: ColorFilter.mode(
                              widget.isAddressInvalid == true
                                  ? CoconutColors.hotPink
                                  : CoconutColors.white,
                              BlendMode.srcIn),
                        ),
                ),
                placeholderText: widget.addressPlaceholder,
                isError: widget.isAddressInvalid,
                padding:
                    const EdgeInsets.only(left: CoconutLayout.defaultPadding)),
            CoconutLayout.spacing_200h,
            Text(t.amount, style: CoconutTypography.body3_12),
            CoconutLayout.spacing_200h,
            _buildCoconutTextField(
                controller: _amountController,
                focusNode: _quantityFocusNode,
                onChanged: _onAmountChanged,
                textInputType: TextInputType.number,
                suffix: _amountController.text.isEmpty
                    ? null
                    : IconButton(
                        iconSize: 14,
                        padding: EdgeInsets.zero,
                        onPressed: () => _onAmountChanged(''),
                        icon: SvgPicture.asset(
                          'assets/svg/text-field-clear.svg',
                          colorFilter: ColorFilter.mode(
                              widget.isAmountDust == true
                                  ? CoconutColors.hotPink
                                  : CoconutColors.white,
                              BlendMode.srcIn),
                        ),
                      ),
                placeholderText: widget.amountPlaceholder,
                isError: widget.isAmountDust,
                errorText: widget.isAmountDust
                    ? t.alert.error_send.minimum_amount(
                        bitcoin: UnitUtil.satoshiToBitcoin(dustLimit + 1))
                    : null),
          ],
        ),
      ]),
    );
  }

  void _onAddressChanged(String value) {
    if (value.isEmpty) {
      _addressController.clear();
    }

    widget.onAddressChanged(value);
  }

  void _onAmountChanged(String value) {
    if (value.isEmpty) {
      _amountController.clear();
    }

    widget.onAmountChanged(value);
  }

  void _onDeleted() {
    widget.onDeleted(
        _addressController.text.isEmpty && _amountController.text.isEmpty);
  }
}
