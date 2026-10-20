import 'dart:math' as math;

import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_inputs.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';

/// Wallet Health 점수·점검 판정. 순수 함수이며 표시 문구 대신 enum만 돌려준다(SPEC §7, ARCH §2.6).
/// Premium 여부는 입력에 없다(점수 불변).
abstract final class SafetyEngine {
  static const unfundedWalletWeight = 0.5;
  static const unfundedWeightCap = 0.25;
  static const conflictWindow = Duration(days: 7);
  static const certExpiringWindow = Duration(days: 30);

  static WalletHealthReport evaluate(SafetyInputs inputs) {
    final wallets = inputs.wallets;
    final state = inputs.state;
    final walletIds = {for (final w in wallets) w.id};
    final results = <SafetyCheckResult>[];
    final recommended = <RecommendedItem>[];

    final incidents = [
      for (final i in state.incidents)
        if (walletIds.contains(i.walletId)) i,
    ];
    final criticalIncidents =
        incidents.where((i) => i.isCritical).toList()..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));
    final infoIncidents =
        incidents.where((i) => i.isInfo).toList()..sort((a, b) => b.detectedAt.compareTo(a.detectedAt));

    bool funded(SafetyWalletSnapshot w) => w.balanceSats > 0;
    bool used(SafetyWalletSnapshot w) => funded(w) || w.txs.isNotEmpty;

    // App = 잠금 80 + 업데이트 20(조회 실패면 잠금만)
    final hasFundedHot = wallets.any((w) => w.kind == SafetyWalletKind.hot && funded(w));
    results.add(
      inputs.appLockEnabled
          ? const SafetyCheckResult(SafetyCheckId.appLock, SafetyOutcome.passed)
          : SafetyCheckResult(
            SafetyCheckId.appLock,
            SafetyOutcome.failed,
            severity: hasFundedHot ? SafetySeverity.actionNeeded : SafetySeverity.warning,
          ),
    );
    results.add(switch (inputs.appUpdate) {
      AppUpdateStatus.unknown => const SafetyCheckResult(
        SafetyCheckId.appUpdate,
        SafetyOutcome.unknown,
        reason: NotApplicableReason.updateCheckFailed,
      ),
      AppUpdateStatus.upToDate => const SafetyCheckResult(SafetyCheckId.appUpdate, SafetyOutcome.passed),
      AppUpdateStatus.available => const SafetyCheckResult(
        SafetyCheckId.appUpdate,
        SafetyOutcome.failed,
        severity: SafetySeverity.warning,
      ),
    });
    final appEarned = (inputs.appLockEnabled ? 80 : 0) + (inputs.appUpdate == AppUpdateStatus.upToDate ? 20 : 0);
    final appScore = (appEarned * 100 / (inputs.appUpdate == AppUpdateStatus.unknown ? 80 : 100)).round();

    // 복구: 지갑별 점수 → 가중 평균
    final scoredWallets = <({SafetyWalletSnapshot wallet, int score, List<SafetyCheckId> failing})>[];
    for (final w in wallets) {
      final checks = _recoveryChecks(w, state);
      results.addAll(checks.map((c) => c.result));
      final scored = checks.where((c) => c.max > 0);
      if (scored.isEmpty) continue;
      final max = scored.fold<int>(0, (sum, c) => sum + c.max);
      final earned = scored.fold<int>(0, (sum, c) => sum + c.earned);
      scoredWallets.add((
        wallet: w,
        score: (earned * 100 / max).round(),
        failing: [
          for (final c in scored)
            if (c.result.outcome == SafetyOutcome.failed) c.result.id,
        ],
      ));
    }
    final recovery = _recoveryContributions(scoredWallets);
    final recoveryScore = _recoveryScore(recovery);

    // 활동 = max(70, 100 − 10 × 최근 7일 충돌). 위급 사건은 점수 대신 criticalOverride.
    // 하나뿐인 받은 거래가 사라진 지갑(거래·잔액 없음)도 최근 충돌이 있으면 사용 이력으로 본다(경고가 보이도록, 데이터 충분 판정 포함)
    final since = inputs.now.subtract(conflictWindow);
    final recentConflicts = [
      for (final c in state.conflicts)
        if (walletIds.contains(c.walletId) && c.at.isAfter(since)) c,
    ];
    final conflictWalletIds = {for (final c in recentConflicts) c.walletId};
    bool active(SafetyWalletSnapshot w) => used(w) || conflictWalletIds.contains(w.id);
    final activityApplies = wallets.any(active);
    final usageReason = wallets.isEmpty ? NotApplicableReason.noWallet : NotApplicableReason.noHistory;
    if (incidents.every((i) => !i.isOpen)) {
      final waitingBaseline = wallets.any((w) => used(w) && state.baselines[w.id] == null);
      results.add(
        !activityApplies
            ? SafetyCheckResult(SafetyCheckId.unrecognizedOutgoing, SafetyOutcome.notApplicable, reason: usageReason)
            : waitingBaseline
            ? const SafetyCheckResult(
              SafetyCheckId.unrecognizedOutgoing,
              SafetyOutcome.unknown,
              reason: NotApplicableReason.notSettled,
            )
            : const SafetyCheckResult(SafetyCheckId.unrecognizedOutgoing, SafetyOutcome.passed),
      );
    }
    _addAggregate(
      results,
      SafetyCheckId.txConflict,
      applies: activityApplies,
      reason: usageReason,
      failing: {
        for (final w in wallets)
          w.id: [
            for (final c in recentConflicts)
              if (c.walletId == w.id) c.txid,
          ],
      },
    );
    final int? activityScore = activityApplies ? math.max(70, 100 - 10 * recentConflicts.length) : null;

    // 개인정보 = 100 − min(45, 15 × UTXO 남은 재사용 주소) − min(15, 5 × 잠기지 않은 더스트)
    final receiveWallets = wallets.where((w) => w.hasReceiveHistory);
    final utxoWallets = wallets.where((w) => w.hasUtxoHistory);
    _addAggregate(
      results,
      SafetyCheckId.addressReuse,
      applies: receiveWallets.isNotEmpty,
      reason: wallets.isEmpty ? NotApplicableReason.noWallet : NotApplicableReason.noReceiveHistory,
      failing: {for (final w in receiveWallets) w.id: w.reusedAddressesWithUtxo},
    );
    _addAggregate(
      results,
      SafetyCheckId.possibleDusting,
      applies: utxoWallets.isNotEmpty,
      reason: wallets.isEmpty ? NotApplicableReason.noWallet : NotApplicableReason.noUtxoHistory,
      failing: {for (final w in utxoWallets) w.id: w.unlockedDustUtxoIds},
      evidence: SafetyEvidence.heuristic,
    );
    final reused = receiveWallets.fold<int>(0, (sum, w) => sum + w.reusedAddressesWithUtxo.length);
    final dust = utxoWallets.fold<int>(0, (sum, w) => sum + w.unlockedDustUtxoIds.length);
    final int? privacyScore =
        receiveWallets.isNotEmpty || utxoWallets.isNotEmpty
            ? 100 - math.min<int>(45, 15 * reused) - math.min<int>(15, 5 * dust)
            : null;

    // 점수 밖 검토 항목(조치 필요): 기준점 때 대기 중이었거나 7일 안에 확정된 출금(레드팀 §2), 기준점 뒤 앱이 만들지 않은
    // 자기 앞 전송(§7). 확정돼도 남고 "내 거래예요"(인지)나 사건이 되면 닫힌다. 지갑에서 거래가 사라지면 보여 줄 수 없어 뺀다
    final incidentTxids = {for (final i in state.incidents) i.txid};
    for (final w in wallets) {
      final baseline = state.baselines[w.id];
      if (baseline == null) continue;
      final listed = {for (final tx in w.txs) tx.txid};
      for (final (id, txids) in [
        (SafetyCheckId.pendingOutgoingAtBaseline, baseline.pendingSentAtBaseline),
        (SafetyCheckId.unexpectedSelfTransfer, baseline.unexpectedSelfTxids),
      ]) {
        final open = [
          for (final txid in txids)
            if (listed.contains(txid) &&
                !state.recognizedTxids.contains(txid) &&
                !state.isAppCreated(txid) &&
                !incidentTxids.contains(txid))
              txid,
        ];
        if (open.isEmpty) continue;
        results.add(
          SafetyCheckResult(
            id,
            SafetyOutcome.failed,
            walletId: w.id,
            severity: SafetySeverity.actionNeeded,
            subjects: open,
          ),
        );
      }
    }

    // 점수 밖: 서버 인증서(만료 임박은 추천 목록)
    final cert = _serverCert(inputs);
    if (cert.severity == SafetySeverity.recommended) {
      recommended.add(RecommendedItem(check: cert));
    } else {
      results.add(cert);
    }

    // 점수 밖: 추천 점검(rec.*)과 메모·태그 백업
    final hasHot = wallets.any((w) => w.kind == SafetyWalletKind.hot);
    final hasMultisig = wallets.any((w) => w.kind == SafetyWalletKind.multisig);
    for (final id in RecommendedCheckId.values) {
      final applies = switch (id) {
        RecommendedCheckId.hotPhysicalBackup || RecommendedCheckId.hotSafeStorage => hasHot,
        RecommendedCheckId.hotPassphraseOffline => wallets.any(
          (w) => w.kind == SafetyWalletKind.hot && w.passphraseOnSigning,
        ),
        RecommendedCheckId.multisigQuorumAccess || RecommendedCheckId.multisigBackupSeparation => hasMultisig,
        RecommendedCheckId.metadataStoredOffsite => state.metadataExport != null,
      };
      if (applies) recommended.add(RecommendedItem(id: id, done: state.recommendedDoneAt.containsKey(id.key)));
    }
    final metadata = _metadataBackup(inputs);
    if (metadata.outcome == SafetyOutcome.notApplicable) {
      results.add(metadata);
    } else {
      recommended.add(RecommendedItem(check: metadata, done: metadata.outcome == SafetyOutcome.passed));
    }

    final reviewItems =
        results
            .where((r) => r.outcome == SafetyOutcome.failed && r.severity.index <= SafetySeverity.warning.index)
            .toList()
          ..sort(_byPriority);
    final allGoodItems = results.where((r) => r.outcome == SafetyOutcome.passed).toList()..sort(_byPriority);
    final notIncluded =
        results.where((r) => r.outcome == SafetyOutcome.notApplicable || r.outcome == SafetyOutcome.unknown).toList()
          ..sort(_byPriority);

    // 프로필: 자금 있는 핫·그 외 유형으로 고른다. 자금 있는 지갑이 없으면 보기 전용 프로필
    final fundedOther = wallets.any((w) => w.kind != SafetyWalletKind.hot && funded(w));
    final profile =
        hasFundedHot ? (fundedOther ? WeightProfile.mixed : WeightProfile.hotFunded) : WeightProfile.watchOnlyOnly;
    final scores = <SafetyCategory, int?>{
      SafetyCategory.app: appScore,
      SafetyCategory.recovery: recoveryScore,
      SafetyCategory.activity: activityScore,
      SafetyCategory.privacy: privacyScore,
    };
    final totalWeight = scores.entries.fold<int>(0, (sum, e) => e.value == null ? sum : sum + profile.weightOf(e.key));
    final categories = {
      for (final MapEntry(key: category, value: score) in scores.entries)
        category: CategoryScore(
          category: category,
          score: score,
          weightPercent: score == null ? 0 : profile.weightOf(category) * 100 / totalWeight,
          issueCount:
              reviewItems.where((r) => r.id.category == category).length +
              (category == SafetyCategory.activity ? criticalIncidents.length : 0),
          waitingReason:
              score != null
                  ? null
                  : switch (category) {
                    SafetyCategory.app => null,
                    SafetyCategory.recovery =>
                      wallets.isEmpty ? NotApplicableReason.noWallet : NotApplicableReason.noFunds,
                    SafetyCategory.activity => NotApplicableReason.noHistory,
                    SafetyCategory.privacy => NotApplicableReason.noReceiveHistory,
                  },
        ),
    };
    final overall =
        (scores.entries.fold<int>(0, (sum, e) => sum + (e.value ?? 0) * profile.weightOf(e.key)) / totalWeight).round();

    // 상태: 지갑 0 → 위급 → (자금 || 사용 이력) && 점수 카테고리 ≥ 2 → 데이터 부족
    final enoughData = wallets.any(active) && scores.values.where((s) => s != null).length >= 2;
    final critical = criticalIncidents.isNotEmpty || reviewItems.any((r) => r.severity == SafetySeverity.critical);
    final status =
        wallets.isEmpty
            ? WalletHealthStatus.noWallet
            : critical
            ? WalletHealthStatus.criticalOverride
            : enoughData
            ? WalletHealthStatus.scored
            : WalletHealthStatus.notEnoughData;
    final score = status != WalletHealthStatus.noWallet && enoughData ? overall : null;

    return WalletHealthReport(
      status: status,
      score: score,
      label: score == null ? null : WalletHealthLabel.of(score),
      profile: profile,
      categories: categories,
      recovery: recovery,
      criticalIncidents: criticalIncidents,
      infoIncidents: infoIncidents,
      reviewItems: reviewItems,
      allGoodItems: allGoodItems,
      notIncluded: notIncluded,
      recommended: recommended,
      walletCount: wallets.length,
      fundedWalletCount: wallets.where(funded).length,
      evaluatedAt: inputs.now,
      lastSuccessfulSyncAt: state.lastSuccessfulSyncAt,
      isConnected: inputs.isConnected,
    );
  }

  /// 지갑 하나의 복구 점검. max = 배점(0이면 점수 밖), earned = 얻은 점수
  static List<({SafetyCheckResult result, int max, int earned})> _recoveryChecks(
    SafetyWalletSnapshot w,
    SafetyState state,
  ) {
    final funded = w.balanceSats > 0;
    ({SafetyCheckResult result, int max, int earned}) check(
      SafetyCheckId id,
      int max, {
      required bool passed,
      SafetySeverity severity = SafetySeverity.actionNeeded,
      SafetyEvidence evidence = SafetyEvidence.automatic,
      SafetyCheckDetail? detail,
      int? earned,
      int? points,
    }) => (
      result: SafetyCheckResult(
        id,
        passed ? SafetyOutcome.passed : SafetyOutcome.failed,
        walletId: w.id,
        severity: passed ? SafetySeverity.none : severity,
        evidence: evidence,
        points: points,
        detail: passed ? null : detail,
      ),
      max: max,
      earned: earned ?? (passed ? max : 0),
    );
    ({SafetyCheckResult result, int max, int earned}) notApplicable(SafetyCheckId id, NotApplicableReason reason) => (
      result: SafetyCheckResult(id, SafetyOutcome.notApplicable, walletId: w.id, reason: reason),
      max: 0,
      earned: 0,
    );

    switch (w.kind) {
      case SafetyWalletKind.hot:
        // 핫 = 백업 70(자금 || 이력) + 패스프레이즈 30(자금 && 서명 시 입력)
        return [
          funded || w.txs.isNotEmpty
              ? check(SafetyCheckId.mnemonicBackup, 70, passed: w.backupVerified)
              : notApplicable(SafetyCheckId.mnemonicBackup, NotApplicableReason.noFunds),
          !w.passphraseOnSigning
              ? notApplicable(SafetyCheckId.passphraseVerify, NotApplicableReason.noPassphrase)
              : !funded
              ? notApplicable(SafetyCheckId.passphraseVerify, NotApplicableReason.noFunds)
              : check(
                SafetyCheckId.passphraseVerify,
                30,
                passed: state.passphraseVerifiedAt.containsKey(w.id),
                detail: SafetyCheckDetail.notVerified,
              ),
        ];
      case SafetyWalletKind.watchOnly:
      case SafetyWalletKind.taproot:
        // 보기 전용·탭루트 = QR 일치 100 / 사용자 확인 60 / 그 외 0. 디스크립터가 바뀐 기록은 무효
        final v = state.watchOnlyVerifications[w.id];
        final record = v != null && v.descriptorHash == w.descriptorHash ? v : null;
        if (record == null || record.result != VerificationResult.match) {
          return [
            check(
              SafetyCheckId.watchOnlyVerify,
              100,
              passed: false,
              // 사용자가 "이 서명 기기가 맞아요"로 확인한 불일치만 위급(SPEC v2)
              severity:
                  record?.result == VerificationResult.confirmedMismatch
                      ? SafetySeverity.critical
                      : SafetySeverity.actionNeeded,
              detail: record == null ? SafetyCheckDetail.notVerified : SafetyCheckDetail.mismatch,
              points: 0,
            ),
          ];
        }
        final byQr = record.method == VerificationMethod.qr;
        return [
          check(
            SafetyCheckId.watchOnlyVerify,
            100,
            passed: true,
            evidence: byQr ? SafetyEvidence.automatic : SafetyEvidence.userConfirmed,
            earned: byQr ? 100 : 60,
            points: byQr ? 100 : 60,
          ),
        ];
      case SafetyWalletKind.multisig:
        // 다중서명 = 구성 50 + BSMS 50. 자금·사용 이력이 있는데 구성이 불일치하면 위급
        final config = w.multisigConfig ?? MultisigConfigStatus.incomplete;
        final bsms = state.bsms[w.id];
        return [
          check(
            SafetyCheckId.multisigConfig,
            50,
            passed: config == MultisigConfigStatus.complete,
            severity:
                config == MultisigConfigStatus.mismatch && (funded || w.txs.isNotEmpty)
                    ? SafetySeverity.critical
                    : SafetySeverity.actionNeeded,
            detail: config == MultisigConfigStatus.mismatch ? SafetyCheckDetail.mismatch : SafetyCheckDetail.incomplete,
          ),
          check(
            SafetyCheckId.bsmsBackup,
            50,
            passed: bsms != null && bsms.matched && bsms.configHash == w.descriptorHash,
            detail:
                bsms == null
                    ? SafetyCheckDetail.notVerified
                    : !bsms.matched
                    ? SafetyCheckDetail.mismatch
                    : SafetyCheckDetail.updateRequired,
          ),
        ];
    }
  }

  /// 자금 있음 w = 1 + 유형(핫·다중서명 1, 보기 전용·탭루트 0.5) + min(3, log10(1 + sats/1e5)), 자금 없음 w = 0.5.
  /// 자금 없는 지갑 가중치 합은 자금 있는 합 × 0.25까지(SPEC v2).
  static List<WalletRecoveryContribution> _recoveryContributions(
    List<({SafetyWalletSnapshot wallet, int score, List<SafetyCheckId> failing})> scored,
  ) {
    double baseWeight(SafetyWalletSnapshot w) {
      if (w.balanceSats <= 0) return unfundedWalletWeight;
      final type = w.kind == SafetyWalletKind.hot || w.kind == SafetyWalletKind.multisig ? 1.0 : 0.5;
      return 1 + type + math.min(3.0, math.log(1 + w.balanceSats / 1e5) / math.ln10);
    }

    final fundedSum = scored
        .where((s) => s.wallet.balanceSats > 0)
        .fold<double>(0, (sum, s) => sum + baseWeight(s.wallet));
    final unfundedSum = scored
        .where((s) => s.wallet.balanceSats <= 0)
        .fold<double>(0, (sum, s) => sum + baseWeight(s.wallet));
    final cap = fundedSum * unfundedWeightCap;
    final unfundedScale = fundedSum > 0 && unfundedSum > cap ? cap / unfundedSum : 1.0;
    return [
      for (final s in scored)
        WalletRecoveryContribution(
          walletId: s.wallet.id,
          kind: s.wallet.kind,
          balanceSats: s.wallet.balanceSats,
          score: s.score,
          weight: baseWeight(s.wallet) * (s.wallet.balanceSats > 0 ? 1 : unfundedScale),
          failing: s.failing,
        ),
    ]..sort((a, b) => b.weight.compareTo(a.weight));
  }

  /// Σ s·w / Σ w. 단, 잔액이 가장 큰 지갑의 점수를 넘지 않는다(같은 잔액이면 낮은 점수).
  /// 자금 있는 지갑이 없으면 두 상한(이 상한과 자금 없는 가중치 25%) 모두 적용하지 않는다(lead 확인).
  static int? _recoveryScore(List<WalletRecoveryContribution> recovery) {
    if (recovery.isEmpty) return null;
    final weightSum = recovery.fold<double>(0, (sum, r) => sum + r.weight);
    var score = recovery.fold<double>(0, (sum, r) => sum + r.score * r.weight) / weightSum;
    final maxBalance = recovery.map((r) => r.balanceSats).reduce(math.max);
    if (maxBalance > 0) {
      final largest = recovery.where((r) => r.balanceSats == maxBalance).map((r) => r.score).reduce(math.min);
      score = math.min(score, largest.toDouble());
    }
    return score.round();
  }

  /// 지갑마다 판정하는 개인정보·활동 점검: 실패한 지갑은 지갑별 결과, 없으면 앱 전체 결과 하나
  static void _addAggregate(
    List<SafetyCheckResult> results,
    SafetyCheckId id, {
    required bool applies,
    required NotApplicableReason reason,
    required Map<int, List<String>> failing,
    SafetyEvidence evidence = SafetyEvidence.automatic,
  }) {
    if (!applies) {
      results.add(SafetyCheckResult(id, SafetyOutcome.notApplicable, reason: reason));
      return;
    }
    final failed = [
      for (final MapEntry(key: walletId, value: subjects) in failing.entries)
        if (subjects.isNotEmpty)
          SafetyCheckResult(
            id,
            SafetyOutcome.failed,
            walletId: walletId,
            severity: SafetySeverity.warning,
            evidence: evidence,
            subjects: subjects,
          ),
    ];
    results.addAll(failed.isEmpty ? [SafetyCheckResult(id, SafetyOutcome.passed, evidence: evidence)] : failed);
  }

  /// 사용자 서버 + 고정 지문일 때만. CA가 보증하지 않는 지문 변경 = 위급, 만료 = 조치 필요, 30일 안 만료 = 추천
  static SafetyCheckResult _serverCert(SafetyInputs inputs) {
    final cert = inputs.serverCert;
    if (cert == null || !cert.applicable) {
      return const SafetyCheckResult(
        SafetyCheckId.serverCert,
        SafetyOutcome.notApplicable,
        reason: NotApplicableReason.notCustomServer,
      );
    }
    final pinned = cert.pinned, actual = cert.actual;
    if (actual == null) return const SafetyCheckResult(SafetyCheckId.serverCert, SafetyOutcome.unknown);
    if (pinned != null && _fingerprint(pinned) != _fingerprint(actual) && !cert.caValid) {
      return SafetyCheckResult(
        SafetyCheckId.serverCert,
        SafetyOutcome.failed,
        severity: SafetySeverity.critical,
        subjects: [pinned, actual],
        detail: SafetyCheckDetail.identityChanged,
      );
    }
    final end = cert.endValidity;
    if (end != null && end.isBefore(inputs.now)) {
      return SafetyCheckResult(
        SafetyCheckId.serverCert,
        SafetyOutcome.failed,
        severity: SafetySeverity.actionNeeded,
        detail: SafetyCheckDetail.expired,
        count: inputs.now.difference(end).inDays,
      );
    }
    if (end != null && !end.isAfter(inputs.now.add(certExpiringWindow))) {
      return SafetyCheckResult(
        SafetyCheckId.serverCert,
        SafetyOutcome.failed,
        severity: SafetySeverity.recommended,
        detail: SafetyCheckDetail.expiresSoon,
        count: end.difference(inputs.now).inDays,
      );
    }
    return const SafetyCheckResult(SafetyCheckId.serverCert, SafetyOutcome.passed);
  }

  /// 지문 표기(대소문자·콜론)가 달라도 같은 인증서로 본다
  static String _fingerprint(String value) => value.replaceAll(RegExp('[^0-9a-fA-F]'), '').toLowerCase();

  /// 태그·메모가 있을 때 마지막 내보내기 뒤 바뀐 게 있으면 추천
  static SafetyCheckResult _metadataBackup(SafetyInputs inputs) {
    if (inputs.labelTagCount + inputs.labelMemoCount == 0) {
      return const SafetyCheckResult(
        SafetyCheckId.metadataBackup,
        SafetyOutcome.notApplicable,
        reason: NotApplicableReason.noLabels,
      );
    }
    final export = inputs.state.metadataExport;
    if (export == null) {
      return const SafetyCheckResult(
        SafetyCheckId.metadataBackup,
        SafetyOutcome.failed,
        severity: SafetySeverity.recommended,
        detail: SafetyCheckDetail.neverExported,
      );
    }
    // ponytail: 개수만 비교해서 개수가 같은 편집은 못 잡는다. 필요하면 내보낸 라벨의 해시를 저장
    final changes = (inputs.labelTagCount - export.tagCount).abs() + (inputs.labelMemoCount - export.memoCount).abs();
    return changes > 0
        ? SafetyCheckResult(
          SafetyCheckId.metadataBackup,
          SafetyOutcome.failed,
          severity: SafetySeverity.recommended,
          detail: SafetyCheckDetail.changed,
          count: changes,
        )
        : const SafetyCheckResult(SafetyCheckId.metadataBackup, SafetyOutcome.passed);
  }

  /// 심각도 → 점검 순서 → 지갑(앱 전체 먼저)
  static int _byPriority(SafetyCheckResult a, SafetyCheckResult b) {
    final bySeverity = a.severity.index.compareTo(b.severity.index);
    if (bySeverity != 0) return bySeverity;
    final byId = a.id.index.compareTo(b.id.index);
    if (byId != 0) return byId;
    return (a.walletId ?? -1).compareTo(b.walletId ?? -1);
  }
}
