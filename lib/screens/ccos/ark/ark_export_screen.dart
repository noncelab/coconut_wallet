import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar, CoconutTextField;
import 'package:coconut_lib/coconut_lib.dart' show NetworkType;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/constants/dust_constants.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_export_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_move_parts.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_navigation.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 아크 잔액을 내 코코넛 지갑이나 직접 넣은 주소로 내보내기. 아크 지갑 ↓ 받는 곳, 버튼을 누르면 인증 뒤 바로 내보냄
class ArkExportScreen extends StatefulWidget {
  const ArkExportScreen({super.key, required this.walletId});

  /// 없으면 주소를 직접 넣음(코코넛 지갑이 하나도 없을 때)
  final int? walletId;

  static Future<void> open(BuildContext context, int? walletId) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletExport),
      builder: (_) => ArkExportScreen(walletId: walletId),
    ),
  );

  @override
  State<ArkExportScreen> createState() => _ArkExportScreenState();
}

class _ArkExportScreenState extends State<ArkExportScreen> {
  /// 직접 넣는 주소의 더스트 한도, 주소 유형을 모르니 표준 출력 중 가장 큰 값
  static const int _manualDustThreshold = 546;

  late int? _walletId = widget.walletId;
  bool _running = false;
  final TextEditingController _addressController = TextEditingController();
  final FocusNode _addressFocus = FocusNode();
  String? _addressError;

  late final ArkExportViewModel _viewModel = () {
    final wallets = context.read<WalletProvider>();
    final walletId = _walletId;
    return ArkExportViewModel(
      context.read<ArkWalletProvider>(),
      address: walletId == null ? null : wallets.getReceiveAddress(walletId).address,
      dustThreshold:
          walletId == null
              ? _manualDustThreshold
              : wallets.getWalletById(walletId).walletType.addressType.dustThreshold,
    );
  }();

  @override
  void dispose() {
    _viewModel.dispose();
    _addressController.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  void _useWallet(int walletId) {
    final wallets = context.read<WalletProvider>();
    setState(() => _walletId = walletId);
    _viewModel.setDestination(
      wallets.getReceiveAddress(walletId).address,
      dustThreshold: wallets.getWalletById(walletId).walletType.addressType.dustThreshold,
    );
  }

  void _useAddress() {
    setState(() => _walletId = null);
    _onAddress(_addressController.text);
  }

  void _onAddress(String text) {
    final error = text.isEmpty ? null : AddressValidator.validateAddress(text, NetworkType.currentNetworkType);
    setState(() => _addressError = error?.message);
    final valid = text.isNotEmpty && error == null;
    _viewModel.setDestination(
      valid ? AddressValidator.normalizeAddress(text) : null,
      dustThreshold: _manualDustThreshold,
    );
  }

  /// 고를 지갑이 둘 이상이면 카드 이름을 눌러 바꿈
  Future<void> _changeWallet() async {
    final picked = await pickCoconutWallet(
      context,
      [for (final wallet in context.read<WalletProvider>().walletItemList) wallet.id],
      AnalyticsScreenNames.ccosArkWalletExportWallet,
      title: t.ark_wallet.export_to,
    );
    if (picked != null && mounted && picked != _walletId) _useWallet(picked);
  }

  String? _problem(ArkExportProblem? problem) => switch (problem) {
    null => null,
    ArkExportProblem.overBalance => t.ark_wallet.export_over_balance,
    ArkExportProblem.feeOverBalance => t.ark_wallet.export_fee_over_balance,
    ArkExportProblem.belowDust => t.ark_wallet.problem_dust,
    ArkExportProblem.estimateFailed => t.ark_wallet.problem_fee,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final viewModel = _viewModel;
        final unit = context.select<ArkWalletProvider, BitcoinUnit>((wallet) => wallet.unit);
        String sats(int value) => unit.displayBitcoinAmount(value, withUnit: true);
        final wallets = context.read<WalletProvider>();
        final walletIds = [for (final wallet in wallets.walletItemList) wallet.id];
        final walletId = _walletId;
        final problem = _problem(viewModel.problem);
        return Scaffold(
          backgroundColor: colors.background,
          appBar: CoconutAppBar.build(context: context, title: t.ark_wallet.export),
          body: Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  ArkMoveRoute(
                    key: const Key('ark-export-route'),
                    fromName: t.ark_wallet.wallet_name,
                    fromBalance: sats(viewModel.balanceSats),
                    amount: ArkMoveAmountBox(
                      amountSats: viewModel.amountSats,
                      onAmount: viewModel.setAmount,
                      isError: problem != null,
                      onMax: () => viewModel.setAmount(viewModel.balanceSats, isMax: true),
                    ),
                    isEstimating: viewModel.isEstimating,
                    total: viewModel.spendSats == null ? null : sats(viewModel.spendSats!),
                    fees: [if (viewModel.fee != null) '${t.ark_wallet.fee_server} ${sats(viewModel.fee!)}'],
                    toLabel: walletId == null ? t.ark_wallet.recipient : null,
                    toName: walletId == null ? null : wallets.getWalletById(walletId).name,
                    toBalance: walletId == null ? null : sats(wallets.getWalletBalance(walletId).total),
                    onToTap: walletId != null && walletIds.length > 1 ? _changeWallet : null,
                    toDetail:
                        walletId == null
                            ? null
                            : '${viewModel.address}\n${wallets.getReceiveAddress(walletId).derivationPath}',
                    toInput:
                        walletId != null
                            ? null
                            : CoconutTextField(
                              key: const Key('ark-export-address'),
                              controller: _addressController,
                              focusNode: _addressFocus,
                              onChanged: _onAddress,
                              placeholderText: t.ark_wallet.export_address_hint,
                              maxLines: 2,
                              isLengthVisible: false,
                              backgroundColor: colors.inputSurface,
                              isError: _addressError != null,
                              errorText: _addressError,
                              clearButtonVisibility: CoconutTextFieldClearButtonVisibility.whenNotEmpty,
                              onClear: () => _onAddress(''),
                            ),
                    arrival: viewModel.arrivalSats == null ? null : sats(viewModel.arrivalSats!),
                  ),
                  if (walletId != null || walletIds.isNotEmpty) ...[
                    CoconutLayout.spacing_200h,
                    Align(
                      alignment: Alignment.centerRight,
                      child: CoconutUnderlinedButton(
                        key: const Key('ark-export-switch'),
                        padding: const EdgeInsets.all(8),
                        text: walletId == null ? t.ark_wallet.export_use_wallet : t.ark_wallet.export_use_address,
                        textStyle: CoconutTypography.body3_12,
                        onTap: walletId == null ? () => _useWallet(walletIds.first) : _useAddress,
                      ),
                    ),
                  ],
                ],
              ),
              FixedBottomButton(
                buttonKey: const Key('ark-export-next'),
                subWidget: problem == null ? null : arkMoveProblemText(context, problem),
                text: t.ark_wallet.export,
                isActive: viewModel.canExport && !_running,
                onButtonClicked: _export,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _export() => runArkMove(
    context,
    authenticate: authenticateArkMove,
    run: _viewModel.export,
    doneMessage: t.ark_wallet.export_done,
    failedMessage: t.ark_wallet.export_failed,
    onRunning: (running) {
      if (mounted) setState(() => _running = running);
    },
  );
}
