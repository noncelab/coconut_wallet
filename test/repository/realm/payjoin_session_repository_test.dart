import 'dart:typed_data';

import 'package:coconut_wallet/repository/realm/payjoin_session_repository.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_session_persister.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payjoin/payjoin.dart' as pj;

import '../../services/payjoin/payjoin_test_vectors.dart';
import 'test_realm_manager.dart';

void main() {
  late TestRealmManager realmManager;
  late PayjoinSessionRepository repository;

  setUp(() {
    realmManager = TestRealmManager();
    repository = PayjoinSessionRepository(realmManager);
  });

  tearDown(() => realmManager.dispose());

  pj.Initialized newReceiver(String id) {
    repository.create(id: id, walletId: 1, role: PayjoinRole.receive);
    return pj.ReceiverBuilder(
      address: kTestReceiverAddress,
      directory: 'https://example.com',
      ohttpKeys: pj.OhttpKeys.decode(bytes: Uint8List.fromList(hex.decode(kTestOhttpKeysHex))),
    ).build().save(persister: StoredReceiverSessionPersister(repository, id));
  }

  test('a session replays from Realm after the repository is recreated', () {
    final uri = newReceiver('r1').pjUri().asString();

    final reopened = PayjoinSessionRepository(realmManager);
    final state = pj.replayReceiverEventLog(persister: StoredReceiverSessionPersister(reopened, 'r1')).state();
    expect(state, isA<pj.InitializedReceiveSession>());
    expect((state as pj.InitializedReceiveSession).inner.pjUri().asString(), uri);
  });

  test('open sessions exclude closed ones and filter by role and wallet', () {
    final first = newReceiver('r1');
    newReceiver('r2');
    repository.create(id: 's1', walletId: 2, role: PayjoinRole.send);

    first.cancel().save(persister: StoredReceiverSessionPersister(repository, 'r1'));

    expect(repository.openSessions(role: PayjoinRole.receive).map((s) => s.id), ['r2']);
    expect(repository.openSessions(role: PayjoinRole.send, walletId: 2).map((s) => s.id), ['s1']);
    expect(repository.openSessions(walletId: 1).map((s) => s.id), ['r2']);
    expect(repository.openSessions().map((s) => s.id), ['r2', 's1']);
  });

  test('values survive beside the event log', () {
    newReceiver('r1');
    repository.writeValue('r1', 'proposalTxid', 'ab');
    repository.writeValue('r1', 'other', 'cd');
    expect(PayjoinSessionRepository(realmManager).readValue('r1', 'proposalTxid'), 'ab');
    expect(repository.readValue('r1', 'missing'), isNull);
  });

  test('an outpoint counts as seen from its second offer on', () {
    expect(repository.markInputSeen('aa:0'), isFalse);
    expect(repository.markInputSeen('aa:0'), isTrue);
    expect(repository.markInputSeen('aa:1'), isFalse);
  });
}
