import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:flutter/material.dart';

const _divider = Divider(color: CoconutColors.gray800);

class UnderlineButtonItemCard extends StatelessWidget {
  final String label;
  final Widget child;
  final String? underlineButtonLabel;
  final VoidCallback? onTapUnderlineButton;
  final bool? showDivider;

  const UnderlineButtonItemCard({
    super.key,
    required this.label,
    required this.child,
    this.underlineButtonLabel,
    this.onTapUnderlineButton,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 2, right: 2, bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(label, style: CoconutTypography.body2_14.copyWith(color: CoconutColors.gray400, height: 1.0)),
              CoconutLayout.spacing_100w,
              if (underlineButtonLabel != null)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: CustomUnderlinedButton(
                      text: underlineButtonLabel!,
                      onTap: () {
                        if (onTapUnderlineButton != null) {
                          onTapUnderlineButton!();
                        }
                      },
                      fontSize: 12,
                      lineHeight: 12,
                    ),
                  ),
                ),
            ],
          ),
          CoconutLayout.spacing_100h,
          child,
          CoconutLayout.spacing_300h,
          if (showDivider == true) _divider,
        ],
      ),
    );
  }
}
