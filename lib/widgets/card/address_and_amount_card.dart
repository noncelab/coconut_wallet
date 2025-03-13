import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/body/send_address/send_address_body.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/overlays/custom_toast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

class AddressAndAmountCard extends StatefulWidget {
  final String title;
  final String address;
  final String amount;
  final String? addressPlaceholder;
  final String? amountPlaceholder;
  final void Function(String address) onAddressChanged;
  final void Function(String amount) onAmountChanged;
  final void Function(bool isContentEmpty) onDeleted;
  final Future<void> Function(String address) validateAddress;
  final bool isRemovable;
  final bool isAddressInvalid;
  final bool isAmountDust;
  final String? addressErrorMessage;

  const AddressAndAmountCard(
      {super.key,
      required this.title,
      required this.address,
      required this.amount,
      required this.onAddressChanged,
      required this.onAmountChanged,
      required this.onDeleted,
      required this.validateAddress,
      required this.isRemovable,
      required this.isAddressInvalid,
      required this.isAmountDust,
      this.addressPlaceholder,
      this.amountPlaceholder,
      this.addressErrorMessage});

  @override
  State<AddressAndAmountCard> createState() => _AddressAndAmountCardState();
}

class _AddressAndAmountCardState extends State<AddressAndAmountCard> {
  late final TextEditingController _addressController;
  late final TextEditingController _amountController;
  final _addressFocusNode = FocusNode();
  final _quantityFocusNode = FocusNode();
  QRViewController? _qrViewController;
  bool _isQrDataHandling = false;

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
                  onPressed: _addressController.text.isEmpty
                      ? _showAddressScanner
                      : () => _onAddressChanged(''),
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
                errorText: widget.addressErrorMessage,
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

  void _onQRViewCreated(QRViewController qrViewController) {
    _qrViewController = qrViewController;
    qrViewController.scannedDataStream.listen((scanData) {
      if (_isQrDataHandling || scanData.code == null) return;
      if (scanData.code!.isEmpty) return;

      _isQrDataHandling = true;

      widget.validateAddress(scanData.code!).then((_) {
        Navigator.pop(context, scanData.code!);
      }).catchError((e) {
        CustomToast.showToast(context: context, text: e.toString());
      }).whenComplete(() async {
        // 하나의 QR 스캔으로, 동시에 여러번 호출되는 것을 방지하기 위해
        await Future.delayed(const Duration(seconds: 1));
        _isQrDataHandling = false;
      });
    });
  }

  void _showAddressScanner() async {
    final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
    final scannedAddress = await CommonBottomSheets.showBottomSheet_100(
        context: context,
        child: Scaffold(
            backgroundColor: CoconutColors.black,
            appBar: CoconutAppBar.build(
                title: t.send,
                context: context,
                actionButtonList: [
                  IconButton(
                    icon: SvgPicture.asset('assets/svg/arrow-reload.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          CoconutColors.white,
                          BlendMode.srcIn,
                        )),
                    onPressed: () {
                      _qrViewController?.flipCamera();
                    },
                  ),
                ],
                onBackPressed: () {
                  _qrViewController?.dispose();
                  _qrViewController = null;
                  Navigator.of(context).pop();
                }),
            body: SendAddressBody(
                qrKey: qrKey, onQRViewCreated: _onQRViewCreated)));

    _addressController.text = scannedAddress;
    _onAddressChanged(scannedAddress);
  }
}
