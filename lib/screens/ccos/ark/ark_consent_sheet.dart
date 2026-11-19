import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
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
      t.ark_wallet.consent_seed_memory,
      t.ark_wallet.consent_refresh,
      t.ark_wallet.consent_same_words,
      if (restoring) t.ark_wallet.consent_restore_history,
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CoconutLayout.defaultPadding,
        0,
        CoconutLayout.defaultPadding,
        FixedBottomButton.fixedBottomButtonDefaultBottomPadding,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          CoconutLayout.spacing_300h,
          InlineActionButton(text: t.ark_wallet.consent_confirm, onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
  }
}
