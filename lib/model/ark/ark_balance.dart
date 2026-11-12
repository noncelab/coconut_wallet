import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;

/// The Ark (bark) side of a hot wallet's balance, in sats.
class ArkBalance {
  const ArkBalance({
    required this.spendable,
    required this.pendingInRound,
    required this.pendingBoard,
    required this.pendingExit,
    required this.pendingLightningSend,
    required this.claimableLightningReceive,
  });

  static const zero = ArkBalance(
    spendable: 0,
    pendingInRound: 0,
    pendingBoard: 0,
    pendingExit: 0,
    pendingLightningSend: 0,
    claimableLightningReceive: 0,
  );

  factory ArkBalance.fromBark(bark.Balance balance) => ArkBalance(
    spendable: balance.spendableSats,
    pendingInRound: balance.pendingInRoundSats,
    pendingBoard: balance.pendingBoardSats,
    pendingExit: balance.pendingExitSats,
    pendingLightningSend: balance.pendingLightningSendSats,
    claimableLightningReceive: balance.claimableLightningReceiveSats,
  );

  final int spendable;
  final int pendingInRound;
  final int pendingBoard;
  final int pendingExit;
  final int pendingLightningSend;
  final int claimableLightningReceive;

  /// Sats held by operations in progress.
  int get pending => pendingInRound + pendingBoard + pendingExit + pendingLightningSend + claimableLightningReceive;

  /// Everything that belongs to the Ark wallet, mirroring `Balance::total()` on bark master.
  ///
  /// bark 0.7.1 has no total of its own, and its fields can overlap: the inputs of a delegated
  /// round the server hasn't picked up yet count as both spendable and pending in round, so this
  /// over-reports while a delegated refresh waits. Sats held by an offboard or an Ark send in
  /// progress are in no field. Switch to bark's `summary()` once the SDK ships it.
  int get total => spendable + pending;
}
