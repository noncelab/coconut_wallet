import 'dart:convert';

import 'package:cbor/cbor.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/transaction_intent_validator.dart';
import 'package:ur/ur.dart';

enum SignedScanProcessingError { invalidPayload, transactionIntentMismatch, insufficientSignatures }

class SignedScanProcessingResult {
  final SignedScanProcessingError? error;
  final int? missingSignatureCount;

  const SignedScanProcessingResult.success() : error = null, missingSignatureCount = null;

  const SignedScanProcessingResult.failure(SignedScanProcessingError processingError, {this.missingSignatureCount})
    : error = processingError;

  bool get isSuccess => error == null;
}

class SignedPsbtScannerViewModel {
  final SendInfoProvider _sendInfoProvider;
  final WalletProvider _walletProvider;

  SignedPsbtScannerViewModel(this._sendInfoProvider, this._walletProvider);

  bool get isMultisig => _sendInfoProvider.isMultisig!;
  WalletImportSource get walletImportSource => _sendInfoProvider.walletImportSource!;

  int _getMissingSignaturesCount(Psbt psbt) {
    if (!isMultisig) return 0;

    MultisignatureWallet multisigWallet =
        _walletProvider.getWalletById(_sendInfoProvider.walletId!).walletBase as MultisignatureWallet;
    final signedCount = multisigWallet.keyStoreList.where((keyStore) => psbt.isSigned(keyStore)).length;
    final missingCount = multisigWallet.requiredSignature - signedCount;
    return missingCount > 0 ? missingCount : 0;
  }

  WalletBase _getWalletBase() {
    return _walletProvider.getWalletById(_sendInfoProvider.walletId!).walletBase;
  }

  Psbt _parseUnsignedPsbt() {
    return Psbt.parse(_sendInfoProvider.txWaitingForSign!);
  }

  bool _matchesTransactionIntent(Psbt unsignedPsbt, Psbt signedPsbt) {
    return TransactionIntentValidator.matches(unsignedPsbt.unsignedTransaction, signedPsbt.unsignedTransaction);
  }

  bool _matchesDefaultPsbt(Psbt unsignedPsbt, Psbt signedPsbt) {
    final wallet = _getWalletBase();
    final unsignedSendingAmount = unsignedPsbt.sendingAmount(wallet);
    final signedSendingAmount = signedPsbt.sendingAmount(wallet);
    final unsignedTransactionHash = unsignedPsbt.unsignedTransaction?.transactionHash;
    final signedTransactionHash = signedPsbt.unsignedTransaction?.transactionHash;
    final result = unsignedSendingAmount == signedSendingAmount && unsignedTransactionHash == signedTransactionHash;
    return result;
  }

  bool _matchesP2wpkhSigningResult(Psbt unsignedPsbt, Psbt signedPsbt) {
    /// 시드사이너로 서명한 경우 partial_signatures에 pubkey와 DER signature만 있어 defaultCheckResult 항상 false
    /// 패스포트 프라임은 Input/Output의 BIP32 derivation metadata가 제거되어 있어 defaultCheckResult 항상 false (Global XPUB의 derivation 정보는 유지되어 있음)
    /// 아래 코드는 defaultCheckResult가 false인 경우, 서명 전후 트랜잭션이 동일함을 추가 검사함
    final tx = signedPsbt.getSignedTransaction(AddressType.p2wpkh);
    for (var inputIndex = 0; inputIndex < tx.inputs.length; inputIndex++) {
      // 1. 서명 검증
      if (!tx.validateEcdsa(inputIndex, TransactionOutput.parse(unsignedPsbt.psbtMap["inputs"][inputIndex]["01"]))) {
        return false;
      }

      // 2. 공개키 검증
      final signedInput = signedPsbt.inputs[inputIndex];
      final unsignedPublicKey = unsignedPsbt.inputs[inputIndex].bip32Derivation![0].publicKey;
      final hasMismatchedSignatureKey =
          signedInput.signatureList.isNotEmpty && unsignedPublicKey != signedInput.signatureList[0].publicKey;

      /// Passport: partialSig 대신 finalScriptWitness에 최종 witness를 반환
      final hasMismatchedWitnessKey =
          signedInput.finalScriptWitness != null && unsignedPublicKey != signedInput.finalScriptWitness![1];
      if (hasMismatchedSignatureKey || hasMismatchedWitnessKey) {
        return false;
      }
    }

    return true;
  }

  bool _isSignedPsbtMatchingUnsignedPsbt(Psbt signedPsbt) {
    try {
      final unsignedPsbt = _parseUnsignedPsbt();

      if (!_matchesTransactionIntent(unsignedPsbt, signedPsbt)) {
        return false;
      }

      final defaultCheckResult = _matchesDefaultPsbt(unsignedPsbt, signedPsbt);
      if (isMultisig || defaultCheckResult) {
        return defaultCheckResult;
      }

      return _matchesP2wpkhSigningResult(unsignedPsbt, signedPsbt);
    } catch (e) {
      Logger.error(e);
      return false;
    }
  }

  SignedScanProcessingResult processUrSigningResult(UR ur) {
    try {
      final decodedCbor = cbor.decode(ur.cbor) as CborBytes;
      final signedPsbtBase64 = base64Encode(decodedCbor.bytes);
      final signedPsbt = Psbt.parse(signedPsbtBase64);
      return processSignedPsbt(signedPsbt);
    } catch (_) {
      return const SignedScanProcessingResult.failure(SignedScanProcessingError.invalidPayload);
    }
  }

  Psbt? _tryParsePsbt(String signingResult) {
    try {
      return Psbt.parse(signingResult);
    } catch (_) {
      return null;
    }
  }

  Transaction? _tryParseRawTransaction(String signingResult) {
    try {
      return Transaction.parse(signingResult);
    } catch (_) {
      return null;
    }
  }

  bool _isTransactionMatchingUnsignedPsbt(Transaction signedTransaction) {
    try {
      final unsignedPsbt = Psbt.parse(_sendInfoProvider.txWaitingForSign!);
      return TransactionIntentValidator.matches(unsignedPsbt.unsignedTransaction, signedTransaction);
    } catch (e) {
      Logger.error(e);
      return false;
    }
  }

  SignedScanProcessingResult processBbQrSigningResult(dynamic signingResult) {
    try {
      final encodedSigningResult = switch (signingResult) {
        Map() => jsonEncode(signingResult),
        String value => value,
        _ => null,
      };
      if (encodedSigningResult == null) {
        return const SignedScanProcessingResult.failure(SignedScanProcessingError.invalidPayload);
      }

      final signedPsbt = _tryParsePsbt(encodedSigningResult);
      if (signedPsbt != null) {
        return processSignedPsbt(signedPsbt);
      }

      // PSBT가 아닌 경우에도 Raw transaction인지 확인한 뒤 처리한다.
      final rawTransaction = _tryParseRawTransaction(encodedSigningResult);
      if (rawTransaction == null) {
        return const SignedScanProcessingResult.failure(SignedScanProcessingError.invalidPayload);
      }

      return processRawSigningResult(encodedSigningResult, parsedTransaction: rawTransaction);
    } catch (_) {
      return const SignedScanProcessingResult.failure(SignedScanProcessingError.invalidPayload);
    }
  }

  SignedScanProcessingResult processSignedPsbt(Psbt signedPsbt) {
    if (!_isSignedPsbtMatchingUnsignedPsbt(signedPsbt)) {
      return const SignedScanProcessingResult.failure(SignedScanProcessingError.transactionIntentMismatch);
    }

    if (isMultisig) {
      final missingSignatureCount = _getMissingSignaturesCount(signedPsbt);
      if (missingSignatureCount > 0) {
        return SignedScanProcessingResult.failure(
          SignedScanProcessingError.insufficientSignatures,
          missingSignatureCount: missingSignatureCount,
        );
      }
    }

    final serializedSignedPsbt = signedPsbt.serialize();
    _setSignedResult(serializedSignedPsbt);
    return const SignedScanProcessingResult.success();
  }

  SignedScanProcessingResult processRawSigningResult(String signingResult, {Transaction? parsedTransaction}) {
    final signedTransaction = parsedTransaction ?? _tryParseRawTransaction(signingResult);
    if (signedTransaction == null) {
      return const SignedScanProcessingResult.failure(SignedScanProcessingError.invalidPayload);
    }
    if (!_isTransactionMatchingUnsignedPsbt(signedTransaction)) {
      return const SignedScanProcessingResult.failure(SignedScanProcessingError.transactionIntentMismatch);
    }

    _setSignedResult(signingResult);
    return const SignedScanProcessingResult.success();
  }

  void _setSignedResult(String signedResult) {
    _sendInfoProvider.setSignedResult(signedResult);
  }
}
