import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/services/wallet_add_service.dart';

String formatMfp(String mfp) {
  if (mfp.length != 8) return mfp;
  final upper = mfp.toUpperCase();
  return '${upper.substring(0, 4)} ${upper.substring(4)}';
}

String? walletMasterFingerprint(WalletItemBase wallet) {
  final walletBase = wallet.walletBase;
  if (walletBase is! SingleSignatureWallet) return null;
  final mfp = walletBase.keyStore.masterFingerprint;
  if (mfp.isEmpty || mfp == WalletAddService.masterFingerprintPlaceholder) return null;
  return mfp;
}
