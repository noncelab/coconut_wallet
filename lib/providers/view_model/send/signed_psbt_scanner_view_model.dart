import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';

class SignedPsbtScannerViewModel {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;

  SignedPsbtScannerViewModel(this._sendInfoProvider, this._walletProvider);

  bool get isMultisig => _sendInfoProvider.isMultisig!;

  bool compareAmountAndTxHashWithUnsignedPsbt(PSBT signedPsbt) {
    try {
      var unsignedPsbt = PSBT.parse(_sendInfoProvider.txWaitingForSign!);

      return unsignedPsbt.sendingAmount == signedPsbt.sendingAmount &&
          unsignedPsbt.unsignedTransaction?.transactionHash ==
              signedPsbt.unsignedTransaction?.transactionHash;
    } catch (e) {
      return false;
    }
  }

  int getMissingSignaturesCount(PSBT psbt) {
    if (!isMultisig) return 0;

    MultisignatureWallet multisigWallet = _walletProvider
        .getWalletById(_sendInfoProvider.walletId!)
        .walletBase as MultisignatureWallet;
    int signedCount = multisigWallet.keyStoreList
        .where((keyStore) => psbt.isSigned(keyStore))
        .length;
    int difference = multisigWallet.requiredSignature - signedCount;
    return difference;
  }

  WalletBase getWalletBase() {
    return _walletProvider
        .getWalletById(_sendInfoProvider.walletId!)
        .walletBase;
  }

  PSBT parseBase64EncodedToPsbt(String signedPsbtBase64Encoded) {
    return PSBT.parse(signedPsbtBase64Encoded);
  }

  void setSignedPsbt(String signedPsbtBase64Encoded) {
    _sendInfoProvider.setSignedPsbtBase64Encoded(signedPsbtBase64Encoded);
  }
}
