import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/services/security/hot_wallet_signing_service.dart';
import 'package:coconut_wallet/services/transaction/unsigned_psbt_service.dart';
import 'package:coconut_wallet/utils/transaction_intent_validator.dart';

/// 핫월렛 온체인 잔액에서 한 주소로 보내는 거래를 만들고 서명함(보딩 펀딩, 직접 출금 수수료 준비)
class HotWalletOnchainPayment {
  HotWalletOnchainPayment(this._walletProvider, this.walletId, {HotWalletSigningService? signingService})
    : _signingService = signingService ?? HotWalletSigningService();

  final WalletProvider _walletProvider;
  final HotWalletSigningService _signingService;
  final int walletId;

  List<UtxoState> get _spendableUtxos => [
    for (final utxo in _walletProvider.getUtxoList(walletId))
      if (utxo.status == UtxoStatus.unspent) utxo,
  ];

  /// [sweep]이면 수수료를 [amountSats]에서 뺌
  TransactionBuildResult build({
    required String address,
    required int amountSats,
    required double feeRate,
    bool sweep = false,
    List<UtxoState> utxos = const [],
  }) {
    final wallet = _walletProvider.getWalletById(walletId);
    return TransactionBuilder(
      availableUtxos: utxos.isNotEmpty ? utxos : _spendableUtxos,
      recipients: {address: amountSats},
      feeRate: feeRate,
      changeDerivationPath: _walletProvider.getChangeAddress(walletId).derivationPath,
      walletItemBase: wallet,
      isFeeSubtractedFromAmount: sweep,
      isUtxoFixed: utxos.isNotEmpty,
    ).build();
  }

  bool get needsPassphrase =>
      _walletProvider.getWalletById(walletId).hotWalletMetadata?.enterPassphraseWhenSigning ?? false;

  Future<bool> validatePassphrase(Uint8List passphrase) {
    final wallet = _walletProvider.getWalletById(walletId);
    final metadata = wallet.hotWalletMetadata;
    final walletBase = wallet.walletBase;
    if (metadata == null || walletBase is! SingleSignatureWallet) return Future.value(false);
    return _signingService.validatePassphrase(
      storageKey: metadata.secureStorageKey,
      passphrase: passphrase,
      addressTypeName: walletBase.addressType.name,
      accountIndex: metadata.accountIndex,
      expectedExtendedPublicKey: walletBase.keyStore.extendedPublicKey.serialize(),
    );
  }

  /// 서명 전 PSBT(보딩 등록용)와 서명한 거래
  Future<({String unsignedPsbt, Transaction signedTx})> sign(Transaction transaction, {Uint8List? passphrase}) async {
    final wallet = _walletProvider.getWalletById(walletId);
    final metadata = wallet.hotWalletMetadata;
    final walletBase = wallet.walletBase;
    if (metadata == null || walletBase is! SingleSignatureWallet) throw StateError('Local signer is not available');
    final prepared = await prepareUnsignedPsbt(transaction: transaction, wallet: walletBase);
    final signed = await _signingService.sign((
      storageKey: metadata.secureStorageKey,
      passphrase: passphrase,
      addressTypeName: walletBase.addressType.name,
      accountIndex: metadata.accountIndex,
      expectedExtendedPublicKey: walletBase.keyStore.extendedPublicKey.serialize(),
      unsignedPsbt: prepared.serialized,
    ));
    final signedTx = Psbt.parse(signed).getSignedTransaction(walletBase.addressType);
    TransactionIntentValidator.ensureMatches(prepared.psbt.unsignedTransaction, signedTx);
    return (unsignedPsbt: prepared.serialized, signedTx: signedTx);
  }
}
