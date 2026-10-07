enum ShortcutWalletMode { askEveryTime, wallet }

class ShortcutWalletContext {
  final ShortcutWalletMode mode;
  final int? walletId;

  const ShortcutWalletContext.askEveryTime() : mode = ShortcutWalletMode.askEveryTime, walletId = null;

  const ShortcutWalletContext.wallet(int this.walletId) : mode = ShortcutWalletMode.wallet;

  factory ShortcutWalletContext.fromJson(Map<String, Object?> json) {
    final walletId = json['walletId'];
    if (json['mode'] == ShortcutWalletMode.wallet.name && walletId is int) {
      return ShortcutWalletContext.wallet(walletId);
    }
    return const ShortcutWalletContext.askEveryTime();
  }

  Map<String, Object?> toJson() => {'mode': mode.name, if (walletId != null) 'walletId': walletId};

  @override
  bool operator ==(Object other) => other is ShortcutWalletContext && other.mode == mode && other.walletId == walletId;

  @override
  int get hashCode => Object.hash(mode, walletId);
}
