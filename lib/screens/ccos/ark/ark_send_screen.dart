import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutTextField;
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_send_view_model.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_send_confirm_screen.dart';
import 'package:coconut_wallet/screens/common/bip21_amount_bottom_sheet.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/utils/address_scan_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 아크 지갑 보내기 첫 화면. 받는 곳과 금액
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
  late final TextEditingController _controller = TextEditingController(text: context.read<ArkSendViewModel>().input);
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setInput(String value) {
    _controller.text = value;
    context.read<ArkSendViewModel>().setInput(value);
  }

  Future<void> _scan() async {
    final scanned = await showAddressScannerBottomSheet(context, title: t.ark_wallet.scan);
    if (scanned != null && mounted) _setInput(scanned.trim());
  }

  Future<void> _enterAmount(ArkSendViewModel viewModel) async {
    final result = await Bip21AmountBottomSheet.show(
      context: context,
      currentUnit: context.read<PreferenceProvider>().currentUnit,
      initialAmountSats: viewModel.amountSats,
      screenName: AnalyticsScreenNames.ccosArkWalletSendAmount,
    );
    if (!mounted || result == null || !result.didEdit) return;
    await viewModel.setAmount(result.amountInSats);
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
    final unit = context.select<PreferenceProvider, BitcoinUnit>((preferences) => preferences.currentUnit);
    final problem = _problemText(viewModel.problem);
    final rail = viewModel.rail;
    final amount = viewModel.amountSats;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(context: context, title: t.send),
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
                onChanged: viewModel.setInput,
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
                CoconutLayout.spacing_400h,
                Text(
                  rail == ArkPaymentRail.ark ? t.ark_wallet.parsed_ark : t.ark_wallet.parsed_lightning,
                  style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                ),
              ],
              if (rail != null) ...[
                CoconutLayout.spacing_500h,
                Text(t.ark_wallet.send_amount, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
                CoconutLayout.spacing_200h,
                GestureDetector(
                  key: const Key('ark-send-amount'),
                  behavior: HitTestBehavior.opaque,
                  onTap: viewModel.invoiceHasAmount ? null : () => _enterAmount(viewModel),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: colors.inputSurface, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      amount == null ? t.ark_wallet.set_amount : unit.displayBitcoinAmount(amount, withUnit: true),
                      style: (amount == null ? CoconutTypography.body1_16 : CoconutTypography.heading4_18_NumberBold)
                          .setColor(amount == null ? colors.secondaryText : colors.primaryText),
                    ),
                  ),
                ),
                CoconutLayout.spacing_200h,
                Text(
                  t.ark_wallet.available(amount: unit.displayBitcoinAmount(wallet.balance.spendable, withUnit: true)),
                  style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                ),
              ],
              if (problem != null) ...[
                CoconutLayout.spacing_300h,
                Text(problem, style: CoconutTypography.body2_14.setColor(colors.danger)),
              ],
            ],
          ),
          FixedBottomButton(
            text: t.next,
            isActive: viewModel.canContinue,
            onButtonClicked: () => ArkSendConfirmScreen.open(context, viewModel),
          ),
        ],
      ),
    );
  }
}
