import 'package:coconut_wallet/constants/icon_path.dart';

enum WalletType {
  singleSignature,
  multiSignature,
}

enum WalletSyncResult {
  newWalletAdded,
  existingWalletUpdated, // coconut vault 지갑 ui 업데이트 됨
  existingWalletNoUpdate,
  existingName, // fail sync
  existingWalletUpdateImpossible, // 이미 추가된 descriptor를 서드파티 방법으로 또 추가한 경우
}

enum WalletImportSource {
  coconutVault,
  keystone,
  jade,
  seedSigner,
  extendedPublicKey,
}

extension WalletImportSourceExtension on WalletImportSource {
  static WalletImportSource fromString(String name) {
    return WalletImportSource.values.firstWhere(
      (type) => type.name == name,
      orElse: () => WalletImportSource.coconutVault,
    );
  }

  static String getExternalWalletIconPath(WalletImportSource walletImportSource) {
    switch (walletImportSource) {
      case WalletImportSource.keystone:
        return kKeystoneIconPath;
      case WalletImportSource.jade:
        return kJadeIconPath;
      case WalletImportSource.seedSigner:
        return kSeedSignerIconPath;
      default:
        return kZpubIconPath;
    }
  }
}
