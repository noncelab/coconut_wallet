import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class DonationBannerCard extends StatefulWidget {
  final int walletListLength;
  const DonationBannerCard({
    super.key,
    required this.walletListLength,
  });

  @override
  State<DonationBannerCard> createState() => _DonationBannerCardState();
}

class _DonationBannerCardState extends State<DonationBannerCard>
    with SingleTickerProviderStateMixin {
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(context, '/select-donation-amount',
            arguments: {'wallet-list-length': widget.walletListLength});
      },
      onTapDown: (_) {
        setState(() {
          _isTapped = true;
        });
      },
      onTapUp: (_) {
        setState(() {
          _isTapped = false;
        });
      },
      onTapCancel: () {
        setState(() {
          _isTapped = false;
        });
      },
      child: Container(
        width: double.maxFinite,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(CoconutStyles.radius_400),
          color: _isTapped ? CoconutColors.gray900 : CoconutColors.gray800,
        ),
        margin: const EdgeInsets.only(
          left: CoconutLayout.defaultPadding,
          right: CoconutLayout.defaultPadding,
          bottom: 12,
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.donation.donate,
                    style: CoconutTypography.body3_12,
                  ),
                  Text(
                    t.donation.supportImpactMessage,
                    style: CoconutTypography.body2_14_Bold,
                  ),
                ],
              ),
            ),
            CoconutLayout.spacing_300w,
            Lottie.asset(
              'assets/lottie/hand-with-floating-heart.json',
              width: 82,
              height: 82,
            ),
          ],
        ),
      ),
    );
  }
}
