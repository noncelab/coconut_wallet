import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/send_confirm_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/card/send_transaction_flow_card.dart';
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

  String get estimatedFeeText => _currentUnit.displayBitcoinAmount(
    _viewModel.estimatedFee,
    defaultWhenZero: t.calculation_failed,
    shouldCheckZero: true,
  );

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
            backgroundColor: CoconutColors.black,
            appBar: CoconutAppBar.build(title: t.send_confirm_screen.title, context: context),
            body: SafeArea(
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        SendAmountHeader(
                          amountText: totalSendAmountText,
                          unitText: unitText,
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
                  FixedBottomButton(
                    onButtonClicked: () {
                      context.loaderOverlay.show();
                      viewModel.setTxWaitingForSign();
                      if (context.mounted) {
                        context.loaderOverlay.hide();
                        Navigator.pushNamed(
                          context,
                          '/unsigned-transaction-qr',
                          arguments: {'walletName': viewModel.walletName},
                        );
                      }
                    },
                    text: t.next,
                    backgroundColor: CoconutColors.gray100,
                    pressedBackgroundColor: CoconutColors.gray500,
                  ),
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

  void _toggleUnit() {
    setState(() {
      _currentUnit = _currentUnit == BitcoinUnit.btc ? BitcoinUnit.sats : BitcoinUnit.btc;
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

    final externalOutputAmounts =
        transaction.outputs.where((output) => output.isChangeOutput != true).map((output) => output.amount).toList();
    final changeOutputAmounts =
        transaction.outputs.where((output) => output.isChangeOutput == true).map((output) => output.amount).toList();

    return SendTransactionFlowCard(
      inputAmounts: inputAmounts,
      externalOutputAmounts: externalOutputAmounts,
      changeOutputAmounts: changeOutputAmounts,
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

    return SendOutputDetailCard(items: detailItems);
  }
}
