import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/extensions/double_extensions.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_ble_connectivity_service.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter/foundation.dart';

typedef _HotWalletSigningArguments =
    ({
      String mnemonic,
      String passphrase,
      String addressTypeName,
      int accountIndex,
      String expectedExtendedPublicKey,
      String unsignedPsbt,
    });

typedef _HotWalletPassphraseValidationArguments =
    ({String mnemonic, String passphrase, String addressTypeName, int accountIndex, String expectedExtendedPublicKey});

bool _validateHotWalletPassphraseInBackground(_HotWalletPassphraseValidationArguments arguments) {
  final mnemonicBytes = Uint8List.fromList(utf8.encode(arguments.mnemonic));
  final passphraseBytes = Uint8List.fromList(utf8.encode(arguments.passphrase));
  SingleSignatureVault? vault;
  try {
    vault = SingleSignatureVault.fromMnemonic(
      mnemonicBytes,
      passphrase: passphraseBytes,
      addressType: AddressType.getAddressTypeFromName(arguments.addressTypeName),
      accountIndex: arguments.accountIndex,
    );
    return vault.keyStore.extendedPublicKey.serialize() == arguments.expectedExtendedPublicKey;
  } finally {
    vault?.keyStore.wipeSeed();
    mnemonicBytes.fillRange(0, mnemonicBytes.length, 0);
    passphraseBytes.fillRange(0, passphraseBytes.length, 0);
  }
}

String _signHotWalletInBackground(_HotWalletSigningArguments arguments) {
  final mnemonicBytes = Uint8List.fromList(utf8.encode(arguments.mnemonic));
  final passphraseBytes = Uint8List.fromList(utf8.encode(arguments.passphrase));
  SingleSignatureVault? vault;
  try {
    final addressType = AddressType.getAddressTypeFromName(arguments.addressTypeName);
    vault = SingleSignatureVault.fromMnemonic(
      mnemonicBytes,
      passphrase: passphraseBytes,
      addressType: addressType,
      accountIndex: arguments.accountIndex,
    );
    if (vault.keyStore.extendedPublicKey.serialize() != arguments.expectedExtendedPublicKey) {
      throw StateError('The signer does not match this wallet');
    }

    final signedPsbt = vault.addSignatureToPsbt(arguments.unsignedPsbt);
    Psbt.parse(signedPsbt).getSignedTransaction(addressType);
    return signedPsbt;
  } finally {
    vault?.keyStore.wipeSeed();
    mnemonicBytes.fillRange(0, mnemonicBytes.length, 0);
    passphraseBytes.fillRange(0, passphraseBytes.length, 0);
  }
}

class SendConfirmViewModel extends ChangeNotifier {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;
  late WalletItemBase _walletListItemBase;
  Psbt? _unsignedPsbt;
  int? _totalUsedAmount;
  late final double _totalSendAmount;

  SendConfirmViewModel(this._sendInfoProvider, this._walletProvider) {
    _walletListItemBase = _walletProvider.getWalletById(_sendInfoProvider.walletId!);
    _setTotalSendAmount();
  }

  int? get estimatedFee => _unsignedPsbt?.fee;
  String get walletName => _walletListItemBase.name;
  String? get txWaitingForSign => _sendInfoProvider.txWaitingForSign;
  int? get totalUsedAmount => _totalUsedAmount;
  Transaction? get transaction => _sendInfoProvider.transaction;
  List<int> get externalOutputAmounts =>
      transaction?.outputs.where((output) => output.isChangeOutput != true).map((output) => output.amount).toList() ??
      [];
  List<int> get changeOutputAmounts =>
      transaction?.outputs.where((output) => output.isChangeOutput == true).map((output) => output.amount).toList() ??
      [];
  List<int?> get inputAmounts =>
      _unsignedPsbt?.inputs.map((input) => input.witnessUtxo?.amount).toList() ??
      List<int?>.filled(transaction?.inputs.length ?? 0, null);
  double? get totalSendAmount => _totalSendAmount; // BTC
  WalletImportSource get walletImportSource => _walletListItemBase.walletImportSource;
  bool get isHotWallet => _walletListItemBase.hasLocalKey && _walletListItemBase.localSignerMetadata != null;
  bool get shouldEnterPassphraseWhenSigning =>
      _walletListItemBase.localSignerMetadata?.enterPassphraseWhenSigning ?? false;
  String? get hotWalletSecretStorageKey => _walletListItemBase.localSignerMetadata?.secureStorageKey;

  String get walletFingerprint {
    final wallet = _walletListItemBase.walletBase;
    if (wallet is SingleSignatureWallet) {
      return wallet.keyStore.masterFingerprint;
    }
    return '';
  }

  bool get isSingleSigWallet => _walletListItemBase.walletType == WalletType.singleSignature;

  String? get walletExtendedPublicKey {
    final wallet = _walletListItemBase.walletBase;
    if (wallet is SingleSignatureWallet) {
      return wallet.keyStore.extendedPublicKey.serialize();
    }
    return null;
  }

  /// Returns the import source of a currently connected hardware device whose
  /// cached xpub matches the current wallet, or null if none is connected.
  Future<WalletImportSource?> findConnectedMatchingDevice() async {
    final xpub = walletExtendedPublicKey;
    if (xpub == null) return null;

    final trezorDevice = TrezorDevice.lastConnected;
    if (trezorDevice != null && trezorDevice.cachedXpub == xpub) {
      final connected = await TrezorBleConnectivityService.isDeviceConnected(trezorDevice.transport);
      if (connected) return WalletImportSource.trezor;
    }

    final bitboxDevice = BitBox02Device.lastConnected;
    if (bitboxDevice != null && bitboxDevice.cachedXpub == xpub) {
      final connected = await BitBox02Device.isConnected();
      if (connected) return WalletImportSource.bitbox02;
    }

    return null;
  }

  void _setTotalSendAmount() {
    final externalOutputAmountSum = externalOutputAmounts.fold<int>(0, (sum, amount) => sum + amount);
    _totalSendAmount = UnitUtil.convertSatoshiToBitcoin(externalOutputAmountSum).roundTo8Digits();
  }

  Future<void> setEstimatedFeeAndTotalUsedAmount() async {
    _unsignedPsbt = await _generateUnsignedPsbt();
    _totalUsedAmount = UnitUtil.convertBitcoinToSatoshi(_totalSendAmount) + _unsignedPsbt!.fee;
    notifyListeners();
  }

  Future<Psbt> _generateUnsignedPsbt() async {
    assert(_sendInfoProvider.transaction != null);
    return Psbt.fromTransaction(_sendInfoProvider.transaction!, _walletListItemBase.walletBase);
  }

  void setTxWaitingForSign() {
    assert(_unsignedPsbt != null);
    _sendInfoProvider.setTxWaitingForSign(_unsignedPsbt!.serialize());
  }

  Future<void> signHotWallet({required String mnemonic, required String passphrase}) async {
    final metadata = _walletListItemBase.localSignerMetadata;
    final watchOnlyWallet = _walletListItemBase.walletBase;
    if (!isHotWallet || metadata == null || watchOnlyWallet is! SingleSignatureWallet || _unsignedPsbt == null) {
      throw StateError('Local signer is not available');
    }

    final unsignedPsbt = _unsignedPsbt!.serialize();
    _sendInfoProvider.setTxWaitingForSign(unsignedPsbt);
    final signedPsbt = await compute(_signHotWalletInBackground, (
      mnemonic: mnemonic,
      passphrase: passphrase,
      addressTypeName: watchOnlyWallet.addressType.name,
      accountIndex: metadata.accountIndex,
      expectedExtendedPublicKey: watchOnlyWallet.keyStore.extendedPublicKey.serialize(),
      unsignedPsbt: unsignedPsbt,
    ));
    _sendInfoProvider.setSignedResult(signedPsbt);
  }

  Future<bool> validateHotWalletPassphrase({required String mnemonic, required String passphrase}) async {
    final metadata = _walletListItemBase.localSignerMetadata;
    final wallet = _walletListItemBase.walletBase;
    if (!isHotWallet || metadata == null || wallet is! SingleSignatureWallet) {
      return false;
    }

    return compute(_validateHotWalletPassphraseInBackground, (
      mnemonic: mnemonic,
      passphrase: passphrase,
      addressTypeName: wallet.addressType.name,
      accountIndex: metadata.accountIndex,
      expectedExtendedPublicKey: wallet.keyStore.extendedPublicKey.serialize(),
    ));
  }
}
