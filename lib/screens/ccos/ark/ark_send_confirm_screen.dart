import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_send_view_model.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_send_result_screen.dart';
import 'package:coconut_wallet/screens/common/flutter_hot_wallet_authenticator.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_info_row.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 보내기 최종 확인. 받는 주소, 경로, 도착 예상, 수수료, 합계
class ArkSendConfirmScreen extends StatefulWidget {
  const ArkSendConfirmScreen({super.key});

  static Future<void> open(BuildContext context, ArkSendViewModel viewModel) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletSendConfirm),
      builder: (_) => ChangeNotifierProvider.value(value: viewModel, child: const ArkSendConfirmScreen()),
    ),
  );

  @override
  State<ArkSendConfirmScreen> createState() => _ArkSendConfirmScreenState();
}

class _ArkSendConfirmScreenState extends State<ArkSendConfirmScreen> {
  bool _sending = false;

  Future<void> _send(ArkSendViewModel viewModel) async {
    if (_sending) return;
    if (!await AppGuard.runWithoutPrivacyScreen(() => FlutterHotWalletAuthenticator(context).authenticate())) return;
    setState(() => _sending = true);
    final result = await viewModel.send();
    if (!mounted) return;
    setState(() => _sending = false);
    await ArkSendResultScreen.replace(context, viewModel, result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final viewModel = context.watch<ArkSendViewModel>();
    final unit = context.select<PreferenceProvider, BitcoinUnit>((preferences) => preferences.currentUnit);
    final isArk = viewModel.rail == ArkPaymentRail.ark;
    final amount = viewModel.amountSats ?? 0;
    final fee = viewModel.fee ?? 0;
    String sats(int value) => unit.displayBitcoinAmount(value, withUnit: true);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(context: context, title: ''),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              Text(
                isArk ? t.ark_wallet.confirm_ark : t.ark_wallet.confirm_lightning,
                style: CoconutTypography.heading3_21_Bold.setColor(colors.primaryText),
              ),
              CoconutLayout.spacing_300h,
              BitcoinAmountUnit(
                currentUnit: unit,
                unitStyle: CoconutTypography.heading4_18_Number.setColor(colors.primaryText),
                spacing: CoconutLayout.spacing_100w,
                child: Text(
                  unit.displayBitcoinAmount(amount),
                  style: CoconutTypography.heading2_28_NumberBold.setColor(colors.primaryText),
                ),
              ),
              CoconutLayout.spacing_500h,
              ArkInfoRow(label: t.ark_wallet.recipient, value: viewModel.destination ?? '', isNumber: true),
              ArkInfoRow(
                label: t.ark_wallet.route,
                value: isArk ? t.ark_wallet.route_ark : t.ark_wallet.route_lightning,
              ),
              ArkInfoRow(
                label: t.ark_wallet.arrives,
                value: isArk ? t.ark_wallet.arrives_now : t.ark_wallet.arrives_seconds,
              ),
              ArkInfoRow(label: t.fee, value: fee == 0 ? t.ark_wallet.fee_free : sats(fee), isNumber: fee != 0),
              ArkInfoRow(label: t.ark_wallet.total, value: sats(amount + fee), isNumber: true),
            ],
          ),
          FixedBottomButton(text: t.send, isActive: !_sending, onButtonClicked: () => _send(viewModel)),
        ],
      ),
    );
  }
}
