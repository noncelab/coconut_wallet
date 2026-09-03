import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_design_system/coconut_design_system.dart'
    hide
        CoconutAppBar,
        CoconutToolTip,
        CoconutTooltipType,
        CoconutTooltipState,
        CoconutToast,
        CoconutToastLevel,
        CoconutPopup;
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/send_confirm_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/bitbox02_connect_screen.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_connectivity_service.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_transport.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_ble_connectivity_service.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_navigator.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/dialogs/dialog.dart';
import 'package:coconut_wallet/widgets/features/send/send_transaction_flow_card.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/send/send_amount_header.dart';
import 'package:coconut_wallet/widgets/features/send/send_output_detail_card.dart';
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
    if (!mounted) return;

    final connectedDeviceSource = await viewModel.findConnectedMatchingDevice();
    if (!mounted) return;
    context.loaderOverlay.hide();

    if (connectedDeviceSource != null && connectedDeviceSource != viewModel.walletImportSource) {
      final language = context.read<PreferenceProvider>().language;
      final deviceName = connectedDeviceSource.displayName;
      if (!mounted) return;
      bool useConnectedDevice = false;
      await showConfirmDialog(
        context,
        language,
        t.send_confirm_screen.sign_with_connected_device_title,
        t.send_confirm_screen.sign_with_connected_device_description(deviceName: deviceName),
        leftButtonText: t.no,
        rightButtonText: t.yes,
        barrierDismissible: true,
        onTapLeft: () {
          useConnectedDevice = false;
          Navigator.of(context).pop();
        },
        onTapRight: () {
          useConnectedDevice = true;
          Navigator.of(context).pop();
        },
      );
      if (!mounted) return;
      _navigateToNextScreen(viewModel, connectedDeviceSource: useConnectedDevice ? connectedDeviceSource : null);
      return;
    }

    _navigateToNextScreen(viewModel, connectedDeviceSource: connectedDeviceSource);
  }

  void _navigateToNextScreen(SendConfirmViewModel viewModel, {WalletImportSource? connectedDeviceSource}) {
    final source = connectedDeviceSource ?? viewModel.walletImportSource;
    switch (source) {
      case WalletImportSource.bitbox02:
        if (connectedDeviceSource != null) {
          _pushBitBox02SignScreen(viewModel);
        } else {
          _navigateToBitBox02ConnectIfNeeded(viewModel);
        }
      case WalletImportSource.trezor:
        if (connectedDeviceSource != null) {
          _pushTrezorSignScreen(viewModel);
        } else {
          _navigateToTrezorConnectIfNeeded(viewModel);
        }
      default:
        Navigator.pushNamed(
          context,
          AppRouteNames.unsignedTransactionQr,
          arguments: UnsignedTransactionQrRouteArgs(walletName: viewModel.walletName),
        );
    }
  }

  void _pushBitBox02SignScreen(SendConfirmViewModel viewModel) {
    Navigator.pushNamed(
      context,
      AppRouteNames.bitbox02Sign,
      arguments: BitBox02SignRouteArgs(
        psbtBase64: viewModel.txWaitingForSign!,
        walletName: viewModel.walletName,
        walletFingerprint: viewModel.walletFingerprint,
        isFromSendFlow: true,
        transport: BitBox02Transport.resolveForSign(),
      ),
    );
  }

  Future<void> _navigateToBitBox02ConnectIfNeeded(SendConfirmViewModel viewModel) async {
    final isConnected = await BitBox02ConnectivityService.isDeviceConnected();
    final lastConnected = BitBox02Device.lastConnected;
    final hasSession = lastConnected != null;
    final isMatchingWallet =
        hasSession && lastConnected.cachedXpub != null && lastConnected.cachedXpub == viewModel.walletExtendedPublicKey;
    if (!mounted) return;
    if (isConnected && hasSession && isMatchingWallet) {
      _pushBitBox02SignScreen(viewModel);
    } else {
      CommonBottomSheets.showCustomHeightBottomSheet(
        context: context,
        screenName: AnalyticsScreenNames.sendConfirmConnectBitbox02Sheet,
        child: BitBox02ConnectScreen(
          importSource: WalletImportSource.bitbox02,
          psbtBase64: viewModel.txWaitingForSign,
          walletName: viewModel.walletName,
          walletFingerprint: viewModel.walletFingerprint,
          resumeFromExistingSession: isConnected && hasSession,
        ),
        heightRatio: 0.9,
      );
    }
  }

  void _pushTrezorSignScreen(SendConfirmViewModel viewModel) {
    final lastConnected = TrezorDevice.lastConnected!;
    Navigator.pushNamed(
      context,
      AppRouteNames.trezorSign,
      arguments: TrezorSignRouteArgs(
        psbtBase64: viewModel.txWaitingForSign!,
        walletName: viewModel.walletName,
        walletFingerprint: viewModel.walletFingerprint,
        isFromSendFlow: true,
        transport: lastConnected.transport.name,
      ),
    );
  }

  Future<void> _navigateToTrezorConnectIfNeeded(SendConfirmViewModel viewModel) async {
    final lastConnected = TrezorDevice.lastConnected;
    final isConnected = await TrezorBleConnectivityService.isDeviceConnected(
      lastConnected?.transport ?? TrezorTransport.ble,
    );
    final hasSession = lastConnected != null;
    final isMatchingWallet =
        hasSession && lastConnected.cachedXpub != null && lastConnected.cachedXpub == viewModel.walletExtendedPublicKey;
    if (!mounted) return;
    if (isConnected && hasSession && isMatchingWallet) {
      _pushTrezorSignScreen(viewModel);
    } else {
      TrezorNavigator.showConnectScreen(
        context: context,
        psbtBase64: viewModel.txWaitingForSign,
        walletName: viewModel.walletName,
        walletFingerprint: viewModel.walletFingerprint,
        resumeFromExistingSession: isConnected && hasSession,
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
