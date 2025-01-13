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
