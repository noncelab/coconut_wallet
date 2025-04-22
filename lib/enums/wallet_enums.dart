enum WalletType {
  singleSignature,
  multiSignature,
}

enum WalletSyncResult {
  newWalletAdded,
  existingWalletUpdated,
  existingWalletNoUpdate,
  existingName, // fail sync
}

enum WalletImportSource {
  coconutVault,
  keystone,
  seedSigner,
  extendedPublicKey,
  descriptor,
}

extension WalletImportSourceExtension on WalletImportSource {
  static WalletImportSource fromString(String name) {
    return WalletImportSource.values.firstWhere(
      (type) => type.name == name,
      orElse: () => WalletImportSource.coconutVault,
    );
  }
}
