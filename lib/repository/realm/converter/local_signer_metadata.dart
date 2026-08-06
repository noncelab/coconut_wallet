import 'package:coconut_wallet/model/wallet/local_signer_metadata.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

LocalSignerMetadata mapRealmToLocalSignerMetadata(RealmLocalSignerMetadata metadata) {
  return LocalSignerMetadata(
    walletId: metadata.walletId,
    secureStorageKey: metadata.secureStorageKey,
    masterFingerprint: metadata.masterFingerprint,
    derivationPath: metadata.derivationPath,
    accountIndex: metadata.accountIndex,
    backupVerified: metadata.backupVerified,
    enterPassphraseWhenSigning: metadata.enterPassphraseWhenSigning,
    createdAt: metadata.createdAt,
  );
}
