import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/speed_app_ln_invoice_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/button/copy_text_container.dart';
import 'package:coconut_wallet/widgets/overlays/coconut_loading_overlay.dart';
import 'package:coconut_wallet/widgets/qrcode.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class LightningDonationInfoScreen extends StatefulWidget {
  final int donationAmount;
  const LightningDonationInfoScreen({super.key, required this.donationAmount});

  @override
  State<LightningDonationInfoScreen> createState() => _LightningDonationInfoScreenState();
}

class _LightningDonationInfoScreenState extends State<LightningDonationInfoScreen> {
  final SpeedAppLnInvoiceService _lnInvoiceService = SpeedAppLnInvoiceService();
  final String _lnAppScheme = "lightning";
  String? _lnInvoice;
  bool _hasLnInvoice = false;
  bool _hasLnApp = false;
  bool _isInitialized = false;

  bool get canLaunchLnApp => Platform.isAndroid && _hasLnApp; // iOS의 경우 라이트닝앱 선택이 불가능하므로 제외

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    Future.wait([getLnInvoice(), checkLnAppAvailability()]).then((_) {
      _isInitialized = true;
      setState(() {});
    });
  }

  Future<void> checkLnAppAvailability() async {
    _hasLnApp = await canLaunchUrl(Uri.parse("$_lnAppScheme:"));
    Logger.log("_hasLnApp = $_hasLnApp");
  }

  Future<void> getLnInvoice() async {
    try {
      _lnInvoice = await _lnInvoiceService.getLnInvoiceOfPow(widget.donationAmount);
      _hasLnInvoice = true;
      Logger.log(_lnInvoice);
    } catch (e) {
      _lnInvoice = null;
      _hasLnInvoice = false;
      Logger.log(e);
      if (mounted) {
        CoconutToast.showWarningToast(context: context, text: t.donation.ln_invoice_api_error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CoconutAppBar.build(
        title: t.donation.donate,
        context: context,
        backgroundColor: CoconutColors.black,
        isBottom: false,
      ),
      resizeToAvoidBottomInset: false,
      backgroundColor: CoconutColors.black,
      body:
          !_isInitialized
              ? const CoconutLoadingOverlay()
              : Padding(
                padding: const EdgeInsets.only(left: CoconutLayout.defaultPadding, right: CoconutLayout.defaultPadding),
                child: Column(
                  children: [
                    CoconutLayout.spacing_800h,
                    QrCode(qrData: _lnInvoice != null ? _lnInvoice! : t.donation.ln_address_pow),
                    CoconutLayout.spacing_800h,
                    _buildDonationAmountRow(),
                    CoconutLayout.spacing_300h,
                    IgnorePointer(
                      ignoring: _lnInvoice == null,
                      child: CopyTextContainer(
                        text: t.donation.ln_invoice,
                        middleText:
                            _lnInvoice != null
                                ? "${_lnInvoice!.substring(0, 7)}... ${_lnInvoice!.substring(_lnInvoice!.length - 7)}"
                                : null,
                        textStyle: CoconutTypography.body2_14_Bold,
                        copyText: _lnInvoice,
                        showButton: _lnInvoice != null,
                      ),
                    ),
                    CoconutLayout.spacing_300h,
                    CopyTextContainer(
                      text: t.donation.ln_address,
                      middleText: t.donation.ln_address_pow,
                      textStyle: CoconutTypography.body2_14_Bold,
                      copyText: t.donation.ln_address_pow,
                    ),
                    const Spacer(),
                    if (canLaunchLnApp)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Sizes.size30),
                        child: CoconutButton(
                          isActive: _hasLnInvoice,
                          backgroundColor: CoconutColors.white,
                          foregroundColor: CoconutColors.black,
                          pressedTextColor: CoconutColors.gray500,
                          pressedBackgroundColor: CoconutColors.gray300,
                          disabledBackgroundColor: CoconutColors.gray600,
                          onPressed: () async {
                            await launchUrl(
                              Uri.parse("$_lnAppScheme:$_lnInvoice"),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          text: t.donation.donate,
                        ),
                      ),
                  ],
                ),
              ),
    );
  }

  Widget _buildDonationAmountRow() {
    return Row(
      children: [
        Expanded(
          child: Text(
            t.donation.donation_amount,
            textAlign: TextAlign.start,
            style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
          ),
        ),
        CoconutLayout.spacing_400w,
        Text(
          "${widget.donationAmount.toThousandsSeparatedString()} ${t.sats}",
          style: CoconutTypography.body2_14_Number.setColor(CoconutColors.gray400),
        ),
        CoconutLayout.spacing_100w,
      ],
    );
  }
}
