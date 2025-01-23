import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';

class SignedPsbtScannerViewModel {
  late final SendInfoProvider _sendInfoProvider;
  late final WalletProvider _walletProvider;

  SignedPsbtScannerViewModel(this._sendInfoProvider, this._walletProvider);

  bool get isMultisig => _sendInfoProvider.isMultisig!;
  String get txWaitingForSign => _sendInfoProvider.txWaitingForSign!;

  WalletBase getWalletBase() {
    return _walletProvider
        .getWalletById(_sendInfoProvider.walletId!)
        .walletBase;
  }

  void setSignedPsbt(String signedPsbtBase64Encoded) {
    _sendInfoProvider.setSignedPsbtBase64Encoded(signedPsbtBase64Encoded);
  }
}
