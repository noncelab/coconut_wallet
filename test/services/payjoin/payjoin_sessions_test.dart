import 'dart:math';
import 'dart:typed_data';

import 'package:coconut_wallet/services/payjoin/ohttp_relay_pool.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_config.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_receiver.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_sender.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_session_persister.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payjoin/payjoin.dart' as pj;

import 'payjoin_test_vectors.dart';

void main() {
  late InMemoryPayjoinEventStore store;
  late List<String> posted;
  final relays = ['https://relay-a.example', 'https://relay-b.example'];

  Future<Uint8List> unreachable(String url, Uint8List body, String contentType) async {
    posted.add(url);
    throw Exception('offline');
  }

  setUp(() {
    store = InMemoryPayjoinEventStore();
    posted = [];
  });

  const mailrooms = PayjoinConfig.mailrooms;
  pj.OhttpKeys testKeys() => pj.OhttpKeys.decode(bytes: Uint8List.fromList(hex.decode(kTestOhttpKeysHex)));

  /// The relay a posted URL went to.
  String relayOf(String url) => [...relays, ...mailrooms].firstWhere(url.startsWith);

  String directoryOf(String bip21) => pj.Uri.parse(uri: bip21).checkPjSupported().pjEndpoint();

  String receiverUri({int expirySecs = 3600, String directory = 'https://example.com'}) =>
      pj.ReceiverBuilder(
            address: kTestReceiverAddress,
            directory: directory,
            ohttpKeys: pj.OhttpKeys.decode(bytes: Uint8List.fromList(hex.decode(kTestOhttpKeysHex))),
          )
          .withExpiration(expirationSecs: expirySecs)
          .build()
          .save(persister: StoredReceiverSessionPersister(store, 'r'))
          .pjUri()
          .asString();

  PayjoinSender sender() => PayjoinSender(store: store, relays: OhttpRelayPool(relays), post: unreachable);

  test('isPayjoinUri tells BIP 77 URIs from plain ones', () {
    expect(isPayjoinUri(receiverUri()), isTrue);
    expect(isPayjoinUri('bitcoin:$kTestReceiverAddress?amount=0.001'), isFalse);
    expect(isPayjoinUri('not a uri'), isFalse);
  });

  test('a sender session survives an unreachable directory', () async {
    final s = sender();
    s.begin(sessionId: 's', bip21: receiverUri(), originalPsbt: kTestOriginalPsbt, feeRateSatPerVb: 2);
    await expectLater(s.step('s'), throwsA(isA<NoOhttpRelayAvailableException>()));
    expect(posted.map(relayOf).toSet(), relays.toSet(), reason: 'every relay was tried');
    expect(posted, hasLength(relays.length), reason: 'no relay was tried twice');
    expect(
      pj.replaySenderEventLog(persister: StoredSenderSessionPersister(store, 's')).state(),
      isA<pj.WithReplyKeySendSession>(),
      reason: 'the next step retries the post',
    );
  });

  test("a sender never posts through a relay run by the directory's operator", () async {
    final s = PayjoinSender(store: store, relays: OhttpRelayPool(mailrooms), post: unreachable);
    s.begin(
      sessionId: 's',
      bip21: receiverUri(directory: 'https://pj.pow.plan-b.foundation'),
      originalPsbt: kTestOriginalPsbt,
      feeRateSatPerVb: 2,
    );
    await expectLater(s.step('s'), throwsA(isA<NoOhttpRelayAvailableException>()));
    expect(posted.map(relayOf).toList()..sort(), ['https://payjoin.lab.vinteum.org', 'https://pj.bobspacebkk.com']);
  });

  test('a sender uses every relay for a directory none of their operators runs', () async {
    final s = PayjoinSender(store: store, relays: OhttpRelayPool(mailrooms), post: unreachable);
    s.begin(
      sessionId: 's',
      bip21: receiverUri(directory: 'https://payjo.in'),
      originalPsbt: kTestOriginalPsbt,
      feeRateSatPerVb: 2,
    );
    await expectLater(s.step('s'), throwsA(isA<NoOhttpRelayAvailableException>()));
    expect(posted.map(relayOf).toSet(), mailrooms.toSet());
  });

  test("a sender refuses to start when every relay is the directory's operator", () {
    final s = PayjoinSender(
      store: store,
      relays: OhttpRelayPool(const ['https://pj.bobspacebkk.com']),
      post: unreachable,
    );
    expect(
      () => s.begin(
        sessionId: 's',
        bip21: receiverUri(directory: 'https://pj.bobspacebkk.com'),
        originalPsbt: kTestOriginalPsbt,
        feeRateSatPerVb: 2,
      ),
      throwsA(isA<NoIndependentRelayException>()),
    );
    expect(store.loadEvents('s'), isEmpty, reason: 'no session was saved');
    expect(posted, isEmpty);
  });

  test('an expired sender session falls back to the Original and closes', () async {
    final uri = receiverUri(expirySecs: 1);
    final s = sender();
    s.begin(sessionId: 's', bip21: uri, originalPsbt: kTestOriginalPsbt, feeRateSatPerVb: 2);
    await Future<void>.delayed(const Duration(seconds: 2));

    final progress = await s.step('s');
    expect(progress, isA<PayjoinSendFallback>());
    expect(posted, isEmpty, reason: 'nothing is sent for an expired session');
    expect(store.closed, contains('s'));
  });

  test('cancelling a sender session closes it', () {
    final s = sender();
    s.begin(sessionId: 's', bip21: receiverUri(), originalPsbt: kTestOriginalPsbt, feeRateSatPerVb: 2);
    s.cancel('s');
    expect(store.closed, contains('s'));
    expect(
      pj.replaySenderEventLog(persister: StoredSenderSessionPersister(store, 's')).state(),
      isA<pj.ClosedSendSession>(),
    );
  });

  test('fee rates convert from sat/vB to sat/kwu', () {
    expect(satPerVbToSatPerKwu(1), 250);
    expect(satPerVbToSatPerKwu(2.5), 625);
    expect(satPerVbToSatPerKwu(0.1), 25);
  });

  test('a receiver session with no sender yet can be cancelled without a fallback', () async {
    receiverUri();
    final receiver = PayjoinReceiver(
      store: store,
      relays: OhttpRelayPool(relays),
      directoryUrls: const ['https://example.com'],
      post: unreachable,
    );
    await expectLater(receiver.step('r', _NoWallet()), throwsA(isA<NoOhttpRelayAvailableException>()));
    expect(receiver.fallbackTx('r'), isNull);
    expect(receiver.cancel('r'), isNull);
    expect(store.closed, contains('r'));
  });

  group('receiver directories', () {
    late List<(String, String)> keyFetches;

    Future<pj.OhttpKeys> fetchKeys({
      required String ohttpRelayUrl,
      required String directoryUrl,
      Uint8List? certificate,
    }) async {
      keyFetches.add((ohttpRelayUrl, directoryUrl));
      return testKeys();
    }

    PayjoinReceiver receiver({List<String> directories = mailrooms, int seed = 0}) => PayjoinReceiver(
      store: store,
      relays: OhttpRelayPool(mailrooms, random: Random(seed)),
      directoryUrls: directories,
      post: unreachable,
      fetchKeys: fetchKeys,
      random: Random(seed),
    );

    Future<String> begin(PayjoinReceiver r, String sessionId) async {
      await r.begin(sessionId: sessionId, address: kTestReceiverAddress, expiry: const Duration(hours: 1));
      return directoryOf(r.pjUri(sessionId));
    }

    setUp(() => keyFetches = []);

    test('each session picks its directory at random from every mailroom', () async {
      final r = receiver(seed: 1);
      final chosen = <String>{};
      for (var i = 0; i < 30; i++) {
        chosen.add(payjoinOperator(await begin(r, 'r$i')));
      }
      expect(chosen, mailrooms.map(payjoinOperator).toSet());
      for (final (relay, directory) in keyFetches) {
        expect(payjoinOperator(relay), isNot(payjoinOperator(directory)), reason: 'keys for $directory via $relay');
      }
    });

    test("polls only through relays apart from the session's directory", () async {
      final r = receiver(seed: 2);
      final directory = await begin(r, 'r');
      await expectLater(r.step('r', _NoWallet()), throwsA(isA<NoOhttpRelayAvailableException>()));
      expect(
        posted.map(relayOf).toSet(),
        mailrooms.where((m) => payjoinOperator(m) != payjoinOperator(directory)).toSet(),
      );
      expect(posted, hasLength(2));
    });

    test('a resumed session keeps its directory and its relays still exclude it', () async {
      final directory = await begin(receiver(seed: 3), 'r');

      // After a restart with a configuration that no longer lists it.
      final resumed = receiver(directories: const ['https://payjo.in'], seed: 4);
      expect(directoryOf(resumed.pjUri('r')), directory);
      await expectLater(resumed.step('r', _NoWallet()), throwsA(isA<NoOhttpRelayAvailableException>()));
      expect(posted.map(relayOf).map(payjoinOperator), isNot(contains(payjoinOperator(directory))));
      expect(posted, hasLength(2));
    });
  });
}

class _NoWallet implements PayjoinReceiverWallet {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}
