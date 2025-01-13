enum WalletSyncResult {
  newWalletAdded,
  existingWalletUpdated,
  existingWalletNoUpdate,
  existingName, // fail sync
}

enum WalletType {
  singleSignature,
  multiSignature,
}
