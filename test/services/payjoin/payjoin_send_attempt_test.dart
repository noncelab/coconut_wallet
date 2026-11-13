import 'dart:typed_data';

import 'package:coconut_wallet/repository/realm/payjoin_session_repository.dart';
import 'package:coconut_wallet/services/payjoin/ohttp_relay_pool.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_send_attempt.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_sender.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_session_persister.dart';
import 'package:convert/convert.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payjoin/payjoin.dart' as pj;

import '../../repository/realm/test_realm_manager.dart';
import 'payjoin_test_vectors.dart';

void main() {
  late TestRealmManager realmManager;
  late PayjoinSessionRepository repository;

  setUp(() {
    realmManager = TestRealmManager();
    repository = PayjoinSessionRepository(realmManager);
  });

  tearDown(() => realmManager.dispose());

  test("sends the Original when every relay is run by the directory's operator", () async {
    final bip21 =
        pj.ReceiverBuilder(
          address: kTestReceiverAddress,
          directory: 'https://pj.bobspacebkk.com',
          ohttpKeys: pj.OhttpKeys.decode(bytes: Uint8List.fromList(hex.decode(kTestOhttpKeysHex))),
        ).build().save(persister: StoredReceiverSessionPersister(InMemoryPayjoinEventStore(), 'r')).pjUri().asString();
    final posted = <String>[];
    final attempt = PayjoinSendAttempt(
      repository: repository,
      sender: PayjoinSender(
        store: repository,
        relays: OhttpRelayPool(const ['https://relay.bobspacebkk.com']),
        post: (url, _, __) async {
          posted.add(url);
          return Uint8List(0);
        },
      ),
    );
    addTearDown(attempt.dispose);

    final outcome = await attempt.run(
      walletId: 1,
      bip21: bip21,
      signedOriginalPsbt: kTestOriginalPsbt,
      originalTxHex: '00',
      feeRateSatPerVb: 2,
    );

    expect(outcome, isA<PayjoinSendFallsBack>());
    expect((outcome as PayjoinSendFallsBack).reason, isA<NoIndependentRelayException>());
    expect(posted, isEmpty);
    expect(repository.find(outcome.sessionId!)!.isClosed, isTrue);
  });
}
