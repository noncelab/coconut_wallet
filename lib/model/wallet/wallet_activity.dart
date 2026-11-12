import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/model/ark/ark_movement.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';

/// The network an entry went over, shown as a pill in wallets with Ark: on-chain (a transaction,
/// or an Ark payment to a Bitcoin address), Ark or Lightning.
enum ArkRail { onchain, ark, lightning }

/// What an Ark activity is, where "sent" or "received" would mislead.
enum ArkActivityLabel { refresh, movedToArk, movedOnchain, exit, failed, canceled }

/// One entry of a wallet's history: an on-chain transaction or, for hot wallets with Ark, an
/// Ark movement (an Ark or Lightning payment, a refresh…).
///
/// Lists merge both kinds here, in view models; sync, RBF/CPFP and the repositories keep dealing
/// with on-chain [TransactionRecord]s only.
sealed class WalletActivity {
  const WalletActivity();

  /// Unique within a wallet's history: the txid, or `ark:<movement id>`.
  String get key;

  /// Signed change to the wallet's balance, fees included.
  int get amount;

  /// The amount a row shows. Usually [amount]; for a move between on-chain and Ark (whose net
  /// change is just the fees) it's the amount moved.
  int get displayAmount => amount;

  /// When it happened (for pending entries, when they started).
  DateTime get time;

  bool get isPending;
  TransactionStatus? get status;
  String? get memo;

  /// The network it went over, for the pill wallets with Ark show.
  ArkRail get rail;

  /// Changes whenever the entry would render differently.
  int get contentHash;

  /// Merges both histories, pending entries first, then newest first, like the on-chain list.
  ///
  /// A move between on-chain and Ark (a board, an offboard, an on-chain payment from Ark) is one
  /// entry: the Ark movement carries the on-chain transaction its [ArkMovement.linkedTxid] names,
  /// and that transaction isn't listed separately.
  static List<WalletActivity> merge(List<TransactionRecord> transactions, List<ArkMovement> movements) {
    final transactionsById = {for (final tx in transactions) tx.transactionHash: tx};
    final linkedIds = <String>{};
    final arkActivities = <WalletActivity>[];
    for (final movement in movements.where((movement) => movement.isVisibleInHistory)) {
      final linkedTx = transactionsById[movement.linkedTxid];
      if (linkedTx != null) linkedIds.add(linkedTx.transactionHash);
      arkActivities.add(ArkActivity(movement, linkedTx: linkedTx));
    }
    return [
      ...transactions.where((tx) => !linkedIds.contains(tx.transactionHash)).map(OnchainActivity.new),
      ...arkActivities,
    ]..sort(compare);
  }

  static int compare(WalletActivity a, WalletActivity b) {
    if (a.isPending != b.isPending) return a.isPending ? -1 : 1;
    return b.time.compareTo(a.time);
  }

  @override
  bool operator ==(Object other) => other is WalletActivity && other.key == key && other.contentHash == contentHash;

  @override
  int get hashCode => Object.hash(key, contentHash);
}

class OnchainActivity extends WalletActivity {
  const OnchainActivity(this.tx);

  final TransactionRecord tx;

  @override
  String get key => tx.transactionHash;

  @override
  int get amount => tx.amount;

  /// Unconfirmed transactions are ordered by when Coconut first saw them, as in the repository.
  @override
  DateTime get time => isPending ? tx.createdAt : tx.timestamp;

  @override
  bool get isPending => tx.blockHeight == 0;

  @override
  TransactionStatus? get status => TransactionUtil.getStatus(tx);

  @override
  String? get memo => tx.memo;

  @override
  ArkRail get rail => ArkRail.onchain;

  @override
  int get contentHash => tx.contentHashCode;
}

class ArkActivity extends WalletActivity {
  const ArkActivity(this.movement, {this.linkedTx});

  final ArkMovement movement;

  /// This wallet's on-chain side of a move between on-chain and Ark, when it has one.
  final TransactionRecord? linkedTx;

  bool get isMove => linkedTx != null;

  @override
  String get key => 'ark:${movement.id}';

  /// For a move, both sides together: what changed overall is the fees.
  @override
  int get amount => movement.effectiveBalanceSats + (linkedTx?.amount ?? 0);

  /// For a move, what arrived on the other side: in Ark for a board, on-chain for an offboard.
  @override
  int get displayAmount {
    final tx = linkedTx;
    if (tx == null) return movement.effectiveBalanceSats;
    return movement.kind == ArkMovementKind.board ? movement.effectiveBalanceSats : tx.amount;
  }

  @override
  DateTime get time => movement.timestamp;

  @override
  bool get isPending => movement.isPending || (linkedTx != null && linkedTx!.blockHeight == 0);

  @override
  TransactionStatus get status {
    if (isMove) return isPending ? TransactionStatus.selfsending : TransactionStatus.self;
    if (amount > 0) return isPending ? TransactionStatus.receiving : TransactionStatus.received;
    if (amount < 0 && movement.kind != ArkMovementKind.refresh) {
      return isPending ? TransactionStatus.sending : TransactionStatus.sent;
    }
    return isPending ? TransactionStatus.selfsending : TransactionStatus.self;
  }

  /// Ark movements have no memos yet: Coconut's memo table also feeds the BIP-329 label export.
  @override
  String? get memo => null;

  /// Which network it went over, shown next to the status. A payment from Ark to a Bitcoin
  /// address (and an exit) lands on-chain, so it gets the on-chain pill like any transaction.
  @override
  ArkRail get rail => switch (movement.kind) {
    ArkMovementKind.lightningSend || ArkMovementKind.lightningReceive => ArkRail.lightning,
    ArkMovementKind.offboard || ArkMovementKind.sendOnchain || ArkMovementKind.exit => ArkRail.onchain,
    _ => ArkRail.ark,
  };

  /// Replaces the generic sent/received label where that would mislead.
  ArkActivityLabel? get label => switch (movement.kind) {
    ArkMovementKind.refresh => ArkActivityLabel.refresh,
    ArkMovementKind.board => ArkActivityLabel.movedToArk,
    // Without this wallet's transaction, the funds went elsewhere (a vault, someone else): a
    // plain send, labelled like one.
    ArkMovementKind.offboard || ArkMovementKind.sendOnchain => isMove ? ArkActivityLabel.movedOnchain : null,
    ArkMovementKind.exit => ArkActivityLabel.exit,
    _ =>
      movement.status == ArkMovementStatus.failed
          ? ArkActivityLabel.failed
          : movement.status == ArkMovementStatus.canceled
          ? ArkActivityLabel.canceled
          : null,
  };

  @override
  int get contentHash => Object.hash(
    movement.id,
    movement.status,
    movement.effectiveBalanceSats,
    movement.updatedAt.microsecondsSinceEpoch,
    linkedTx?.contentHashCode,
  );
}
