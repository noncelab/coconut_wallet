import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;

/// A VTXO the hot wallet's Ark wallet holds.
class ArkVtxo {
  const ArkVtxo({
    required this.id,
    required this.amountSats,
    required this.expiryHeight,
    required this.kind,
    required this.isLocked,
    required this.exitDepth,
  });

  factory ArkVtxo.fromBark(bark.Vtxo vtxo) => ArkVtxo(
    id: vtxo.id,
    amountSats: vtxo.amountSats,
    expiryHeight: vtxo.expiryHeight,
    kind: vtxo.kind,
    isLocked: vtxo.state is bark.LockedVtxoState,
    exitDepth: vtxo.exitDepth,
  );

  final String id;
  final int amountSats;

  /// Block height after which the server may sweep the VTXO, so it must be refreshed before.
  final int expiryHeight;

  /// bark's policy type, e.g. `Pubkey` or `ServerHtlcRecv`.
  final String kind;

  /// Held by an operation in progress (a round, a Lightning payment…), so not spendable now.
  final bool isLocked;

  /// Length of the VTXO's transaction chain; the server refuses Ark payments from VTXOs past
  /// its limit until they are refreshed.
  final int exitDepth;

  int? blocksUntilExpiry(int? tipHeight) => tipHeight == null ? null : expiryHeight - tipHeight;
}
