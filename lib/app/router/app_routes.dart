import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/screens/home/wallet_add/air-gapped/airgap_wallet_add_scanner_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/bitbox02_connect_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/trezor_ble_connect_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/trezor_transport_select_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_add/connected/trezor_usb_connect_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_list_screen.dart';
import 'package:coconut_wallet/screens/send/connected/bitbox02_sign_screen.dart';
import 'package:coconut_wallet/screens/send/connected/trezor_sign_screen.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/screens/settings/home_settings/wallet_home_edit_screen.dart';
import 'package:coconut_wallet/screens/settings/home_settings/home_settings_screen.dart';
import 'package:coconut_wallet/screens/settings/app_settings/about/app_info_screen.dart';
import 'package:coconut_wallet/screens/settings/app_settings/about/coconut_crew_screen.dart';
import 'package:coconut_wallet/screens/settings/app_settings/network/block_explorer_screen.dart';
import 'package:coconut_wallet/screens/settings/app_settings/network/electrum_server_screen.dart';
import 'package:coconut_wallet/screens/settings/app_settings/tools/log_viewer_screen.dart';
import 'package:coconut_wallet/screens/review/negative_feedback_screen.dart';
import 'package:coconut_wallet/screens/review/positive_feedback_screen.dart';
import 'package:coconut_wallet/screens/send/broadcasting_complete_screen.dart';
import 'package:coconut_wallet/screens/send/broadcasting_screen.dart';
import 'package:coconut_wallet/screens/send/send_screen.dart';
import 'package:coconut_wallet/screens/send/utxo_selection_screen.dart';
import 'package:coconut_wallet/screens/send/send_confirm_screen.dart';
import 'package:coconut_wallet/screens/send/air-gapped/signed_psbt_scanner_screen.dart';
import 'package:coconut_wallet/screens/send/air-gapped/unsigned_transaction_qr_screen.dart';
import 'package:coconut_wallet/screens/settings/tools/bip329/label_export_screen.dart';
import 'package:coconut_wallet/screens/settings/tools/bip329/label_import_screen.dart';
import 'package:coconut_wallet/screens/settings/tools/bip329/label_management_screen.dart';
import 'package:coconut_wallet/screens/settings/tools/bip39_word_list_screen.dart';
import 'package:coconut_wallet/screens/settings/tools/p2p_calculator_screen.dart';
import 'package:coconut_wallet/screens/settings/tools/transaction_draft_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/address_list_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/address_search_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_detail_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_detail_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_list_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_merge/utxo_merge_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_overview_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_split_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_tag_crud_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/taproot_wallet_backup_data_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_backup_data_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_receive_address_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_resync/wallet_resync_screen.dart';
import 'package:coconut_wallet/widgets/common/overlays/custom_loading_overlay.dart';
import 'package:flutter/widgets.dart';

Map<String, WidgetBuilder> buildAppRoutes() {
  return {
    AppRouteNames.walletList: (context) => const WalletListScreen(),
    AppRouteNames.homeSettings: (context) => const HomeSettingsScreen(),
    AppRouteNames.appInfo: (context) => const AppInfoScreen(),
    AppRouteNames.signedPsbtScanner: (context) => const SignedPsbtScannerScreen(),
    AppRouteNames.positiveFeedback: (context) => const PositiveFeedbackScreen(),
    AppRouteNames.negativeFeedback: (context) => const NegativeFeedbackScreen(),
    AppRouteNames.mnemonicWordList: (context) => const Bip39ListScreen(),
    AppRouteNames.coconutCrew: (context) => const CoconutCrewScreen(),
    AppRouteNames.logViewer: (context) => const LogViewerScreen(),
    AppRouteNames.electrumServer: (context) => const ElectrumServerScreen(),
    AppRouteNames.blockExplorer: (context) => const BlockExplorerScreen(),
    AppRouteNames.broadcasting:
        (context) => _buildLoadingScreenWithArgs<BroadcastingRouteArgs>(
          context,
          (args) => BroadcastingScreen(signedTransactionDraftId: args.signedTransactionDraftId),
        ),
    AppRouteNames.receiveAddress:
        (context) =>
            _buildScreenWithArgs<ReceiveAddressRouteArgs>(context, (args) => ReceiveAddressScreen(id: args.id)),
    AppRouteNames.addressList:
        (context) => _buildScreenWithArgs<AddressListRouteArgs>(
          context,
          (args) => AddressListScreen(
            id: args.id,
            initialShowOnlyWatchedAddresses: args.initialShowOnlyWatchedAddresses ?? false,
          ),
        ),
    AppRouteNames.walletDetail:
        (context) => _buildScreenWithArgs<WalletDetailRouteArgs>(
          context,
          (args) => WalletDetailScreen(id: args.id, entryPoint: args.entryPoint),
        ),
    AppRouteNames.walletBackupData:
        (context) => _buildScreenWithArgs<WalletBackupDataRouteArgs>(
          context,
          (args) => WalletBackupDataScreen(id: args.id, walletName: args.walletName),
        ),
    AppRouteNames.taprootWalletBackupData:
        (context) => _buildScreenWithArgs<TaprootWalletBackupDataRouteArgs>(
          context,
          (args) => TaprootWalletBackupDataScreen(id: args.id, walletName: args.walletName),
        ),
    AppRouteNames.addressSearch:
        (context) => _buildScreenWithArgs<AddressSearchRouteArgs>(context, (args) => AddressSearchScreen(id: args.id)),
    AppRouteNames.transactionDetail:
        (context) => _buildScreenWithArgs<TransactionDetailRouteArgs>(
          context,
          (args) => TransactionDetailScreen(id: args.id, txHash: args.txHash),
        ),
    AppRouteNames.transactionFeeBumping:
        (context) => _buildScreenWithArgs<TransactionFeeBumpingRouteArgs>(
          context,
          (args) => TransactionFeeBumpingScreen(
            transaction: args.transaction,
            feeBumpingType: args.feeBumpingType,
            walletId: args.id,
            walletName: args.walletName,
          ),
        ),
    AppRouteNames.unsignedTransactionQr:
        (context) => _buildScreenWithArgs<UnsignedTransactionQrRouteArgs>(
          context,
          (args) => UnsignedTransactionQrScreen(walletName: args.walletName),
        ),
    AppRouteNames.send:
        (context) => _buildScreenWithArgs<SendRouteArgs>(
          context,
          (args) => SendScreen(
            walletId: args.id,
            sendEntryPoint: args.sendEntryPoint,
            transactionDraftId: args.transactionDraftId,
            initialSatsFromP2P: args.initialSatsFromP2P,
            selectedUtxoList: args.selectedUtxoList,
            initialBitcoinUri: args.initialBitcoinUri,
          ),
        ),
    AppRouteNames.mergeUtxos:
        (context) => _buildLoadingScreenWithArgs<UtxoMergeRouteArgs>(context, (args) => UtxoMergeScreen(id: args.id)),
    AppRouteNames.splitUtxo:
        (context) => _buildScreenWithArgs<UtxoSplitRouteArgs>(context, (args) => UtxoSplitScreen(id: args.id)),
    AppRouteNames.utxoTag:
        (context) => _buildScreenWithArgs<UtxoTagCrudRouteArgs>(context, (args) => UtxoTagCrudScreen(id: args.id)),
    AppRouteNames.walletResync:
        (context) => _buildScreenWithArgs<WalletResyncRouteArgs>(context, (args) => WalletResyncScreen(id: args.id)),
    AppRouteNames.walletAddScanner:
        (context) => _buildLoadingScreenWithArgs<WalletAddScannerRouteArgs>(
          context,
          (args) => WalletAddScannerScreen(importSource: args.walletImportSource),
        ),
    AppRouteNames.walletInfo:
        (context) => _buildLoadingScreenWithArgs<WalletInfoRouteArgs>(
          context,
          (args) => WalletInfoScreen(
            id: args.id,
            walletType: args.walletType,
            entryPoint: args.entryPoint,
            showMfpInput: args.showMfpInput ?? false,
          ),
        ),
    AppRouteNames.broadcastingComplete:
        (context) => _buildLoadingScreenWithArgs<BroadcastingCompleteRouteArgs>(
          context,
          (args) => BroadcastingCompleteScreen(id: args.id, txHash: args.txHash),
        ),
    AppRouteNames.utxoSelection:
        (context) => _buildLoadingScreenWithArgs<UtxoSelectionRouteArgs>(
          context,
          (args) => UtxoSelectionScreen(
            selectedUtxoList: args.selectedUtxoList,
            walletId: args.id,
            currentUnit: args.currentUnit,
          ),
        ),
    AppRouteNames.sendConfirm:
        (context) => _buildLoadingScreenWithArgs<SendConfirmRouteArgs>(
          context,
          (args) => SendConfirmScreen(currentUnit: args.currentUnit),
        ),
    AppRouteNames.utxoList:
        (context) => _buildLoadingScreenWithArgs<UtxoListRouteArgs>(context, (args) => UtxoListScreen(id: args.id)),
    AppRouteNames.utxoOverview:
        (context) =>
            _buildLoadingScreenWithArgs<UtxoOverviewRouteArgs>(context, (args) => UtxoOverviewScreen(id: args.id)),
    AppRouteNames.utxoDetail:
        (context) => _buildLoadingScreenWithArgs<UtxoDetailRouteArgs>(
          context,
          (args) => UtxoDetailScreen(utxo: args.utxo, id: args.id),
        ),
    AppRouteNames.p2pCalculator: (context) => const P2PCalculatorScreen(),
    AppRouteNames.transactionDraft:
        (context) => _buildScreenWithArgs<TransactionDraftRouteArgs>(
          context,
          (args) => TransactionDraftScreen(isSignedTabActive: args.isSignedTabActive),
        ),
    AppRouteNames.walletHomeEdit: (context) => const WalletHomeEditScreen(),
    AppRouteNames.trezorTransportSelect:
        (context) => _buildScreenWithArgs<TrezorTransportSelectRouteArgs>(
          context,
          (args) => TrezorTransportSelectScreen(
            psbtBase64: args.psbtBase64,
            walletName: args.walletName,
            walletFingerprint: args.walletFingerprint,
          ),
        ),
    AppRouteNames.trezorBleConnect:
        (context) => _buildScreenWithArgs<TrezorBleConnectRouteArgs>(
          context,
          (args) => TrezorBleConnectScreen(
            psbtBase64: args.psbtBase64,
            walletName: args.walletName,
            walletFingerprint: args.walletFingerprint,
          ),
        ),
    AppRouteNames.trezorUsbConnect:
        (context) => _buildScreenWithArgs<TrezorUsbConnectRouteArgs>(
          context,
          (args) => TrezorUsbConnectScreen(
            psbtBase64: args.psbtBase64,
            walletName: args.walletName,
            walletFingerprint: args.walletFingerprint,
          ),
        ),
    AppRouteNames.bitbox02Connect:
        (context) => _buildScreenWithArgs<BitBox02ConnectRouteArgs>(
          context,
          (args) => BitBox02ConnectScreen(
            importSource: args.importSource,
            psbtBase64: args.psbtBase64,
            walletName: args.walletName,
          ),
        ),
    AppRouteNames.bitbox02Sign:
        (context) => _buildScreenWithArgs<BitBox02SignRouteArgs>(
          context,
          (args) => BitBox02SignScreen(
            psbtBase64: args.psbtBase64,
            walletName: args.walletName,
            walletFingerprint: args.walletFingerprint ?? '',
            isFromSendFlow: args.isFromSendFlow ?? false,
            transport: args.transport ?? 'usb',
          ),
        ),
    AppRouteNames.trezorSign:
        (context) => _buildScreenWithArgs<TrezorSignRouteArgs>(
          context,
          (args) => TrezorSignScreen(
            psbtBase64: args.psbtBase64,
            walletName: args.walletName,
            walletFingerprint: args.walletFingerprint ?? '',
            isFromSendFlow: args.isFromSendFlow ?? false,
            transport: args.transport == 'usb' ? TrezorTransport.usb : TrezorTransport.ble,
          ),
        ),
    AppRouteNames.labelManagement:
        (context) => _buildScreenWithArgs<LabelManagementRouteArgs>(
          context,
          (args) => LabelManagementScreen(
            walletId: args.id,
            showImportMemosFromOtherWalletsOption: args.showImportMemosFromOtherWalletsOption ?? true,
          ),
        ),
    AppRouteNames.labelImport:
        (context) => _buildScreenWithArgs<LabelImportRouteArgs>(
          context,
          (args) => LabelImportScreen(
            walletId: args.id,
            showImportMemosFromOtherWalletsOption: args.showImportMemosFromOtherWalletsOption ?? true,
          ),
        ),
    AppRouteNames.labelExport:
        (context) => _buildScreenWithArgs<LabelExportRouteArgs>(
          context,
          (args) => LabelExportScreen(initialSelectedWalletId: args.id),
        ),
  };
}

Widget _buildScreenWithArgs<T>(BuildContext context, Widget Function(T) builder) {
  final args = ModalRoute.of(context)!.settings.arguments as T;
  return builder(args);
}

Widget _buildLoadingScreenWithArgs<T>(BuildContext context, Widget Function(T) builder) {
  final args = ModalRoute.of(context)!.settings.arguments as T;
  return CustomLoadingOverlay(child: builder(args));
}
