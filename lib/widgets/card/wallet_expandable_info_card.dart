import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

class WalletExpandableInfoCard extends StatefulWidget {
  const WalletExpandableInfoCard({super.key});

  @override
  State<WalletExpandableInfoCard> createState() => _WalletExpandableInfoCardState();
}

class _WalletExpandableInfoCardState extends State<WalletExpandableInfoCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(CoconutStyles.radius_200),
      decoration: const BoxDecoration(
        color: CoconutColors.gray800,
        borderRadius: BorderRadius.all(Radius.circular(CoconutStyles.radius_200)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              color: Colors.transparent,
              child: Row(
                children: [
                  SvgPicture.asset(
                    _isExpanded ? 'assets/svg/circle-warning.svg' : 'assets/svg/circle-help.svg',
                    width: 18,
                    colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                  ),
                  CoconutLayout.spacing_100w,
                  Expanded(
                    child: Text(t.wallet_add_input_screen.wallet_description_text, style: CoconutTypography.body2_14),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            CoconutLayout.spacing_200h,
            _buildWalletInfoSection(
              titleText: t.wallet_add_input_screen.blue_wallet_texts[0],
              descriptionList: [...t.wallet_add_input_screen.blue_wallet_texts.getRange(1, 3)],
              addressText: t.wallet_add_input_screen.blue_wallet_texts[3],
            ),
            CoconutLayout.spacing_200h,
            _buildWalletInfoSection(
              titleText: t.wallet_add_input_screen.nunchuck_wallet_texts[0],
              descriptionList: [...t.wallet_add_input_screen.nunchuck_wallet_texts.getRange(1, 2)],
              addressText:
                  Platform.isAndroid
                      ? t.wallet_add_input_screen.nunchuck_wallet_texts[2]
                      : t.wallet_add_input_screen.nunchuck_wallet_texts[3],
            ),
            CoconutLayout.spacing_200h,
          ],
        ],
      ),
    );
  }

  Widget _buildWalletInfoSection({
    required String titleText,
    required List<String> descriptionList,
    required String addressText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(titleText, style: CoconutTypography.body3_12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sizes.size12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...descriptionList.map((desc) => Text(desc, style: CoconutTypography.body3_12)),
              CoconutLayout.spacing_200h,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Sizes.size8),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: CoconutColors.black,
                    borderRadius: BorderRadius.all(Radius.circular(CoconutStyles.radius_100)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: Sizes.size12, vertical: Sizes.size8),
                  child: RichText(
                    text: TextSpan(
                      text: addressText.substring(0, 4),
                      style:
                          addressText.startsWith("zpub")
                              ? CoconutTypography.body3_12_NumberBold
                              : CoconutTypography.body3_12_Number,
                      children: [TextSpan(text: addressText.substring(4), style: CoconutTypography.body3_12_Number)],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
