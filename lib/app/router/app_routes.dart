import 'package:coconut_wallet/screens/home/wallet_add_scanner_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_list_screen.dart';
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
import 'package:coconut_wallet/screens/send/refactor/send_screen.dart';
import 'package:coconut_wallet/screens/send/refactor/utxo_selection_screen.dart';
import 'package:coconut_wallet/screens/send/send_confirm_screen.dart';
import 'package:coconut_wallet/screens/send/signed_psbt_scanner_screen.dart';
import 'package:coconut_wallet/screens/send/unsigned_transaction_qr_screen.dart';
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
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_split_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_tag_crud_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_backup_data_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_receive_address_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_detail_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info_screen.dart';
import 'package:coconut_wallet/widgets/custom_loading_overlay.dart';
import 'package:flutter/widgets.dart';

Map<String, WidgetBuilder> buildAppRoutes() {
  return {
    '/wallet-list': (context) => const WalletListScreen(),
    '/home-settings': (context) => const HomeSettingsScreen(),
    '/app-info': (context) => const AppInfoScreen(),
    '/signed-psbt-scanner': (context) => const SignedPsbtScannerScreen(),
    '/positive-feedback': (context) => const PositiveFeedbackScreen(),
    '/negative-feedback': (context) => const NegativeFeedbackScreen(),
    '/mnemonic-word-list': (context) => const Bip39ListScreen(),
    '/coconut-crew': (context) => const CoconutCrewScreen(),
    '/log-viewer': (context) => const LogViewerScreen(),
    '/electrum-server': (context) => const ElectrumServerScreen(),
    '/block-explorer': (context) => const BlockExplorerScreen(),
    '/broadcasting':
        (context) => _buildLoadingScreenWithArgs(
          context,
          (args) => BroadcastingScreen(
            signedTransactionDraftId:
                args.containsKey('signedTransactionDraftId') ? args['signedTransactionDraftId'] as int? : null,
          ),
        ),
    '/receive-address': (context) => _buildScreenWithArgs(context, (args) => ReceiveAddressScreen(id: args['id'])),
    '/address-list': (context) => _buildScreenWithArgs(context, (args) => AddressListScreen(id: args['id'])),
    '/wallet-detail':
        (context) =>
            _buildScreenWithArgs(context, (args) => WalletDetailScreen(id: args['id'], entryPoint: args['entryPoint'])),
    '/wallet-backup-data':
        (context) => _buildScreenWithArgs(
          context,
          (args) => WalletBackupDataScreen(id: args['id'], walletName: args['walletName']),
        ),
    '/address-search': (context) => _buildScreenWithArgs(context, (args) => AddressSearchScreen(id: args['id'])),
    '/transaction-detail':
        (context) =>
            _buildScreenWithArgs(context, (args) => TransactionDetailScreen(id: args['id'], txHash: args['txHash'])),
    '/transaction-fee-bumping':
        (context) => _buildScreenWithArgs(
          context,
          (args) => TransactionFeeBumpingScreen(
            transaction: args['transaction'],
            feeBumpingType: args['feeBumpingType'],
            walletId: args['walletId'],
            walletName: args['walletName'],
          ),
        ),
    '/unsigned-transaction-qr':
        (context) =>
            _buildScreenWithArgs(context, (args) => UnsignedTransactionQrScreen(walletName: args['walletName'])),
    '/send':
        (context) => _buildScreenWithArgs(
          context,
          (args) => SendScreen(
            walletId: args['walletId'],
            sendEntryPoint: args['sendEntryPoint'],
            transactionDraftId: args['transactionDraftId'],
            initialSatsFromP2P: args['initialSatsFromP2P'],
            selectedUtxoList: args['selectedUtxoList'],
            initialBitcoinUri: args['initialBitcoinUri'],
          ),
        ),
    '/merge-utxos': (context) => _buildLoadingScreenWithArgs(context, (args) => UtxoMergeScreen(id: args['id'])),
    '/split-utxo': (context) => _buildScreenWithArgs(context, (args) => UtxoSplitScreen(id: args['id'])),
    '/utxo-tag': (context) => _buildScreenWithArgs(context, (args) => UtxoTagCrudScreen(id: args['id'])),
    '/wallet-add-scanner':
        (context) => _buildLoadingScreenWithArgs(
          context,
          (args) => WalletAddScannerScreen(importSource: args['walletImportSource']),
        ),
    '/wallet-info':
        (context) => _buildLoadingScreenWithArgs(
          context,
          (args) => WalletInfoScreen(
            id: args['id'],
            isMultisig: args['isMultisig'],
            entryPoint: args['entryPoint'],
            showMfpInput: args['showMfpInput'] ?? false,
          ),
        ),
    '/broadcasting-complete':
        (context) => _buildLoadingScreenWithArgs(
          context,
          (args) => BroadcastingCompleteScreen(id: args['id'], txHash: args['txHash']),
        ),
    '/utxo-selection':
        (context) => _buildLoadingScreenWithArgs(
          context,
          (args) => UtxoSelectionScreen(
            selectedUtxoList: args['selectedUtxoList'],
            walletId: args['walletId'],
            currentUnit: args['currentUnit'],
          ),
        ),
    '/send-confirm':
        (context) =>
            _buildLoadingScreenWithArgs(context, (args) => SendConfirmScreen(currentUnit: args['currentUnit'])),
    '/utxo-list': (context) => _buildLoadingScreenWithArgs(context, (args) => UtxoListScreen(id: args['id'])),
    '/utxo-overview': (context) => _buildLoadingScreenWithArgs(context, (args) => UtxoOverviewScreen(id: args['id'])),
    '/utxo-detail':
        (context) =>
            _buildLoadingScreenWithArgs(context, (args) => UtxoDetailScreen(utxo: args['utxo'], id: args['id'])),
    '/p2p-calculator': (context) => const P2PCalculatorScreen(),
    '/transaction-draft':
        (context) => _buildScreenWithArgs(
          context,
          (args) => TransactionDraftScreen(isSignedTabActive: args['isSignedTabActive']),
        ),
    '/wallet-home-edit': (context) => const WalletHomeEditScreen(),
  };
}

Widget _buildScreenWithArgs(BuildContext context, Widget Function(Map<String, dynamic>) builder) {
  final Map<String, dynamic> args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
  return builder(args);
}

Widget _buildLoadingScreenWithArgs(BuildContext context, Widget Function(Map<String, dynamic>) builder) {
  final Map<String, dynamic> args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};
  return CustomLoadingOverlay(child: builder(args));
}
