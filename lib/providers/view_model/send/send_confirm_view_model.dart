import 'package:coconut_wallet/services/transaction/unsigned_psbt_service.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/extensions/double_extensions.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/hardware_wallet/bitbox02_device.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_connectivity_service.dart';
import 'package:coconut_wallet/services/hardware_wallet/trezor_device.dart';
import 'package:coconut_wallet/services/security/hot_wallet_signing_service.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:flutter/foundation.dart';

class SendConfirmViewModel extends ChangeNotifier {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;
  final HotWalletSigningService _hotWalletSigningService;
  late WalletItemBase _walletListItemBase;
  Psbt? _unsignedPsbt;
  String? _serializedUnsignedPsbt;
  int? _preparedFee;
  bool _disposed = false;
  int? _totalUsedAmount;
  late final double _totalSendAmount;

  SendConfirmViewModel(this._sendInfoProvider, this._walletProvider, {HotWalletSigningService? hotWalletSigningService})
    : _hotWalletSigningService = hotWalletSigningService ?? HotWalletSigningService() {
    _walletListItemBase = _walletProvider.getWalletById(_sendInfoProvider.walletId!);
    _setTotalSendAmount();
  }

  int? get estimatedFee => _preparedFee;
  bool get isTransactionReady => _unsignedPsbt != null;
  int get walletId => _walletListItemBase.id;
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
  bool get isHotWallet => _walletListItemBase.hasLocalKey && _walletListItemBase.hotWalletMetadata != null;
  bool get shouldEnterPassphraseWhenSigning =>
      _walletListItemBase.hotWalletMetadata?.enterPassphraseWhenSigning ?? false;
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
      final connected = await TrezorConnectivityService.isDeviceConnected(trezorDevice.transport);
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
    final result = await prepareUnsignedPsbt(
      transaction: _sendInfoProvider.transaction!,
      wallet: _walletListItemBase.walletBase,
      passport: walletImportSource == WalletImportSource.passport,
    );
    if (_disposed) return;
    _unsignedPsbt = result.psbt;
    _serializedUnsignedPsbt = result.serialized;
    _preparedFee = result.fee;
    _totalUsedAmount = UnitUtil.convertBitcoinToSatoshi(_totalSendAmount) + result.fee;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void setTxWaitingForSign() {
    assert(_unsignedPsbt != null);
    _sendInfoProvider.setTxWaitingForSign(_serializedUnsignedPsbt!);
  }

  Future<void> signHotWallet({Uint8List? passphrase}) async {
    final metadata = _walletListItemBase.hotWalletMetadata;
    final watchOnlyWallet = _walletListItemBase.walletBase;
    if (!isHotWallet || metadata == null || watchOnlyWallet is! SingleSignatureWallet || _unsignedPsbt == null) {
      throw StateError('Local signer is not available');
    }

    final unsignedPsbt = _serializedUnsignedPsbt!;
    _sendInfoProvider.setTxWaitingForSign(unsignedPsbt);
    final signedPsbt = await _hotWalletSigningService.sign((
      storageKey: metadata.secureStorageKey,
      passphrase: passphrase,
      addressTypeName: watchOnlyWallet.addressType.name,
      accountIndex: metadata.accountIndex,
      expectedExtendedPublicKey: watchOnlyWallet.keyStore.extendedPublicKey.serialize(),
      unsignedPsbt: unsignedPsbt,
    ));
    _sendInfoProvider.setSignedResult(signedPsbt);
  }

  Future<bool> validateHotWalletPassphrase(Uint8List passphrase) async {
    final metadata = _walletListItemBase.hotWalletMetadata;
    final wallet = _walletListItemBase.walletBase;
    if (!isHotWallet || metadata == null || wallet is! SingleSignatureWallet) {
      return false;
    }

    return _hotWalletSigningService.validatePassphrase(
      storageKey: metadata.secureStorageKey,
      passphrase: passphrase,
      addressTypeName: wallet.addressType.name,
      accountIndex: metadata.accountIndex,
      expectedExtendedPublicKey: wallet.keyStore.extendedPublicKey.serialize(),
    );
  }
}
