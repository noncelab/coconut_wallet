import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/send_confirm_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/card/information_item_card.dart';
import 'package:coconut_wallet/widgets/contents/fiat_price.dart';
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

  String get confirmText => _currentUnit.displayBitcoinAmount(UnitUtil.convertBitcoinToSatoshi(_viewModel.amount));

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
                        GestureDetector(
                          onTap: _toggleUnit,
                          child: Column(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 40),
                                child: Center(
                                  child: Text.rich(
                                    TextSpan(
                                      text: confirmText,
                                      children: <TextSpan>[TextSpan(text: ' $unitText', style: Styles.unit)],
                                    ),
                                    style: Styles.balance1,
                                    textScaler: const TextScaler.linear(1.0),
                                  ),
                                ),
                              ),
                              FiatPrice(satoshiAmount: UnitUtil.convertBitcoinToSatoshi(viewModel.amount)),
                            ],
                          ),
                        ),
                        CoconutLayout.spacing_1000h,
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28.0),
                              color: MyColors.transparentWhite_06,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24),
                              child: Column(
                                children: [
                                  InformationItemCard(
                                    label: t.receiver,
                                    value: viewModel.addresses,
                                    isNumber: true,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                  ),
                                  const Divider(color: MyColors.transparentWhite_12, height: 1),
                                  InformationItemCard(
                                    label: t.estimated_fee,
                                    value: ["$estimatedFeeText $unitText"],
                                    isNumber: true,
                                  ),
                                  const Divider(color: MyColors.transparentWhite_12, height: 1),
                                  InformationItemCard(
                                    label: t.total_cost,
                                    value: ["$totalCostText $unitText"],
                                    isNumber: true,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
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
}
