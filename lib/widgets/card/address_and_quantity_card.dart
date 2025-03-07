import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class AddressAndQuantityCard extends StatefulWidget {
  final String title;
  final void Function() showAddressScanner;
  const AddressAndQuantityCard(
      {super.key, required this.title, required this.showAddressScanner});

  @override
  State<AddressAndQuantityCard> createState() => _AddressAndQuantityCardState();
}

class _AddressAndQuantityCardState extends State<AddressAndQuantityCard> {
  final _addressController = TextEditingController();
  final _quantityController = TextEditingController();
  final _addressFocusNode = FocusNode();
  final _quantityFocusNode = FocusNode();
  bool _isAddressEmpty = true;
  bool _isAmountEmpty = true;

  @override
  void initState() {
    super.initState();
  }

  void _onAddressChanged(String value) {
    if (_isAddressEmpty != value.isEmpty) {
      setState(() {
        _isAddressEmpty = value.isEmpty;
      });
    }
  }

  void _onAmountChanged(String value) {
    if (_isAmountEmpty != value.isEmpty) {
      setState(() {
        _isAmountEmpty = value.isEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Logger.log('--> 글자: ${_addressController.value.text}');
    return Container(
      decoration: BoxDecoration(
          color: CoconutColors.gray800,
          borderRadius: BorderRadius.circular(CoconutStyles.radius_200)),
      padding: const EdgeInsets.all(CoconutLayout.defaultPadding),
      child: Stack(children: [
        Positioned(
          width: 14,
          height: 14,
          top: 0,
          right: 0,
          child: IconButton(
            iconSize: 14,
            padding: EdgeInsets.zero,
            onPressed: () {
              throw 'imple';
            },
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
            CoconutTextField(
              controller: _addressController,
              focusNode: _addressFocusNode,
              activeColor: CoconutColors.gray100,
              cursorColor: CoconutColors.gray100,
              placeholderColor: CoconutColors.gray600,
              onChanged: _onAddressChanged,
              suffix: IconButton(
                iconSize: 14,
                padding: EdgeInsets.zero,
                onPressed: () {
                  throw 'imple';
                },
                icon: _isAddressEmpty
                    ? SvgPicture.asset('assets/svg/scan.svg')
                    : SvgPicture.asset('assets/svg/text-field-clear.svg'),
              ),
            ),
            CoconutLayout.spacing_200h,
            Text(t.amount, style: CoconutTypography.body3_12),
            CoconutLayout.spacing_200h,
            CoconutTextField(
              controller: _quantityController,
              focusNode: _quantityFocusNode,
              textInputType: TextInputType.number,
              activeColor: CoconutColors.gray100,
              cursorColor: CoconutColors.gray100,
              placeholderColor: CoconutColors.gray600,
              onChanged: _onAmountChanged,
              suffix: _isAmountEmpty
                  ? null
                  : IconButton(
                      iconSize: 14,
                      padding: EdgeInsets.zero,
                      onPressed: () {
                        throw 'imple';
                      },
                      icon: SvgPicture.asset('assets/svg/text-field-clear.svg'),
                    ),
            )
          ],
        ),
      ]),
    );
  }
}
