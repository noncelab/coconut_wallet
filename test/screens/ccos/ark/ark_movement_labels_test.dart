import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_movement_labels.dart';
import 'package:flutter_test/flutter_test.dart';

ArkMovement _movement(int id, {required String subsystem, required int sats, String status = 'successful'}) =>
    ArkMovement.fromBark(
      bark.Movement(
        id: id,
        status: status,
        subsystemName: subsystem,
        subsystemKind: sats < 0 ? 'send' : 'receive',
        metadataJson: '{}',
        intendedBalanceSats: sats,
        effectiveBalanceSats: sats,
        offchainFeeSats: 0,
        sentToAddresses: const [],
        receivedOnAddresses: const [],
        inputVtxoIds: const [],
        outputVtxoIds: const [],
        exitedVtxoIds: const [],
        createdAt: '2026-11-18T10:00:00Z',
        updatedAt: '2026-11-18T10:00:00Z',
      ),
    );

void main() {
  String? iconOf(ArkMovement movement) => arkMovementIconPath([movement], arkMovementAsRecent(movement));

  test('Lightning rows keep the status circle of the matching Ark row and swap only the glyph', () {
    expect(
      iconOf(_movement(1, subsystem: 'bark.lightning_receive', sats: 100)),
      FeatureArkIconPath.txLightningReceived,
    );
    expect(
      iconOf(_movement(2, subsystem: 'bark.lightning_receive', sats: 100, status: 'pending')),
      FeatureArkIconPath.txLightningReceiving,
    );
    expect(iconOf(_movement(3, subsystem: 'bark.lightning_send', sats: -100)), FeatureArkIconPath.txLightningSent);
    expect(
      iconOf(_movement(4, subsystem: 'bark.lightning_send', sats: -100, status: 'pending')),
      FeatureArkIconPath.txLightningSending,
    );
    expect(iconOf(_movement(5, subsystem: 'bark.arkoor', sats: -100)), FeatureArkIconPath.txSent);
    expect(iconOf(_movement(6, subsystem: 'bark.arkoor', sats: 100)), FeatureArkIconPath.txReceived);
  });

  test('the route goes next to the time and the right side keeps only the memo', () {
    final lightning = _movement(1, subsystem: 'bark.lightning_receive', sats: 100);
    final failed = _movement(2, subsystem: 'bark.arkoor', sats: -100, status: 'failed');

    expect(arkMovementAsRecent(lightning).walletName, '');
    expect(arkMovementAsRecent(lightning, memo: 'Coffee').walletName, 'Coffee');
    expect(arkMovementRouteLabel(lightning), t.ark_wallet.route_lightning);
    expect(arkMovementRouteLabel(failed), '${t.ark_wallet.route_ark} · ${t.ark_wallet.failed}');
  });

  test('adding funds and withdrawing go on-chain', () {
    expect(arkMovementRouteLabel(_movement(7, subsystem: 'bark.board', sats: 1000)), t.ark_wallet.route_onchain);
    expect(arkMovementRouteLabel(_movement(8, subsystem: 'bark.offboard', sats: -1000)), t.ark_wallet.route_onchain);
    expect(arkMovementRouteLabel(_movement(9, subsystem: 'bark.exit', sats: -1000)), t.ark_wallet.route_onchain);
  });

  test('exits, adding funds and withdrawing read as what the person did, other rows keep the usual status', () {
    expect(arkMovementStatusText(_movement(1, subsystem: 'bark.exit', sats: -100)), t.ark_wallet.activity_exit_done);
    expect(
      arkMovementStatusText(_movement(2, subsystem: 'bark.exit', sats: -100, status: 'pending')),
      t.ark_wallet.activity_exit_pending,
    );
    expect(
      arkMovementStatusText(_movement(3, subsystem: 'bark.exit', sats: -100, status: 'failed')),
      t.ark_wallet.activity_exit_failed,
    );
    expect(arkMovementStatusText(_movement(4, subsystem: 'bark.board', sats: 100)), t.ark_wallet.activity_fill_done);
    expect(
      arkMovementStatusText(_movement(5, subsystem: 'bark.board', sats: 100, status: 'pending')),
      t.ark_wallet.activity_fill_pending,
    );
    expect(
      arkMovementStatusText(_movement(6, subsystem: 'bark.offboard', sats: -100)),
      t.ark_wallet.activity_export_done,
    );
    expect(arkMovementStatusText(_movement(7, subsystem: 'bark.arkoor', sats: -100)), isNull);
  });

  test('a renewal reads as a renewal, with the fee taken or nothing, never as a send or receive', () {
    final paid = _movement(10, subsystem: 'bark.round', sats: -2);
    final free = _movement(11, subsystem: 'bark.round', sats: 0);
    final pending = _movement(12, subsystem: 'bark.round', sats: 0, status: 'pending');

    expect(arkMovementStatusText(paid), t.ark_wallet.activity_renew_done);
    expect(arkMovementStatusText(pending), t.ark_wallet.activity_renew_pending);
    expect(
      arkMovementStatusText(_movement(13, subsystem: 'bark.round', sats: 0, status: 'failed')),
      t.ark_wallet.activity_renew_failed,
    );
    expect(arkMovementAsRecent(paid).amount, -2);
    expect(arkMovementAsRecent(free).amount, 0);
    expect(iconOf(paid), FeatureArkIconPath.txRenewed);
    expect(iconOf(pending), FeatureArkIconPath.txRenewing);
  });

  test('a renewal happens in Ark, so its route reads Ark and it sits under the Ark filter', () {
    final renewal = _movement(14, subsystem: 'bark.round', sats: 0);

    expect(arkMovementRouteLabel(renewal), t.ark_wallet.route_ark);
    expect(arkMovementRail(renewal), ArkActivityRail.ark);
  });

  test('filling shows a plus, exporting and exits a minus, each with its pending form', () {
    expect(iconOf(_movement(20, subsystem: 'bark.board', sats: 1000)), FeatureArkIconPath.txFilled);
    expect(iconOf(_movement(21, subsystem: 'bark.board', sats: 1000, status: 'pending')), FeatureArkIconPath.txFilling);
    expect(iconOf(_movement(22, subsystem: 'bark.offboard', sats: -1000)), FeatureArkIconPath.txExported);
    expect(
      iconOf(_movement(23, subsystem: 'bark.offboard', sats: -1000, status: 'pending')),
      FeatureArkIconPath.txExporting,
    );
    expect(iconOf(_movement(24, subsystem: 'bark.exit', sats: -1000)), FeatureArkIconPath.txExported);
  });
}
