import 'dart:math' as math;

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_inputs.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';

/// 감지 한 번의 결과. 비어 있지 않으면 `SafetyStore.update(delta.applyTo)`로 최신 상태에 적용한다.
class IncidentDelta {
  const IncidentDelta({
    this.baselines = const {},
    this.created = const [],
    this.txStates = const {},
    this.incomingWatch = const {},
    this.conflicts = const [],
    this.resolvedConflicts = const {},
  });

  /// 새로 만든 기준점(지갑당 1회), 또는 자기 앞 전송 검토 목록을 더한 기준점. 적용하면 덮어쓴다(감지는 한 번에 하나씩, SafetyProvider)
  final Map<int, WalletBaseline> baselines;
  final List<SafetyIncident> created;

  /// 사건 id → 바뀐 거래 상태
  final Map<String, IncidentTxState> txStates;

  /// 감시 목록이 바뀐 지갑의 새 목록 전체(빈 맵 = 감시 끝)
  final Map<int, Map<String, IncomingWatchEntry>> incomingWatch;

  /// 새로 판정한 받은 거래 충돌
  final List<WalletTxEvent> conflicts;

  /// 원래 받은 거래가 돌아와 확정돼서 풀린 충돌
  final Set<({int walletId, String txid})> resolvedConflicts;

  // ponytail: 충돌 기록은 최근 100건만(점수는 7일치만 씀). 기록 화면이 생기면 기간으로 자르기
  static const maxConflicts = 100;

  bool get isEmpty =>
      baselines.isEmpty &&
      created.isEmpty &&
      txStates.isEmpty &&
      incomingWatch.isEmpty &&
      conflicts.isEmpty &&
      resolvedConflicts.isEmpty;

  SafetyState applyTo(SafetyState s) {
    final known = {for (final i in s.incidents) i.id};
    final seen = {for (final c in s.conflicts) '${c.walletId}:${c.txid}'};
    final allConflicts = [
      for (final c in s.conflicts)
        if (!resolvedConflicts.contains((walletId: c.walletId, txid: c.txid))) c,
      for (final c in conflicts)
        if (!seen.contains('${c.walletId}:${c.txid}')) c,
    ];
    return s.copyWith(
      baselines: {...s.baselines, ...baselines},
      incidents: [
        for (final i in s.incidents) txStates.containsKey(i.id) ? i.withTxState(txStates[i.id]!) : i,
        // 감지와 적용 사이에 인지했거나 앱이 기록한 거래는 사건으로 만들지 않는다
        for (final i in created)
          if (!known.contains(i.id) && !s.recognizedTxids.contains(i.txid) && !s.isAppCreated(i.txid)) i,
      ],
      incomingWatch: {...s.incomingWatch, ...incomingWatch}..removeWhere((_, watch) => watch.isEmpty),
      conflicts:
          allConflicts.length > maxConflicts ? allConflicts.sublist(allConflicts.length - maxConflicts) : allConflicts,
    );
  }
}

/// 모르는 출금(사건)·받은 거래 충돌 감지. 순수 함수이며 동기화가 끝난 실행마다 저장된 거래 전부를 다시 본다.
/// 옛 거래는 기준점 때 있던 txid로만 거르고, 앱 생성 여부는 모든 지갑 공용 txid 앞부분 집합으로 본다(높이·시각 기준 없음).
abstract final class IncidentDetector {
  /// 기준점이 txid로 기억하는 거래 수 상한
  // ponytail: 거래가 2만 개를 넘는 지갑은 최신 2만 개만 txid로 기억하고, 나머지(옛 확정)는 그 높이 이하를 옛 거래로 본다.
  // 그런 지갑에서만 그 높이 이하로 적힌 새 출금(서버가 꾸민 높이·깊은 리오그)을 놓칠 수 있다
  static const maxKnownTxids = 20000;

  /// 기준점 때 이 기간 안에 확정된 출금도 검토 항목으로 남긴다(지갑을 다시 넣기 직전에 확정된 도난, 레드팀 §2)
  static const recentOutgoingWindow = Duration(days: 7);
  static const strikeInterval = Duration(minutes: 10);
  static const conflictStrikes = 2;

  static IncidentDelta detect(SafetyInputs inputs) {
    final state = inputs.state;
    final known = {for (final i in state.incidents) i.id};
    final heightKnown = inputs.currentBlockHeight > 0;
    final baselines = <int, WalletBaseline>{};
    final created = <SafetyIncident>[];
    final txStates = <String, IncidentTxState>{};
    final incomingWatch = <int, Map<String, IncomingWatchEntry>>{};
    final conflicts = <WalletTxEvent>[];
    final resolvedConflicts = <({int walletId, String txid})>{};

    for (final w in inputs.wallets) {
      final txById = {for (final tx in w.txs) tx.txid: tx};
      final baseline = state.baselines[w.id];
      if (baseline == null) {
        // 높이 0(첫 블록 조회 전)이나 동기화 중엔 기준점을 만들지 않는다(ARCH F5). 만든 실행에선 판정하지 않는다
        if (w.isSettled && heightKnown) baselines[w.id] = _baseline(w, inputs.currentBlockHeight, inputs.now);
      } else if (w.isSettled) {
        final unexpectedSelf = <String>{};
        for (final tx in w.txs) {
          if (baseline.knows(tx.txid, tx.blockHeight) ||
              state.isAppCreated(tx.txid) ||
              state.recognizedTxids.contains(tx.txid)) {
            continue;
          }
          if (_isOutgoing(tx, w)) {
            if (known.contains('${w.id}:${tx.txid}')) continue;
            created.add(
              SafetyIncident(
                walletId: w.id,
                txid: tx.txid,
                detectedAt: inputs.now,
                txState: tx.blockHeight == 0 ? IncidentTxState.pending : IncidentTxState.confirmed,
              ),
            );
          } else if (tx.type == TransactionType.self && !baseline.unexpectedSelfTxids.contains(tx.txid)) {
            // 앱이 만들지 않은 자기 앞 전송: 지갑 안에서 옮기거나 수수료로 태우는 경우(레드팀 §7) → 검토 항목
            unexpectedSelf.add(tx.txid);
          }
        }
        if (unexpectedSelf.isNotEmpty) {
          baselines[w.id] = baseline.copyWith(
            unexpectedSelfTxids: {...baseline.unexpectedSelfTxids, ...unexpectedSelf},
          );
        }
      }

      for (final incident in state.incidents) {
        if (incident.walletId != w.id || !incident.isOpen) continue;
        final txState = _txState(incident, w, txById[incident.txid]);
        if (txState != incident.txState) txStates[incident.id] = txState;
      }

      if (w.isSettled) {
        final watch = _watchIncoming(w, state.incomingWatch[w.id] ?? const {}, txById, inputs.now, conflicts);
        if (watch != null) incomingWatch[w.id] = watch;
        // 충돌로 본 받은 거래가 돌아와 확정됐으면 결국 받은 것이다
        for (final c in state.conflicts) {
          if (c.walletId == w.id && (txById[c.txid]?.blockHeight ?? 0) > 0) {
            resolvedConflicts.add((walletId: w.id, txid: c.txid));
          }
        }
      }
    }

    return IncidentDelta(
      baselines: baselines,
      created: created,
      txStates: txStates,
      incomingWatch: incomingWatch,
      conflicts: conflicts,
      resolvedConflicts: resolvedConflicts,
    );
  }

  /// 출금 = sent, 또는 received로 잘못 분류됐지만 내 UTXO를 쓰는 대기 거래(ARCH R4). self는 출금이 아니다
  static bool _isOutgoing(SafetyTx tx, SafetyWalletSnapshot w) =>
      tx.type == TransactionType.sent ||
      (tx.type == TransactionType.received && w.pendingSpentByTxids.contains(tx.txid));

  static WalletBaseline _baseline(SafetyWalletSnapshot w, int height, DateTime now) {
    final known = _known(w);
    final recentSince = now.subtract(recentOutgoingWindow);
    final listed = {for (final tx in w.txs) tx.txid};
    return WalletBaseline(
      height: height,
      at: now,
      knownTxids: known.txids,
      knownBelowHeight: known.belowHeight,
      pendingSentAtBaseline: {
        for (final tx in w.txs)
          if (_isOutgoing(tx, w) && (tx.blockHeight == 0 || tx.timestamp.isAfter(recentSince))) tx.txid,
        for (final txid in w.pendingSpentByTxids)
          if (!listed.contains(txid)) txid,
      },
    );
  }

  /// 지금 있는 거래(최신 2만 개)와 대기 지출의 txid 앞부분. 넘친 옛 확정 거래는 그 최고 높이로만 기억한다
  static ({Set<String> txids, int? belowHeight}) _known(SafetyWalletSnapshot w) {
    int recency(SafetyTx tx) => tx.blockHeight == 0 ? 0x7fffffff : tx.blockHeight;
    final byRecency = [...w.txs]..sort((a, b) => recency(b).compareTo(recency(a)));
    final overflow = byRecency.skip(maxKnownTxids);
    return (
      txids: {
        for (final tx in byRecency.take(maxKnownTxids)) SafetyState.txidPrefix(tx.txid),
        for (final txid in w.pendingSpentByTxids) SafetyState.txidPrefix(txid),
      },
      belowHeight: overflow.isEmpty ? null : overflow.map((tx) => tx.blockHeight).reduce(math.max),
    );
  }

  /// 목록에 있으면 대기/확정, 없으면 수집기가 본 대체/드롭(정보 상태). 동기화 중엔 사라짐을 판단하지 않는다.
  static IncidentTxState _txState(SafetyIncident incident, SafetyWalletSnapshot w, SafetyTx? tx) {
    if (tx != null) return tx.blockHeight == 0 ? IncidentTxState.pending : IncidentTxState.confirmed;
    if (!w.isSettled) return incident.txState;
    return w.trackedTxStates[incident.txid] ?? incident.txState;
  }

  /// 대기 중인 받은 거래를 감시하다 DB에서 사라지면 10분 이상 간격으로 두 번 확인한 뒤 충돌로 본다. 바뀐 게 없으면 null.
  /// 남이 대체한 받은 거래는 DB에서 지워져서(ARCH F7) 목록 비교로만 알 수 있다.
  static Map<String, IncomingWatchEntry>? _watchIncoming(
    SafetyWalletSnapshot w,
    Map<String, IncomingWatchEntry> watch,
    Map<String, SafetyTx> txById,
    DateTime now,
    List<WalletTxEvent> conflicts,
  ) {
    final next = <String, IncomingWatchEntry>{};
    var changed = false;
    for (final MapEntry(key: txid, value: entry) in watch.entries) {
      // 내 UTXO를 쓰는 거래는 받은 거래가 아니다(R4 오분류) → 감시 끝
      if (w.pendingSpentByTxids.contains(txid)) {
        changed = true;
        continue;
      }
      final tx = txById[txid];
      if (tx != null) {
        if (tx.blockHeight > 0) {
          changed = true; // 확정 → 감시 끝
        } else if (entry.strikes > 0) {
          // 다시 보이면 앞선 사라짐은 일시적이었다
          next[txid] = (seenAt: entry.seenAt, strikes: 0, lastStrikeAt: null, paidAddresses: entry.paidAddresses);
          changed = true;
        } else {
          next[txid] = entry;
        }
        continue;
      }
      // 재동기화로 DB를 다시 만들었으면 사라졌는지 판단할 수 없다
      final resynced = w.lastResyncAt?.isAfter(entry.seenAt) ?? false;
      // 감시 시작 뒤 생긴 거래가 같은 내 주소로 다시 지급했으면 보낸 사람이 수수료를 올린 것
      final bumped = w.txs.any(
        (t) => t.createdAt.isAfter(entry.seenAt) && t.ownReceiveOutputs.any(entry.paidAddresses.contains),
      );
      if (resynced || bumped) {
        changed = true;
        continue;
      }
      final lastStrikeAt = entry.lastStrikeAt;
      if (lastStrikeAt != null && now.difference(lastStrikeAt) < strikeInterval) {
        next[txid] = entry;
        continue;
      }
      changed = true;
      final strikes = entry.strikes + 1;
      if (strikes >= conflictStrikes) {
        conflicts.add((walletId: w.id, txid: txid, at: now));
      } else {
        next[txid] = (seenAt: entry.seenAt, strikes: strikes, lastStrikeAt: now, paidAddresses: entry.paidAddresses);
      }
    }
    for (final tx in w.txs) {
      if (tx.type != TransactionType.received ||
          tx.blockHeight != 0 ||
          watch.containsKey(tx.txid) ||
          w.pendingSpentByTxids.contains(tx.txid)) {
        continue;
      }
      next[tx.txid] = (seenAt: now, strikes: 0, lastStrikeAt: null, paidAddresses: tx.ownReceiveOutputs);
      changed = true;
    }
    return changed ? next : null;
  }
}
