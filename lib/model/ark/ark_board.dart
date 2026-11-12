/// Where to send on-chain funds to board them into an Ark wallet, from
/// `boardFundingAddress()`. [keypairIndex] and [expiryHeight] must be handed back with the
/// funding PSBT: the address commits to both.
class ArkBoardFunding {
  const ArkBoardFunding({required this.address, required this.expiryHeight, required this.keypairIndex});

  final String address;
  final int expiryHeight;
  final int keypairIndex;
}

/// The Ark server's limits for boards.
class ArkBoardTerms {
  const ArkBoardTerms({required this.minAmountSats, required this.maxAmountSats, required this.requiredConfirmations});

  /// Bitcoin's dust limit for the P2TR funding output, below which a board can't exist anyway.
  static const int dustLimitSats = 330;

  final int minAmountSats;
  final int? maxAmountSats;
  final int requiredConfirmations;

  /// Why [amountSats] can't be boarded, or null if it can.
  String? check(int amountSats) {
    final minimum = minAmountSats > dustLimitSats ? minAmountSats : dustLimitSats;
    if (amountSats < minimum) return 'The Ark server accepts at least $minimum sats';
    if (maxAmountSats != null && amountSats > maxAmountSats!) {
      return 'The Ark server accepts at most $maxAmountSats sats';
    }
    return null;
  }
}

/// An offboard or on-chain send from Ark that bark accepted but couldn't finish yet; it stays
/// pending and bark retries it on sync. Not a failure, and not to be retried by the user.
class ArkMovePendingException implements Exception {
  ArkMovePendingException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// A send that boards into hot wallet [walletId]'s Ark wallet through [funding]'s address. It
/// travels with the transaction through signing (hot wallet or Coconut Vault) to broadcasting,
/// where the board is registered just before the broadcast.
class ArkBoardIntent {
  const ArkBoardIntent({required this.walletId, required this.funding});

  final int walletId;
  final ArkBoardFunding funding;
}
