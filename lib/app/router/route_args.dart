import 'dart:typed_data';

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_fee_bumping_screen.dart';

class BroadcastingRouteArgs {
  final int? signedTransactionDraftId;
  const BroadcastingRouteArgs({this.signedTransactionDraftId});
}

class ReceiveAddressRouteArgs {
  final int id;
  const ReceiveAddressRouteArgs({required this.id});
}

class AddressListRouteArgs {
  final int id;
  final bool? initialShowOnlyWatchedAddresses;
  const AddressListRouteArgs({required this.id, this.initialShowOnlyWatchedAddresses});
}

class WalletDetailRouteArgs {
  final int id;
  final String entryPoint;
  const WalletDetailRouteArgs({required this.id, required this.entryPoint});
}

class UtxoOrganizerRouteArgs {
  final int id;
  const UtxoOrganizerRouteArgs({required this.id});
}

class WalletBackupDataRouteArgs {
  final int id;
  final String walletName;
  const WalletBackupDataRouteArgs({required this.id, required this.walletName});
}

class TaprootWalletBackupDataRouteArgs {
  final int id;
  final String walletName;
  const TaprootWalletBackupDataRouteArgs({required this.id, required this.walletName});
}

class AddressSearchRouteArgs {
  final int id;
  const AddressSearchRouteArgs({required this.id});
}

class TransactionDetailRouteArgs {
  final int id;
  final String txHash;
  const TransactionDetailRouteArgs({required this.id, required this.txHash});
}

class TransactionFeeBumpingRouteArgs {
  final TransactionRecord transaction;
  final FeeBumpingType feeBumpingType;
  final int id;
  final String walletName;
  const TransactionFeeBumpingRouteArgs({
    required this.transaction,
    required this.feeBumpingType,
    required this.id,
    required this.walletName,
  });
}

class UnsignedTransactionQrRouteArgs {
  final String walletName;
  const UnsignedTransactionQrRouteArgs({required this.walletName});
}

class SendRouteArgs {
  final int? id;
  final SendEntryPoint sendEntryPoint;
  final int? transactionDraftId;
  final int? initialSatsFromP2P;
  final List<UtxoState>? selectedUtxoList;
  final String? initialBitcoinUri;
  const SendRouteArgs({
    this.id,
    required this.sendEntryPoint,
    this.transactionDraftId,
    this.initialSatsFromP2P,
    this.selectedUtxoList,
    this.initialBitcoinUri,
  });
}

class UtxoMergeRouteArgs {
  final int id;
  final bool isActive;
  const UtxoMergeRouteArgs({required this.id, required this.isActive});
}

class UtxoSplitRouteArgs {
  final int id;
  final bool isActive;
  const UtxoSplitRouteArgs({required this.id, required this.isActive});
}

class UtxoTagCrudRouteArgs {
  final int id;
  const UtxoTagCrudRouteArgs({required this.id});
}

class WalletResyncRouteArgs {
  final int id;
  const WalletResyncRouteArgs({required this.id});
}

class WalletAddScannerRouteArgs {
  final WalletImportSource walletImportSource;
  const WalletAddScannerRouteArgs({required this.walletImportSource});
}

class WalletInfoRouteArgs {
  final int id;
  final WalletType walletType;
  final String entryPoint;
  final bool? showMfpInput;
  final bool? highlightMnemonicBackup;
  final bool? showTargetSetting;
  const WalletInfoRouteArgs({
    required this.id,
    required this.walletType,
    required this.entryPoint,
    this.showMfpInput,
    this.highlightMnemonicBackup,
    this.showTargetSetting,
  });
}

class HotWalletMnemonicBackupGuideRouteArgs {
  final int walletId;
  final String descriptor;
  final Uint8List? mnemonic;
  final Uint8List? passphrase;
  final String? secureStorageKey;
  final bool enterPassphraseWhenSigning;
  final bool showWalletCreatedIntro;
  final bool continueToAppLockGuide;
  final bool returnToPreviousOnExit;

  const HotWalletMnemonicBackupGuideRouteArgs({
    required this.walletId,
    required this.descriptor,
    this.mnemonic,
    this.passphrase,
    this.secureStorageKey,
    required this.enterPassphraseWhenSigning,
    this.showWalletCreatedIntro = true,
    this.continueToAppLockGuide = true,
    this.returnToPreviousOnExit = false,
  });
}

class HotWalletMnemonicBackupRouteArgs {
  final Uint8List mnemonic;
  final Uint8List passphrase;
  final bool enterPassphraseWhenSigning;
  final String descriptor;
  final int? walletId;
  final bool continueToAppLockGuide;

  const HotWalletMnemonicBackupRouteArgs({
    required this.mnemonic,
    required this.passphrase,
    this.enterPassphraseWhenSigning = false,
    this.descriptor = '',
    this.walletId,
    this.continueToAppLockGuide = false,
  });
}

class MnemonicBackupConfirmRouteArgs {
  final Uint8List mnemonic;
  final Uint8List passphrase;
  final String descriptor;
  final bool confirmPassphrase;
  final int? walletId;
  final bool continueToAppLockGuide;

  const MnemonicBackupConfirmRouteArgs({
    required this.mnemonic,
    required this.passphrase,
    this.descriptor = '',
    this.confirmPassphrase = false,
    this.walletId,
    this.continueToAppLockGuide = false,
  });
}

class MnemonicBackupCompleteRouteArgs {
  final int? walletId;
  final bool continueToAppLockGuide;
  const MnemonicBackupCompleteRouteArgs({this.walletId, this.continueToAppLockGuide = false});
}

class HotWalletPassphraseCheckRouteArgs {
  final Uint8List mnemonic;
  final String descriptor;
  const HotWalletPassphraseCheckRouteArgs({required this.mnemonic, required this.descriptor});
}

class BroadcastingCompleteRouteArgs {
  final int id;
  final String txHash;
  const BroadcastingCompleteRouteArgs({required this.id, required this.txHash});
}

class UtxoSelectionRouteArgs {
  final List<UtxoState> selectedUtxoList;
  final int id;
  final BitcoinUnit currentUnit;
  const UtxoSelectionRouteArgs({required this.selectedUtxoList, required this.id, required this.currentUnit});
}

class SendConfirmRouteArgs {
  final BitcoinUnit? currentUnit;
  const SendConfirmRouteArgs({this.currentUnit});
}

class UtxoListRouteArgs {
  final int id;
  const UtxoListRouteArgs({required this.id});
}

class UtxoOverviewRouteArgs {
  final int id;
  const UtxoOverviewRouteArgs({required this.id});
}

class UtxoDetailRouteArgs {
  final UtxoState utxo;
  final int id;
  const UtxoDetailRouteArgs({required this.utxo, required this.id});
}

class TransactionDraftRouteArgs {
  final bool? isSignedTabActive;
  const TransactionDraftRouteArgs({this.isSignedTabActive});
}

class TrezorTransportSelectRouteArgs {
  final int? walletId;
  final String? psbtBase64;
  final String? walletName;
  final String? walletFingerprint;
  const TrezorTransportSelectRouteArgs({this.walletId, this.psbtBase64, this.walletName, this.walletFingerprint});
}

class TrezorBleConnectRouteArgs {
  final int? walletId;
  final String? psbtBase64;
  final String? walletName;
  final String? walletFingerprint;
  const TrezorBleConnectRouteArgs({this.walletId, this.psbtBase64, this.walletName, this.walletFingerprint});
}

class TrezorUsbConnectRouteArgs {
  final int? walletId;
  final String? psbtBase64;
  final String? walletName;
  final String? walletFingerprint;
  const TrezorUsbConnectRouteArgs({this.walletId, this.psbtBase64, this.walletName, this.walletFingerprint});
}

class BitBox02ConnectRouteArgs {
  final WalletImportSource importSource;
  final int? walletId;
  final String? psbtBase64;
  final String? walletName;
  const BitBox02ConnectRouteArgs({required this.importSource, this.walletId, this.psbtBase64, this.walletName});
}

class BitBox02SignRouteArgs {
  final int walletId;
  final String psbtBase64;
  final String walletName;
  final String? walletFingerprint;
  final bool? isFromSendFlow;

  const BitBox02SignRouteArgs({
    required this.walletId,
    required this.psbtBase64,
    required this.walletName,
    this.walletFingerprint,
    this.isFromSendFlow,
  });
}

class TrezorSignRouteArgs {
  final int walletId;
  final String psbtBase64;
  final String walletName;
  final String? walletFingerprint;
  final bool? isFromSendFlow;
  final String? transport;
  const TrezorSignRouteArgs({
    required this.walletId,
    required this.psbtBase64,
    required this.walletName,
    this.walletFingerprint,
    this.isFromSendFlow,
    this.transport,
  });
}

class LabelManagementRouteArgs {
  final int? id;
  final bool? showImportMemosFromOtherWalletsOption;
  const LabelManagementRouteArgs({this.id, this.showImportMemosFromOtherWalletsOption});
}

class LabelImportRouteArgs {
  final int? id;
  final bool? showImportMemosFromOtherWalletsOption;
  const LabelImportRouteArgs({this.id, this.showImportMemosFromOtherWalletsOption});
}

class LabelExportRouteArgs {
  final int? id;
  const LabelExportRouteArgs({this.id});
}
