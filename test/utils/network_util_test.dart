import 'package:coconut_wallet/utils/network_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes normalized onion hosts, but not embedded onion substrings', () {
    for (final host in ['service.onion', ' SERVICE.ONION ']) {
      expect(isOnionHost(host), isTrue, reason: host);
    }
    for (final host in ['', 'example.com', '127.0.0.1', 'service.onion.example.com']) {
      expect(isOnionHost(host), isFalse, reason: host);
    }
  });
}
