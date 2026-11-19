import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/security/hot_wallet_signing_service.dart';
import 'package:coconut_wallet/services/transaction/unsigned_psbt_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/transaction_intent_validator.dart';

/// 서명한 보딩 펀딩 거래. [unsignedPsbt]로 보딩을 등록한 뒤 전송
class ArkSignedFunding {
  const ArkSignedFunding({
    required this.unsignedPsbt,
    required this.signedTxHex,
    required this.txid,
    this.transaction,
    this.feeSats = 0,
  });

  final String unsignedPsbt;
  final String signedTxHex;
  final String txid;
  final Transaction? transaction;
  final int feeSats;
}

/// 아크를 채울 온체인 돈이 나오는 곳(핫월렛 하나)
abstract interface class ArkFillSource {
  /// 확정된 잔액만 씀
  int get confirmedSats;
  bool get needsPassphrase;
  Future<bool> validatePassphrase(Uint8List passphrase);

  /// [address]로 [amountSats]를 보낼 때 온체인 수수료, 잔액이 모자라면 null. [sweep]이면 수수료를 금액에서 뺌
  int? quoteFee(String address, int amountSats, double feeRate, {bool sweep = false});
  Future<ArkSignedFunding> sign(
    String address,
    int amountSats,
    double feeRate, {
    bool sweep = false,
    Uint8List? passphrase,
  });

  /// 코코넛 노드로 전송, 실패하면 false
  Future<bool> broadcast(ArkSignedFunding funding);
  Future<void> markSpent(ArkSignedFunding funding);
}

/// 코코넛 핫월렛에서 보딩 주소로 보내는 거래를 만들고 서명(feat/ark의 HotWalletOnchainPayment)
class HotWalletFillSource implements ArkFillSource {
  HotWalletFillSource(
    this._walletProvider,
    this._nodeProvider,
    this._utxoRepository,
    this.walletId, {
    HotWalletSigningService? signingService,
  }) : _signingService = signingService ?? HotWalletSigningService();

  final WalletProvider _walletProvider;
  final NodeProvider _nodeProvider;
  final UtxoRepository _utxoRepository;
  final HotWalletSigningService _signingService;
  final int walletId;

  List<UtxoState> get _spendableUtxos => [
    for (final utxo in _walletProvider.getUtxoList(walletId))
      if (utxo.status == UtxoStatus.unspent) utxo,
  ];

  TransactionBuildResult _build(String address, int amountSats, double feeRate, bool sweep) {
    final wallet = _walletProvider.getWalletById(walletId);
    return TransactionBuilder(
      availableUtxos: _spendableUtxos,
      recipients: {address: amountSats},
      feeRate: feeRate,
      changeDerivationPath: _walletProvider.getChangeAddress(walletId).derivationPath,
      walletItemBase: wallet,
      isFeeSubtractedFromAmount: sweep,
      isUtxoFixed: false,
    ).build();
  }

  @override
  int get confirmedSats => _walletProvider.getWalletBalance(walletId).confirmed;

  @override
  bool get needsPassphrase =>
      _walletProvider.getWalletById(walletId).hotWalletMetadata?.enterPassphraseWhenSigning ?? false;

  @override
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

  @override
  int? quoteFee(String address, int amountSats, double feeRate, {bool sweep = false}) {
    final built = _build(address, amountSats, feeRate, sweep);
    return built.isFailure ? null : built.estimatedFee;
  }

  @override
  Future<ArkSignedFunding> sign(
    String address,
    int amountSats,
    double feeRate, {
    bool sweep = false,
    Uint8List? passphrase,
  }) async {
    final built = _build(address, amountSats, feeRate, sweep);
    if (built.isFailure) throw built.exception ?? StateError('The funding transaction could not be built');
    final wallet = _walletProvider.getWalletById(walletId);
    final metadata = wallet.hotWalletMetadata;
    final walletBase = wallet.walletBase;
    if (metadata == null || walletBase is! SingleSignatureWallet) throw StateError('Local signer is not available');
    final prepared = await prepareUnsignedPsbt(transaction: built.transaction!, wallet: walletBase);
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
    return ArkSignedFunding(
      unsignedPsbt: prepared.serialized,
      signedTxHex: signedTx.serialize(),
      txid: signedTx.transactionHash,
      transaction: signedTx,
      feeSats: built.estimatedFee,
    );
  }

  @override
  Future<bool> broadcast(ArkSignedFunding funding) async {
    final result = await _nodeProvider.broadcast(funding.transaction!);
    if (result.isFailure) Logger.error('HotWalletFillSource: node broadcast failed: ${result.error}');
    return result.isSuccess;
  }

  @override
  Future<void> markSpent(ArkSignedFunding funding) async {
    try {
      await _utxoRepository.markUnspentInputsAsOutgoing(walletId, funding.transaction!);
    } catch (error) {
      Logger.error('HotWalletFillSource: funding sent, but marking inputs failed: $error');
    }
  }
}
