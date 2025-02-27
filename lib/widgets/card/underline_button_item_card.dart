import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/custom_chip.dart';
import 'package:flutter/cupertino.dart';

class UnderlineButtonItemCard extends StatelessWidget {
  final String label;
  final bool isChangeTagVisible;
  final Widget child;
  final String? underlineButtonLabel;
  final VoidCallback? onTapUnderlineButton;

  const UnderlineButtonItemCard(
      {super.key,
      required this.label,
      this.isChangeTagVisible = false,
      required this.child,
      this.underlineButtonLabel,
      this.onTapUnderlineButton});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 16,
        horizontal: 2,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Text(label,
                style: CoconutTypography.body2_14
                    .copyWith(color: CoconutColors.gray500)),
            const SizedBox(width: 6),
            if (isChangeTagVisible) const CustomChip(text: '잔돈'),
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
                    lineHeight: 18,
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 4),
          child
        ],
      ),
    );
  }
}
