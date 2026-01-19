import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';

class SignedPsbtScannerViewModel {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;

  bool _isSendingDonation = false;

  SignedPsbtScannerViewModel(this._sendInfoProvider, this._walletProvider) {
    _isSendingDonation = _sendInfoProvider.isDonation ?? false;
  }

  bool get isMultisig => _sendInfoProvider.isMultisig!;
  bool get isSendingDonation => _isSendingDonation;
  WalletImportSource get walletImportSource => _sendInfoProvider.walletImportSource!;

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

      /// single signature인 경우, 시드사이너로 서명한 경우를 커버하기 위해 아래 검증을 추가합니다.
      /// 시드사이너로 서명한 경우는 defaultCheckResult가 항상 false입니다.
      /// 왜냐하면 bip32_deriv 정보를 모두 제외한 채 서명 결과만 주기 때문입니다.
      Transaction tx = signedPsbt.getSignedTransaction(AddressType.p2wpkh);
      for (int inputIndex = 0; inputIndex < tx.inputs.length; inputIndex++) {
        // 1. 서명 검증
        if (!tx.validateEcdsa(inputIndex, TransactionOutput.parse(unsignedPsbt.psbtMap["inputs"][inputIndex]["01"]))) {
          return false;
        }
        // 2. 공개키 검증
        if (unsignedPsbt.inputs[inputIndex].bip32Derivation![0].publicKey !=
            signedPsbt.inputs[inputIndex].signatureList[0].publicKey) {
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

  void setSignedPsbt(String signedPsbtBase64Encoded) {
    _sendInfoProvider.setSignedPsbtBase64Encoded(signedPsbtBase64Encoded);
  }

  void setRawSignedTransaction(String rawSignedTransaction) {
    _sendInfoProvider.setRawSignedTransaction(rawSignedTransaction);
  }
}
