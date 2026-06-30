import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';

class SignedPsbtScannerViewModel {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;

  SignedPsbtScannerViewModel(this._sendInfoProvider, this._walletProvider);

  bool get isMultisig => _sendInfoProvider.isMultisig!;
  WalletImportSource get walletImportSource => _sendInfoProvider.walletImportSource!;
  String? get unsignedPsbtString => _sendInfoProvider.txWaitingForSign;

  int getMissingSignaturesCount(Psbt psbt) {
    if (!isMultisig) return 0;

    MultisignatureWallet multisigWallet =
        _walletProvider.getWalletById(_sendInfoProvider.walletId!).walletBase as MultisignatureWallet;
    int signedCount = multisigWallet.keyStoreList.where((keyStore) => psbt.isSigned(keyStore)).length;
    int difference = multisigWallet.requiredSignature - signedCount;
    return difference;
  }

  WalletBase getWalletBase() {
    return _walletProvider.getWalletById(_sendInfoProvider.walletId!).walletBase;
  }

  bool isSignedPsbtMatchingUnsignedPsbt(Psbt signedPsbt) {
    try {
      var unsignedPsbt = Psbt.parse(_sendInfoProvider.txWaitingForSign!);

      final defaultCheckResult =
          unsignedPsbt.sendingAmount == signedPsbt.sendingAmount &&
          unsignedPsbt.unsignedTransaction?.transactionHash == signedPsbt.unsignedTransaction?.transactionHash;

      if (isMultisig || defaultCheckResult) {
        return defaultCheckResult;
      }

      /// p2wpkh, 시드사이너/패스포트로 서명한 경우 defaultCheckResult 항상 false
      /// 아래 코드는 defaultCheckResult가 false인 경우, 서명 전후 트랜잭션이 동일함을 추가 검사함
      /// seedSigner: bip32_deriv 정보를 모두 제외한 채 서명 결과만 줌
      /// passport: signature를 제외하고 finalScriptWitness 결과를 줌
      Transaction tx = signedPsbt.getSignedTransaction(AddressType.p2wpkh);
      for (int inputIndex = 0; inputIndex < tx.inputs.length; inputIndex++) {
        // 1. 서명 검증
        if (!tx.validateEcdsa(inputIndex, TransactionOutput.parse(unsignedPsbt.psbtMap["inputs"][inputIndex]["01"]))) {
          return false;
        }
        // 2. 공개키 검증
        if (signedPsbt.inputs[inputIndex].signatureList.isNotEmpty &&
                unsignedPsbt.inputs[inputIndex].bip32Derivation![0].publicKey !=
                    signedPsbt.inputs[inputIndex].signatureList[0].publicKey ||
            signedPsbt.inputs[inputIndex].finalScriptWitness != null &&
                unsignedPsbt.inputs[inputIndex].bip32Derivation![0].publicKey !=
                    signedPsbt.inputs[inputIndex].finalScriptWitness![1]) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Psbt parseBase64EncodedToPsbt(String signedPsbtBase64Encoded) {
    return Psbt.parse(signedPsbtBase64Encoded);
  }

  void setSignedResult(String signedResult) {
    _sendInfoProvider.setSignedResult(signedResult);
  }
}
