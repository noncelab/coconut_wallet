import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/send_confirm_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/bitbox02_connect_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/trezor_connect_screen.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_connectivity_service.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_transport.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_connectivity_service.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/card/send_transaction_flow_card.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/send_amount_header.dart';
import 'package:coconut_wallet/widgets/send_output_detail_card.dart';
import 'package:flutter/material.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

class SendConfirmScreen extends StatefulWidget {
  final BitcoinUnit? currentUnit;

  const SendConfirmScreen({super.key, this.currentUnit});

  @override
  State<SendConfirmScreen> createState() => _SendConfirmScreenState();
}

class _SendConfirmScreenState extends State<SendConfirmScreen> {
  late SendConfirmViewModel _viewModel;
  late BitcoinUnit _currentUnit;

  String get totalSendAmountText =>
      _currentUnit.displayBitcoinAmount(UnitUtil.convertBitcoinToSatoshi(_viewModel.totalSendAmount ?? 0));

  String get totalCostText => _currentUnit.displayBitcoinAmount(
    _viewModel.totalUsedAmount,
    defaultWhenZero: t.calculation_failed,
    shouldCheckZero: true,
  );

  String get unitText => _currentUnit.symbol;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SendConfirmViewModel>(
      create: (_) => _viewModel,
      child: Consumer<SendConfirmViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: context.coconutColors.background,
            appBar: CoconutAppBar.build(title: t.send_confirm_screen.title, context: context),
            body: SafeArea(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 10, right: 10),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          SendAmountHeader(
                            amountText: totalSendAmountText,
                            unit: _currentUnit,
                            satoshiAmount: UnitUtil.convertBitcoinToSatoshi(viewModel.totalSendAmount ?? 0),
                            totalCostAmountText: totalCostText,
                            onTap: _toggleUnit,
                          ),
                          CoconutLayout.spacing_300h,
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _buildTransactionFlowCard(viewModel),
                          ),
                          CoconutLayout.spacing_500h,
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: _buildOutputDetailCard(viewModel),
                          ),
                          CoconutLayout.spacing_500h,
                          CoconutLayout.spacing_2500h,
                        ],
                      ),
                    ),
                  ),
                  FixedBottomButton(text: t.next, onButtonClicked: () => _onButtonClicked(viewModel)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    context.loaderOverlay.show();
    _currentUnit = widget.currentUnit ?? context.read<PreferenceProvider>().currentUnit;
    _viewModel = SendConfirmViewModel(
      Provider.of<SendInfoProvider>(context, listen: false),
      Provider.of<WalletProvider>(context, listen: false),
    );
    _viewModel
        .setEstimatedFeeAndTotalUsedAmount()
        .then((_) {
          if (mounted) {
            context.loaderOverlay.hide();
          }
        })
        .catchError((error) async {
          if (mounted) {
            context.loaderOverlay.hide();
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return CoconutPopup(
                  languageCode: context.read<PreferenceProvider>().language,
                  title: t.alert.error_tx.created_failed,
                  description: t.alert.error_tx.not_created(error: error.toString()),
                  onTapRight: () {
                    Navigator.pop(context);
                  },
                  rightButtonText: t.OK,
                );
              },
            );
          }
        });
  }

  Future<void> _onButtonClicked(SendConfirmViewModel viewModel) async {
    context.loaderOverlay.show();
    viewModel.setTxWaitingForSign();
    if (!context.mounted) return;
    context.loaderOverlay.hide();

    switch (viewModel.walletImportSource) {
      case WalletImportSource.bitbox02:
        await _navigateToBitBox02Sign(viewModel);
      case WalletImportSource.trezor:
        _navigateToTrezorSign(viewModel);
      default:
        Navigator.pushNamed(context, '/unsigned-transaction-qr', arguments: {'walletName': viewModel.walletName});
    }
  }

  Future<void> _navigateToBitBox02Sign(SendConfirmViewModel viewModel) async {
    final isPhysicallyConnected = await BitBox02ConnectivityService.isDeviceConnected();
    final hasSession = BitBox02Device.lastConnected != null;
    if (!context.mounted) return;
    if (isPhysicallyConnected && hasSession) {
      Navigator.pushNamed(
        context,
        '/bitbox02-sign',
        arguments: {
          'psbtBase64': viewModel.txWaitingForSign,
          'walletName': viewModel.walletName,
          'walletFingerprint': viewModel.walletFingerprint,
          'isFromSendFlow': true,
          'transport': BitBox02Transport.resolveForSign(),
        },
      );
    } else {
      CommonBottomSheets.showCustomHeightBottomSheet(
        context: context,
        child: BitBox02ConnectScreen(
          importSource: WalletImportSource.bitbox02,
          psbtBase64: viewModel.txWaitingForSign,
          walletName: viewModel.walletName,
          walletFingerprint: viewModel.walletFingerprint,
        ),
        heightRatio: 0.9,
      );
    }
  }

  Future<void> _navigateToTrezorSign(SendConfirmViewModel viewModel) async {
    final isPhysicallyConnected = await TrezorConnectivityService.isDeviceConnected();
    final hasSession = TrezorDevice.lastConnected != null;
    if (!context.mounted) return;
    if (isPhysicallyConnected && hasSession) {
      Navigator.pushNamed(
        context,
        '/trezor-sign',
        arguments: {
          'psbtBase64': viewModel.txWaitingForSign,
          'walletName': viewModel.walletName,
          'walletFingerprint': viewModel.walletFingerprint,
          'isFromSendFlow': true,
        },
      );
    } else {
      CommonBottomSheets.showCustomHeightBottomSheet(
        context: context,
        child: TrezorConnectScreen(
          psbtBase64: viewModel.txWaitingForSign,
          walletName: viewModel.walletName,
          walletFingerprint: viewModel.walletFingerprint,
        ),
        heightRatio: 0.9,
      );
    }
  }

  void _toggleUnit() {
    setState(() {
      _currentUnit = _currentUnit.next;
    });
  }

  Widget _buildTransactionFlowCard(SendConfirmViewModel viewModel) {
    final transaction = viewModel.transaction;
    if (transaction == null) {
      return const SizedBox.shrink();
    }

    final inputCount = transaction.inputs.length;
    final List<int?> inputAmounts = List<int?>.from(viewModel.inputAmounts);
    if (inputAmounts.length != inputCount) {
      inputAmounts
        ..clear()
        ..addAll(List<int?>.filled(inputCount, null));
    }

    return SendTransactionFlowCard(
      inputAmounts: inputAmounts,
      externalOutputAmounts: viewModel.externalOutputAmounts,
      changeOutputAmounts: viewModel.changeOutputAmounts,
      fee: viewModel.estimatedFee,
      currentUnit: _currentUnit,
    );
  }

  Widget _buildOutputDetailCard(SendConfirmViewModel viewModel) {
    final transaction = viewModel.transaction;
    if (transaction == null || transaction.outputs.isEmpty) {
      return const SizedBox.shrink();
    }

    final detailItems = <OutputDetailItem>[];
    int outputIndex = 0;
    for (final output in transaction.outputs) {
      final isChange = output.isChangeOutput == true;
      if (!isChange) {
        outputIndex += 1;
      }
      detailItems.add(
        OutputDetailItem(
          label: isChange ? t.change : t.send_confirm_screen.flow_output_title(index: outputIndex),
          address: output.getAddress(),
          amountSats: output.amount,
          isChange: isChange,
        ),
      );
    }

    return SendOutputDetailCard(items: detailItems, currentUnit: _currentUnit);
  }
}
