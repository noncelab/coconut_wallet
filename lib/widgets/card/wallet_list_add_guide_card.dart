import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/dashed_border_painter.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';

class WalletAdditionGuideCard extends StatefulWidget {
  final VoidCallback onPressed;

  const WalletAdditionGuideCard({
    super.key,
    required this.onPressed,
  });

  @override
  State<WalletAdditionGuideCard> createState() => _WalletAdditionGuideCardState();
}

class _WalletAdditionGuideCardState extends State<WalletAdditionGuideCard> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CoconutLayout.defaultPadding),
      child: ShrinkAnimationButton(
        defaultColor: CoconutColors.gray800,
        pressedColor: CoconutColors.gray750,
        onPressed: widget.onPressed,
        child: CustomPaint(
          painter: DashedBorderPainter(dashSpace: 4.0, dashWidth: 4.0),
          child: Container(
            width: MediaQuery.sizeOf(context).width,
            padding: const EdgeInsets.symmetric(
              vertical: 42,
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset('assets/svg/wallet-eyes.svg'),
                  CoconutLayout.spacing_100w,
                  Text(
                    t.wallet_list_add_guide_card.add_watch_only,
                    style: CoconutTypography.body2_14,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
