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

/// bark가 `{"type":"ark","value":"tark1…"}` 같은 JSON 문자열로 주는 보낸 곳·받은 곳
class ArkPaymentDestination {
  const ArkPaymentDestination(this.type, this.value);

  factory ArkPaymentDestination.parse(String encoded) {
    try {
      final json = jsonDecode(encoded);
      if (json is Map<String, dynamic>) {
        return ArkPaymentDestination(json['type']?.toString() ?? 'unknown', json['value']?.toString() ?? encoded);
      }
    } on FormatException {
      // JSON이 아니면 bark의 Debug 형식
    }
    return ArkPaymentDestination('unknown', encoded);
  }

  final String type;
  final String value;
}

/// 아크 지갑 거래 하나(bark의 movement). 금액은 수수료를 포함한 아크 잔액 변화량
class ArkMovement {
  const ArkMovement({
    required this.id,
    required this.status,
    required this.subsystemName,
    required this.subsystemKind,
    required this.metadataJson,
    required this.effectiveBalanceSats,
    required this.offchainFeeSats,
    required this.sentTo,
    required this.receivedOn,
    required this.inputVtxoIds,
    required this.outputVtxoIds,
    required this.createdAt,
    this.completedAt,
    this.paymentHash,
    this.lightningInvoice,
  });

  factory ArkMovement.fromBark(bark.Movement movement) => ArkMovement(
    id: movement.id,
    status: ArkMovementStatus.fromName(movement.status),
    subsystemName: movement.subsystemName,
    subsystemKind: movement.subsystemKind,
    metadataJson: movement.metadataJson,
    effectiveBalanceSats: movement.effectiveBalanceSats,
    offchainFeeSats: movement.offchainFeeSats,
    sentTo: movement.sentToAddresses,
    receivedOn: movement.receivedOnAddresses,
    inputVtxoIds: movement.inputVtxoIds,
    outputVtxoIds: movement.outputVtxoIds,
    createdAt: DateTime.parse(movement.createdAt),
    completedAt: movement.completedAt == null ? null : DateTime.parse(movement.completedAt!),
    paymentHash: movement.paymentHash,
    lightningInvoice: movement.lightningInvoice,
  );

  final int id;
  final ArkMovementStatus status;

  /// bark의 하위 시스템(`bark.arkoor`)과 그 안의 종류(`send`)
  final String subsystemName;
  final String subsystemKind;
  final String metadataJson;
  final int effectiveBalanceSats;
  final int offchainFeeSats;
  final List<String> sentTo;
  final List<String> receivedOn;
  final List<String> inputVtxoIds;
  final List<String> outputVtxoIds;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? paymentHash;
  final String? lightningInvoice;

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

  bool get isFailed => status == ArkMovementStatus.failed || status == ArkMovementStatus.canceled;

  bool get isSend => effectiveBalanceSats < 0;

  bool get isLightning => kind == ArkMovementKind.lightningSend || kind == ArkMovementKind.lightningReceive;

  DateTime get timestamp => completedAt ?? createdAt;

  /// 보낸 거래는 보낸 곳, 받은 거래는 받은 곳의 첫 항목
  String? get counterparty {
    final destinations = isSend ? sentTo : receivedOn;
    return destinations.isEmpty ? null : ArkPaymentDestination.parse(destinations.first).value;
  }

  /// 바뀐 것이 없는 실패·취소, 서버가 시작조차 하지 않은 라이트닝 보내기(bark 0.7.1은 계속 대기로 둠)는 숨김
  bool get isVisibleInHistory {
    if (effectiveBalanceSats != 0) return true;
    if (isFailed) return false;
    return !(kind == ArkMovementKind.lightningSend && isPending);
  }
}
