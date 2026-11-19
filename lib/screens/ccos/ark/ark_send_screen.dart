import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutTextField;
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_send_view_model.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_move_parts.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_send_confirm_screen.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/utils/address_scan_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 아크 지갑 보내기 첫 화면. 받는 주소, 금액(바로 입력, 잔액은 라벨 줄 끝), 메모
class ArkSendScreen extends StatelessWidget {
  const ArkSendScreen({super.key, this.initialInput});

  final String? initialInput;

  static Future<void> open(BuildContext context, {String? initialInput}) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletSend),
      builder: (_) => ArkSendScreen(initialInput: initialInput),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final viewModel = ArkSendViewModel(context.read<ArkWalletProvider>(), network: NetworkType.currentNetworkType);
        if (initialInput != null) viewModel.setInput(initialInput!);
        return viewModel;
      },
      child: const _ArkSendView(),
    );
  }
}

class _ArkSendView extends StatefulWidget {
  const _ArkSendView();

  @override
  State<_ArkSendView> createState() => _ArkSendViewState();
}

class _ArkSendViewState extends State<_ArkSendView> {
  late final TextEditingController _controller;
  late final TextEditingController _memoController;
  final FocusNode _focusNode = FocusNode();
  final FocusNode _memoFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final viewModel = context.read<ArkSendViewModel>();
    _controller = TextEditingController(text: viewModel.input);
    _memoController = TextEditingController(text: viewModel.memo);
  }

  @override
  void dispose() {
    _controller.dispose();
    _memoController.dispose();
    _focusNode.dispose();
    _memoFocusNode.dispose();
    super.dispose();
  }

  void _setInput(String value) {
    _controller.text = value;
    _onInputChanged(value);
  }

  void _onInputChanged(String value) {
    final viewModel = context.read<ArkSendViewModel>()..setInput(value);
    _memoController.text = viewModel.memo;
  }

  Future<void> _scan() async {
    final scanned = await showAddressScannerBottomSheet(context, title: t.ark_wallet.scan);
    if (scanned != null && mounted) _setInput(scanned.trim());
  }

  String? _problemText(ArkSendProblem? problem) => switch (problem) {
    null => null,
    ArkSendProblem.onchainNotYet => t.ark_wallet.problem_onchain,
    ArkSendProblem.wrongNetwork => t.ark_wallet.problem_network,
    ArkSendProblem.unsupported => t.ark_wallet.problem_unsupported,
    ArkSendProblem.unknown => t.ark_wallet.problem_unknown,
    ArkSendProblem.notEnoughBalance => t.ark_wallet.problem_balance,
    ArkSendProblem.feeFailed => t.ark_wallet.problem_fee,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final viewModel = context.watch<ArkSendViewModel>();
    final wallet = context.watch<ArkWalletProvider>();
    final unit = context.select<ArkWalletProvider, BitcoinUnit>((wallet) => wallet.unit);
    final problem = _problemText(viewModel.problem);
    final rail = viewModel.rail;
    final amount = viewModel.amountSats;
    String sats(int value) => unit.displayBitcoinAmount(value, withUnit: true);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(context: context, backgroundColor: colors.background, title: t.send),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              Text(t.ark_wallet.send_to, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
              CoconutLayout.spacing_200h,
              CoconutTextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onInputChanged,
                placeholderText: t.ark_wallet.send_to_hint,
                maxLines: 1,
                padding: const EdgeInsets.only(left: 16, right: 0),
                backgroundColor: colors.inputSurface,
                clearButtonVisibility: CoconutTextFieldClearButtonVisibility.whenNotEmpty,
                onClear: () => _setInput(''),
                onSuffixPressed: _scan,
                suffixSemanticLabel: t.ark_wallet.scan,
                suffixIconAsset: CommonActionIconPath.scan,
                suffixIconColor: colors.primaryText,
                suffixIconSize: 18,
              ),
              if (rail != null) ...[
                CoconutLayout.spacing_200h,
                Text(
                  rail == ArkPaymentRail.ark ? t.ark_wallet.parsed_ark : t.ark_wallet.parsed_lightning,
                  style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                ),
                if (viewModel.lightningMemo case final lightningMemo?) ...[
                  CoconutLayout.spacing_100h,
                  Text(
                    '${t.ark_wallet.lightning_memo}  $lightningMemo',
                    key: const Key('ark-send-lightning-memo'),
                    style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                  ),
                ],
                CoconutLayout.spacing_500h,
                Row(
                  children: [
                    Text(t.ark_wallet.send_amount, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
                    const Spacer(),
                    Text(
                      t.ark_wallet.wallet_balance(amount: sats(wallet.balance.spendable)),
                      key: const Key('ark-send-balance'),
                      style: CoconutTypography.body3_12_Number.setColor(colors.secondaryText),
                    ),
                  ],
                ),
                CoconutLayout.spacing_200h,
                if (viewModel.invoiceHasAmount)
                  Container(
                    key: const Key('ark-send-fixed-amount'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: colors.inputSurface, borderRadius: BorderRadius.circular(12)),
                    child: Text(sats(amount!), style: CoconutTypography.body2_14_Number.setColor(colors.primaryText)),
                  )
                else
                  ArkMoveAmountBox(
                    amountSats: viewModel.amountSats,
                    onAmount: viewModel.setAmount,
                    isError: viewModel.problem == ArkSendProblem.notEnoughBalance,
                    onMax: () => viewModel.setAmount(wallet.balance.spendable),
                  ),
              ],
              CoconutLayout.spacing_500h,
              Text(t.ark_wallet.memo, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
              CoconutLayout.spacing_200h,
              CoconutTextField(
                key: const Key('ark-send-memo'),
                controller: _memoController,
                focusNode: _memoFocusNode,
                onChanged: viewModel.setMemo,
                placeholderText: t.ark_wallet.memo_hint,
                maxLines: 1,
                maxLength: 50,
                padding: const EdgeInsets.only(left: 16, right: 12),
                backgroundColor: colors.inputSurface,
                clearButtonVisibility: CoconutTextFieldClearButtonVisibility.whenNotEmpty,
                onClear: () {
                  _memoController.clear();
                  viewModel.setMemo('');
                },
              ),
            ],
          ),
          FixedBottomButton(
            subWidget: problem == null ? null : arkMoveProblemText(context, problem),
            text: t.next,
            isActive: viewModel.canContinue,
            onButtonClicked: () => ArkSendConfirmScreen.open(context, viewModel),
          ),
        ],
      ),
    );
  }
}
