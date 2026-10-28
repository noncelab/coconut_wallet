import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_inputs.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/repository/shared_preference/safety_store.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/safety/incident_detector.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../model/safety/safety_fixtures.dart';

void main() {
  IncidentDelta detect(
    List<SafetyWalletSnapshot> wallets, {
    SafetyState state = const SafetyState(),
    int height = 1000,
    DateTime? now,
  }) => IncidentDetector.detect(inputs(wallets: wallets, state: state, height: height, now: now));
  DateTime day(int n) => testNow.add(Duration(days: n));
  String p(String txid) => SafetyState.txidPrefix(txid);

  group('baseline', () {
    test('made once per wallet, only when settled and the block height is known', () {
      expect(detect([wallet(1, settled: false)]).baselines, isEmpty);
      expect(detect([wallet(1)], height: 0).baselines, isEmpty);
      final delta = detect([wallet(1)]);
      expect(delta.baselines[1]!.height, 1000);
      expect(delta.baselines[1]!.at, testNow);
      expect(detect([wallet(1)], state: delta.applyTo(const SafetyState()), height: 1200).baselines, isEmpty);
    });

    test('remembers every txid present (any type or state) plus pending spends, by prefix', () {
      final w = wallet(
        1,
        txs: [
          tx('pendingSent'),
          tx('received', type: TransactionType.received, height: 400),
          tx('self', type: TransactionType.self, height: 999),
          tx('old', height: 10),
        ],
        pendingSpentBy: {'notListed'},
      );
      final b = detect([w]).baselines[1]!;
      expect(b.knownTxids, {p('pendingSent'), p('received'), p('self'), p('old'), p('notListed')});
      expect(b.knownBelowHeight, isNull);
    });

    test('review set: outgoing that was pending or confirmed within 7 days (block time) at baseline; not self', () {
      final w = wallet(
        1,
        txs: [
          tx('pendingSent'),
          tx('misclassified', type: TransactionType.received),
          tx('selfPending', type: TransactionType.self),
          tx('recentConfirmed', height: 990, timestamp: day(-2)),
          tx('oldConfirmed', height: 900, timestamp: day(-8)),
          tx('received', type: TransactionType.received, height: 995, timestamp: day(-1)),
        ],
        pendingSpentBy: {'misclassified', 'selfPending', 'notListed'},
      );
      expect(detect([w]).baselines[1]!.pendingSentAtBaseline, {
        'pendingSent',
        'misclassified',
        'recentConfirmed',
        'notListed',
      });
    });

    test('self transfers and sends to my other wallets are not recent outgoing at baseline', () {
      final w = wallet(
        1,
        txs: [
          tx('selfPending', type: TransactionType.self),
          tx('selfRecent', type: TransactionType.self, height: 990, timestamp: day(-2)),
          tx('toMyOtherWallet', toOwnWallet: true),
          tx('toSomeoneElse'),
        ],
      );
      final b = detect([w]).baselines[1]!;
      expect(b.unexpectedSelfTxids, isEmpty);
      expect(b.pendingSentAtBaseline, {'toSomeoneElse'});
      expect(b.knownTxids, containsAll([p('selfPending'), p('selfRecent'), p('toMyOtherWallet'), p('toSomeoneElse')]));
    });

    test('the run that creates the baseline creates no incident', () {
      expect(
        detect([
          wallet(1, txs: [tx('pendingSent'), tx('confirmed', height: 1000)]),
        ]).created,
        isEmpty,
      );
    });

    test('more than 20,000 txs: the newest 20,000 by txid, the rest by height (ponytail)', () {
      final many = [for (var h = 1; h <= IncidentDetector.maxKnownTxids + 5; h++) tx('t$h', height: h)];
      final b = detect([wallet(1, txs: many)], height: 30000).baselines[1]!;
      expect(b.knownTxids.length, IncidentDetector.maxKnownTxids);
      expect(b.knownBelowHeight, 5);
      expect((b.knows('t1', 1), b.knows('t6', 6), b.knows('later', 5), b.knows('later', 6)), (true, true, true, false));
    });
  });

  group('incident candidates', () {
    SafetyState based({Set<String> known = const {}}) =>
        SafetyState(baselines: {1: baseline(height: 1000, known: known)});

    test('a new outgoing tx after the baseline becomes an incident (pending or confirmed)', () {
      final created =
          detect([
            wallet(1, txs: [tx('pending'), tx('confirmed', height: 1001)]),
          ], state: based()).created;
      expect(created.map((i) => (i.id, i.txState, i.state, i.detectedAt)), [
        ('1:pending', IncidentTxState.pending, IncidentState.detected, testNow),
        ('1:confirmed', IncidentTxState.confirmed, IncidentState.detected, testNow),
      ]);
    });

    test('a new tx is judged whatever height the server reports (red team §8) or a reorg gives it (R2)', () {
      final w = wallet(1, txs: [tx('fakeOld', height: 500), tx('atBaseline', height: 1000), tx('recent', height: 997)]);
      expect(detect([w], state: based()).created.map((i) => i.txid), ['fakeOld', 'atBaseline', 'recent']);
    });

    test('txs present at baseline stay quiet whatever height or state they show later', () {
      final state = based(known: {'a', 'b'});
      final w = wallet(1, txs: [tx('a', height: 1005), tx('b')]);
      expect(detect([w], state: state).created, isEmpty);
    });

    test('a sent tx misclassified as received is caught through the pending spend (R4 of ARCH)', () {
      final w = wallet(1, txs: [tx('stolen', type: TransactionType.received)], pendingSpentBy: {'stolen'});
      expect(detect([w], state: based()).created.single.txid, 'stolen');
    });

    test('a self transfer with a pending spend is not an outgoing incident', () {
      final w = wallet(1, txs: [tx('self', type: TransactionType.self)], pendingSpentBy: {'self'});
      expect(detect([w], state: based()).created, isEmpty);
    });

    test('received txs are never incidents', () {
      final w = wallet(
        1,
        txs: [tx('in', type: TransactionType.received), tx('in2', type: TransactionType.received, height: 5)],
      );
      expect(detect([w], state: based()).created, isEmpty);
    });

    test('app-created txids (any wallet), recognized txids and existing incidents are excluded', () {
      final state = based().copyWith(
        appTxidPrefixes: {p('fromOtherWallet')},
        recognizedTxids: {'known'},
        incidents: [SafetyIncident(walletId: 1, txid: 'dup', detectedAt: DateTime(2026, 10, 19))],
      );
      final w = wallet(1, txs: [tx('fromOtherWallet'), tx('known'), tx('dup'), tx('new')]);
      expect(detect([w], state: state).created.map((i) => i.id), ['1:new']);
    });

    test('the same unknown tx in two wallets is an incident in each', () {
      final state = SafetyState(baselines: {1: baseline(), 2: baseline()});
      final created =
          detect([
            wallet(1, txs: [tx('x')]),
            wallet(2, kind: SafetyWalletKind.watchOnly, txs: [tx('x')]),
          ], state: state).created;
      expect(created.map((i) => i.id), ['1:x', '2:x']);
    });

    test('judged only on settled runs', () {
      expect(
        detect([
          wallet(1, settled: false, txs: [tx('x')]),
        ], state: based()).created,
        isEmpty,
      );
      expect(
        detect([
          wallet(1, txs: [tx('x')]),
        ], state: based()).created.single.txid,
        'x',
      );
    });
  });

  group('only bitcoin leaving my wallets is an incident', () {
    test('after the baseline a self transfer or a send to my other wallet is not an incident; a send elsewhere is', () {
      final s = SafetyState(
        baselines: {
          1: baseline(known: {'old'}),
        },
      );
      final w = wallet(
        1,
        txs: [
          tx('old'),
          tx('self', type: TransactionType.self, height: 1005),
          tx('toMyOtherWallet', toOwnWallet: true),
          tx('toSomeoneElse'),
        ],
      );
      final d = detect([w], state: s);
      expect(d.created.map((i) => i.txid), ['toSomeoneElse']);
      expect(d.baselines, isEmpty, reason: 'self transfers are no longer kept for review');
    });
  });

  group('app-created provenance (one global prefix set)', () {
    final txid = 'ab' * 32; // 실제 길이 64자리

    test('a record repaired into sent is judged on the next run, whatever its old createdAt (R1)', () {
      // 이전 거래 조회가 실패해 received로 저장된 확정 출금 x. 40일 뒤 상세 화면 보정으로 sent가 되며 옛 createdAt을 유지
      var s = SafetyState(baselines: {1: baseline(height: 1000)});
      final misread = tx('x', type: TransactionType.received, height: 1100, createdAt: day(-41));
      final other = tx('later', type: TransactionType.received, height: 1150, createdAt: day(-1));
      s = detect(
        [
          wallet(1, txs: [misread, other]),
        ],
        state: s,
        height: 1200,
      ).applyTo(s);
      expect(s.incidents, isEmpty);
      final repaired = tx('x', height: 1100, createdAt: day(-41));
      expect(
        detect(
          [
            wallet(1, txs: [repaired, other]),
          ],
          state: s,
          height: 1210,
        ).created.single.txid,
        'x',
      );
    });

    test(
      'with 5,000+ unrelated app records, a record later repaired into sent still alerts (R1-M1, no compaction)',
      () {
        var s = SafetyState(
          baselines: {1: baseline(height: 1000)},
          appTxidPrefixes: {for (var i = 0; i < 5001; i++) 'other$i'},
        );
        final misread = tx('x', type: TransactionType.received, height: 1100, createdAt: day(-41));
        final other = tx('later', type: TransactionType.received, height: 1150, createdAt: day(-1));
        // 모든 지갑이 동기화를 마친 실행이 여러 번 지나도 기준점은 넓어지지 않고 기록도 줄지 않는다
        for (var height = 1200; height < 1204; height++) {
          s = detect(
            [
              wallet(1, txs: [misread, other]),
              wallet(2),
            ],
            state: s,
            height: height,
          ).applyTo(s);
        }
        expect(s.baselines[1]!.knownTxids, isEmpty);
        expect(s.appTxidPrefixes.length, 5001);
        final repaired = tx('x', height: 1100, createdAt: day(-41));
        expect(
          detect(
            [
              wallet(1, txs: [repaired, other]),
              wallet(2),
            ],
            state: s,
            height: 1210,
          ).created.single.txid,
          'x',
        );
      },
    );

    test('a recorded app tx stays quiet even when it first appears after many other records (R4)', () async {
      SharedPreferences.setMockInitialValues({});
      // ignore: deprecated_member_use_from_same_package
      final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
      final store = SafetyStore(prefs);
      await store.update((s) => s.copyWith(baselines: {1: baseline(height: 1000)}));
      await store.recordAppCreatedTxid(1, txid);
      for (var i = 0; i < 1500; i++) {
        await store.recordAppCreatedTxid(2, 'draft$i');
      }
      final s = store.load();
      // 처음 보는 대기 x, 잠깐 사라졌다 다시 온 x, 시계가 바뀐 뒤의 x, 확정된 x 모두 조용
      expect(
        detect([
          wallet(1, txs: [tx(txid)]),
        ], state: s).created,
        isEmpty,
      );
      expect(detect([wallet(1)], state: s).created, isEmpty);
      expect(
        detect(
          [
            wallet(1, txs: [tx(txid)]),
          ],
          state: s,
          now: day(40),
        ).created,
        isEmpty,
      );
      expect(
        detect(
          [
            wallet(1, txs: [tx(txid, height: 1005)]),
          ],
          state: s,
          now: day(-40),
        ).created,
        isEmpty,
      );
      // 모르는 거래는 여전히 사건
      expect(
        detect([
          wallet(1, txs: [tx('cd' * 32)]),
        ], state: s).created.single.txid,
        'cd' * 32,
      );
    });

    test('provenance is shared by all wallets and survives deleting the wallet that made the tx (R5, F9)', () {
      SafetyWalletSnapshot watchOnly(List<SafetyTx> txs) => wallet(2, kind: SafetyWalletKind.watchOnly, txs: txs);
      var s = SafetyState(baselines: {1: baseline(), 2: baseline()}, appTxidPrefixes: {p(txid)});
      expect(
        detect([
          wallet(1, txs: [tx(txid)]),
        ], state: s).created,
        isEmpty,
      );
      // 같은 디스크립터의 W가 한참 뒤(그 사이 다른 기록 많음)에야 x를 본다. 만든 지갑 H를 지운 뒤여도 조용
      s = s.copyWith(appTxidPrefixes: {...s.appTxidPrefixes, for (var i = 0; i < 1200; i++) 'other$i'});
      expect(
        detect([
          watchOnly([tx(txid)]),
        ], state: s).created,
        isEmpty,
      );
      s = s.withoutWallet(1);
      expect(s.isAppCreated(txid), isTrue);
      expect(
        detect([
          watchOnly([tx(txid)]),
        ], state: s).created,
        isEmpty,
      );
    });

    test('keeps 20 hex chars (80 bits) of the txid, case-insensitively', () {
      expect(p(txid), 'ab' * 10);
      expect(p(txid.toUpperCase()), 'ab' * 10);
      final s = SafetyState(appTxidPrefixes: {p(txid)});
      expect(s.isAppCreated(txid), isTrue);
      expect(s.isAppCreated('${'ab' * 10}${'00' * 22}'), isTrue, reason: 'only the 80-bit prefix is kept');
      expect(s.isAppCreated('${'ab' * 9}ac${'ab' * 22}'), isFalse);
    });
  });

  group('incident tx state', () {
    final incident = SafetyIncident(walletId: 1, txid: 'x', detectedAt: DateTime(2026, 10, 19));
    SafetyState withIncident(SafetyIncident i) => SafetyState(baselines: {1: baseline()}, incidents: [i]);

    test('follows the wallet: confirmed, replaced/dropped (info), back to pending', () {
      expect(
        detect([
          wallet(1, txs: [tx('x', height: 1001)]),
        ], state: withIncident(incident)).txStates,
        {'1:x': IncidentTxState.confirmed},
      );
      for (final gone in [IncidentTxState.replaced, IncidentTxState.dropped]) {
        expect(
          detect([
            wallet(1, tracked: {'x': gone}),
          ], state: withIncident(incident)).txStates,
          {'1:x': gone},
        );
      }
      final dropped = incident.withTxState(IncidentTxState.dropped);
      expect(
        detect([
          wallet(1, txs: [tx('x')]),
        ], state: withIncident(dropped)).txStates,
        {'1:x': IncidentTxState.pending},
      );
    });

    test('unchanged, still syncing or unknown to the collector → no change', () {
      expect(
        detect([
          wallet(1, txs: [tx('x')]),
        ], state: withIncident(incident)).txStates,
        isEmpty,
      );
      expect(
        detect([
          wallet(1, settled: false, tracked: {'x': IncidentTxState.dropped}),
        ], state: withIncident(incident)).txStates,
        isEmpty,
      );
      expect(detect([wallet(1)], state: withIncident(incident)).txStates, isEmpty);
    });

    test('closed incidents are left alone', () {
      final recognized = incident.recognize(testNow);
      expect(
        detect([
          wallet(1, tracked: {'x': IncidentTxState.dropped}),
        ], state: withIncident(recognized)).txStates,
        isEmpty,
      );
    });
  });

  group('incoming watch → txConflict', () {
    final incoming = tx('in', type: TransactionType.received, paid: {'bc1qme'});
    DateTime at(int minutes) => testNow.add(Duration(minutes: minutes));

    test('two disappearances at least 10 minutes apart make a conflict', () {
      var d = detect([
        wallet(1, txs: [incoming]),
      ]);
      final watched = d.incomingWatch[1]!['in']!;
      expect((watched.seenAt, watched.strikes, watched.lastStrikeAt), (testNow, 0, null));
      expect(watched.paidAddresses, {'bc1qme'});
      var s = d.applyTo(const SafetyState());

      d = detect([wallet(1)], state: s, now: at(1));
      expect(d.incomingWatch[1]!['in']!.strikes, 1);
      expect(d.conflicts, isEmpty);
      s = d.applyTo(s);

      expect(detect([wallet(1)], state: s, now: at(6)).isEmpty, isTrue, reason: 'second strike needs 10 minutes');

      d = detect([wallet(1)], state: s, now: at(11));
      expect(d.conflicts, [(walletId: 1, txid: 'in', at: at(11))]);
      s = d.applyTo(s);
      expect(s.conflicts.single.txid, 'in');
      expect(s.incomingWatch, isEmpty);
    });

    test('reappearing resets the strike; confirmation ends the watch', () {
      var s = detect([
        wallet(1, txs: [incoming]),
      ]).applyTo(const SafetyState());
      s = detect([wallet(1)], state: s, now: at(1)).applyTo(s);
      s = detect(
        [
          wallet(1, txs: [incoming]),
        ],
        state: s,
        now: at(2),
      ).applyTo(s);
      expect(s.incomingWatch[1]!['in']!.strikes, 0);
      s = detect(
        [
          wallet(1, txs: [tx('in', type: TransactionType.received, height: 1001)]),
        ],
        state: s,
        now: at(3),
      ).applyTo(s);
      expect(s.incomingWatch, isEmpty);
      expect(s.conflicts, isEmpty);
    });

    test('a newer tx paying the same address of mine is the sender bumping the fee — no conflict', () {
      var s = detect([
        wallet(1, txs: [incoming]),
      ]).applyTo(const SafetyState());
      final bump = tx('bump', type: TransactionType.received, paid: {'bc1qme'}, createdAt: at(1));
      final d = detect(
        [
          wallet(1, txs: [bump]),
        ],
        state: s,
        now: at(2),
      );
      expect(d.conflicts, isEmpty);
      s = d.applyTo(s);
      expect(s.incomingWatch[1]!.keys, ['bump'], reason: 'the replacement is watched instead');
    });

    test('a resync after the watch started skips the judgement', () {
      final s = detect([
        wallet(1, txs: [incoming]),
      ]).applyTo(const SafetyState());
      final d = detect([wallet(1, lastResyncAt: at(1))], state: s, now: at(2));
      expect(d.conflicts, isEmpty);
      expect(d.incomingWatch[1], isEmpty);
    });

    test('a tx spending my UTXOs is never watched as incoming; my own fee bump is not a conflict', () {
      // 앱이 만든 x가 received로 분류됐지만 내 UTXO를 쓴다(R4). 잔돈뿐이라 내 받기 주소 지급이 없다
      final x = tx('x', type: TransactionType.received);
      final s = SafetyState(baselines: {1: baseline()}, appTxidPrefixes: const {'x', 'y'});
      expect(
        detect([
          wallet(1, txs: [x], pendingSpentBy: {'x'}),
        ], state: s).incomingWatch,
        isEmpty,
      );
      // 증거가 늦게 생기면 그때 감시를 끝낸다
      var t = detect([
        wallet(1, txs: [x]),
      ], state: s).applyTo(s);
      expect(t.incomingWatch[1]!.keys, ['x']);
      t = detect(
        [
          wallet(1, txs: [x], pendingSpentBy: {'x'}),
        ],
        state: t,
        now: at(1),
      ).applyTo(t);
      expect(t.incomingWatch, isEmpty);
      // 수수료를 올려 x가 y로 바뀌어도 충돌 아님
      final bumped = wallet(1, txs: [tx('y', type: TransactionType.received)], pendingSpentBy: {'y'});
      t = detect([bumped], state: t, now: at(2)).applyTo(t);
      t = detect([bumped], state: t, now: at(15)).applyTo(t);
      expect(t.conflicts, isEmpty);
    });

    test('a conflict is resolved once its original tx is back and confirmed in a settled snapshot', () {
      final s = SafetyState(baselines: {1: baseline()}, conflicts: [(walletId: 1, txid: 'in', at: testNow)]);
      final back = wallet(1, txs: [tx('in', type: TransactionType.received, height: 1001)]);
      expect(detect([back], state: s).resolvedConflicts, {(walletId: 1, txid: 'in')});
      expect(detect([back], state: s).applyTo(s).conflicts, isEmpty);
      // 동기화 중이거나 아직 대기 중이면 그대로
      expect(detect([wallet(1, settled: false, txs: back.txs)], state: s).resolvedConflicts, isEmpty);
      expect(
        detect([
          wallet(1, txs: [tx('in', type: TransactionType.received)]),
        ], state: s).resolvedConflicts,
        isEmpty,
      );
    });

    test('wallets still syncing are neither watched nor judged', () {
      expect(
        detect([
          wallet(1, settled: false, txs: [incoming]),
        ]).incomingWatch,
        isEmpty,
      );
      final s = detect([
        wallet(1, txs: [incoming]),
      ]).applyTo(const SafetyState());
      expect(detect([wallet(1, settled: false)], state: s, now: at(30)).isEmpty, isTrue);
    });
  });

  group('applyTo', () {
    test('writes the delta baselines (new or extended) and does not duplicate incidents', () {
      final delta = IncidentDelta(
        baselines: {1: baseline(height: 900)},
        created: [SafetyIncident(walletId: 1, txid: 'x', detectedAt: testNow)],
      );
      final once = delta.applyTo(SafetyState(baselines: {1: baseline(height: 500), 2: baseline(height: 700)}));
      expect((once.baselines[1]!.height, once.baselines[2]!.height), (900, 700));
      expect(delta.applyTo(once).incidents.length, 1);
    });

    test('skips txs recognized or recorded by the app between detection and apply', () {
      final delta = IncidentDelta(
        created: [
          SafetyIncident(walletId: 1, txid: 'recognized', detectedAt: testNow),
          SafetyIncident(walletId: 1, txid: 'appSent', detectedAt: testNow),
        ],
      );
      final s = delta.applyTo(SafetyState(recognizedTxids: const {'recognized'}, appTxidPrefixes: {p('appSent')}));
      expect(s.incidents, isEmpty);
    });

    test('conflicts are de-duplicated and capped', () {
      final events = [for (var i = 0; i < IncidentDelta.maxConflicts + 5; i++) (walletId: 1, txid: 'c$i', at: testNow)];
      final s = IncidentDelta(conflicts: events).applyTo(const SafetyState());
      expect(s.conflicts.length, IncidentDelta.maxConflicts);
      expect(s.conflicts.last.txid, 'c${IncidentDelta.maxConflicts + 4}');
      expect(IncidentDelta(conflicts: [events.last]).applyTo(s).conflicts.length, IncidentDelta.maxConflicts);
    });

    test('detecting again on the applied state changes nothing', () {
      final incoming = tx('in', type: TransactionType.received, paid: {'a'});
      var s = detect([
        wallet(1, txs: [incoming]),
      ]).applyTo(const SafetyState());
      final later = [
        wallet(1, txs: [incoming, tx('stolen')]),
      ];
      final withIncident = detect(later, state: s);
      expect(withIncident.created.single.txid, 'stolen');
      s = withIncident.applyTo(s);
      expect(detect(later, state: s).isEmpty, isTrue);
    });
  });
}
