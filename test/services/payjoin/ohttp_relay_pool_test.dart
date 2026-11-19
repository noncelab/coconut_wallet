import 'dart:math';
import 'dart:typed_data';

import 'package:coconut_wallet/services/payjoin/ohttp_relay_pool.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const relays = ['https://a.example', 'https://b.example', 'https://c.example'];
  const directory = 'https://directory.test';

  group('payjoinOperator', () {
    test('tells the listed mailrooms apart', () {
      expect(PayjoinConfig.mailrooms.map(payjoinOperator).toList(), [
        'bobspacebkk.com',
        'plan-b.foundation',
        'vinteum.org',
      ]);
    });

    test('groups hosts of one domain, whatever their case or path', () {
      expect(payjoinOperator('https://pj.bobspacebkk.com'), payjoinOperator('https://relay.BOBSPACEBKK.com.'));
      expect(payjoinOperator('HTTPS://PAYJOIN.LAB.VINTEUM.ORG/ABCD#EX1XYZ'), 'vinteum.org');
      expect(payjoinOperator('https://payjo.in'), 'payjo.in');
    });

    test('errs towards one operator under a multi-label public suffix', () {
      expect(payjoinOperator('https://a.co.uk'), payjoinOperator('https://pj.b.co.uk'));
    });

    test('counts each loopback port as its own operator', () {
      expect(payjoinOperator('https://127.0.0.1:60480'), isNot(payjoinOperator('http://127.0.0.1:60481')));
      expect(payjoinOperator('http://localhost:1'), isNot(payjoinOperator('http://localhost:2')));
      expect(payjoinOperator('http://[::1]:1'), isNot(payjoinOperator('http://[::1]:2')));
    });

    test('takes any other IP address whole, ignoring the port', () {
      expect(payjoinOperator('https://203.0.113.5:1'), payjoinOperator('http://203.0.113.5:2'));
      expect(payjoinOperator('https://203.0.113.5'), isNot(payjoinOperator('https://198.51.100.5')));
    });
  });

  group('OhttpRelayPool', () {
    test('rejects an empty relay list', () {
      expect(() => OhttpRelayPool(const []), throwsArgumentError);
    });

    test('spreads choices over all relays', () {
      final pool = OhttpRelayPool(relays, random: Random(1));
      final seen = {for (var i = 0; i < 200; i++) pool.choose(directory)};
      expect(seen, relays.toSet());
    });

    test('skips failed relays and runs out when all failed', () {
      final pool = OhttpRelayPool(relays, random: Random(2));
      pool.markFailed(relays[0]);
      pool.markFailed(relays[1]);
      for (var i = 0; i < 20; i++) {
        expect(pool.choose(directory), relays[2]);
      }
      pool.markFailed(relays[2]);
      expect(pool.choose(directory), isNull);
      pool.clearFailed();
      expect(pool.choose(directory), isNotNull);
    });

    test("never picks a relay run by the directory's operator", () {
      final pool = OhttpRelayPool(PayjoinConfig.mailrooms, random: Random(6));
      for (final mailroom in PayjoinConfig.mailrooms) {
        final others = PayjoinConfig.mailrooms.where((relay) => relay != mailroom).toSet();
        final seen = {for (var i = 0; i < 100; i++) pool.choose('$mailroom/MAILBOX')};
        expect(seen, others, reason: 'directory $mailroom');
      }
      final seen = {for (var i = 0; i < 100; i++) pool.choose('https://other.bobspacebkk.com')};
      expect(seen, isNot(contains('https://pj.bobspacebkk.com')), reason: 'same domain, other host');
    });

    test('uses every relay for a directory no relay operator runs', () {
      final pool = OhttpRelayPool(PayjoinConfig.mailrooms, random: Random(7));
      final seen = {for (var i = 0; i < 100; i++) pool.choose('https://payjo.in')};
      expect(seen, PayjoinConfig.mailrooms.toSet());
    });

    test('refuses a directory whose operator runs every relay', () {
      final pool = OhttpRelayPool(const ['https://pj.bobspacebkk.com'], random: Random(8));
      expect(pool.serves('https://pj.bobspacebkk.com'), isFalse);
      expect(pool.serves('https://pj.pow.plan-b.foundation'), isTrue);
      expect(() => pool.choose('https://pj.bobspacebkk.com'), throwsA(isA<NoIndependentRelayException>()));
    });
  });

  group('postViaRelay', () {
    RelayRequest<String> build(String relay) =>
        RelayRequest(url: '$relay/x', body: Uint8List(0), contentType: 'message/ohttp-req', context: relay);

    test('builds a fresh request per attempt and marks the failing relay', () async {
      final pool = OhttpRelayPool(relays, random: Random(3));
      final attempts = <String>[];
      final (body, ctx) = await postViaRelay<String>(
        pool,
        directory,
        (relay) {
          attempts.add(relay);
          return build(relay);
        },
        (url, _, __) async {
          if (attempts.length == 1) throw Exception('relay down');
          return Uint8List.fromList([1, 2, 3]);
        },
      );
      expect(attempts, hasLength(2));
      expect(attempts.toSet(), hasLength(2), reason: 'the failed relay is not retried');
      expect(pool.failedRelays, {attempts.first});
      expect(ctx, attempts.last, reason: 'the context belongs to the request that succeeded');
      expect(body, [1, 2, 3]);
    });

    test('throws after every relay failed and resets the pool', () async {
      final pool = OhttpRelayPool(relays, random: Random(4));
      final attempts = <String>[];
      await expectLater(
        postViaRelay<String>(pool, directory, (relay) {
          attempts.add(relay);
          return build(relay);
        }, (_, __, ___) async => throw Exception('down')),
        throwsA(isA<NoOhttpRelayAvailableException>()),
      );
      expect(attempts.toSet(), relays.toSet());
      expect(attempts, hasLength(relays.length));
      expect(pool.failedRelays, isEmpty);
    });

    test("rotates only among relays apart from the directory's operator", () async {
      final pool = OhttpRelayPool(PayjoinConfig.mailrooms, random: Random(9));
      final attempts = <String>[];
      await expectLater(
        postViaRelay<String>(pool, 'https://payjoin.lab.vinteum.org', (relay) {
          attempts.add(relay);
          return build(relay);
        }, (_, __, ___) async => throw Exception('down')),
        throwsA(isA<NoOhttpRelayAvailableException>()),
      );
      expect(attempts.toSet(), {'https://pj.bobspacebkk.com', 'https://pj.pow.plan-b.foundation'});
      expect(attempts, hasLength(2));
    });

    test('errors from building the request are not relay failures', () async {
      final pool = OhttpRelayPool(relays, random: Random(5));
      await expectLater(
        postViaRelay<String>(pool, directory, (_) => throw StateError('expired'), (_, __, ___) async => Uint8List(0)),
        throwsStateError,
      );
      expect(pool.failedRelays, isEmpty);
    });
  });
}
