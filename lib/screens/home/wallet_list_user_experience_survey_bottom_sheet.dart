import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';

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
        appBar: isFirst
            ? null
            : CoconutAppBar.build(
                context: context,
                title: '',
                hasRightIcon: false,
                isBottom: true,
              ),
        backgroundColor: MyColors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/splash_logo.png',
              ),
              const SizedBox(height: 30),
              if (isFirst)
                Text(
                  t.user_experience_survey_bottom_sheet.text1,
                  style: Styles.h3,
                ),
              Text(
                t.user_experience_survey_bottom_sheet.text2,
                style: Styles.h3,
              ),
              const SizedBox(
                height: 80,
              ),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/positive-feedback'),
                child: Container(
                    width: MediaQuery.of(context).size.width * 0.5,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: MyColors.primary),
                    child: Text(
                      t.user_experience_survey_bottom_sheet.text3,
                      style: Styles.label.merge(const TextStyle(
                          color: MyColors.darkgrey,
                          fontWeight: FontWeight.bold)),
                      textAlign: TextAlign.center,
                    )),
              ),
              const SizedBox(
                height: 20,
              ),
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, '/negative-feedback');
                },
                child: Container(
                    width: MediaQuery.of(context).size.width * 0.5,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: MyColors.transparentWhite_15),
                    child: Text(
                      t.user_experience_survey_bottom_sheet.text4,
                      style: Styles.label.merge(const TextStyle(
                          color: MyColors.white, fontWeight: FontWeight.bold)),
                      textAlign: TextAlign.center,
                    )),
              ),
              const SizedBox(
                height: 40,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
