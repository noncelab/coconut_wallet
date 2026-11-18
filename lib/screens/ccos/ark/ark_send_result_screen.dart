import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_send_view_model.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_info_row.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 보내기 결과. 완료하면 아크 지갑 홈으로
class ArkSendResultScreen extends StatelessWidget {
  const ArkSendResultScreen({super.key, required this.result});

  final ArkSendResult result;

  static Future<void> replace(BuildContext context, ArkSendViewModel viewModel, ArkSendResult result) =>
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletSendResult),
          builder: (_) => ChangeNotifierProvider.value(value: viewModel, child: ArkSendResultScreen(result: result)),
        ),
      );

  void _done(BuildContext context) => Navigator.of(
    context,
  ).popUntil((route) => route.settings.name == AnalyticsScreenNames.ccosArkWalletHome || route.isFirst);

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final viewModel = context.watch<ArkSendViewModel>();
    final unit = context.select<PreferenceProvider, BitcoinUnit>((preferences) => preferences.currentUnit);
    final amount = viewModel.amountSats ?? 0;
    final fee = viewModel.fee ?? 0;
    final isArk = viewModel.rail == ArkPaymentRail.ark;
    final (title, description) = switch (result.outcome) {
      ArkSendOutcome.sent => (t.ark_wallet.result_sent, null),
      ArkSendOutcome.pending => (t.ark_wallet.result_pending, t.ark_wallet.result_pending_desc),
      ArkSendOutcome.failed => (t.ark_wallet.result_failed, t.ark_wallet.result_failed_desc),
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _done(context);
      },
      child: Scaffold(
        backgroundColor: colors.background,
        body: SafeArea(
          child: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 40, 16, 120),
                children: [
                  Text(
                    '$title  ${unit.displayBitcoinAmount(amount, withUnit: true)}',
                    style: CoconutTypography.heading3_21_Bold.setColor(
                      result.outcome == ArkSendOutcome.failed ? colors.danger : colors.primaryText,
                    ),
                  ),
                  if (description != null) ...[
                    CoconutLayout.spacing_200h,
                    Text(description, style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
                  ],
                  CoconutLayout.spacing_500h,
                  ArkInfoRow(label: t.ark_wallet.recipient, value: viewModel.destination ?? '', isNumber: true),
                  ArkInfoRow(
                    label: t.ark_wallet.route,
                    value: isArk ? t.ark_wallet.route_ark : t.ark_wallet.route_lightning,
                  ),
                  if (result.outcome != ArkSendOutcome.failed)
                    ArkInfoRow(
                      label: t.fee,
                      value: fee == 0 ? t.ark_wallet.fee_free : unit.displayBitcoinAmount(fee, withUnit: true),
                      isNumber: fee != 0,
                    ),
                ],
              ),
              FixedBottomButton(text: t.done, onButtonClicked: () => _done(context)),
            ],
          ),
        ),
      ),
    );
  }
}
