import 'dart:typed_data';

import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/ark/ark_exit.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/ark/ark_exit_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/common/flutter_hot_wallet_authenticator.dart';
import 'package:coconut_wallet/screens/send/hot_wallet_passphrase_input_sheet.dart';
import 'package:coconut_wallet/services/notification/local_notification_service.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/common/buttons/copy_text_container.dart';
import 'package:coconut_wallet/widgets/common/buttons/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/transaction/card/underline_button_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

/// 서버 없이 아크 잔액을 비트코인 주소로 꺼내는 직접 출금 화면. 한 화면에서 단계만 바뀜
class ArkExitScreen extends StatefulWidget {
  const ArkExitScreen({super.key, required this.walletId});

  final int walletId;

  @override
  State<ArkExitScreen> createState() => _ArkExitScreenState();
}

class _ArkExitScreenState extends State<ArkExitScreen> {
  late final ArkExitViewModel _viewModel = ArkExitViewModel(
    context.read<ArkProvider>(),
    context.read<WalletProvider>(),
    context.read<NodeProvider>(),
    context.read<UtxoRepository>(),
    widget.walletId,
    isManualUtxoSelection: context.read<PreferenceProvider>().isManualUtxoSelectionMode,
    notifications: LocalNotificationService.instance,
  );

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: context.coconutColors.background,
          appBar: CoconutAppBar.build(context: context, title: t.ark.exit.title),
          body: SafeArea(
            child: Stack(
              children: [
                switch (_viewModel.step) {
                  ArkExitStep.loading => const Center(child: CircularProgressIndicator()),
                  ArkExitStep.confirm => _buildConfirm(context),
                  _ => _buildProgress(context),
                },
                if (_viewModel.step == ArkExitStep.confirm)
                  FixedBottomButton(
                    isVisibleAboveKeyboard: false,
                    isActive: _viewModel.canStart,
                    text: t.ark.exit.start,
                    subWidget: _buildBlockerText(context),
                    onButtonClicked: _start,
                  ),
                if (_viewModel.step == ArkExitStep.done || _viewModel.step == ArkExitStep.failed)
                  FixedBottomButton(
                    isVisibleAboveKeyboard: false,
                    text: t.ark.exit.confirm,
                    onButtonClicked: _finish,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConfirm(BuildContext context) {
    final colors = context.coconutColors;
    final estimate = _viewModel.estimate!;
    final unit = context.read<PreferenceProvider>().currentUnit;
    final valueStyle = CoconutTypography.body2_14_Bold.setColor(colors.primaryText);
    final numberStyle = CoconutTypography.body2_14_NumberBold.setColor(colors.primaryText);
    final serverReachable = _viewModel.serverReachable;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 160),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 서버 확인 전에는 숨김
          if (serverReachable != null) ...[
            CoconutToolTip(
              backgroundColor: colors.surface,
              borderColor: colors.surface,
              icon: SvgPicture.asset(
                serverReachable ? CommonStateIconPath.megaphone : CommonStateIconPath.triangleWarning,
                width: 20,
                colorFilter: ColorFilter.mode(serverReachable ? colors.primaryText : colors.warning, BlendMode.srcIn),
              ),
              tooltipType: CoconutTooltipType.fixed,
              richText: RichText(
                text: TextSpan(
                  text: _keepWords(serverReachable ? t.ark.exit.server_ok_hint : t.ark.exit.server_down_hint),
                  style: CoconutTypography.body2_14.setColor(colors.primaryText),
                ),
              ),
            ),
            CoconutLayout.spacing_500h,
          ],
          Text(t.ark.exit.description, style: CoconutTypography.body1_16_Bold.setColor(colors.primaryText)),
          CoconutLayout.spacing_200h,
          Text(t.ark.exit.how_it_works, style: CoconutTypography.body2_14.setColor(colors.secondaryText)),
          CoconutLayout.spacing_600h,
          UnderlineButtonItemCard(
            label: t.ark.exit.amount,
            child: Text(unit.displayBitcoinAmount(estimate.amountSats, withUnit: true), style: numberStyle),
          ),
          UnderlineButtonItemCard(
            label: t.ark.exit.fee,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(unit.displayBitcoinAmount(estimate.feeSats, withUnit: true), style: numberStyle),
                CoconutLayout.spacing_100h,
                Text(t.ark.exit.fee_note, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
              ],
            ),
          ),
          UnderlineButtonItemCard(
            label: t.ark.exit.fee_utxo,
            underlineButtonLabel: t.select_utxo,
            onTapUnderlineButton: _selectUtxos,
            child: Text(
              _viewModel.selectedUtxos.isEmpty
                  ? t.ark.exit.fee_utxo_auto
                  : t.ark.exit.fee_utxo_selected(
                    count: _viewModel.selectedUtxos.length,
                    amount: unit.displayBitcoinAmount(_viewModel.selectedUtxoSats, withUnit: true),
                  ),
              style: _viewModel.selectedUtxos.isEmpty ? valueStyle : numberStyle,
            ),
          ),
          UnderlineButtonItemCard(
            label: t.ark.exit.duration,
            child: Text(t.ark.exit.duration_value, style: valueStyle),
          ),
          UnderlineButtonItemCard(
            label: t.ark.exit.destination,
            showDivider: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.ark.exit.destination_value, style: CoconutTypography.body3_12.setColor(colors.secondaryText)),
                CoconutLayout.spacing_200h,
                CopyTextContainer(
                  text: _viewModel.receiveAddress.address,
                  textStyle: CoconutTypography.body2_14_Number.setColor(colors.primaryText),
                  suffixText: '${_viewModel.receiveAddress.derivationPath} · ${_viewModel.walletName}',
                  suffixTextStyle: CoconutTypography.body3_12_Number.setColor(colors.secondaryText),
                ),
              ],
            ),
          ),
          if (estimate.expiredSats > 0) ...[
            CoconutLayout.spacing_300h,
            Text(
              t.ark.exit.expired_excluded(amount: unit.displayBitcoinAmount(estimate.expiredSats, withUnit: true)),
              style: CoconutTypography.body3_12.setColor(colors.secondaryText),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _start() async {
    if (!_viewModel.canStart) return;
    Uint8List? passphrase;
    try {
      final requiresAuthentication = context.read<AuthProvider>().isAuthEnabled;
      if (_viewModel.needsPassphrase) {
        var showIncorrectError = false;
        while (mounted) {
          passphrase = await CommonBottomSheets.showBottomSheet<Uint8List>(
            context: context,
            screenName: AnalyticsScreenNames.arkExitPassphraseSheet,
            title: t.send_confirm_screen.passphrase_input_title,
            showCloseButton: true,
            backgroundColor: context.coconutColors.surfaceBottomSheet,
            showDragHandle: true,
            titlePadding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            keyboardInsetAnimationDuration: Duration.zero,
            child: HotWalletPassphraseInputSheet(
              requiresAuthentication: requiresAuthentication,
              showIncorrectError: showIncorrectError,
              onAuthenticationStarted: () async {},
              onPassphraseInputResumed: () {},
            ),
          );
          if (!mounted || passphrase == null) return;
          final matches = await AppGuard.runWithoutPrivacyScreen(() => _viewModel.validatePassphrase(passphrase!));
          if (!mounted) return;
          if (matches) break;
          passphrase.fillRange(0, passphrase.length, 0);
          passphrase = null;
          showIncorrectError = true;
        }
      } else if (requiresAuthentication) {
        final authenticated = await AppGuard.runWithoutPrivacyScreen(
          () => FlutterHotWalletAuthenticator(context).authenticate(),
        );
        if (!mounted || !authenticated) return;
      }
      if (!mounted) return;
      context.loaderOverlay.show();
      try {
        await AppGuard.runWithoutPrivacyScreen(() => _viewModel.start(passphrase: passphrase));
      } finally {
        if (mounted) context.loaderOverlay.hide();
      }
    } catch (_) {
      if (!mounted) return;
      await showInfoDialog(
        context,
        context.read<PreferenceProvider>().language,
        t.ark.exit.failed_title,
        t.ark.exit.failed_funding,
      );
    } finally {
      passphrase?.fillRange(0, passphrase.length, 0);
    }
  }

  Future<void> _selectUtxos() async {
    final selected = await Navigator.pushNamed(
      context,
      AppRouteNames.utxoSelection,
      arguments: UtxoSelectionRouteArgs(
        selectedUtxoList: _viewModel.selectedUtxos,
        id: widget.walletId,
        currentUnit: context.read<PreferenceProvider>().currentUnit,
      ),
    );
    if (selected is List<UtxoState>) _viewModel.setSelectedUtxos(selected);
  }

  Future<void> _finish() async {
    await _viewModel.dismiss();
    if (mounted) Navigator.of(context).pop();
  }

  Widget _buildProgress(BuildContext context) {
    final colors = context.coconutColors;
    final session = _viewModel.session;
    final step = _viewModel.step;
    final isResult = step == ArkExitStep.done || step == ArkExitStep.failed;
    final unit = context.read<PreferenceProvider>().currentUnit;
    final bodyStyle = CoconutTypography.body2_14.setColor(colors.secondaryText);
    final title = switch (step) {
      ArkExitStep.preparing => t.ark.exit.preparing_title,
      ArkExitStep.exiting => t.ark.exit.exiting_title,
      ArkExitStep.waiting => t.ark.exit.waiting_title,
      ArkExitStep.claiming => t.ark.exit.claiming_title,
      ArkExitStep.done => t.ark.exit.done_title(
        amount: unit.displayBitcoinAmount(session?.receivedSats ?? session?.amountSats ?? 0, withUnit: true),
      ),
      _ => t.ark.exit.failed_title,
    };
    final bodies = <String>[
      if (step == ArkExitStep.preparing) t.ark.exit.preparing_body,
      if (step == ArkExitStep.exiting && _viewModel.txProgress != null)
        t.ark.exit.exiting_progress(
          done: _viewModel.txProgress!.done,
          total: _viewModel.txProgress!.total,
          time: _durationText(_viewModel.txProgress!.remaining),
        ),
      if (step == ArkExitStep.preparing || step == ArkExitStep.exiting || step == ArkExitStep.claiming)
        t.ark.exit.exiting_body,
      if (step == ArkExitStep.waiting) ..._waitingBodies(),
      if (step == ArkExitStep.failed) ...[
        session?.failure == ArkExitFailure.spent ? t.ark.exit.failed_spent : t.ark.exit.failed_expired,
        if (session != null) t.ark.exit.fee_refund,
      ],
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 160),
      child: Column(
        crossAxisAlignment: isResult ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          if (isResult) ...[_buildStepIcon(context, step), CoconutLayout.spacing_500h],
          Text(
            _keepWords(title),
            style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText),
            textAlign: isResult ? TextAlign.center : TextAlign.start,
          ),
          if (bodies.isNotEmpty) ...[
            CoconutLayout.spacing_200h,
            Text(
              bodies.map(_keepWords).join('\n'),
              style: bodyStyle,
              textAlign: isResult ? TextAlign.center : TextAlign.start,
            ),
          ],
          if (!isResult) ...[CoconutLayout.spacing_600h, _buildSteps(context, step)],
          if (session != null) ...[CoconutLayout.spacing_600h, _buildExitInfo(context, session)],
        ],
      ),
    );
  }

  String _durationText(Duration remaining) =>
      remaining.inHours >= 1
          ? t.ark.exit.time_hours(n: remaining.inHours)
          : t.ark.exit.time_minutes(n: remaining.inMinutes < 1 ? 1 : remaining.inMinutes);

  List<String> _waitingBodies() {
    final blocks = _viewModel.blocksLeft;
    final at = _viewModel.claimableAt;
    if (blocks == null || at == null) return const [];
    final time = _durationText(at.difference(DateTime.now()));
    final clock = DateFormat('HH:mm').format(at);
    return [
      t.ark.exit.waiting_body(time: time, blocks: blocks),
      _viewModel.notificationsAllowed == false ? t.ark.exit.waiting_no_notify : t.ark.exit.waiting_notify(time: clock),
    ];
  }

  Widget _buildExitInfo(BuildContext context, ArkExitSession session) {
    final colors = context.coconutColors;
    final unit = context.read<PreferenceProvider>().currentUnit;
    final labelStyle = CoconutTypography.body3_12.setColor(colors.secondaryText);
    final valueStyle = CoconutTypography.body3_12_NumberBold.setColor(colors.primaryText);
    Widget row(String label, Widget value) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [SizedBox(width: 80, child: Text(label, style: labelStyle)), Expanded(child: value)],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(t.ark.exit.info_title, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
        ),
        CoconutLayout.spacing_300h,
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
          ),
          child: Column(
            children: [
              row(
                t.ark.exit.amount,
                Text(
                  unit.displayBitcoinAmount(session.amountSats, withUnit: true),
                  style: valueStyle,
                  textAlign: TextAlign.right,
                ),
              ),
              CoconutLayout.spacing_300h,
              row(
                t.ark.exit.destination,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(session.destination, style: valueStyle, textAlign: TextAlign.right),
                    CoconutLayout.spacing_100h,
                    Text(
                      '${session.destinationPath} · ${_viewModel.walletName}',
                      style: CoconutTypography.body3_12_Number.setColor(colors.secondaryText),
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
              if (session.claimTxid != null) ...[
                CoconutLayout.spacing_300h,
                row(
                  t.tx_id,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(session.claimTxid!, style: valueStyle, textAlign: TextAlign.right),
                      if (_viewModel.hasClaimTransaction) ...[
                        CoconutLayout.spacing_200h,
                        CustomUnderlinedButton(
                          text: t.view_tx_details,
                          fontSize: 12,
                          lineHeight: 12,
                          onTap:
                              () => Navigator.pushNamed(
                                context,
                                AppRouteNames.transactionDetail,
                                arguments: TransactionDetailRouteArgs(id: widget.walletId, txHash: session.claimTxid!),
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSteps(BuildContext context, ArkExitStep step) {
    final colors = context.coconutColors;
    const order = [ArkExitStep.preparing, ArkExitStep.exiting, ArkExitStep.waiting, ArkExitStep.claiming];
    final labels = [t.ark.exit.step_fee, t.ark.exit.step_exit, t.ark.exit.step_wait, t.ark.exit.step_claim];
    final current = order.indexOf(step);
    return Column(
      children: [
        for (var i = 0; i < order.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 16),
            child: Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: switch (i.compareTo(current)) {
                    < 0 => Center(
                      child: SvgPicture.asset(
                        CommonActionIconPath.check,
                        width: 14,
                        colorFilter: ColorFilter.mode(colors.secondaryText, BlendMode.srcIn),
                      ),
                    ),
                    0 => Padding(
                      padding: const EdgeInsets.all(2),
                      child: CircularProgressIndicator(color: colors.primaryText, strokeWidth: 2),
                    ),
                    _ => Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: colors.tertiaryText, shape: BoxShape.circle),
                      ),
                    ),
                  },
                ),
                CoconutLayout.spacing_300w,
                Text(
                  labels[i],
                  style: (i == current ? CoconutTypography.body2_14_Bold : CoconutTypography.body2_14).setColor(
                    i == current
                        ? colors.primaryText
                        : i < current
                        ? colors.secondaryText
                        : colors.tertiaryText,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildStepIcon(BuildContext context, ArkExitStep step) {
    final colors = context.coconutColors;
    return switch (step) {
      ArkExitStep.done => SvgPicture.asset(CommonStateIconPath.completionCheck, width: 64),
      _ => SvgPicture.asset(
        CommonStateIconPath.triangleWarning,
        width: 40,
        colorFilter: ColorFilter.mode(colors.warning, BlendMode.srcIn),
      ),
    };
  }

  String _keepWords(String text) =>
      LocaleSettings.currentLocale == AppLocale.ko ? TextUtils.preventLineBreakInsideWords(text) : text;

  Widget? _buildBlockerText(BuildContext context) {
    final blocker = _viewModel.blocker;
    if (blocker == null) return null;
    final unit = context.read<PreferenceProvider>().currentUnit;
    final text = switch (blocker) {
      ArkExitBlocker.nothingToExit => t.ark.exit.blocked_nothing,
      ArkExitBlocker.tooCloseToExpiry => t.ark.exit.blocked_expiry,
      ArkExitBlocker.notEnoughOnchain => t.ark.exit.blocked_onchain(
        amount: unit.displayBitcoinAmount(_viewModel.estimate!.fundingSats, withUnit: true),
      ),
      ArkExitBlocker.selectUtxo => t.ark.exit.blocked_select_utxo,
      ArkExitBlocker.notEnoughSelected => t.ark.exit.blocked_utxo_short(
        amount: unit.displayBitcoinAmount(_viewModel.requiredSelectedSats, withUnit: true),
      ),
    };
    return Text(text, style: CoconutTypography.body3_12.setColor(context.coconutColors.dangerText));
  }
}
