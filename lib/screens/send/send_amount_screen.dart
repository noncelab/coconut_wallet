import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/bitcoin_network_rules.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/send_amount_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/button/custom_underlined_button.dart';
import 'package:coconut_wallet/widgets/button/key_button.dart';
import 'package:coconut_wallet/widgets/overlays/network_error_tooltip.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SendAmountScreen extends StatefulWidget {
  const SendAmountScreen({
    super.key,
  });

  @override
  State<SendAmountScreen> createState() => _SendAmountScreenState();
}

class _SendAmountScreenState extends State<SendAmountScreen> {
  late SendAmountViewModel _viewModel;

  // TODO: ...
  List<String> get errorMessages => [
        t.errors.insufficient_balance,
        t.alert.error_send.minimum_amount(
            bitcoin: _viewModel.currentUnit == BitcoinUnit.btc
                ? UnitUtil.convertSatoshiToBitcoin(dustLimit + 1)
                : (dustLimit + 1).toThousandsSeparatedString(),
            unit: unitText)
      ];

  String get incomingBalanceTooltipText => t.tooltip.amount_to_be_sent(
      bitcoin: _viewModel.currentUnit.displayBitcoinAmount(_viewModel.incomingBalance),
      unit: unitText);

  String get maxBalanceText =>
      _viewModel.currentUnit.displayBitcoinAmount(_viewModel.confirmedBalance, withUnit: true);

  String get unitText => _viewModel.currentUnit.symbol;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider2<ConnectivityProvider, WalletProvider, SendAmountViewModel>(
      create: (_) => _viewModel,
      update: (_, connectivityProvider, walletProvider, viewModel) {
        if (connectivityProvider.isNetworkOn != viewModel!.isNetworkOn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            viewModel.setIsNetworkOn(connectivityProvider.isNetworkOn);
          });
        }
        return viewModel;
      },
      child: Consumer<SendAmountViewModel>(
        builder: (context, viewModel, child) => Scaffold(
          appBar: CoconutAppBar.buildWithNext(
            title: t.send,
            context: context,
            nextButtonTitle: t.next,
            onNextPressed: () => _goNextScreen('/fee-selection'),
            isActive: viewModel.isNetworkOn && viewModel.isNextButtonEnabled,
            backgroundColor: CoconutColors.black,
            usePrimaryActiveColor: true,
            isBottom: false,
          ),
          body: Stack(
            children: [
              Container(
                color: CoconutColors.black,
                child: Column(
                  children: [
                    Expanded(
                        child: Align(
                            alignment: Alignment.center,
                            child: Column(children: [
                              const SizedBox(height: 16),
                              if (viewModel.incomingBalance > 0)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: CoconutLayout.defaultPadding),
                                  child: CoconutToolTip(
                                    baseBackgroundColor: CoconutColors.white.withOpacity(0.9),
                                    richText: RichText(
                                        text: TextSpan(
                                      text: incomingBalanceTooltipText,
                                      style: const TextStyle(
                                        fontFamily: 'Pretendard',
                                        fontWeight: FontWeight.normal,
                                        fontSize: 15,
                                        height: 1.4,
                                        letterSpacing: 0.5,
                                        color: CoconutColors.black,
                                      ),
                                    )),
                                    tooltipType: CoconutTooltipType.fixed,
                                  ),
                                ),
                              Expanded(
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      // 최대
                                      GestureDetector(
                                          onTap: () {
                                            viewModel.setMaxAmount();
                                          },
                                          child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 12, vertical: 6.0),
                                              margin: const EdgeInsets.only(bottom: 4),
                                              decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(12.0),
                                                  border: Border.all(
                                                      color: viewModel.errorIndex == 0
                                                          ? MyColors.warningRed
                                                          : Colors.transparent,
                                                      width: 1),
                                                  color: viewModel.errorIndex == 0
                                                      ? Colors.transparent
                                                      : MyColors.grey),
                                              child: RichText(
                                                  text: TextSpan(children: [
                                                TextSpan(
                                                    text: '${t.max} ',
                                                    style: Styles.caption.merge(TextStyle(
                                                        color: viewModel.errorIndex == 0
                                                            ? MyColors.warningRed
                                                            : CoconutColors.white,
                                                        fontFamily:
                                                            CustomFonts.text.getFontFamily))),
                                                TextSpan(
                                                    text: maxBalanceText,
                                                    style: Styles.caption.merge(TextStyle(
                                                        color: viewModel.errorIndex == 0
                                                            ? MyColors.warningRed
                                                            : CoconutColors.white))),
                                              ])))),
                                      // BTC Input
                                      GestureDetector(
                                        onTap: viewModel.toggleUnit,
                                        child: Text(
                                          '${viewModel.input.isEmpty ? 0 : viewModel.input} $unitText',
                                          style: TextStyle(
                                            fontFamily: CustomFonts.number.getFontFamily,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 38,
                                            color: viewModel.input.isEmpty
                                                ? MyColors.transparentWhite_20
                                                : CoconutColors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                      // Error
                                      Text(
                                        viewModel.errorIndex != null
                                            ? errorMessages[viewModel.errorIndex!]
                                            : '',
                                        style: Styles.caption
                                            .merge(const TextStyle(color: MyColors.warningRed)),
                                      ),

                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: CustomUnderlinedButton(
                                            text: t.select_utxo,
                                            fontSize: 14,
                                            lineHeight: 21,
                                            isEnable: viewModel.errorIndex == null &&
                                                viewModel.isNextButtonEnabled,
                                            onTap: () => _goNextScreen('/utxo-selection')),
                                      )
                                    ],
                                  ),
                                ),
                              )
                            ]))),
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 3,
                        childAspectRatio: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          '1',
                          '2',
                          '3',
                          '4',
                          '5',
                          '6',
                          '7',
                          '8',
                          '9',
                          if (viewModel.currentUnit == BitcoinUnit.btc) '.' else ' ',
                          '0',
                          '<',
                        ].map((key) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: KeyButton(
                              keyValue: key,
                              onKeyTap: viewModel.onKeyTap,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              NetworkErrorTooltip(isNetworkOn: viewModel.isNetworkOn),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    final sendInfoProvider = Provider.of<SendInfoProvider>(context, listen: false);
    final walletId = sendInfoProvider.walletId;
    _viewModel = SendAmountViewModel(
        sendInfoProvider,
        Provider.of<WalletProvider>(context, listen: false),
        walletId != null
            ? Provider.of<NodeProvider>(context, listen: false).getWalletStateStream(walletId)
            : const Stream.empty(),
        Provider.of<ConnectivityProvider>(context, listen: false).isNetworkOn,
        context.read<PreferenceProvider>().currentUnit);
  }

  void _goNextScreen(String routeName) {
    if (_viewModel.isNetworkOn != true) {
      CoconutToast.showWarningToast(context: context, text: ErrorCodes.networkError.message);
      return;
    }

    _viewModel.onBeforeGoNextScreen();
    Navigator.pushNamed(context, routeName).then((_) {
      _viewModel.onBackFromNextScreen();
    });
  }
}
