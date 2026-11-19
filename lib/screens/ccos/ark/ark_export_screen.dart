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
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/utils/address_scan_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// 아크 잔액을 온체인 주소로 내보내기. 주소는 직접 넣거나 내 코코넛 지갑 받는 주소에서 고름(보내기 화면의 내 주소 상자와 같음)
class ArkExportScreen extends StatefulWidget {
  const ArkExportScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      settings: const RouteSettings(name: AnalyticsScreenNames.ccosArkWalletExport),
      builder: (_) => const ArkExportScreen(),
    ),
  );

  @override
  State<ArkExportScreen> createState() => _ArkExportScreenState();
}

class _ArkExportScreenState extends State<ArkExportScreen> {
  /// 직접 넣는 주소의 더스트 한도, 주소 유형을 모르니 표준 출력 중 가장 큰 값
  static const int _manualDustThreshold = 546;

  bool _running = false;
  final TextEditingController _addressController = TextEditingController();
  final FocusNode _addressFocus = FocusNode();
  String? _addressError;
  bool _showMyAddresses = false;

  late final ArkExportViewModel _viewModel = ArkExportViewModel(
    context.read<ArkWalletProvider>(),
    address: null,
    dustThreshold: _manualDustThreshold,
  );

  @override
  void initState() {
    super.initState();
    _addressFocus.addListener(_onFocus);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _addressController.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  /// 내 지갑마다 지금 받는 주소
  List<({WalletItemBase wallet, WalletAddress address})> _myAddresses() {
    final wallets = context.read<WalletProvider>();
    return [
      for (final wallet in wallets.walletItemList) (wallet: wallet, address: wallets.getReceiveAddress(wallet.id)),
    ];
  }

  ({WalletItemBase wallet, WalletAddress address})? _mineFor(String text) =>
      _myAddresses().where((mine) => mine.address.address.toLowerCase() == text.trim().toLowerCase()).firstOrNull;

  void _onFocus() {
    final show = _addressFocus.hasFocus && _myAddresses().isNotEmpty && _mineFor(_addressController.text) == null;
    if (show != _showMyAddresses) setState(() => _showMyAddresses = show);
  }

  void _onAddress(String text) {
    final error = text.isEmpty ? null : AddressValidator.validateAddress(text, NetworkType.currentNetworkType);
    final mine = _mineFor(text);
    setState(() {
      _addressError = error?.message;
      if (mine != null) _showMyAddresses = false;
    });
    final valid = text.isNotEmpty && error == null;
    _viewModel.setDestination(
      valid ? AddressValidator.normalizeAddress(text) : null,
      dustThreshold: mine?.wallet.walletType.addressType.dustThreshold ?? _manualDustThreshold,
    );
  }

  void _pick(String address) {
    _addressController.text = address;
    _onAddress(address);
    _addressFocus.unfocus();
  }

  Future<void> _scan() async {
    final scanned = await showAddressScannerBottomSheet(context, title: t.ark_wallet.scan);
    if (scanned == null || !mounted) return;
    final address = scanned.trim().replaceFirst(RegExp(r'^bitcoin:', caseSensitive: false), '').split('?').first;
    _addressController.text = address;
    _onAddress(address);
  }

  String? _problem(ArkExportProblem? problem) => switch (problem) {
    null => null,
    ArkExportProblem.overBalance => t.ark_wallet.export_over_balance,
    ArkExportProblem.feeOverBalance => t.ark_wallet.export_fee_over_balance,
    ArkExportProblem.belowDust => t.ark_wallet.problem_dust,
    ArkExportProblem.estimateFailed => t.ark_wallet.problem_fee,
  };

  Widget _myAddressBox(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      key: const Key('ark-export-my-addresses'),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.borderStrong, width: 1),
        borderRadius: const BorderRadius.all(Radius.circular(14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Text(t.send_screen.my_address, style: CoconutTypography.body3_12_Bold.setColor(colors.primaryText)),
                const Spacer(),
                CoconutUnderlinedButton(
                  text: t.close,
                  onTap: () => setState(() => _showMyAddresses = false),
                  textStyle: CoconutTypography.body3_12,
                  padding: const EdgeInsets.only(left: 24),
                ),
              ],
            ),
          ),
          CoconutLayout.spacing_200h,
          for (final mine in _myAddresses())
            ShrinkAnimationButton(
              key: Key('ark-export-my-address-${mine.wallet.id}'),
              onPressed: () => _pick(mine.address.address),
              defaultColor: Colors.transparent,
              pressedOverlayColor: colors.surfacePressOverlay,
              borderRadius: 12,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shortenAddress(mine.address.address, head: 12, tail: 14),
                      style: CoconutTypography.body2_14_Number.setColor(colors.primaryText),
                    ),
                    Text(
                      '${mine.wallet.name} • ${mine.address.derivationPath}',
                      style: CoconutTypography.body3_12.setColor(colors.secondaryText),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return ListenableBuilder(
      listenable: _viewModel,
      builder: (context, _) {
        final viewModel = _viewModel;
        final unit = context.select<ArkWalletProvider, BitcoinUnit>((wallet) => wallet.unit);
        String sats(int value) => unit.displayBitcoinAmount(value, withUnit: true);
        final problem = _problem(viewModel.problem);
        final mine = _mineFor(_addressController.text);
        return Scaffold(
          backgroundColor: colors.background,
          appBar: CoconutAppBar.build(context: context, backgroundColor: colors.background, title: t.ark_wallet.export),
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
                    toLabel: t.ark_wallet.recipient,
                    toInput: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CoconutTextField(
                          key: const Key('ark-export-address'),
                          controller: _addressController,
                          focusNode: _addressFocus,
                          onChanged: _onAddress,
                          placeholderText: t.ark_wallet.export_address_hint,
                          maxLines: 1,
                          isLengthVisible: false,
                          padding: const EdgeInsets.only(left: 16, right: 0),
                          backgroundColor: colors.inputSurface,
                          isError: _addressError != null,
                          errorText: _addressError,
                          clearButtonVisibility: CoconutTextFieldClearButtonVisibility.whenNotEmpty,
                          onClear: () {
                            _addressController.clear();
                            _onAddress('');
                            _onFocus();
                          },
                          onSuffixPressed: _scan,
                          suffixSemanticLabel: t.ark_wallet.scan,
                          suffixIconAsset: CommonActionIconPath.scan,
                          suffixIconColor: colors.primaryText,
                          suffixIconSize: 18,
                        ),
                        if (_showMyAddresses) _myAddressBox(context),
                      ],
                    ),
                    toDetail: mine == null ? null : '${mine.wallet.name} • ${mine.address.derivationPath}',
                    arrival: viewModel.arrivalSats == null ? null : sats(viewModel.arrivalSats!),
                  ),
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
