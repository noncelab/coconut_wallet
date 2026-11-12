import 'dart:io';

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/ark/ark_fee_guide.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';

class ArkConsent {
  const ArkConsent({required this.autoRefresh});

  final bool autoRefresh;
}

/// 아크를 켜기 전 동의, 취소하면 null
Future<ArkConsent?> showArkConsentSheet(
  BuildContext context, {
  required Future<ArkFeeGuide?> Function() loadFeeGuide,
  bool initialAutoRefresh = true,
}) {
  final mediaQuery = MediaQuery.of(context);
  final feeGuide = loadFeeGuide();
  return CommonBottomSheets.showDraggableBottomSheet<ArkConsent>(
    context: context,
    screenName: AnalyticsScreenNames.arkConsentSheet,
    title: t.ark.consent.title,
    minChildSize: 0.75,
    initialChildSize: 0.75,
    maxChildSize: 1 - mediaQuery.padding.top / mediaQuery.size.height,
    adjustForKeyboardInset: false,
    childBuilder:
        (scrollController) => ArkConsentSheet(
          scrollController: scrollController,
          feeGuide: feeGuide,
          initialAutoRefresh: initialAutoRefresh,
          onAgree: (consent) => Navigator.pop(context, consent),
        ),
  );
}

class ArkConsentSheet extends StatefulWidget {
  const ArkConsentSheet({
    super.key,
    required this.scrollController,
    required this.feeGuide,
    this.initialAutoRefresh = true,
    required this.onAgree,
  });

  final ScrollController scrollController;

  final Future<ArkFeeGuide?> feeGuide;
  final bool initialAutoRefresh;
  final ValueChanged<ArkConsent> onAgree;

  @override
  State<ArkConsentSheet> createState() => _ArkConsentSheetState();
}

class _ArkConsentSheetState extends State<ArkConsentSheet> {
  late bool _autoRefresh = widget.initialAutoRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final buttonHeight = FixedBottomButton.fixedBottomButtonDefaultHeight + (Platform.isAndroid ? 0 : 3);
    return Stack(
      children: [
        SingleChildScrollView(
          controller: widget.scrollController,
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            buttonHeight +
                FixedBottomButton.fixedBottomButtonDefaultBottomPadding +
                MediaQuery.paddingOf(context).bottom +
                40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final text in [
                t.ark.consent.payments,
                t.ark.consent.memory,
                t.ark.consent.server,
                t.ark.consent.expiry,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(color: colors.secondaryText, shape: BoxShape.circle),
                        ),
                      ),
                      CoconutLayout.spacing_200w,
                      Expanded(child: Text(text, style: CoconutTypography.body2_14.setColor(colors.primaryText))),
                    ],
                  ),
                ),
              CoconutLayout.spacing_200h,
              _buildAutoRefresh(),
              CoconutLayout.spacing_300h,
              _buildFeeGuide(),
            ],
          ),
        ),
        FixedBottomButton(
          buttonKey: const ValueKey('ark-consent-agree'),
          isVisibleAboveKeyboard: false,
          horizontalPadding: 16,
          showSurroundings: true,
          surroundingsColor: colors.surfaceBottomSheet,
          text: t.ark.consent.agree,
          onButtonClicked: () => widget.onAgree(ArkConsent(autoRefresh: _autoRefresh)),
        ),
      ],
    );
  }

  Widget _buildAutoRefresh() {
    final colors = context.coconutColors;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(CoconutStyles.radius_200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleButton(
            key: const ValueKey('ark-consent-auto-refresh'),
            title: t.ark.consent.auto_refresh_title,
            titleStyle: CoconutTypography.body1_16_Bold.setColor(colors.primaryText),
            subtitle: t.ark.consent.auto_refresh_description,
            isVerticalSubtitle: true,
            subtitleStyle: CoconutTypography.body3_12.setColor(colors.secondaryText),
            customPadding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            onPressed: () => setState(() => _autoRefresh = !_autoRefresh),
            rightElement: CoconutSwitch(
              isOn: _autoRefresh,
              scale: 0.75,
              activeTrackColor: colors.switchActiveTrack,
              activeThumbColor: colors.switchActiveThumb,
              inactiveTrackColor: colors.switchInactiveTrack,
              inactiveThumbColor: colors.switchInactiveThumb,
              onChanged: (value) => setState(() => _autoRefresh = value),
            ),
          ),
          if (!_autoRefresh) ...[
            CoconutLayout.spacing_300h,
            Text(
              t.ark.consent.auto_refresh_off_warning,
              key: const ValueKey('ark-consent-auto-refresh-warning'),
              style: CoconutTypography.body3_12.setColor(colors.dangerText),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFeeGuide() {
    final colors = context.coconutColors;
    return Container(
      key: const ValueKey('ark-consent-fees'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(CoconutStyles.radius_200)),
      child: FutureBuilder<ArkFeeGuide?>(
        future: widget.feeGuide,
        builder: (context, snapshot) {
          final guide = snapshot.data;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(t.ark.consent.fee_title, style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText)),
              CoconutLayout.spacing_100h,
              Text(t.ark.consent.fee_note, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
              CoconutLayout.spacing_300h,
              Divider(height: 1, thickness: 1, color: colors.divider),
              CoconutLayout.spacing_300h,
              if (snapshot.connectionState != ConnectionState.done)
                Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: colors.secondaryText),
                    ),
                    CoconutLayout.spacing_200w,
                    Expanded(
                      child: Text(
                        t.ark.consent.fee_loading,
                        style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                      ),
                    ),
                  ],
                )
              else if (guide == null)
                Text(t.ark.consent.fee_unavailable, style: CoconutTypography.body3_12.setColor(colors.secondaryText))
              else
                for (final (index, row) in _feeRows(guide).indexed)
                  _buildFeeRow(row.$1, row.$2, row.$3, isLast: index == _feeRows(guide).length - 1),
            ],
          );
        },
      ),
    );
  }

  List<(String, ArkFeeRate, String?)> _feeRows(ArkFeeGuide guide) => [
    (t.ark.consent.fee_ark, ArkFeeGuide.arkPayment, null),
    (t.ark.consent.fee_ln_receive, guide.lightningReceive, null),
    (t.ark.consent.fee_ln_send, guide.lightningSend, null),
    (t.ark.consent.fee_board, guide.board, t.ark.consent.fee_plus_onchain),
    (t.ark.consent.fee_offboard, guide.offboard, t.ark.consent.fee_plus_onchain),
    (t.ark.consent.fee_refresh, guide.refresh, t.ark.consent.fee_refresh_hint),
  ];

  Widget _buildFeeRow(String label, ArkFeeRate rate, String? extra, {bool isLast = false}) {
    final colors = context.coconutColors;
    final details = [if (rate.minFeeSats > 0) t.ark.consent.fee_min(sats: rate.minFeeSats), if (extra != null) extra];
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: CoconutTypography.body3_12.setColor(colors.secondaryText))),
          CoconutLayout.spacing_300w,
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                t.ark.consent.fee_percent(value: rate.percentText),
                style: CoconutTypography.body3_12_Bold.setColor(colors.primaryText),
              ),
              for (final detail in details)
                Text(detail, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
            ],
          ),
        ],
      ),
    );
  }
}
