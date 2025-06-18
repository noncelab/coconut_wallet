import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

class OnchainDonationInfoScreen extends StatefulWidget {
  final int donationAmount;
  const OnchainDonationInfoScreen({
    super.key,
    required this.donationAmount,
  });

  @override
  State<OnchainDonationInfoScreen> createState() => _OnchainDonationInfoScreenState();
}

class _OnchainDonationInfoScreenState extends State<OnchainDonationInfoScreen> {
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
        child:  Text('온체인 donationAmount${widget.donationAmount}'),
      ),
    );
  }
}
