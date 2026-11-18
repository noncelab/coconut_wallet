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
}
