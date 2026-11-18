import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature_copy.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 아크 지갑이 없을 때의 시작 화면
class ArkWalletWelcomeView extends StatelessWidget {
  const ArkWalletWelcomeView({super.key, required this.onCreateNew, required this.onRestore});

  final VoidCallback onCreateNew;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          CoconutLayout.defaultPadding,
          0,
          CoconutLayout.defaultPadding,
          FixedBottomButton.fixedBottomButtonDefaultBottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/images/ccos/ark_illustration.svg',
                    width: 220,
                    theme: SvgTheme(currentColor: colors.primaryText),
                  ),
                  CoconutLayout.spacing_500h,
                  Text(
                    ArkFeatureCopySource.current.title,
                    style: CoconutTypography.heading3_21_Bold.setColor(colors.primaryText),
                  ),
                  CoconutLayout.spacing_200h,
                  Text(
                    t.ark_wallet.welcome_line,
                    textAlign: TextAlign.center,
                    style: CoconutTypography.body1_16.setColor(colors.secondaryText),
                  ),
                ],
              ),
            ),
            InlineActionButton(text: t.ark_wallet.create_new, onPressed: onCreateNew),
            CoconutLayout.spacing_200h,
            CoconutButton(
              text: t.ark_wallet.restore,
              height: 48,
              buttonType: CoconutButtonType.none,
              onPressed: onRestore,
              foregroundColor: colors.primaryText,
            ),
          ],
        ),
      ),
    );
  }
}
