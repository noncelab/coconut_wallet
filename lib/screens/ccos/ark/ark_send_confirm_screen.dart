import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_send_view_model.dart';
import 'package:coconut_wallet/screens/common/flutter_hot_wallet_authenticator.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/amount/bitcoin_amount_unit.dart';
import 'package:coconut_wallet/widgets/common/amount/fiat_price.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_send_icon.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_info_row.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

/// 보내기 최종 확인과 결과. 보내면 같은 화면에서 위쪽은 그대로 두고 상태만 바뀜
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
  ArkSendResult? _result;

  bool get _started => _sending || _result != null;

  Future<void> _send(ArkSendViewModel viewModel) async {
    if (_started) return;
    if (!await AppGuard.runWithoutPrivacyScreen(() => FlutterHotWalletAuthenticator(context).authenticate())) return;
    setState(() => _sending = true);
    final result = await viewModel.send();
    if (!mounted) return;
    setState(() {
      _sending = false;
      _result = result;
    });
  }

  /// 보낸 직후 아직 보내는 중이었으면 이후 내역 상태를 따라감
  static ArkSendOutcome? _settled(ArkSendOutcome? outcome, ArkMovementStatus? status) {
    if (outcome != ArkSendOutcome.pending || status == null) return outcome;
    return switch (status) {
      ArkMovementStatus.pending => ArkSendOutcome.pending,
      ArkMovementStatus.failed || ArkMovementStatus.canceled => ArkSendOutcome.failed,
      _ => ArkSendOutcome.sent,
    };
  }

  void _done() => Navigator.of(
    context,
  ).popUntil((route) => route.settings.name == AnalyticsScreenNames.ccosArkWalletHome || route.isFirst);

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final viewModel = context.watch<ArkSendViewModel>();
    final unit = context.select<ArkWalletProvider, BitcoinUnit>((wallet) => wallet.unit);
    final isArk = viewModel.rail == ArkPaymentRail.ark;
    final amount = viewModel.amountSats ?? 0;
    final fee = viewModel.fee ?? 0;
    String sats(int value) => unit.displayBitcoinAmount(value, withUnit: true);
    final movementId = _result?.movementId;
    final status = context.select<ArkWalletProvider, ArkMovementStatus?>(
      (wallet) => wallet.movements.where((movement) => movement.id == movementId).firstOrNull?.status,
    );
    final outcome = _sending ? ArkSendOutcome.pending : _settled(_result?.outcome, status);
    final failed = outcome == ArkSendOutcome.failed;
    final (title, description) = switch (outcome) {
      null => (isArk ? t.ark_wallet.confirm_ark : t.ark_wallet.confirm_lightning, null),
      ArkSendOutcome.pending => (t.ark_wallet.result_pending, isArk ? null : t.ark_wallet.result_pending_desc),
      ArkSendOutcome.sent => (t.ark_wallet.result_sent, null),
      ArkSendOutcome.failed => (t.ark_wallet.result_failed, t.ark_wallet.result_failed_desc),
    };
    final descriptionStyle = CoconutTypography.body2_14.setColor(colors.secondaryText);
    final longestDescription = [
      t.ark_wallet.result_pending_desc,
      t.ark_wallet.result_failed_desc,
    ].reduce((a, b) => a.length >= b.length ? a : b);
    return PopScope(
      canPop: !_started,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _result != null) _done();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: CoconutAppBar.build(
          context: context,
          backgroundColor: colors.background,
          title: '',
          isLeadingVisible: !_started,
        ),
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                CoconutLayout.spacing_400h,
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child:
                        failed
                            ? SvgPicture.asset(
                              CommonStateIconPath.circleWarning,
                              key: const Key('ark-send-result-failed'),
                              width: 56,
                              height: 56,
                              colorFilter: ColorFilter.mode(colors.danger, BlendMode.srcIn),
                            )
                            : ArkSendIcon(
                              key: ValueKey(outcome),
                              lightning: !isArk,
                              sending: outcome != ArkSendOutcome.sent,
                            ),
                  ),
                ),
                CoconutLayout.spacing_400h,
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    title,
                    key: ValueKey(title),
                    textAlign: TextAlign.center,
                    style: CoconutTypography.body1_16_Bold.setColor(failed ? colors.danger : colors.primaryText),
                  ),
                ),
                CoconutLayout.spacing_200h,
                Center(
                  child: BitcoinAmountUnit(
                    currentUnit: unit,
                    unitStyle: CoconutTypography.heading4_18_Number.setColor(colors.primaryText),
                    spacing: CoconutLayout.spacing_100w,
                    child: Text(
                      unit.displayBitcoinAmount(amount),
                      style: CoconutTypography.heading2_28_NumberBold.setColor(colors.primaryText),
                    ),
                  ),
                ),
                Center(child: FiatPrice(satoshiAmount: amount, textColor: colors.secondaryText)),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      Opacity(
                        opacity: 0,
                        child: Text(longestDescription, textAlign: TextAlign.center, style: descriptionStyle),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          description ?? '',
                          key: ValueKey<String>(description ?? ''),
                          textAlign: TextAlign.center,
                          style: descriptionStyle,
                        ),
                      ),
                    ],
                  ),
                ),
                CoconutLayout.spacing_400h,
                ArkInfoBox(
                  children: [
                    ArkInfoRow(
                      label: t.ark_wallet.route,
                      value: isArk ? t.ark_wallet.route_ark : t.ark_wallet.route_lightning,
                    ),
                    ArkInfoRow(
                      label:
                          viewModel.rail == ArkPaymentRail.lightningInvoice
                              ? t.ark_wallet.invoice
                              : t.ark_wallet.recipient,
                      value: viewModel.destination ?? '',
                      isNumber: true,
                    ),
                    if (viewModel.lightningMemo case final lightningMemo?)
                      ArkInfoRow(label: t.ark_wallet.lightning_memo, value: lightningMemo),
                    ArkInfoRow(
                      label: t.ark_wallet.arrives,
                      value: isArk ? t.ark_wallet.arrives_now : t.ark_wallet.arrives_seconds,
                    ),
                    ArkInfoRow(label: t.fee, value: sats(fee), isNumber: true),
                    ArkInfoRow(label: t.ark_wallet.total, value: sats(amount + fee), isNumber: true),
                    if (viewModel.memo.trim().isNotEmpty)
                      ArkInfoRow(label: t.ark_wallet.memo, value: viewModel.memo.trim()),
                  ],
                ),
              ],
            ),
            FixedBottomButton(
              text: _result == null ? t.send : t.done,
              isActive: !_sending,
              onButtonClicked: _result == null ? () => _send(viewModel) : _done,
            ),
          ],
        ),
      ),
    );
  }
}
