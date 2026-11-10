import 'dart:async';
import 'dart:convert';

import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter/foundation.dart';

/// Wallet Health 상태를 SharedPreferences JSON 하나로 읽고 쓴다(HomeConfigurationRepository 패턴).
///
/// shared_preferences(와 안드로이드의 메모리 맵)는 기기 저장소의 답을 듣기 전에 새 값으로 바뀌고, 거절돼도 되돌아가지 않는다.
/// 그래서 디스크가 확인한 상태를 Dart 쪽에 따로 들고([_Memory]) 그것만 믿는다(M08):
/// - 쓰기는 앱 전체에서 한 줄로 차례대로 한다. 앞 쓰기의 결과(거절이면 되돌리기까지)가 끝나야 다음 쓰기가 상태를 읽는다
/// - 사용자가 결과를 기다리는 기록([updateConfirmed]): 거절되면 확인된 값을 다시 써서 캐시를 되돌리고 던진다.
///   화면은 실패를 알리고 그 자리에 남는다(저장 안 된 값이 저장된 것처럼 보이지 않게)
/// - 그 밖의 기록([update]: 감지 결과, 앱이 만든 txid, 대응 초안 묶음 등): 바로 메모리에 얹고 차례가 오면 저장한다. 거절돼도
///   메모리에 남겨 다음 쓰기 때 함께 저장한다. 버리면 위급을 숨기거나 내 거래를 모르는 출금으로 잘못 알린다.
///   앱이 꺼지거나 PIN 초기화로 키가 지워지면 사라지고, 그때는 디스크 값이 기준이다
class SafetyStore {
  static const key = SharedPrefKeys.kSafetyState;

  /// 앱 전체가 함께 쓰는 확인된 상태와 쓰기 줄(SafetyStore는 여럿이어도 디스크 키는 하나)
  static _Memory? _memory;

  /// 차례를 기다리는 마지막 쓰기(쉬고 있으면 null)
  static Future<void>? _tail;

  /// 사용자 동작이 저장을 기다리는 최대 시간. 넘으면 실패로 알리고, 아직 차례를 기다리던 요청은 쓰지 않는다
  static const userWait = Duration(seconds: 3);

  @visibleForTesting
  static void resetForTest() {
    _memory = null;
    _tail = null;
  }

  /// 차례를 기다리는 저장이 모두 끝날 때까지(테스트에서 디스크를 확인하기 전에)
  @visibleForTesting
  static Future<void> settledForTest() async {
    while (_tail != null) {
      await _tail;
      await Future<void>.delayed(Duration.zero);
    }
  }

  final SharedPrefsRepository _prefs;

  SafetyStore(this._prefs);

  /// 디스크가 확인한 상태 위에 아직 저장하지 못한 기록을 얹은 상태. 초기화 전(테스트 등)이면 초기 상태
  SafetyState load() {
    if (!_prefs.isInitialized) return SafetyState.initial();
    final memory = _current();
    return _withoutClosedDrafts(memory.pending.fold(memory.saved, (state, change) => change(state)));
  }

  /// 사용자가 기다리지 않는 기록: 메모리에 바로 얹고 저장은 차례대로 한다(기다리지 않는다). 느린 기기 저장이 감지·새 경고를
  /// 늦추지 않게. 기기가 거절하면 메모리에 남겨 두고 다음 쓰기 때 함께 저장한다.
  /// 남긴 [change]는 읽을 때마다 다시 적용하므로 두 번 적용해도 같은 결과여야 한다(지금 기록들은 모두 그렇다)
  Future<SafetyState> update(SafetyState Function(SafetyState) change) async {
    if (!_prefs.isInitialized) return change(SafetyState.initial());
    unawaited(_saveInOrder(change));
    return load();
  }

  /// [update]와 같지만 이 기록의 저장(거절 포함)이 끝날 때까지 기다린다
  Future<void> _saveInOrder(SafetyState Function(SafetyState) change) {
    final memory = _current()..pending.add(change);
    return _serial(() => _flush(memory));
  }

  /// 사용자가 결과를 기다리는 기록: 기기가 거절하거나 [userWait] 안에 답하지 않으면 메모리도 바꾸지 않고
  /// [SafetyStoreWriteException]을 던진다. 요청한 때의 상태를 잡아 두어, 기다리는 동안 PIN 초기화로 키가 지워졌으면
  /// 옛 요청을 새 상태에 쓰지 않는다. 이미 기기에 쓰던 중에 상한을 넘겼고 그 쓰기가 나중에 저장되면 [onLateSave]로 알린다
  /// (확인된 상태가 기준이므로 부른 쪽이 따라온다)
  Future<SafetyState> updateConfirmed(SafetyState Function(SafetyState) change, {void Function()? onLateSave}) async {
    if (!_prefs.isInitialized) return change(SafetyState.initial());
    final memory = _current();
    var expired = false;
    final run = _serial(() async {
      if (expired || !_isCurrent(memory)) throw const SafetyStoreWriteException();
      final applied = [...memory.pending];
      if (!await _write(memory, change(applied.fold(memory.saved, (state, c) => c(state))))) {
        throw const SafetyStoreWriteException();
      }
      memory.pending.removeWhere(applied.contains);
      if (expired) onLateSave?.call();
      return load();
    });
    return run.timeout(
      userWait,
      onTimeout: () {
        expired = true;
        throw const SafetyStoreWriteException();
      },
    );
  }

  Future<void> _flush(_Memory memory) async {
    if (!_isCurrent(memory) || memory.pending.isEmpty) return;
    final applied = [...memory.pending];
    if (await _write(memory, applied.fold(memory.saved, (state, change) => change(state)))) {
      memory.pending.removeWhere(applied.contains);
    }
  }

  /// 기기가 확인하면 확인된 상태로 삼고 true. 거절하거나 던지면 확인된 값을 다시 써서 캐시(안드로이드 메모리 맵 포함)를
  /// 되돌리고 false: 그대로 두면 다음 읽기나 다른 키의 저장이 거절된 값을 살려 낸다
  Future<bool> _write(_Memory memory, SafetyState next) async {
    final state = _withoutClosedDrafts(next);
    final raw = jsonEncode(state.toJson());
    memory.writing = raw;
    var saved = false;
    try {
      saved = await _prefs.setStringAndConfirm(key, raw);
    } catch (_) {}
    memory.writing = null;
    // 쓰는 동안 키가 지워졌으면(PIN 초기화 등) 옛 상태를 새 상태에 올리지도, 되살려 쓰지도 않는다
    if (!_isCurrent(memory)) return false;
    if (saved) {
      memory
        ..saved = state
        ..savedRaw = raw;
      return true;
    }
    final restore = memory.savedRaw;
    try {
      await (restore == null ? _prefs.removeAndConfirm(key) : _prefs.setStringAndConfirm(key, restore));
    } catch (_) {}
    return false;
  }

  /// 메모리가 지금 디스크 키와 같은 상태를 보고 있으면 그대로, 아니면(키를 지움·저장소를 다시 엶·우리가 쓰지 않은 값)
  /// 디스크 값으로 새로 읽는다. 그때 저장하지 못한 기록도 함께 버린다
  _Memory _current() {
    final version = _prefs.versionOf(key);
    final raw = _savedRawOrNull();
    final memory = _memory;
    if (memory != null && memory.version == version && (raw == memory.savedRaw || raw == memory.writing)) return memory;
    return _memory = _Memory(version: version, savedRaw: raw, saved: _parse(raw));
  }

  bool _isCurrent(_Memory memory) => identical(memory, _memory) && memory.version == _prefs.versionOf(key);

  String? _savedRawOrNull() {
    try {
      return _prefs.getStringOrNull(key);
    } catch (_) {
      return null; // 문자열이 아닌 값
    }
  }

  /// 저장값이 깨졌으면(다른 버전·JSON 아님) 초기 상태
  static SafetyState _parse(String? raw) {
    if (raw == null || raw.isEmpty) return SafetyState.initial();
    try {
      final json = jsonDecode(raw);
      return json is Map<String, Object?> ? SafetyState.fromJson(json) : SafetyState.initial();
    } catch (_) {
      return SafetyState.initial();
    }
  }

  static SafetyState _withoutClosedDrafts(SafetyState state) {
    if (state.draftResponseIncidents.isEmpty) return state;
    final openIncidents = state.incidents.where((i) => i.isOpen).map((i) => i.id).toSet();
    return state.copyWith(
      draftResponseIncidents: {
        for (final entry in state.draftResponseIncidents.entries)
          if (openIncidents.contains(entry.value)) entry.key: entry.value,
      },
    );
  }

  /// 앞 쓰기가 끝난 뒤에 [task]를 돌린다. 쉬고 있으면 바로 시작한다(실패해도 줄은 이어진다)
  static Future<T> _serial<T>(Future<T> Function() task) {
    final previous = _tail;
    final run = previous == null ? task() : previous.then((_) => task());
    final tail = _tail = run.then<void>((_) {}, onError: (Object _) {});
    tail.whenComplete(() {
      if (identical(_tail, tail)) _tail = null;
    });
    return run;
  }

  // 아래 기록 메서드는 async + await로 감싸 실제 Future<void>를 돌려준다. update()의 Future<SafetyState>를 그대로 넘기면
  // 호출부의 `.catchError((_) {})`가 디스크 쓰기 실패 때 ArgumentError로 터져, 전송 전 기록이 fail-closed가 된다.

  /// 앱이 만든 txid를 모든 지갑 공용 집합에 앞 20자리로 남긴다(다시 기록하면 맨 뒤로). 버리지 않는다(PIN 초기화 때만 지워짐).
  /// [walletId]는 호출부 호환용
  /// 전송 전 기록은 디스크 저장을 기다린다(부르는 쪽이 기다림에 상한을 둔다). 저장이 안 돼도 메모리에는 먼저 들어간다
  Future<void> recordAppCreatedTxid(int walletId, String txid) async {
    if (!_prefs.isInitialized) return;
    final prefix = SafetyState.txidPrefix(txid);
    await _saveInOrder((s) => s.copyWith(appTxidPrefixes: {...s.appTxidPrefixes.where((p) => p != prefix), prefix}));
  }

  Future<void> recordResponseDraft(int walletId, String txid, {required String incidentId}) async {
    await update((s) {
      if (!s.incidents.any((i) => i.id == incidentId && i.walletId == walletId && i.isOpen)) return s;
      return s.copyWith(draftResponseIncidents: {...s.draftResponseIncidents, txid: incidentId});
    });
  }

  Future<void> recordBroadcastSucceeded(
    int walletId,
    String txid, {
    String? incidentId,
    Set<String> replacedTxids = const {},
  }) async {
    // 저장이 안 되면 기록을 메모리에 남겨 다시 적용하므로 시각은 한 번만 잡는다
    final at = DateTime.now();
    await update((s) {
      final responseIncidentId = incidentId ?? s.draftResponseIncidents[txid];
      return s.copyWith(
        lastBroadcast: (walletId: walletId, txid: txid, at: at),
        draftResponseIncidents: {...s.draftResponseIncidents}..remove(txid),
        incidents: [
          for (final incident in s.incidents)
            if (incident.walletId == walletId &&
                ((incident.id == responseIncidentId && (incidentId != null || incident.isOpen)) ||
                    (incident.responseTxid != null && replacedTxids.contains(incident.responseTxid))))
              incident.withResponseTxid(txid)
            else
              incident,
        ],
      );
    });
  }

  Future<void> recordMetadataExport({required int tagCount, required int memoCount}) async {
    final at = DateTime.now();
    await update((s) => s.copyWith(metadataExport: (at: at, tagCount: tagCount, memoCount: memoCount)));
  }

  Future<void> removeWallet(int walletId) async {
    await update((s) => s.withoutWallet(walletId));
  }
}

/// 기기 저장소가 Wallet Health 기록을 거절했다(저장 공간 가득 등). 사라진 항목(StateError)과 섞이지 않게 따로 둔다
class SafetyStoreWriteException implements Exception {
  const SafetyStoreWriteException();

  @override
  String toString() => 'SafetyStoreWriteException';
}

/// 디스크가 확인한 Wallet Health 상태(Dart 쪽 원본)와 아직 저장하지 못한 기다리지 않는 기록
class _Memory {
  _Memory({required this.version, required this.savedRaw, required this.saved});

  /// 이 메모리를 읽어 온 때의 키 버전(키를 지우거나 저장소를 다시 열면 바뀐다)
  final int version;

  /// 디스크에 확인된 값(없으면 null)과 그 상태
  String? savedRaw;
  SafetyState saved;

  /// 지금 기기에 쓰고 있는 값(그동안 캐시는 이 값을 들고 있다)
  String? writing;

  final pending = <SafetyState Function(SafetyState)>[];
}
