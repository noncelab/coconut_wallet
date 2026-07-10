import 'dart:io' show Platform;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class TrezorConnectScreen extends StatelessWidget {
  const TrezorConnectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final steps =
        Platform.isIOS
            ? [
              t.wallet_connect_screen.guide_bitbox02.init.ble_step1,
              t.wallet_connect_screen.guide_bitbox02.init.ble_step2,
              t.wallet_connect_screen.guide_bitbox02.init.ble_step3(
                btn: t.wallet_connect_screen.guide_bitbox02.btn.connect_via_ble,
              ),
            ]
            : [
              t.wallet_connect_screen.guide_bitbox02.init.step1,
              t.wallet_connect_screen.guide_bitbox02.init.step2,
              t.wallet_connect_screen.guide_bitbox02.init.step3(
                btn: t.wallet_connect_screen.guide_bitbox02.btn.connect_via_usb,
              ),
            ];

    return Scaffold(
      backgroundColor: context.coconutColors.background,
      appBar: CoconutAppBar.build(title: 'Trezor', context: context, isBottom: true),
      body: SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height,
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
                  child: _buildInstructionToolTip(context, steps),
                ),
              ),
              Stack(
                alignment: Alignment.center,
                children: [
                  FixedBottomButton(
                    onButtonClicked: () {},
                    text:
                        Platform.isIOS
                            ? t.wallet_connect_screen.guide_bitbox02.btn.connect_via_ble
                            : t.wallet_connect_screen.guide_bitbox02.btn.connect_via_usb,
                    isActive: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionToolTip(BuildContext context, List<String> steps) {
    return CoconutToolTip(
      backgroundColor: context.coconutColors.surface,
      borderColor: context.coconutColors.surface,
      icon: SvgPicture.asset(
        'assets/svg/circle-info.svg',
        width: 20,
        colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
      ),
      tooltipType: CoconutTooltipType.fixed,
      richText: RichText(
        text: TextSpan(
          style: CoconutTypography.body2_14,
          children:
              steps.asMap().entries.expand((entry) {
                final isLast = entry.key == steps.length - 1;
                return [
                  TextSpan(
                    text: '${entry.key + 1}. ',
                    style: TextStyle(color: context.coconutColors.primaryText),
                  ),
                  TextSpan(text: entry.value, style: TextStyle(color: context.coconutColors.primaryText)),
                  if (!isLast) const TextSpan(text: '\n'),
                ];
              }).toList(),
        ),
      ),
    );
  }
}
