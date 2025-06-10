import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

class LightningDonationInfoScreen extends StatefulWidget {
  final int donationAmount;
  const LightningDonationInfoScreen({
    super.key,
    required this.donationAmount,
  });

  @override
  State<LightningDonationInfoScreen> createState() => _LightningDonationInfoScreenState();
}

class _LightningDonationInfoScreenState extends State<LightningDonationInfoScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CoconutAppBar.build(
        title: t.donation.donate,
        context: context,
        backgroundColor: CoconutColors.black,
        isBottom: true,
      ),
      resizeToAvoidBottomInset: false,
      body: Container(
        child: Text('라이트닝 donationAmount${widget.donationAmount}'),
      ),
    );
  }
}
