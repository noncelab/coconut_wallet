import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/ark/ark_board.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';

enum MoveEndpointKind { onchain, ark, vault }

/// One place funds can move from or to: this hot wallet's on-chain balance, its Ark balance, or
/// a vault (a watch-only wallet signed with Coconut Vault).
class MoveEndpoint {
  const MoveEndpoint({required this.kind, required this.walletId, required this.walletName, required this.balanceSats});

  final MoveEndpointKind kind;
  final int walletId;
  final String walletName;
  final int balanceSats;

  @override
  bool operator ==(Object other) => other is MoveEndpoint && other.kind == kind && other.walletId == walletId;

  @override
  int get hashCode => Object.hash(kind, walletId);
}

class MoveSelection {
  const MoveSelection(this.from, this.to);

  final MoveEndpoint from;
  final MoveEndpoint to;
}

/// The places [hotWallet] can move funds between. One end of a move is always the hot wallet
/// (its on-chain or Ark side): vault-to-vault moves stay in the vault's own Send.
class MoveOptions {
  MoveOptions({
    required WalletItemBase hotWallet,
    required int onchainBalanceSats,
    required int? arkBalanceSats,
    required List<({WalletItemBase wallet, int balanceSats})> vaults,
  }) : onchain = MoveEndpoint(
         kind: MoveEndpointKind.onchain,
         walletId: hotWallet.id,
         walletName: hotWallet.name,
         balanceSats: onchainBalanceSats,
       ),
       ark =
           arkBalanceSats == null
               ? null
               : MoveEndpoint(
                 kind: MoveEndpointKind.ark,
                 walletId: hotWallet.id,
                 walletName: hotWallet.name,
                 balanceSats: arkBalanceSats,
               ),
       vaults = [
         for (final vault in vaults)
           MoveEndpoint(
             kind: MoveEndpointKind.vault,
             walletId: vault.wallet.id,
             walletName: vault.wallet.name,
             balanceSats: vault.balanceSats,
           ),
       ],
       _boardableVaultIds = {
         for (final vault in vaults)
           if (_hasNativeSegwitInputs(vault.wallet)) vault.wallet.id,
       };

  final MoveEndpoint onchain;
  final MoveEndpoint? ark;
  final List<MoveEndpoint> vaults;
  final Set<int> _boardableVaultIds;

  List<MoveEndpoint> get all => [onchain, if (ark != null) ark!, ...vaults];

  /// Whether there is anywhere to move between at all.
  bool get hasChoices => ark != null || vaults.isNotEmpty;

  /// Where funds from [from] can go.
  List<MoveEndpoint> destinationsFor(MoveEndpoint from) => switch (from.kind) {
    MoveEndpointKind.onchain => [if (ark != null) ark!, ...vaults],
    MoveEndpointKind.ark => [onchain, ...vaults],
    MoveEndpointKind.vault => [
      onchain,
      // bark only boards from native segwit inputs: a nested-segwit input's txid changes once signed.
      if (ark != null && _boardableVaultIds.contains(from.walletId)) ark!,
    ],
  };

  bool canMoveFrom(MoveEndpoint from) => from.balanceSats > 0 && destinationsFor(from).isNotEmpty;

  static bool _hasNativeSegwitInputs(WalletItemBase wallet) {
    final name = wallet.walletBase.addressType.name;
    return name == AddressType.p2wpkh.name || name == AddressType.p2wsh.name || name == AddressType.p2tr.name;
  }
}

/// Where a move pays once resolved: an address of the destination, and for a board into Ark the
/// intent the broadcast registers and the Ark server's limits.
class MoveDestination {
  const MoveDestination({required this.address, this.board, this.boardTerms});

  final String address;
  final ArkBoardIntent? board;
  final ArkBoardTerms? boardTerms;

  bool get isBoard => board != null;
}
