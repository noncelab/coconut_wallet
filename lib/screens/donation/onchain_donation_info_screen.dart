import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/button/copy_text_container.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

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
  get s => null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CoconutAppBar.build(
        title: t.donation.donate,
        context: context,
        backgroundColor: CoconutColors.black,
      ),
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Container(
                width: MediaQuery.sizeOf(context).width,
                padding: const EdgeInsets.only(left: 28, right: 28, top: 30, bottom: 60),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    _buildWalletSelectionWidget(),
                    _divider(),
                    _buildDonationAmountInfoWidget(),
                    _divider(),
                    _buildDonationAddressWidget(),
                  ],
                ),
              ),
            ),
            FixedBottomButton(
              onButtonClicked: () {},
              text: t.next,
              backgroundColor: CoconutColors.gray100,
              pressedBackgroundColor: CoconutColors.gray500,
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider() {
    return const Column(
      children: [
        CoconutLayout.spacing_400h,
        Divider(
          height: 1,
          color: CoconutColors.gray600,
        ),
        CoconutLayout.spacing_400h,
      ],
    );
  }

  Widget _buildWalletSelectionWidget() {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            t.donation.donation_wallet,
            style: CoconutTypography.body2_14_Bold.setColor(
              CoconutColors.white,
            ),
          ),
          Text(
            '지갑',
            style: CoconutTypography.body2_14_NumberBold.setColor(
              CoconutColors.gray400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationAmountInfoWidget() {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                // TODO 후원금액 - 수수료
                t.donation.total_donation_amount,
                style: CoconutTypography.body2_14_Bold.setColor(
                  CoconutColors.white,
                ),
              ),
              Text(
                '4451 sats',
                style: CoconutTypography.body2_14_NumberBold.setColor(
                  CoconutColors.gray400,
                ),
              ),
            ],
          ),
          CoconutLayout.spacing_300h,
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.donation.donation_amount,
                  style: CoconutTypography.body2_14_Bold.setColor(
                    CoconutColors.white,
                  ),
                ),
                Text(
                  '${widget.donationAmount} ${t.sats}',
                  style: CoconutTypography.body2_14_NumberBold.setColor(
                    CoconutColors.gray400,
                  ),
                ),
              ],
            ),
          ),
          CoconutLayout.spacing_300h,
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.fee,
                  style: CoconutTypography.body2_14_Bold.setColor(
                    CoconutColors.white,
                  ),
                ),
                Text(
                  // TODO 수수료
                  '549 ${t.sats}',
                  style: CoconutTypography.body2_14_NumberBold.setColor(
                    CoconutColors.gray400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationAddressWidget() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            t.donation.donation_address,
            style: CoconutTypography.body2_14_Bold.setColor(
              CoconutColors.white,
            ),
          ),
        ),
        CoconutLayout.spacing_500h,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
            child: QrImageView(
              backgroundColor: CoconutColors.white,
              // TODO: QR Data
              data: 'bc1q3hyfj96kcmzlkfpxqxs6f0nksqf7rc9tfzkdqk',
              version: QrVersions.auto,
            ),
          ),
        ),
        CoconutLayout.spacing_600h,
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: CopyTextContainer(
            // TODO: QR Data
            text: 'bc1q3hyfj96kcmzlkfpxqxs6f0nksqf7rc9tfzkdqk',
            textStyle: CoconutTypography.body2_14,
          ),
        ),
      ],
    );
  }
}
