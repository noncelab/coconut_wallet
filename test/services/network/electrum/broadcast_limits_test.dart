import 'package:coconut_wallet/constants/network_constants.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the send-result waits: dropping back to a short limit is what made accepted payments look failed.
void main() {
  test('clearnet waits 8 s for the reply and 4 s for the check, doubling on each resend, within 120 s', () {
    final waits = [
      for (final attempt in [0, 1, 2]) broadcastLimits(onion: false, attempt: attempt),
    ];
    expect(
      [for (final w in waits) (w.reply.inSeconds, w.check.inSeconds, w.command.inSeconds)],
      [(8, 4, 15), (16, 8, 27), (32, 16, 51)],
    );
    expect(waits.first.command + waits[1].worstCase, lessThan(kBroadcastTotalLimit));
  });

  test('Tor waits 60 s for the reply and 12 s for the check, doubling on each resend, within 720 s', () {
    final waits = [
      for (final attempt in [0, 1, 2]) broadcastLimits(onion: true, attempt: attempt),
    ];
    expect(
      [for (final w in waits) (w.reply.inSeconds, w.check.inSeconds, w.command.inSeconds)],
      [(60, 12, 75), (120, 24, 147), (240, 48, 291)],
    );
    expect(waits.first.command + waits[1].worstCase, lessThan(kBroadcastTotalLimitForOnion));
  });
}
