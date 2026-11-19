import 'dart:typed_data';

import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_fill_source.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_fill_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_expiry_text.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_move_parts.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_navigation.dart';
import 'package:coconut_wallet/screens/send/hot_wallet_passphrase_input_sheet.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 핫월렛 온체인 잔액으로 아크 지갑 채우기. 보내는 지갑 ↓ 받는 아크 지갑, 버튼을 누르면 인증 뒤 바로 채움
class ArkFillScreen extends StatefulWidget {
  const ArkFillScreen({super.key, required this.walletId});

  final int walletId;

  static Future<void> open(BuildContext context, int walletId) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletFill),
      builder: (_) => ArkFillScreen(walletId: walletId),
    ),
  );

  @override
  State<ArkFillScreen> createState() => _ArkFillScreenState();
}

class _ArkFillScreenState extends State<ArkFillScreen> {
  late int walletId = widget.walletId;

  /// 고를 지갑이 둘 이상이면 카드 이름을 눌러 바꿈
  Future<void> _changeWallet() async {
    final picked = await pickCoconutWallet(
      context,
      ArkWalletNavigation.fillWalletIds(context.read<WalletProvider>()),
      AnalyticsScreenNames.ccosArkWalletFillWallet,
      title: t.ark_wallet.fill_from,
    );
    if (picked != null && mounted && picked != walletId) setState(() => walletId = picked);
  }

  @override
  Widget build(BuildContext context) {
    final canChange = ArkWalletNavigation.fillWalletIds(context.read<WalletProvider>()).length > 1;
    return ChangeNotifierProvider(
      key: ValueKey(walletId),
      create:
          (context) => ArkFillViewModel(
            context.read<ArkWalletProvider>(),
            HotWalletFillSource(
              context.read<WalletProvider>(),
              context.read<NodeProvider>(),
              context.read<UtxoRepository>(),
              walletId,
            ),
          ),
      child: _ArkFillView(walletId: walletId, onChangeWallet: canChange ? _changeWallet : null),
    );
  }
}

class _ArkFillView extends StatefulWidget {
  const _ArkFillView({required this.walletId, this.onChangeWallet});

  final int walletId;
  final VoidCallback? onChangeWallet;

  @override
  State<_ArkFillView> createState() => _ArkFillViewState();
}

class _ArkFillViewState extends State<_ArkFillView> {
  bool _running = false;

  int get walletId => widget.walletId;

  String? _problem(ArkFillViewModel viewModel, BitcoinUnit unit) => switch (viewModel.problem) {
    null => null,
    ArkFillProblem.notEnough => t.alert.error_send.insufficient_balance,
    ArkFillProblem.belowMinimum => t.ark_wallet.problem_fill_min(
      amount: unit.displayBitcoinAmount(viewModel.minimumSats ?? 0, withUnit: true),
    ),
    ArkFillProblem.aboveMaximum => t.ark_wallet.problem_fill_max(
      amount: unit.displayBitcoinAmount(viewModel.boardedSats ?? 0, withUnit: true),
    ),
    ArkFillProblem.estimateFailed => t.ark_wallet.problem_fee,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final viewModel = context.watch<ArkFillViewModel>();
    final unit = context.select<ArkWalletProvider, BitcoinUnit>((wallet) => wallet.unit);
    String sats(int value) => unit.displayBitcoinAmount(value, withUnit: true);
    final walletName = context.read<WalletProvider>().getWalletById(walletId).name;
    final problem = _problem(viewModel, unit);
    final confirmations = viewModel.requiredConfirmations;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(context: context, title: t.ark_wallet.fill),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              ArkMoveRoute(
                key: const Key('ark-fill-route'),
                onFromTap: widget.onChangeWallet,
                fromName: walletName,
                fromBalance: sats(viewModel.source.confirmedSats),
                amount: ArkMoveAmountBox(
                  amountSats: viewModel.amountSats,
                  onAmount: viewModel.setAmount,
                  isError: problem != null,
                  onMax: () => viewModel.setAmount(viewModel.source.confirmedSats, isMax: true),
                ),
                isEstimating: viewModel.isEstimating,
                total: viewModel.spendSats == null ? null : sats(viewModel.spendSats!),
                fees: [
                  if (viewModel.onchainFee != null)
                    [
                      '${t.ark_wallet.fee_network} ${sats(viewModel.onchainFee!)}',
                      if (viewModel.feeRate != null) arkFeeRateText(viewModel.feeRate!),
                    ].join(' · '),
                  if (viewModel.boardFee != null && viewModel.boardFee! > 0)
                    '${t.ark_wallet.fee_server} ${sats(viewModel.boardFee!)}',
                ],
                toName: t.ark_wallet.wallet_name,
                toBalance: sats(context.select<ArkWalletProvider, int>((wallet) => wallet.balance.spendable)),
                arrival: viewModel.arrivalSats == null ? null : sats(viewModel.arrivalSats!),
                arrivalDetail:
                    confirmations == null ? null : t.ark_wallet.fill_wait(time: arkBlocksText(confirmations)),
              ),
            ],
          ),
          FixedBottomButton(
            buttonKey: const Key('ark-fill-next'),
            subWidget: problem == null ? null : arkMoveProblemText(context, problem),
            text: t.ark_wallet.fill,
            isActive: viewModel.canFill && !_running,
            onButtonClicked: () => _fill(viewModel),
          ),
        ],
      ),
    );
  }

  Future<void> _fill(ArkFillViewModel viewModel) {
    final confirmations = arkBlocksText(viewModel.requiredConfirmations ?? 1);
    Uint8List? passphrase;
    return runArkMove(
      context,
      authenticate: (context) async {
        if (!viewModel.source.needsPassphrase) return authenticateArkMove(context);
        passphrase = await _askPassphrase(context, viewModel);
        return passphrase != null;
      },
      run: () async {
        try {
          await viewModel.fill(passphrase: passphrase);
        } finally {
          passphrase?.fillRange(0, passphrase!.length, 0);
        }
      },
      doneMessage: t.ark_wallet.fill_done(time: confirmations),
      failedMessage: t.ark_wallet.fill_failed,
      onRunning: (running) {
        if (mounted) setState(() => _running = running);
      },
    );
  }

  /// 서명할 때 패스프레이즈를 넣는 핫월렛. 틀리면 다시 물음
  Future<Uint8List?> _askPassphrase(BuildContext context, ArkFillViewModel viewModel) async {
    final requiresAuthentication = context.read<AuthProvider>().isAuthEnabled;
    var showIncorrectError = false;
    while (context.mounted) {
      final passphrase = await CommonBottomSheets.showBottomSheet<Uint8List>(
        context: context,
        screenName: AnalyticsScreenNames.ccosArkWalletFillPassphrase,
        title: t.send_confirm_screen.passphrase_input_title,
        showCloseButton: true,
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
      if (passphrase == null) return null;
      if (await viewModel.source.validatePassphrase(passphrase)) return passphrase;
      if (!context.mounted) return null;
      passphrase.fillRange(0, passphrase.length, 0);
      showIncorrectError = true;
    }
    return null;
  }
}
