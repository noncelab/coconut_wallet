import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';

/// Wallet Health 상태를 SharedPreferences JSON 하나로 읽고 쓴다(HomeConfigurationRepository 패턴).
class SafetyStore {
  static const key = SharedPrefKeys.kSafetyState;

  final SharedPrefsRepository _prefs;

  SafetyStore(this._prefs);

  /// 초기화 전(테스트 등)이거나 저장값이 깨졌으면(문자열이 아닌 값 포함) 초기 상태
  SafetyState load() {
    if (!_prefs.isInitialized) return SafetyState.initial();
    try {
      final raw = _prefs.getStringOrNull(key);
      if (raw == null || raw.isEmpty) return SafetyState.initial();
      final json = jsonDecode(raw);
      return json is Map<String, Object?> ? SafetyState.fromJson(json) : SafetyState.initial();
    } catch (_) {
      return SafetyState.initial();
    }
  }

  /// 읽기·바꾸기·캐시 쓰기가 await 없이 이어져 동시에 부른 update끼리 서로 덮어쓰지 않는다.
  Future<SafetyState> update(SafetyState Function(SafetyState) change) async {
    final next = change(load());
    if (_prefs.isInitialized) await _prefs.setString(key, jsonEncode(next.toJson()));
    return next;
  }

  // 아래 기록 메서드는 async + await로 감싸 실제 Future<void>를 돌려준다. update()의 Future<SafetyState>를 그대로 넘기면
  // 호출부의 `.catchError((_) {})`가 디스크 쓰기 실패 때 ArgumentError로 터져, 전송 전 기록이 fail-closed가 된다.

  /// 앱이 만든 txid를 모든 지갑 공용 집합에 앞 20자리로 남긴다(다시 기록하면 맨 뒤로). 버리지 않는다(PIN 초기화 때만 지워짐).
  /// [walletId]는 호출부 호환용
  Future<void> recordAppCreatedTxid(int walletId, String txid) async {
    final prefix = SafetyState.txidPrefix(txid);
    await update((s) => s.copyWith(appTxidPrefixes: {...s.appTxidPrefixes.where((p) => p != prefix), prefix}));
  }

  Future<void> recordBroadcastSucceeded(int walletId, String txid) async {
    await update((s) => s.copyWith(lastBroadcast: (walletId: walletId, txid: txid, at: DateTime.now())));
  }

  Future<void> recordMetadataExport({required int tagCount, required int memoCount}) async {
    await update((s) => s.copyWith(metadataExport: (at: DateTime.now(), tagCount: tagCount, memoCount: memoCount)));
  }

  Future<void> removeWallet(int walletId) async {
    await update((s) => s.withoutWallet(walletId));
  }
}
