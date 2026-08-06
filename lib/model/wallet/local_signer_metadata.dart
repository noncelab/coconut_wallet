class LocalSignerMetadata {
  const LocalSignerMetadata({
    required this.walletId,
    required this.secureStorageKey,
    required this.masterFingerprint,
    required this.derivationPath,
    required this.accountIndex,
    required this.backupVerified,
    required this.enterPassphraseWhenSigning,
    required this.createdAt,
  });

  final int walletId;
  final String secureStorageKey;
  final String masterFingerprint;
  final String derivationPath;
  final int accountIndex;
  final bool backupVerified;
  final bool enterPassphraseWhenSigning;
  final DateTime createdAt;
}
