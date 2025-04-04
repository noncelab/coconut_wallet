import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';

class SignedPsbtScannerViewModel {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;

  SignedPsbtScannerViewModel(this._sendInfoProvider, this._walletProvider);

  bool get isMultisig => _sendInfoProvider.isMultisig!;

  int getMissingSignaturesCount(Psbt psbt) {
    if (!isMultisig) return 0;

    MultisignatureWallet multisigWallet = _walletProvider
        .getWalletById(_sendInfoProvider.walletId!)
        .walletBase as MultisignatureWallet;
    int signedCount =
        multisigWallet.keyStoreList.where((keyStore) => psbt.isSigned(keyStore)).length;
    int difference = multisigWallet.requiredSignature - signedCount;
    return difference;
  }

  WalletBase getWalletBase() {
    return _walletProvider.getWalletById(_sendInfoProvider.walletId!).walletBase;
  }

  bool isPsbtAmountAndTxHashEqualTo(Psbt signedPsbt) {
    try {
      var unsignedPsbt = Psbt.parse(_sendInfoProvider.txWaitingForSign!);

      return unsignedPsbt.sendingAmount == signedPsbt.sendingAmount &&
          unsignedPsbt.unsignedTransaction?.transactionHash ==
              signedPsbt.unsignedTransaction?.transactionHash;
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
}
