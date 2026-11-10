import 'dart:async';
import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/repository/shared_preference/safety_store.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/safety/safety_fakes.dart';

void main() {
  late SharedPrefsRepository prefs;
  late SafetyStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // ignore: deprecated_member_use_from_same_package
    prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    store = SafetyStore(prefs);
  });
  tearDown(SafetyStore.resetForTest);

  test('uses the lead-owned key, which is reset when the PIN is forgotten', () {
    expect(SafetyStore.key, 'SAFETY_STATE_V1');
    expect(SharedPrefKeys.keysToReset, contains(SafetyStore.key));
  });

  test('nothing saved → initial', () {
    expect(store.load(), SafetyState.initial());
  });

  test('update persists and loads back equal', () async {
    final incident = SafetyIncident(walletId: 1, txid: 'x', detectedAt: DateTime(2026, 10, 20));
    final saved = await store.update((s) => s.copyWith(incidents: [incident], cautionWalletIds: {1}));
    expect(saved.incidents, [incident]);
    expect(SafetyStore(prefs).load(), saved);
  });

  test('broken JSON, non-object JSON and other versions → initial', () async {
    for (final raw in ['{not json', '[1, 2]', '"text"', '{"version": 2}', '{"version": 1, "incidents": "x"}']) {
      await prefs.setString(SafetyStore.key, raw);
      expect(store.load(), SafetyState.initial(), reason: raw);
    }
  });

  test('a value of the wrong native type under the key → initial', () async {
    SharedPreferences.setMockInitialValues({SafetyStore.key: 123});
    // ignore: deprecated_member_use_from_same_package
    final wrongType = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    expect(SafetyStore(wrongType).load(), SafetyState.initial());
  });

  test('records app-created txids once, globally, as 20-char prefixes, newest last, with no eviction', () async {
    final txid = 'Ab' * 32;
    await store.recordAppCreatedTxid(1, txid);
    for (var i = 0; i < 1500; i++) {
      await store.recordAppCreatedTxid(i.isEven ? 1 : 2, 'tx$i');
    }
    // 서명용 PSBT 고정 + 전송 직전처럼 같은 txid를 다시 기록하면 하나로, 맨 뒤로
    await store.recordAppCreatedTxid(2, txid);
    final s = store.load();
    expect(s.appTxidPrefixes.length, 1501);
    expect(s.appTxidPrefixes.last, 'ab' * 10);
    expect(s.appTxidPrefixes.first, 'tx0');
    expect(s.isAppCreated(txid.toLowerCase()), isTrue);
  });

  test('records the last successful broadcast and the metadata export', () async {
    await store.recordBroadcastSucceeded(3, 'sent');
    await store.recordMetadataExport(tagCount: 4, memoCount: 7);
    final s = store.load();
    expect((s.lastBroadcast!.walletId, s.lastBroadcast!.txid), (3, 'sent'));
    expect((s.metadataExport!.tagCount, s.metadataExport!.memoCount), (4, 7));
  });

  test('an incident response survives later broadcasts and a restarted Assist after reloading the store', () async {
    final incident = SafetyIncident(
      walletId: 1,
      txid: 'incident',
      detectedAt: DateTime(2026),
    ).respond(IncidentResponseMode.premium).withGuideStep(2, assistStartedAt: DateTime(2026, 1, 1));
    await store.update((s) => s.copyWith(incidents: [incident]));
    await store.recordBroadcastSucceeded(1, 'response', incidentId: incident.id);
    await store.recordBroadcastSucceeded(1, 'unrelated-same-wallet');
    await store.recordBroadcastSucceeded(2, 'unrelated-other-wallet');
    await store.update(
      (s) => s.copyWith(incidents: [s.incidents.single.withGuideStep(2, assistStartedAt: DateTime(2026, 1, 2))]),
    );
    final restored = SafetyStore(prefs).load();
    expect(restored.lastBroadcast!.txid, 'unrelated-other-wallet');
    expect(restored.incidents.single.responseTxid, 'response');
    expect(restored.incidents.single.guideStep, 2);
    expect(restored.incidents.single.state, IncidentState.responding);
  });

  group('M02 response map', () {
    final at = DateTime(2026);
    final incident = SafetyIncident(
      walletId: 1,
      txid: 'incident',
      detectedAt: at,
    ).respond(IncidentResponseMode.premium);
    final other = SafetyIncident(walletId: 2, txid: 'other', detectedAt: at);
    final txid = 'a' * 64;
    final links = {txid: incident.id, 'other-draft': other.id};

    Future<void> seed({List<SafetyIncident>? incidents}) => prefs.setString(
      SafetyStore.key,
      jsonEncode({
        ...SafetyState(incidents: incidents ?? [incident, other]).toJson(),
        'draftResponseIncidents': links,
      }),
    );

    test('only the full successful txid consumes its persisted incident link', () async {
      await seed();
      final reloaded = SafetyStore(prefs);
      await reloaded.recordBroadcastSucceeded(1, '${'a' * 63}b');
      expect(reloaded.load().incidents.every((i) => i.responseTxid == null), isTrue);
      expect(reloaded.load().toJson()['draftResponseIncidents'], links);
      await reloaded.recordBroadcastSucceeded(1, txid);
      expect(reloaded.load().incidents.first.responseTxid, txid);
      expect(reloaded.load().incidents.last.responseTxid, isNull);
      expect(reloaded.load().toJson()['draftResponseIncidents'], {'other-draft': other.id});
    });

    for (final invalid in ['wrong-wallet', 'missing', 'resolved']) {
      test('$invalid link cannot create a response association', () async {
        await seed(
          incidents: [if (invalid != 'missing') invalid == 'resolved' ? incident.recognize(at) : incident, other],
        );
        await store.recordBroadcastSucceeded(invalid == 'wrong-wallet' ? 2 : 1, txid);
        expect(store.load().incidents.every((i) => i.responseTxid == null), isTrue);
        expect(store.load().toJson()['draftResponseIncidents'], {'other-draft': other.id});
      });
    }

    for (final change in ['recognized', 'completed', 'deleted', 'wallet deleted']) {
      test('$change cleans only that incident or wallet links', () async {
        await seed();
        if (change == 'wallet deleted') {
          await store.removeWallet(1);
        } else {
          await store.update(
            (s) => s.copyWith(
              incidents: [
                if (change == 'recognized') incident.recognize(at),
                if (change == 'completed') incident.complete(at),
                other,
              ],
            ),
          );
        }
        expect(SafetyStore(prefs).load().toJson()['draftResponseIncidents'], {'other-draft': other.id});
      });
    }
  });

  test('removeWallet clears that wallet', () async {
    await store.recordAppCreatedTxid(1, 'a');
    await store.recordAppCreatedTxid(2, 'b');
    await store.update((s) => s.copyWith(cautionWalletIds: {1, 2}));
    await store.removeWallet(1);
    final s = store.load();
    // 앱 생성 기록은 지갑을 지워도 남는다(같은 디스크립터의 다른 지갑 보호)
    expect(s.isAppCreated('a'), isTrue);
    expect(s.cautionWalletIds, {2});
  });

  test('updates started together do not lose each other', () async {
    await Future.wait([
      store.recordAppCreatedTxid(1, 'a'),
      store.recordAppCreatedTxid(1, 'b'),
      store.update((s) => s.copyWith(hintDismissed: true)),
    ]);
    final s = SafetyStore(prefs).load();
    expect(s.appTxidPrefixes, {'a', 'b'});
    expect(s.hintDismissed, isTrue);
  });

  test('a failed disk write keeps the record in memory and the call completes normally (fail open)', () async {
    final failing = SafetyStore(_FailingPrefs());
    await failing.recordAppCreatedTxid(1, 'a').catchError((_) {});
    await failing.recordBroadcastSucceeded(1, 'a').catchError((_) {});
    await failing.recordMetadataExport(tagCount: 1, memoCount: 1).catchError((_) {});
    await failing.removeWallet(2).catchError((_) {});
    await expectLater(failing.recordAppCreatedTxid(1, 'b'), completes);
    // 내 거래를 모르는 출금으로 알리지 않게 메모리에는 남는다(M08: 다음에 저장이 되면 함께 쓴다)
    final kept = failing.load();
    expect(kept.isAppCreated('a') && kept.isAppCreated('b'), isTrue);
    expect(kept.lastBroadcast?.txid, 'a');
    expect(kept.metadataExport?.tagCount, 1);
  });

  // M08: 기기가 쓰기를 거절할 때(안드로이드 commit()이 false, 저장 공간 가득 등). 진짜 길:
  // SafetyStore → SharedPrefsRepository → shared_preferences → 기기 저장소
  group('when the device rejects the write (M08)', () {
    late SafetyDiskFake disk;
    late SafetyStore real;
    setUp(() async {
      disk = SafetyDiskFake();
      real = await disk.open();
    });

    test('a user action throws and changes neither memory nor disk', () async {
      disk.accept = false;
      await expectLater(
        real.updateConfirmed((s) => s.copyWith(cautionWalletIds: {1})),
        throwsA(isA<SafetyStoreWriteException>()),
      );
      expect(real.load().cautionWalletIds, isEmpty);
      expect(disk.durable.cautionWalletIds, isEmpty);
      disk.accept = true;
      await real.updateConfirmed((s) => s.copyWith(cautionWalletIds: {1}));
      expect(disk.durable.cautionWalletIds, {1});
    });

    test('a background record stays in memory and is saved with the next accepted write', () async {
      disk.accept = false;
      await real.recordAppCreatedTxid(1, 'a');
      expect(real.load().isAppCreated('a'), isTrue);
      expect(disk.durable.isAppCreated('a'), isFalse);
      disk.accept = true;
      await real.update((s) => s.copyWith(hintDismissed: true));
      await SafetyStore.settledForTest();
      expect(disk.durable.isAppCreated('a'), isTrue);
      expect(disk.durable.hintDismissed, isTrue);
      expect((await disk.open()).load().isAppCreated('a'), isTrue); // 다시 켜도 남는다
    });

    test('a rejected user action keeps the unsaved app-created txid and M02 draft link', () async {
      final incident = SafetyIncident(walletId: 1, txid: 'theft', detectedAt: DateTime(2026, 10, 20));
      await real.update((s) => s.copyWith(incidents: [incident]));
      disk.accept = false;
      await real.recordAppCreatedTxid(1, 'rescue');
      await real.recordResponseDraft(1, 'rescue', incidentId: incident.id);
      await expectLater(
        real.updateConfirmed((s) => s.copyWith(cautionWalletIds: {1})),
        throwsA(isA<SafetyStoreWriteException>()),
      );
      // 대응 이동이 내 거래로 남아 모르는 출금으로 알리지 않고, 사건과의 연결도 남는다
      final kept = real.load();
      expect(kept.isAppCreated('rescue'), isTrue);
      expect(kept.draftResponseIncidents, {'rescue': incident.id});
      expect(kept.cautionWalletIds, isEmpty);
    });

    // Codex M08-B1: 안드로이드는 거절된 값을 메모리 맵에 그대로 둔다(다시 읽으면 그 값이 나온다). 플랫폼 캐시를 믿지 않는다
    test('a rejected value does not come back through the platform cache', () async {
      disk.nativeCache = true;
      await real.updateConfirmed((s) => s.copyWith(cautionWalletIds: {1}));
      disk.accept = false;
      await expectLater(
        real.updateConfirmed((s) => s.copyWith(cautionWalletIds: {})),
        throwsA(isA<SafetyStoreWriteException>()),
      );
      expect(disk.durable.cautionWalletIds, {1});
      expect(real.load().cautionWalletIds, {1});
      // 플랫폼 메모리 맵도 확인된 값으로 돌아가 있다(다른 키의 저장이 거절된 값을 디스크에 쓰지 않게)
      expect((await disk.open()).load().cautionWalletIds, {1});
    });

    // Codex M08-B2: 거절된 사용자 변경 바로 뒤의 백그라운드 쓰기가 그 변경을 싣고 저장하면 안 된다
    test('a rejected user action is not carried to disk by the background write right after it', () async {
      await real.updateConfirmed((s) => s.copyWith(cautionWalletIds: {1}));
      disk.outcomes.addAll([false, true]);
      Object? rejection;
      final user = real
          .updateConfirmed((s) => s.copyWith(cautionWalletIds: {}))
          .then<Object?>((_) => null, onError: (Object e) => rejection = e);
      final background = real.recordMetadataExport(tagCount: 1, memoCount: 0);
      await Future.wait([user, background]);
      await SafetyStore.settledForTest();
      expect(rejection, isA<SafetyStoreWriteException>());
      expect(disk.durable.cautionWalletIds, {1});
      expect(disk.durable.metadataExport?.tagCount, 1);
      expect(real.load().cautionWalletIds, {1});
    });

    // Codex M08-B3: PIN 초기화로 키를 지우면 저장하지 못한 옛 기록도 함께 사라진다(새로 읽거나 다음에 저장해도 되살아나지 않는다)
    test('a PIN reset also drops unsaved background records', () async {
      disk.accept = false;
      final incident = SafetyIncident(walletId: 1, txid: 'old-incident', detectedAt: DateTime(2026));
      await real.update((s) => s.copyWith(incidents: [incident]));
      await real.recordAppCreatedTxid(1, 'old-app-transaction');
      expect(real.load().incidents, hasLength(1));
      disk.accept = true;
      await SharedPrefsRepository().deleteMultipleKeys(SharedPrefKeys.keysToReset);
      final fresh = SafetyStore(SharedPrefsRepository());
      expect(fresh.load().incidents, isEmpty);
      expect(fresh.load().isAppCreated('old-app-transaction'), isFalse);
      await fresh.update((s) => s.copyWith(hintDismissed: true));
      await SafetyStore.settledForTest();
      expect(disk.durable.hintDismissed, isTrue);
      expect(disk.durable.incidents, isEmpty);
      expect(disk.durable.isAppCreated('old-app-transaction'), isFalse);
    });

    // Codex M08-B3 잔여: PIN 초기화 전에 차례를 기다리던 사용자 저장은 초기화 뒤에 쓰지 않는다(지운 표시를 되살리지 않는다)
    test('a user action queued before a PIN reset is not written after it', () async {
      final reply = Completer<void>();
      disk.hold = reply.future; // 앞 쓰기: 디스크에는 쓰고 답만 늦다
      unawaited(real.recordMetadataExport(tagCount: 1, memoCount: 0));
      Object? failure;
      final user = real
          .updateConfirmed((s) => s.copyWith(cautionWalletIds: {1}))
          .then<Object?>((_) => null, onError: (Object e) => failure = e);
      disk.hold = null;
      await SharedPrefsRepository().deleteMultipleKeys(SharedPrefKeys.keysToReset);
      reply.complete();
      await user;
      expect(failure, isA<SafetyStoreWriteException>());
      expect(disk.durable.cautionWalletIds, isEmpty);
      expect(SafetyStore(SharedPrefsRepository()).load().cautionWalletIds, isEmpty);
    });
  });

  test('before SharedPreferences is initialized: initial state, no throw, nothing written', () async {
    final uninitialized = SafetyStore(_UninitializedPrefs());
    expect(uninitialized.load(), SafetyState.initial());
    await uninitialized.recordAppCreatedTxid(1, 'a');
    expect(store.load(), SafetyState.initial());
  });
}

class _UninitializedPrefs implements SharedPrefsRepository {
  @override
  bool get isInitialized => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('prefs not initialized');
}

/// 읽기는 되지만 쓰기가 실패하는 저장소(디스크 가득 참 등)
class _FailingPrefs implements SharedPrefsRepository {
  @override
  bool get isInitialized => true;

  @override
  String? getStringOrNull(String key) => null;

  @override
  Future<bool> setStringAndConfirm(String key, String value) async => throw StateError('disk full');

  @override
  int versionOf(String key) => 0;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('unexpected call');
}
