import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_about_screen.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter/material.dart';

/// 아크 지갑을 만들거나 복원하기 전 확인. 확인하면 true
Future<bool> showArkConsentSheet(BuildContext context, {bool restoring = false}) async =>
    await CommonBottomSheets.showBottomSheet<bool>(
      context: context,
      title: t.ark_wallet.consent_title,
      screenName: AnalyticsScreenNames.ccosArkWalletConsent,
      showDragHandle: true,
      adjustForKeyboardInset: false,
      child: _ArkConsentContent(restoring: restoring),
    ) ??
    false;

class _ArkConsentContent extends StatelessWidget {
  const _ArkConsentContent({required this.restoring});

  final bool restoring;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final items = [
      t.ark_wallet.consent_refresh,
      t.ark_wallet.consent_lightning,
      t.ark_wallet.consent_same_words,
      t.ark_wallet.consent_seed_memory,
      if (restoring) t.ark_wallet.consent_restore_history,
    ];
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.6,
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(CoconutLayout.defaultPadding, 0, CoconutLayout.defaultPadding, 180),
            children: [
              Text(
                TextUtils.preventLineBreakInsideWords(t.ark_wallet.consent_lead),
                style: CoconutTypography.body2_14.setColor(colors.primaryText),
              ),
              CoconutLayout.spacing_400h,
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('•', style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
                      CoconutLayout.spacing_200w,
                      Expanded(
                        child: Text(
                          TextUtils.preventLineBreakInsideWords(item),
                          style: CoconutTypography.body2_14.setColor(colors.primaryText),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          FixedBottomButton(
            text: t.ark_wallet.consent_confirm,
            onButtonClicked: () => Navigator.of(context).pop(true),
            isVisibleAboveKeyboard: false,
            surroundingsColor: colors.surfaceBottomSheet,
            subWidget: CoconutUnderlinedButton(
              key: const Key('ark-consent-about'),
              text: t.ark_wallet.about_row,
              onTap: () => ArkAboutScreen.open(context),
            ),
          ),
        ],
      ),
    );
  }
}
