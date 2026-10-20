import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/repository/shared_preference/safety_store.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPrefsRepository prefs;
  late SafetyStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    // ignore: deprecated_member_use_from_same_package
    prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    store = SafetyStore(prefs);
  });

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

  test(
    'a failed disk write rejects, and `.catchError((_) {})` at the call site completes normally (fail open)',
    () async {
      final failing = SafetyStore(_FailingPrefs());
      await failing.recordAppCreatedTxid(1, 'a').catchError((_) {});
      await failing.recordBroadcastSucceeded(1, 'a').catchError((_) {});
      await failing.recordMetadataExport(tagCount: 1, memoCount: 1).catchError((_) {});
      await failing.removeWallet(1).catchError((_) {});
      await expectLater(failing.recordAppCreatedTxid(1, 'a'), throwsA(isA<StateError>()));
    },
  );

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
  Future setString(String key, String value) async => throw StateError('disk full');

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError('unexpected call');
}
