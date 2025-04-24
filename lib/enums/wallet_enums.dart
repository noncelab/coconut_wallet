enum WalletType {
  singleSignature,
  multiSignature,
}

enum WalletSyncResult {
  newWalletAdded,
  existingWalletUpdated,
  existingWalletNoUpdate,
  existingName, // fail sync
  existingWalletUpdateImpossible, // 이미 추가된 descriptor를 서드파티 방법으로 또 추가한 경우
}

enum WalletImportSource {
  coconutVault,
  keystone,
  seedSigner,
  extendedPublicKey,
}
