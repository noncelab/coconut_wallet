import 'dart:convert';
import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_manager.dart';
import 'package:flutter_test/flutter_test.dart';

/// The main side must wait for the isolate's reply wait and txid check. A 3 s cut-off made accepted payments
/// look failed and invited a second payment.
void main() {
  test('the send command carries the reply and check waits, and the main side waits for both', () {
    final fixture = jsonDecode(File('test/fixtures/signing/coldcard_raw.json').readAsStringSync()) as Map;
    final tx = Transaction.parse(fixture['returnedPayload'] as String);
    final expected = {
      (false, 0): (8, 4, 15),
      (false, 1): (16, 8, 27),
      (false, 2): (32, 16, 51),
      (true, 0): (60, 12, 75),
      (true, 2): (240, 48, 291),
    };
    for (final MapEntry(key: (onion, attempt), value: waits) in expected.entries) {
      final command = IsolateManager.broadcastCommand(tx, onion: onion, attempt: attempt);
      expect(command.params.first, same(tx));
      expect(
        (
          (command.params[1] as Duration).inSeconds,
          (command.params[2] as Duration).inSeconds,
          command.timeout.inSeconds,
        ),
        waits,
        reason: 'onion=$onion attempt=$attempt',
      );
    }
  });
}
