import 'dart:typed_data';

import 'package:coconut_wallet/services/payjoin/payjoin_session_persister.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payjoin/payjoin.dart' as pj;

import 'payjoin_test_vectors.dart';

void main() {
  pj.OhttpKeys ohttpKeys() => pj.OhttpKeys.decode(bytes: Uint8List.fromList(hex.decode(kTestOhttpKeysHex)));

  group('stored receiver persister', () {
    test('replays a saved session from the store alone', () {
      final store = InMemoryPayjoinEventStore();
      final initialized = pj.ReceiverBuilder(
        address: kTestReceiverAddress,
        directory: 'https://example.com',
        ohttpKeys: ohttpKeys(),
      ).build().save(persister: StoredReceiverSessionPersister(store, 'r1'));
      final uri = initialized.pjUri().asString();

      expect(store.events['r1'], isNotEmpty);

      // A new persister over the same store stands in for an app restart.
      final replayed = pj.replayReceiverEventLog(persister: StoredReceiverSessionPersister(store, 'r1'));
      final state = replayed.state();
      expect(state, isA<pj.InitializedReceiveSession>());
      expect((state as pj.InitializedReceiveSession).inner.pjUri().asString(), uri);
    });

    test('cancelling closes the session in the store', () {
      final store = InMemoryPayjoinEventStore();
      final persister = StoredReceiverSessionPersister(store, 'r2');
      final initialized = pj.ReceiverBuilder(
        address: kTestReceiverAddress,
        directory: 'https://example.com',
        ohttpKeys: ohttpKeys(),
      ).build().save(persister: persister);

      expect(initialized.cancel().save(persister: persister), isNull);
      expect(store.closed, contains('r2'));
      final state = pj.replayReceiverEventLog(persister: StoredReceiverSessionPersister(store, 'r2')).state();
      expect(state, isA<pj.ClosedReceiveSession>());
    });

    test('sessions in one store do not mix', () {
      final store = InMemoryPayjoinEventStore();
      for (final id in ['a', 'b']) {
        pj.ReceiverBuilder(
          address: kTestReceiverAddress,
          directory: 'https://example.com',
          ohttpKeys: ohttpKeys(),
        ).build().save(persister: StoredReceiverSessionPersister(store, id));
      }
      final a = pj.replayReceiverEventLog(persister: StoredReceiverSessionPersister(store, 'a')).sessionHistory();
      final b = pj.replayReceiverEventLog(persister: StoredReceiverSessionPersister(store, 'b')).sessionHistory();
      expect(a.pjUri().asString(), isNot(b.pjUri().asString()));
    });
  });

  group('stored sender persister', () {
    test('replays to WithReplyKey and keeps the fallback after cancel', () {
      final store = InMemoryPayjoinEventStore();
      final receiver = pj.ReceiverBuilder(
        address: kTestReceiverAddress,
        directory: 'https://example.com',
        ohttpKeys: ohttpKeys(),
      ).build().save(persister: StoredReceiverSessionPersister(store, 'r'));

      final persister = StoredSenderSessionPersister(store, 's');
      pj.SenderBuilder(
        psbt: kTestOriginalPsbt,
        uri: receiver.pjUri(),
      ).buildRecommended(minFeeRateSatPerKwu: 1000).save(persister: persister);

      final resumed = pj.replaySenderEventLog(persister: StoredSenderSessionPersister(store, 's'));
      final state = resumed.state();
      expect(state, isA<pj.WithReplyKeySendSession>());

      final fallback = (state as pj.WithReplyKeySendSession).inner.cancel().save(persister: persister);
      expect(fallback.fallbackTx(), isNotEmpty);
      fallback.close().save(persister: persister);
      expect(store.closed, contains('s'));
      expect(
        pj.replaySenderEventLog(persister: StoredSenderSessionPersister(store, 's')).state(),
        isA<pj.ClosedSendSession>(),
      );
    });
  });
}
