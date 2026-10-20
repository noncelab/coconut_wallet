import 'dart:convert';

import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final at = DateTime(2026, 10, 20, 9, 30);

  SafetyState full() => SafetyState(
    baselines: {
      1: WalletBaseline(
        height: 100,
        at: at,
        knownTxids: const {'a', 'b'},
        knownBelowHeight: 40,
        pendingSentAtBaseline: const {'a'},
        unexpectedSelfTxids: const {'s'},
      ),
    },
    appTxidPrefixes: const {'t1', 't2', 't3'},
    lastBroadcast: (walletId: 1, txid: 't2', at: at),
    recognizedTxids: const {'r1'},
    incidents: [
      SafetyIncident(
        walletId: 1,
        txid: 'x',
        detectedAt: at,
      ).respond(IncidentResponseMode.premium).withGuideStep(2, assistStartedAt: at),
    ],
    cautionWalletIds: const {1},
    watchOnlyVerifications: {
      2: WatchOnlyVerification(
        method: VerificationMethod.qr,
        result: VerificationResult.match,
        matchedIndex: 3,
        descriptorHash: 'h',
        at: at,
      ),
    },
    passphraseVerifiedAt: {1: at},
    bsms: {3: BsmsVerification(matched: true, configHash: 'c', at: at)},
    bsmsExports: {3: (configHash: 'c2', at: at)},
    recommendedDoneAt: {RecommendedCheckId.hotSafeStorage.key: at},
    metadataExport: (at: at, tagCount: 2, memoCount: 5),
    incomingWatch: {
      1: {
        'in1': (seenAt: at, strikes: 1, lastStrikeAt: at, paidAddresses: const {'addr1'}),
      },
    },
    conflicts: [(walletId: 1, txid: 'c1', at: at)],
    rescue: {
      1: (
        destination: RescueDestination(walletId: 2, setAt: at),
        draft: RescueDraftSummary(
          destinationAddress: 'bc1qdest',
          amount: 1000,
          fee: 200,
          inputCount: 2,
          feeRate: 2.5,
          preparedAt: at,
        ),
      ),
      3: (destination: RescueDestination(address: 'bc1qmanual', setAt: at), draft: null),
    },
    lastSuccessfulSyncAt: at,
    serverCert: ServerCertRecord(
      host: 'node.example',
      port: 50002,
      fingerprint: 'ab:cd',
      endValidity: at,
      caValid: false,
      observedAt: at,
    ),
    hintDismissed: true,
    readItemIds: const {
      'check:appLock:app',
      'check:mnemonicBackup:1',
      'check:mnemonicBackup:11',
      'incident:1:x',
      'incident:11:y',
      'incident:2:z',
    },
  );

  SafetyState decode(SafetyState s) => SafetyState.fromJson(jsonDecode(jsonEncode(s.toJson())) as Map<String, Object?>);

  test('JSON round trip keeps every field', () {
    expect(decode(full()), full());
    expect(decode(SafetyState.initial()), SafetyState.initial());
  });

  test('equality compares the Set inside incoming-watch records by content', () {
    SafetyState withWatch(Set<String> paid) => SafetyState(
      incomingWatch: {
        1: {'in': (seenAt: at, strikes: 0, lastStrikeAt: null, paidAddresses: paid)},
      },
    );
    expect(withWatch({'a', 'b'}), withWatch({'b', 'a'}));
    expect(withWatch({'a'}), isNot(withWatch({'b'})));
  });

  test('other version, missing version or broken values → initial', () {
    final json = jsonDecode(jsonEncode(full().toJson())) as Map<String, Object?>;
    expect(SafetyState.fromJson({...json, 'version': SafetyState.version + 1}), SafetyState.initial());
    expect(SafetyState.fromJson({...json}..remove('version')), SafetyState.initial());
    expect(
      SafetyState.fromJson({
        ...json,
        'incidents': const [
          {'walletId': 'one'},
        ],
      }),
      SafetyState.initial(),
    );
    expect(SafetyState.fromJson({...json, 'appTxidPrefixes': 'nope'}), SafetyState.initial());
    expect(
      SafetyState.fromJson({
        ...json,
        'recognizedTxids': const [1, 2],
      }),
      SafetyState.initial(),
    );
  });

  test('a state saved without the provenance set still loads (empty) and round-trips', () {
    final json = jsonDecode(jsonEncode(full().toJson())) as Map<String, Object?>..remove('appTxidPrefixes');
    final old = SafetyState.fromJson(json);
    expect(old, isNot(SafetyState.initial()), reason: 'not treated as corrupt');
    expect(old.appTxidPrefixes, isEmpty);
    expect(old.incidents, full().incidents);
    expect(decode(old), old);
  });

  test('a state saved before BSMS export records loads with none and round-trips (R30)', () {
    final json = jsonDecode(jsonEncode(full().toJson())) as Map<String, Object?>..remove('bsmsExports');
    final old = SafetyState.fromJson(json);
    expect(old.bsmsExports, isEmpty);
    expect(old.bsms, full().bsms, reason: 'not treated as corrupt');
    expect(decode(old), old);
  });

  test('missing keys read as empty', () {
    expect(SafetyState.fromJson(const {'version': SafetyState.version}), SafetyState.initial());
  });

  test('isAppCreated checks the global 20-char prefix set', () {
    final txid = 'f0' * 32;
    final s = full().copyWith(appTxidPrefixes: {...full().appTxidPrefixes, SafetyState.txidPrefix(txid)});
    expect(SafetyState.txidPrefix(txid).length, SafetyState.txidPrefixLength);
    expect((s.isAppCreated(txid), s.isAppCreated('t3'), s.isAppCreated('t4')), (true, true, false));
  });

  test('withoutWallet drops that wallet everywhere, including rescue entries pointing at it', () {
    final pointing = full().copyWith(
      rescue: {...full().rescue, 4: (destination: RescueDestination(walletId: 1, setAt: at), draft: null)},
    );
    final s = pointing.withoutWallet(1);
    expect(s.baselines, isEmpty);
    expect(s.lastBroadcast, isNull);
    expect(s.incidents, isEmpty);
    expect(s.cautionWalletIds, isEmpty);
    expect(s.passphraseVerifiedAt, isEmpty);
    expect(s.incomingWatch, isEmpty);
    expect(s.conflicts, isEmpty);
    expect(s.rescue.keys, [3]);
    // 다른 지갑 기록은 그대로
    expect(s.watchOnlyVerifications.keys, [2]);
    expect(s.bsms.keys, [3]);
    expect(s.bsmsExports.keys, [3]);
    expect(s.recognizedTxids, {'r1'});
    expect(s.serverCert, full().serverCert);
    // 앱 생성 txid는 지갑에 묶이지 않아 그대로(같은 디스크립터의 다른 지갑 보호, F9)
    expect(s.appTxidPrefixes, full().appTxidPrefixes);
    // 그 지갑의 읽음 표시만 지운다(1과 11을 섞지 않음)
    expect(s.readItemIds, {'check:appLock:app', 'check:mnemonicBackup:11', 'incident:11:y', 'incident:2:z'});

    final other = full().withoutWallet(2);
    expect(other.lastBroadcast, full().lastBroadcast);
    expect(other.watchOnlyVerifications, isEmpty);
    expect(other.rescue.keys, [3], reason: 'wallet 1 pointed at wallet 2 as destination');
    expect(full().withoutWallet(3).bsmsExports, isEmpty);
  });

  test('copyWith changes only the given fields', () {
    final s = full().copyWith(hintDismissed: false, readItemIds: {'x'});
    expect(s.hintDismissed, isFalse);
    expect(s.readItemIds, {'x'});
    expect(s.copyWith(hintDismissed: true, readItemIds: full().readItemIds), full());
  });
}
