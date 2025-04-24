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
}
