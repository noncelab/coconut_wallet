enum HotWalletLifecycleState {
  creating,
  active,
  deleting,
  recoveryRequired;

  static HotWalletLifecycleState fromName(String name) {
    return HotWalletLifecycleState.values.firstWhere(
      (state) => state.name == name,
      orElse: () => HotWalletLifecycleState.recoveryRequired,
    );
  }
}

class HotWalletMetadata {
  const HotWalletMetadata({
    required this.walletId,
    required this.secureStorageKey,
    required this.masterFingerprint,
    required this.derivationPath,
    required this.accountIndex,
    required this.backupVerified,
    required this.enterPassphraseWhenSigning,
    required this.createdAt,
    this.lifecycleState = HotWalletLifecycleState.active,
  });

  final int walletId;
  final String secureStorageKey;
  final String masterFingerprint;
  final String derivationPath;
  final int accountIndex;
  final bool backupVerified;
  final bool enterPassphraseWhenSigning;
  final DateTime createdAt;
  final HotWalletLifecycleState lifecycleState;
}
