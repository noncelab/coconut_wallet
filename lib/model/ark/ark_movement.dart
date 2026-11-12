import 'dart:convert';

import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;

enum ArkMovementKind {
  arkSend,
  arkReceive,
  lightningSend,
  lightningReceive,
  board,
  offboard,
  sendOnchain,
  refresh,
  exit,
  other,
}

enum ArkMovementStatus {
  pending,
  successful,
  failed,
  canceled;

  static ArkMovementStatus fromName(String name) =>
      ArkMovementStatus.values.firstWhere((status) => status.name == name, orElse: () => ArkMovementStatus.pending);
}

/// Where a movement sent to or received on. bark reports these as JSON strings such as
/// `{"type":"ark","value":"tark1…"}`; the type is `ark`, `bitcoin`, `output-script`, `invoice`,
/// `offer`, `lightning-address`, `lnurl` or `custom`.
class ArkPaymentDestination {
  const ArkPaymentDestination(this.type, this.value);

  factory ArkPaymentDestination.parse(String encoded) {
    try {
      final json = jsonDecode(encoded);
      if (json is Map<String, dynamic>) {
        return ArkPaymentDestination(json['type']?.toString() ?? 'unknown', json['value']?.toString() ?? encoded);
      }
    } on FormatException {
      // Not JSON: bark falls back to the Debug format when serialization fails.
    }
    return ArkPaymentDestination('unknown', encoded);
  }

  final String type;
  final String value;
}

/// One entry of the Ark wallet's history (bark calls it a movement): a payment, a board, a
/// refresh… Amounts are signed changes to the Ark balance, fees included.
class ArkMovement {
  const ArkMovement({
    required this.id,
    required this.status,
    required this.subsystemName,
    required this.subsystemKind,
    required this.metadataJson,
    required this.intendedBalanceSats,
    required this.effectiveBalanceSats,
    required this.offchainFeeSats,
    required this.sentTo,
    required this.receivedOn,
    required this.inputVtxoIds,
    required this.outputVtxoIds,
    required this.exitedVtxoIds,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
    this.paymentHash,
    this.lightningInvoice,
    this.lightningOffer,
  });

  factory ArkMovement.fromBark(bark.Movement movement) => ArkMovement(
    id: movement.id,
    status: ArkMovementStatus.fromName(movement.status),
    subsystemName: movement.subsystemName,
    subsystemKind: movement.subsystemKind,
    metadataJson: movement.metadataJson,
    intendedBalanceSats: movement.intendedBalanceSats,
    effectiveBalanceSats: movement.effectiveBalanceSats,
    offchainFeeSats: movement.offchainFeeSats,
    sentTo: movement.sentToAddresses,
    receivedOn: movement.receivedOnAddresses,
    inputVtxoIds: movement.inputVtxoIds,
    outputVtxoIds: movement.outputVtxoIds,
    exitedVtxoIds: movement.exitedVtxoIds,
    createdAt: DateTime.parse(movement.createdAt),
    updatedAt: DateTime.parse(movement.updatedAt),
    completedAt: movement.completedAt == null ? null : DateTime.parse(movement.completedAt!),
    paymentHash: movement.paymentHash,
    lightningInvoice: movement.lightningInvoice,
    lightningOffer: movement.lightningOffer,
  );

  final int id;
  final ArkMovementStatus status;

  /// bark's subsystem, e.g. `bark.arkoor`, and its kind within it, e.g. `send`.
  final String subsystemName;
  final String subsystemKind;
  final String metadataJson;
  final int intendedBalanceSats;
  final int effectiveBalanceSats;
  final int offchainFeeSats;

  /// Encoded [ArkPaymentDestination]s.
  final List<String> sentTo;
  final List<String> receivedOn;
  final List<String> inputVtxoIds;
  final List<String> outputVtxoIds;
  final List<String> exitedVtxoIds;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;
  final String? paymentHash;
  final String? lightningInvoice;
  final String? lightningOffer;

  ArkMovementKind get kind {
    final isSend = subsystemKind == 'send';
    switch (subsystemName) {
      case 'bark.arkoor':
        return isSend ? ArkMovementKind.arkSend : ArkMovementKind.arkReceive;
      case 'bark.lightning_send':
        return ArkMovementKind.lightningSend;
      case 'bark.lightning_receive':
        return ArkMovementKind.lightningReceive;
      case 'bark.board':
        return ArkMovementKind.board;
      case 'bark.offboard':
        return subsystemKind == 'send_onchain' ? ArkMovementKind.sendOnchain : ArkMovementKind.offboard;
      case 'bark.round':
        return ArkMovementKind.refresh;
      case 'bark.exit':
        return ArkMovementKind.exit;
      default:
        return ArkMovementKind.other;
    }
  }

  bool get isPending => status == ArkMovementStatus.pending;

  /// When the movement happened, for ordering next to on-chain transactions.
  DateTime get timestamp => completedAt ?? createdAt;

  List<ArkPaymentDestination> get sentToDestinations => sentTo.map(ArkPaymentDestination.parse).toList();
  List<ArkPaymentDestination> get receivedOnDestinations => receivedOn.map(ArkPaymentDestination.parse).toList();

  Map<String, dynamic> get metadata {
    try {
      final json = jsonDecode(metadataJson);
      return json is Map<String, dynamic> ? json : const {};
    } on FormatException {
      return const {};
    }
  }

  /// The on-chain transaction behind a board (`chain_anchor`, an outpoint) or an offboard
  /// (`offboard_txid`), to pair the movement with Coconut's own record of that transaction.
  String? get linkedTxid {
    final meta = metadata;
    final anchor = meta['chain_anchor'];
    if (anchor is String && anchor.contains(':')) return anchor.split(':').first;
    final offboardTxid = meta['offboard_txid'];
    if (offboardTxid is String) return offboardTxid;
    return null;
  }

  /// The signed on-chain transaction (hex) of an offboard or an on-chain payment from Ark, which
  /// bark records once the server has signed it.
  String? get offboardTxHex {
    final hex = metadata['offboard_tx'];
    return hex is String && hex.isNotEmpty ? hex : null;
  }

  /// Movements that changed nothing are noise in a transaction list: failed or canceled ones, and
  /// Lightning sends the server refused to start (bark 0.7.1 leaves those pending forever, with
  /// nothing locked; a payment really in flight has its amount locked, so a non-zero balance).
  bool get isVisibleInHistory {
    if (effectiveBalanceSats != 0) return true;
    if (status == ArkMovementStatus.failed || status == ArkMovementStatus.canceled) return false;
    return !(kind == ArkMovementKind.lightningSend && status == ArkMovementStatus.pending);
  }
}
