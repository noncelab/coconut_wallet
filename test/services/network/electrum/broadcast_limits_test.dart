import 'package:coconut_wallet/constants/network_constants.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the send-result waits: dropping back to a short limit is what made accepted payments look failed.
void main() {
  test('the whole send result is bounded by 120 s on clearnet and 720 s on Tor', () {
    expect((kBroadcastTotalLimit.inSeconds, kBroadcastTotalLimitForOnion.inSeconds), (120, 720));
  });

  test('clearnet waits 8 s for the reply and 4 s for the check, doubling on each resend', () {
    final waits = [
      for (final attempt in [0, 1, 2]) broadcastLimits(onion: false, attempt: attempt),
    ];
    expect(
      [for (final w in waits) (w.reply.inSeconds, w.check.inSeconds, w.command.inSeconds, w.worstCase.inSeconds)],
      [(8, 4, 15, 36), (16, 8, 27, 48), (32, 16, 51, 72)],
    );
  });

  test('Tor waits 60 s for the reply and 12 s for the check, doubling on each resend', () {
    final waits = [
      for (final attempt in [0, 1, 2]) broadcastLimits(onion: true, attempt: attempt),
    ];
    expect(
      [for (final w in waits) (w.reply.inSeconds, w.check.inSeconds, w.command.inSeconds, w.worstCase.inSeconds)],
      [(60, 12, 75, 326), (120, 24, 147, 398), (240, 48, 291, 542)],
    );
  });

  test('a resend starts only if its worst case still ends within the limit', () {
    bool clearnet(int seconds, int attempt) =>
        canResendWithinLimit(elapsed: Duration(seconds: seconds), onion: false, attempt: attempt);
    bool tor(int seconds, int attempt) =>
        canResendWithinLimit(elapsed: Duration(seconds: seconds), onion: true, attempt: attempt);

    expect([clearnet(72, 1), clearnet(73, 1), clearnet(48, 2), clearnet(49, 2)], [true, false, true, false]);
    expect([tor(322, 1), tor(323, 1), tor(178, 2), tor(179, 2)], [true, false, true, false]);
    // After a worst-case first send and first resend, the second resend is skipped, so the cap holds.
    final afterFirstResend =
        broadcastLimits(onion: false, attempt: 0).command + broadcastLimits(onion: false, attempt: 1).worstCase;
    expect(canResendWithinLimit(elapsed: afterFirstResend, onion: false, attempt: 2), isFalse);
  });
}
