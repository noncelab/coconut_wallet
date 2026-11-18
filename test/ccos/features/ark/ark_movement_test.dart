import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:flutter_test/flutter_test.dart';

bark.Movement _movement({
  int id = 1,
  String status = 'successful',
  String subsystem = 'bark.arkoor',
  String kind = 'receive',
  int effective = 1000,
  int fee = 0,
  List<String> sentTo = const [],
  List<String> receivedOn = const [],
}) => bark.Movement(
  id: id,
  status: status,
  subsystemName: subsystem,
  subsystemKind: kind,
  metadataJson: '{}',
  intendedBalanceSats: effective,
  effectiveBalanceSats: effective,
  offchainFeeSats: fee,
  sentToAddresses: sentTo,
  receivedOnAddresses: receivedOn,
  inputVtxoIds: const [],
  outputVtxoIds: const [],
  exitedVtxoIds: const [],
  createdAt: '2026-11-18T10:00:00Z',
  updatedAt: '2026-11-18T10:00:00Z',
  completedAt: '2026-11-18T10:00:05Z',
);

void main() {
  test('kinds follow the bark subsystem', () {
    expect(ArkMovement.fromBark(_movement()).kind, ArkMovementKind.arkReceive);
    expect(ArkMovement.fromBark(_movement(kind: 'send', effective: -500)).kind, ArkMovementKind.arkSend);
    expect(ArkMovement.fromBark(_movement(subsystem: 'bark.lightning_send')).kind, ArkMovementKind.lightningSend);
    expect(ArkMovement.fromBark(_movement(subsystem: 'bark.lightning_receive')).kind, ArkMovementKind.lightningReceive);
    expect(ArkMovement.fromBark(_movement(subsystem: 'bark.round')).kind, ArkMovementKind.refresh);
  });

  test('a send shows where it went, a receive where it arrived', () {
    final send = ArkMovement.fromBark(
      _movement(kind: 'send', effective: -500, sentTo: const ['{"type":"ark","value":"tark1abc"}']),
    );
    final receive = ArkMovement.fromBark(_movement(receivedOn: const ['{"type":"ark","value":"tark1me"}']));

    expect(send.isSend, isTrue);
    expect(send.counterparty, 'tark1abc');
    expect(receive.isSend, isFalse);
    expect(receive.counterparty, 'tark1me');
  });

  test('failed movements that changed nothing are hidden', () {
    expect(ArkMovement.fromBark(_movement(status: 'failed', effective: 0)).isVisibleInHistory, isFalse);
    expect(ArkMovement.fromBark(_movement(status: 'failed', effective: -10)).isVisibleInHistory, isTrue);
    expect(ArkMovement.fromBark(_movement(status: 'pending')).isPending, isTrue);
  });
}
