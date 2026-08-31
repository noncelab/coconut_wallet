import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

// Usage
// wallet_list_screen.dart
// broadcast_complete_screen.dart (app_reveiw_service.dart가 호출)
class UserExperienceSurveyBottomSheet extends StatelessWidget {
  final bool isFirst;

  const UserExperienceSurveyBottomSheet({super.key, this.isFirst = false});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !isFirst) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar:
            isFirst
                ? null
                : CoconutAppBar.build(
                  context: context,
                  title: '',
                  customTitle: const SizedBox.shrink(),
                  onBackPressed: null,
                  isBottom: true,
                  backgroundColor: Colors.transparent,
                ),
        backgroundColor: context.coconutColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    AppIconPath.coconut,
                    colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
                  ),
                  const SizedBox(height: 30),
                  if (isFirst)
                    FittedBox(
                      child: Text(
                        t.user_experience_survey_bottom_sheet.text1,
                        style: CoconutTypography.heading3_21_Bold.setColor(context.coconutColors.primaryText),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  Text(
                    t.user_experience_survey_bottom_sheet.text2,
                    style: CoconutTypography.heading3_21_Bold.setColor(context.coconutColors.primaryText),
                  ),
                  const SizedBox(height: 80),
                  GestureDetector(
                    onTap: () => Navigator.pushNamed(context, '/positive-feedback'),
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.5,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: context.coconutColors.brandAccentBackground,
                      ),
                      child: Text(
                        t.user_experience_survey_bottom_sheet.text3,
                        style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.brandAccentForeground),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/negative-feedback');
                    },
                    child: Container(
                      width: MediaQuery.of(context).size.width * 0.5,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: context.coconutColors.buttonPrimaryBackground.withValues(alpha: 0.5),
                      ),
                      child: Text(
                        t.user_experience_survey_bottom_sheet.text4,
                        style: CoconutTypography.body2_14_Bold.setColor(context.coconutColors.buttonPrimaryForeground),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
