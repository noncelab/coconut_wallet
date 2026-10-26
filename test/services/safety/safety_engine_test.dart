import 'dart:io';
import 'dart:math' as math;

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_incident.dart';
import 'package:coconut_wallet/model/safety/safety_inputs.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/services/safety/incident_detector.dart';
import 'package:coconut_wallet/services/safety/safety_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../model/safety/safety_fixtures.dart';

final _received = tx('r', type: TransactionType.received, height: 900);

/// 자금과 받은 이력이 있는 핫월렛
SafetyWalletSnapshot _hot(
  int id, {
  int balance = btc,
  bool backup = true,
  bool passphrase = false,
  List<String> reused = const [],
  List<String> dust = const [],
}) => wallet(
  id,
  balance: balance,
  backupVerified: backup,
  passphrase: passphrase,
  txs: [_received],
  reused: reused,
  dust: dust,
);

SafetyWalletSnapshot _watchOnly(
  int id, {
  int balance = 0,
  bool used = false,
  SafetyWalletKind kind = SafetyWalletKind.watchOnly,
}) => wallet(id, kind: kind, balance: balance, txs: used ? [_received] : const []);

WatchOnlyVerification _verified(
  int walletId, {
  VerificationMethod method = VerificationMethod.qr,
  VerificationResult result = VerificationResult.match,
  String? hash,
}) =>
    WatchOnlyVerification(method: method, result: result, descriptorHash: hash ?? 'descriptor-$walletId', at: testNow);

WalletHealthReport _evaluate(
  List<SafetyWalletSnapshot> wallets, {
  SafetyState state = const SafetyState(),
  bool appLock = true,
  AppUpdateStatus update = AppUpdateStatus.upToDate,
  ServerCertObservation? cert,
  int tags = 0,
  int memos = 0,
}) => SafetyEngine.evaluate(
  inputs(wallets: wallets, state: state, appLock: appLock, update: update, cert: cert, tags: tags, memos: memos),
);

int? _score(WalletHealthReport r, SafetyCategory c) => r.categories[c]!.score;

Iterable<SafetyCheckResult> _all(WalletHealthReport r) => [
  ...r.reviewItems,
  ...r.allGoodItems,
  ...r.notIncluded,
  for (final item in r.recommended)
    if (item.check != null) item.check!,
];

SafetyCheckResult _find(WalletHealthReport r, SafetyCheckId id, {int? walletId}) =>
    _all(r).singleWhere((c) => c.id == id && c.walletId == walletId);

double _weight(WalletHealthReport r, int walletId) => r.recovery.singleWhere((c) => c.walletId == walletId).weight;

void main() {
  group('status', () {
    test('no wallet: app lock off is not a review item, so the home chip shows nothing to fix', () {
      final r = _evaluate([], appLock: false);
      expect(_find(r, SafetyCheckId.appLock).outcome, SafetyOutcome.notApplicable);
      expect(r.reviewItems, isEmpty);
      expect(r.attentionCount, 0);
      final withWallet = _evaluate([_hot(1)], appLock: false);
      expect(withWallet.reviewItems.map((r) => r.id), contains(SafetyCheckId.appLock));
    });

    test('no wallet → no score; App Protection still checked, the rest waits for a wallet', () {
      final r = _evaluate([]);
      expect(r.status, WalletHealthStatus.noWallet);
      expect((r.score, r.label, r.walletCount, r.scoreCap), (null, null, 0, null));
      expect(_score(r, SafetyCategory.app), 100);
      expect(r.categories[SafetyCategory.recovery]!.waitingReason, NotApplicableReason.noWallet);
      expect(r.categories[SafetyCategory.activity]!.waitingReason, NotApplicableReason.noHistory);
      expect(r.categories[SafetyCategory.privacy]!.waitingReason, NotApplicableReason.noReceiveHistory);
      for (final id in [
        SafetyCheckId.unrecognizedOutgoing,
        SafetyCheckId.txConflict,
        SafetyCheckId.addressReuse,
        SafetyCheckId.possibleDusting,
      ]) {
        expect(_find(r, id).reason, NotApplicableReason.noWallet, reason: id.name);
      }
    });

    test('wallets without funds or history → not enough data, even with two scored categories', () {
      final fresh = _evaluate([_watchOnly(1)]);
      expect(_score(fresh, SafetyCategory.recovery), 0);
      expect((fresh.status, fresh.score, fresh.label), (WalletHealthStatus.notEnoughData, null, null));

      final emptyHot = _evaluate([wallet(1)]);
      expect(emptyHot.status, WalletHealthStatus.notEnoughData);
      expect(emptyHot.categories[SafetyCategory.recovery]!.waitingReason, NotApplicableReason.noFunds);
      expect(_find(emptyHot, SafetyCheckId.mnemonicBackup, walletId: 1).reason, NotApplicableReason.noFunds);
    });

    test('funds or history → scored', () {
      final r = _evaluate([_hot(1)]);
      expect((r.status, r.score, r.label), (WalletHealthStatus.scored, 100, WalletHealthLabel.excellent));
      expect(
        _evaluate([
          wallet(1, backupVerified: true, txs: [tx('spent', height: 900)]),
        ]).status,
        WalletHealthStatus.scored,
      );
    });

    test('an open incident overrides the status but keeps the score; a disappeared tx is info only', () {
      final incident = SafetyIncident(walletId: 1, txid: 'x', detectedAt: testNow);
      final base = _evaluate([_hot(1)]);
      final critical = _evaluate([_hot(1)], state: SafetyState(incidents: [incident]));
      expect(critical.status, WalletHealthStatus.criticalOverride);
      expect(critical.isCritical, isTrue);
      expect((critical.score, critical.label), (base.score, base.label));
      expect(critical.criticalIncidents, [incident]);
      expect(critical.categories[SafetyCategory.activity]!.issueCount, 1);

      final gone = incident.withTxState(IncidentTxState.dropped);
      final info = _evaluate([_hot(1)], state: SafetyState(incidents: [gone]));
      expect(info.status, WalletHealthStatus.scored);
      expect(info.criticalIncidents, isEmpty);
      expect(info.infoIncidents, [gone]);

      final recognized = _evaluate([_hot(1)], state: SafetyState(incidents: [incident.recognize(testNow)]));
      expect(recognized.status, WalletHealthStatus.scored);
      expect(recognized.criticalIncidents, isEmpty);
    });

    test('incidents of wallets that are no longer listed are ignored', () {
      final r = _evaluate([
        _hot(1),
      ], state: SafetyState(incidents: [SafetyIncident(walletId: 9, txid: 'x', detectedAt: testNow)]));
      expect(r.status, WalletHealthStatus.scored);
    });

    test('critical causes besides incidents', () {
      // 사용자가 확인한 보기 전용 불일치
      expect(
        _evaluate(
          [_watchOnly(1)],
          state: SafetyState(watchOnlyVerifications: {1: _verified(1, result: VerificationResult.confirmedMismatch)}),
        ).status,
        WalletHealthStatus.criticalOverride,
      );
      // 자금·사용 이력 있는 다중서명 구성 불일치
      final multisig = wallet(
        1,
        kind: SafetyWalletKind.multisig,
        balance: btc,
        txs: [_received],
        multisigConfig: MultisigConfigStatus.mismatch,
      );
      expect(_evaluate([multisig]).status, WalletHealthStatus.criticalOverride);
      final unusedMultisig = wallet(1, kind: SafetyWalletKind.multisig, multisigConfig: MultisigConfigStatus.mismatch);
      final unused = _evaluate([unusedMultisig]);
      expect(unused.status, WalletHealthStatus.notEnoughData);
      expect(_find(unused, SafetyCheckId.multisigConfig, walletId: 1).severity, SafetySeverity.actionNeeded);
      // CA가 보증하지 않는 인증서 지문 변경
      const changed = ServerCertObservation(applicable: true, pinned: 'aa', actual: 'bb', caValid: false);
      expect(_evaluate([_hot(1)], cert: changed).status, WalletHealthStatus.criticalOverride);
    });

    test('report carries counts, time and connection', () {
      final r = SafetyEngine.evaluate(
        inputs(
          wallets: [_hot(1), _watchOnly(2)],
          state: SafetyState(lastSuccessfulSyncAt: DateTime(2026, 10, 20, 11)),
          connected: false,
        ),
      );
      expect((r.walletCount, r.fundedWalletCount), (2, 1));
      expect((r.evaluatedAt, r.lastSuccessfulSyncAt, r.isConnected), (testNow, DateTime(2026, 10, 20, 11), false));
    });
  });

  group('App Protection', () {
    test('App Lock 80 + App update 20; update unknown → App Lock only', () {
      int app({required bool lock, required AppUpdateStatus update}) =>
          _score(_evaluate([], appLock: lock, update: update), SafetyCategory.app)!;
      expect(app(lock: true, update: AppUpdateStatus.upToDate), 100);
      expect(app(lock: true, update: AppUpdateStatus.available), 80);
      expect(app(lock: false, update: AppUpdateStatus.upToDate), 20);
      expect(app(lock: false, update: AppUpdateStatus.available), 0);
      expect(app(lock: true, update: AppUpdateStatus.unknown), 100);
      expect(app(lock: false, update: AppUpdateStatus.unknown), 0);
      expect(
        _find(_evaluate([], update: AppUpdateStatus.unknown), SafetyCheckId.appUpdate).reason,
        NotApplicableReason.updateCheckFailed,
      );
    });

    test(
      'App Lock off: action needed with a funded hot wallet, otherwise a warning; update available is a warning',
      () {
        expect(
          _find(_evaluate([_hot(1)], appLock: false), SafetyCheckId.appLock).severity,
          SafetySeverity.actionNeeded,
        );
        expect(
          _find(_evaluate([_hot(1, balance: 0)], appLock: false), SafetyCheckId.appLock).severity,
          SafetySeverity.warning,
        );
        expect(
          _find(_evaluate([_watchOnly(1, balance: btc)], appLock: false), SafetyCheckId.appLock).severity,
          SafetySeverity.warning,
        );
        expect(
          _find(_evaluate([], update: AppUpdateStatus.available), SafetyCheckId.appUpdate).severity,
          SafetySeverity.warning,
        );
      },
    );
  });

  group('Recovery Readiness', () {
    test('hot: backup 70 when funded or used, passphrase 30 when funded and entered on signing', () {
      final verified = SafetyState(passphraseVerifiedAt: {1: testNow});
      int recovery(SafetyWalletSnapshot w, [SafetyState s = const SafetyState()]) =>
          _score(_evaluate([w], state: s), SafetyCategory.recovery)!;
      expect(recovery(_hot(1, passphrase: true), verified), 100);
      expect(recovery(_hot(1, passphrase: true)), 70);
      expect(recovery(_hot(1, backup: false, passphrase: true), verified), 30);
      expect(recovery(_hot(1, backup: false)), 0);

      final historyOnly = _evaluate([_hot(1, balance: 0, backup: false, passphrase: true)]);
      expect(_find(historyOnly, SafetyCheckId.mnemonicBackup, walletId: 1).severity, SafetySeverity.actionNeeded);
      expect(_find(historyOnly, SafetyCheckId.passphraseVerify, walletId: 1).reason, NotApplicableReason.noFunds);
      expect(
        _find(_evaluate([_hot(1)]), SafetyCheckId.passphraseVerify, walletId: 1).reason,
        NotApplicableReason.noPassphrase,
      );
      final passphrase = _find(_evaluate([_hot(1, passphrase: true)]), SafetyCheckId.passphraseVerify, walletId: 1);
      expect((passphrase.severity, passphrase.detail), (SafetySeverity.actionNeeded, SafetyCheckDetail.notVerified));
    });

    test('watch-only and taproot: QR match 100, user-confirmed 60, otherwise 0', () {
      for (final kind in [SafetyWalletKind.watchOnly, SafetyWalletKind.taproot]) {
        final w = _watchOnly(1, balance: btc, used: true, kind: kind);
        SafetyCheckResult check(WatchOnlyVerification? v) => _find(
          _evaluate([w], state: SafetyState(watchOnlyVerifications: {if (v != null) 1: v})),
          SafetyCheckId.watchOnlyVerify,
          walletId: 1,
        );
        final qr = check(_verified(1));
        expect((qr.outcome, qr.points, qr.evidence), (SafetyOutcome.passed, 100, SafetyEvidence.automatic));
        final user = check(_verified(1, method: VerificationMethod.user));
        expect((user.outcome, user.points, user.evidence), (SafetyOutcome.passed, 60, SafetyEvidence.userConfirmed));
        expect(qr.detail, isNull);
        final none = check(null);
        expect((none.outcome, none.points, none.severity), (SafetyOutcome.failed, 0, SafetySeverity.actionNeeded));
        expect(none.detail, SafetyCheckDetail.notVerified);
        // 불일치는 "다시 스캔"(조치 필요), 사용자가 확인한 불일치만 위급
        final mismatch = check(_verified(1, result: VerificationResult.mismatch));
        expect((mismatch.severity, mismatch.detail), (SafetySeverity.actionNeeded, SafetyCheckDetail.mismatch));
        final confirmed = check(_verified(1, result: VerificationResult.confirmedMismatch));
        expect((confirmed.severity, confirmed.detail), (SafetySeverity.critical, SafetyCheckDetail.mismatch));
        // 다른 디스크립터로 한 검증은 무효
        final stale = check(_verified(1, hash: 'old'));
        expect((stale.outcome, stale.detail), (SafetyOutcome.failed, SafetyCheckDetail.notVerified));
        expect(
          _score(
            _evaluate([
              w,
            ], state: SafetyState(watchOnlyVerifications: {1: _verified(1, method: VerificationMethod.user)})),
            SafetyCategory.recovery,
          ),
          60,
        );
      }
    });

    test('multisig: configuration 50 + BSMS 50', () {
      SafetyWalletSnapshot multisig(MultisigConfigStatus config) =>
          wallet(1, kind: SafetyWalletKind.multisig, balance: btc, txs: [_received], multisigConfig: config);
      SafetyState bsms({bool matched = true, String hash = 'descriptor-1'}) =>
          SafetyState(bsms: {1: BsmsVerification(matched: matched, configHash: hash, at: testNow)});
      int recovery(MultisigConfigStatus config, [SafetyState s = const SafetyState()]) =>
          _score(_evaluate([multisig(config)], state: s), SafetyCategory.recovery)!;
      expect(recovery(MultisigConfigStatus.complete, bsms()), 100);
      expect(recovery(MultisigConfigStatus.complete), 50);
      expect(recovery(MultisigConfigStatus.incomplete, bsms()), 50);
      expect(recovery(MultisigConfigStatus.complete, bsms(hash: 'changed')), 50);
      expect(recovery(MultisigConfigStatus.complete, bsms(matched: false)), 50);
      final incomplete = _evaluate([multisig(MultisigConfigStatus.incomplete)]);
      final config = _find(incomplete, SafetyCheckId.multisigConfig, walletId: 1);
      expect((config.severity, config.detail), (SafetySeverity.actionNeeded, SafetyCheckDetail.incomplete));
      expect(incomplete.recovery.single.failing, [SafetyCheckId.multisigConfig, SafetyCheckId.bsmsBackup]);
      SafetyCheckDetail? detail(SafetyCheckId id, MultisigConfigStatus config, [SafetyState s = const SafetyState()]) =>
          _find(_evaluate([multisig(config)], state: s), id, walletId: 1).detail;
      expect(detail(SafetyCheckId.multisigConfig, MultisigConfigStatus.mismatch), SafetyCheckDetail.mismatch);
      expect(detail(SafetyCheckId.multisigConfig, MultisigConfigStatus.complete), isNull);
      expect(detail(SafetyCheckId.bsmsBackup, MultisigConfigStatus.complete), SafetyCheckDetail.notVerified);
      expect(
        detail(SafetyCheckId.bsmsBackup, MultisigConfigStatus.complete, bsms(matched: false)),
        SafetyCheckDetail.mismatch,
      );
      expect(
        detail(SafetyCheckId.bsmsBackup, MultisigConfigStatus.complete, bsms(hash: 'changed')),
        SafetyCheckDetail.updateRequired,
      );
      expect(detail(SafetyCheckId.bsmsBackup, MultisigConfigStatus.complete, bsms()), isNull);
    });

    test('BSMS export: exported · not verified, update required, never counts as verified (R30)', () {
      final multisig = wallet(
        1,
        kind: SafetyWalletKind.multisig,
        balance: btc,
        txs: [_received],
        multisigConfig: MultisigConfigStatus.complete,
      );
      BsmsExport exported(String hash, {int minutes = 0}) => (
        configHash: hash,
        at: testNow.add(Duration(minutes: minutes)),
      );
      BsmsVerification verified({bool matched = true, String hash = 'descriptor-1'}) =>
          BsmsVerification(matched: matched, configHash: hash, at: testNow);
      (SafetyOutcome, SafetyCheckDetail?) bsms(SafetyState s) {
        final r = _find(_evaluate([multisig], state: s), SafetyCheckId.bsmsBackup, walletId: 1);
        return (r.outcome, r.detail);
      }

      // 지금 구성으로 내보내기만 함 → 검증 전, BSMS 점수 0(구성 50만)
      final now = SafetyState(bsmsExports: {1: exported('descriptor-1')});
      expect(bsms(now), (SafetyOutcome.failed, SafetyCheckDetail.exportedNotVerified));
      expect(_score(_evaluate([multisig], state: now), SafetyCategory.recovery), 50);
      // 내보낸 뒤 구성이 바뀜 → 갱신 필요
      expect(bsms(SafetyState(bsmsExports: {1: exported('old')})), (
        SafetyOutcome.failed,
        SafetyCheckDetail.updateRequired,
      ));
      // 검증 뒤 구성이 바뀌어 새 구성으로 다시 내보냄 → 검증 전
      expect(
        bsms(SafetyState(bsms: {1: verified(hash: 'old')}, bsmsExports: {1: exported('descriptor-1', minutes: 1)})),
        (SafetyOutcome.failed, SafetyCheckDetail.exportedNotVerified),
      );
      // 내보낸 뒤에 한 검증이 불일치 → 나중 결과인 불일치
      expect(
        bsms(SafetyState(bsms: {1: verified(matched: false)}, bsmsExports: {1: exported('descriptor-1', minutes: -1)})),
        (SafetyOutcome.failed, SafetyCheckDetail.mismatch),
      );
      // 검증된 지갑은 나중에 내보내도 그대로 검증됨, 기록이 없으면 지금처럼 검증 전
      expect(bsms(SafetyState(bsms: {1: verified()}, bsmsExports: {1: exported('descriptor-1', minutes: 1)})), (
        SafetyOutcome.passed,
        null,
      ));
      expect(bsms(const SafetyState()), (SafetyOutcome.failed, SafetyCheckDetail.notVerified));
    });

    test('wallet weight: funded 1 + type + min(3, log10(1 + sats/1e5)), unfunded 0.5', () {
      final r = _evaluate([
        _hot(1, balance: 100000),
        _watchOnly(2, balance: btc, used: true),
        wallet(
          3,
          kind: SafetyWalletKind.multisig,
          balance: 10000000,
          txs: [_received],
          multisigConfig: MultisigConfigStatus.complete,
        ),
        _watchOnly(4),
      ]);
      expect(_weight(r, 1), closeTo(2 + math.log(2) / math.ln10, 1e-9));
      expect(_weight(r, 2), closeTo(4.5, 1e-9), reason: 'exposure caps at 3');
      expect(_weight(r, 3), closeTo(2 + math.log(101) / math.ln10, 1e-9));
      expect(_weight(r, 4), SafetyEngine.unfundedWalletWeight);
    });

    test('unfunded wallets together weigh at most 25% of the funded ones', () {
      final r = _evaluate([_hot(1, balance: 100000), for (var id = 2; id <= 11; id++) _watchOnly(id)]);
      final funded = _weight(r, 1);
      final unfunded = [for (var id = 2; id <= 11; id++) _weight(r, id)];
      expect(unfunded.reduce((a, b) => a + b), closeTo(funded * 0.25, 1e-9));
      expect(unfunded.toSet().length, 1);
    });

    test('overall recovery never exceeds the score of the wallet holding the most bitcoin', () {
      final verified = SafetyState(watchOnlyVerifications: {2: _verified(2)});
      // 핫 1 BTC 백업 안 함(0) + 보기 전용 0.5 BTC QR 검증(100): 평균 46 → 상한 0
      expect(
        _score(
          _evaluate([_hot(1, backup: false), _watchOnly(2, balance: btc ~/ 2, used: true)], state: verified),
          SafetyCategory.recovery,
        ),
        0,
      );
      // 반대면 평균 그대로: 100 × 5 / (5 + 4.2) = 54
      expect(_score(_evaluate([_hot(1), _watchOnly(2, balance: btc ~/ 2, used: true)]), SafetyCategory.recovery), 54);
      // 같은 잔액이면 낮은 점수가 상한
      expect(_score(_evaluate([_hot(1), _watchOnly(2, balance: btc, used: true)]), SafetyCategory.recovery), 0);
      // 자금 있는 지갑이 없으면 상한 없음
      expect(_score(_evaluate([_hot(1, balance: 0), _hot(2, balance: 0, backup: false)]), SafetyCategory.recovery), 50);
    });

    test('1 BTC unbacked hot wallet + 10 empty verified watch-only wallets is not Good', () {
      for (final method in VerificationMethod.values) {
        final watchOnly = [for (var id = 2; id <= 11; id++) _watchOnly(id)];
        final r = _evaluate(
          [_hot(1, backup: false), ...watchOnly],
          state: SafetyState(
            watchOnlyVerifications: {for (final w in watchOnly) w.id: _verified(w.id, method: method)},
          ),
        );
        expect(_score(r, SafetyCategory.recovery), 0, reason: method.name);
        // 20 × 100 + 45 × 0 + 25 × 100 + 10 × 100 = 55. 상한이 없으면 QR 검증일 때 78(양호)
        expect((r.score, r.label), (55, WalletHealthLabel.needsAttention), reason: method.name);
      }
    });
  });

  group('Wallet Activity', () {
    test('max(70, 100 − 10 × conflicts in the last 7 days)', () {
      int activity(List<WalletTxEvent> conflicts) =>
          _score(_evaluate([_hot(1)], state: SafetyState(conflicts: conflicts)), SafetyCategory.activity)!;
      WalletTxEvent conflict(String txid, {int daysAgo = 1, int walletId = 1}) => (
        walletId: walletId,
        txid: txid,
        at: testNow.subtract(Duration(days: daysAgo)),
      );
      expect(activity([]), 100);
      expect(activity([conflict('a')]), 90);
      expect(activity([conflict('a'), conflict('b'), conflict('c')]), 70);
      expect(activity([for (var i = 0; i < 5; i++) conflict('c$i')]), 70);
      expect(activity([conflict('old', daysAgo: 8), conflict('removed', walletId: 9)]), 100);

      final r = _evaluate([_hot(1), _hot(2)], state: SafetyState(conflicts: [conflict('a'), conflict('b')]));
      final item = r.reviewItems.singleWhere((i) => i.id == SafetyCheckId.txConflict);
      expect((item.walletId, item.severity), (1, SafetySeverity.warning));
      expect(item.subjects, ['a', 'b']);
    });

    test('a wallet whose only (first) incoming tx disappeared still gets the conflict warning', () {
      // 감지기: 대기 중인 첫 입금이 10분 넘는 간격으로 두 번 사라짐 → 충돌. 지갑엔 거래·잔액이 남지 않는다
      final later = testNow.add(const Duration(minutes: 12));
      var s = IncidentDetector.detect(
        inputs(
          wallets: [
            wallet(
              1,
              txs: [
                tx('first', type: TransactionType.received, paid: {'bc1qme'}),
              ],
            ),
          ],
        ),
      ).applyTo(const SafetyState());
      s = IncidentDetector.detect(
        inputs(wallets: [wallet(1)], state: s, now: testNow.add(const Duration(minutes: 1))),
      ).applyTo(s);
      s = IncidentDetector.detect(inputs(wallets: [wallet(1)], state: s, now: later)).applyTo(s);
      expect(s.conflicts.single.txid, 'first');

      final r = SafetyEngine.evaluate(inputs(wallets: [wallet(1)], state: s, now: later));
      expect(r.status, WalletHealthStatus.scored, reason: 'a recent conflict counts as wallet usage');
      expect(_score(r, SafetyCategory.activity), 90);
      final item = r.reviewItems.singleWhere((i) => i.id == SafetyCheckId.txConflict);
      expect((item.walletId, item.severity), (1, SafetySeverity.warning));
      expect(item.subjects, ['first']);
      expect(r.attentionCount, 1);
    });

    test(
      'unrecognized outgoing: none found after the baseline, waiting before it, hidden while an incident is open',
      () {
        final settled = SafetyState(baselines: {1: baseline()});
        expect(
          _find(_evaluate([_hot(1)], state: settled), SafetyCheckId.unrecognizedOutgoing).outcome,
          SafetyOutcome.passed,
        );
        expect(_find(_evaluate([_hot(1)]), SafetyCheckId.unrecognizedOutgoing).reason, NotApplicableReason.notSettled);
        expect(_find(_evaluate([wallet(1)]), SafetyCheckId.unrecognizedOutgoing).reason, NotApplicableReason.noHistory);
        final open = settled.copyWith(incidents: [SafetyIncident(walletId: 1, txid: 'x', detectedAt: testNow)]);
        expect(
          _all(_evaluate([_hot(1)], state: open)).where((c) => c.id == SafetyCheckId.unrecognizedOutgoing),
          isEmpty,
        );
      },
    );
  });

  group('Privacy', () {
    test('100 − min(45, 15 × reused addresses with UTXOs) − min(15, 5 × unlocked dust)', () {
      int privacy(List<SafetyWalletSnapshot> wallets) => _score(_evaluate(wallets), SafetyCategory.privacy)!;
      List<String> n(String prefix, int count) => [for (var i = 0; i < count; i++) '$prefix$i'];
      expect(privacy([_hot(1)]), 100);
      expect(privacy([_hot(1, reused: n('a', 1))]), 85);
      expect(privacy([_hot(1, reused: n('a', 4))]), 55);
      expect(privacy([_hot(1, dust: n('u', 2))]), 90);
      expect(privacy([_hot(1, dust: n('u', 5))]), 85);
      expect(privacy([_hot(1, reused: n('a', 4), dust: n('u', 5))]), 40);
      expect(privacy([_hot(1, reused: n('a', 2)), _hot(2, reused: n('b', 1))]), 55);

      final r = _evaluate([
        _hot(1, reused: ['addr']),
        _hot(2, dust: ['utxo']),
      ]);
      final reuse = _find(r, SafetyCheckId.addressReuse, walletId: 1);
      expect(reuse.subjects, ['addr']);
      expect(reuse.severity, SafetySeverity.warning);
      final dusting = _find(r, SafetyCheckId.possibleDusting, walletId: 2);
      expect(dusting.subjects, ['utxo']);
      expect(dusting.evidence, SafetyEvidence.heuristic);
      expect(r.categories[SafetyCategory.privacy]!.issueCount, 2);
    });

    test('not applicable without receive or UTXO history', () {
      final r = _evaluate([
        wallet(1, balance: btc, backupVerified: true, txs: [tx('s', height: 900)]),
      ]);
      expect(_score(r, SafetyCategory.privacy), isNull);
      expect(r.categories[SafetyCategory.privacy]!.waitingReason, NotApplicableReason.noReceiveHistory);
      expect(_find(r, SafetyCheckId.addressReuse).reason, NotApplicableReason.noReceiveHistory);
      expect(_find(r, SafetyCheckId.possibleDusting).reason, NotApplicableReason.noUtxoHistory);
    });
  });

  group('weights', () {
    test('App Protection weight follows how much bitcoin sits in hot wallets; Recovery stays first', () {
      List<double> weights(List<SafetyWalletSnapshot> wallets, {SafetyState state = const SafetyState()}) {
        final r = _evaluate(wallets, state: state);
        return [for (final c in SafetyCategory.values) r.categories[c]!.weightPercent];
      }

      // 노출도 = min(1, 핫 잔액 / 10만) × 핫 잔액 비중. 앱 15 + 15 × 노출도, 활동·개인정보가 25:15로 나머지를 나눈다
      expect(weights([_hot(1)]), [30, 45, 15.625, 9.375]);
      expect(weights([_hot(1), _watchOnly(2)]), [30, 45, 15.625, 9.375]);
      expect(weights([_hot(1, balance: 50000)]), [22.5, 45, 20.3125, 12.1875]);
      expect(
        weights([
          _hot(1),
          _watchOnly(2, balance: btc, used: true),
        ], state: SafetyState(watchOnlyVerifications: {2: _verified(2)})),
        [22.5, 45, 20.3125, 12.1875],
      );
      expect(weights([_hot(1, balance: 0)]), [15, 45, 25, 15]);
      expect(
        weights([
          wallet(1, kind: SafetyWalletKind.watchOnly, balance: btc, txs: [_received]),
        ]),
        [10, 40, 30, 20],
      );
    });

    test('the weights combine the category scores', () {
      // 보기 전용만: 10 × 100 + 40 × 100 + 30 × 100 + 20 × 85 = 97
      final watchOnly = _evaluate([
        wallet(1, kind: SafetyWalletKind.watchOnly, balance: btc, txs: [_received], reused: ['a']),
      ], state: SafetyState(watchOnlyVerifications: {1: _verified(1)}));
      expect((watchOnly.score, watchOnly.label), (97, WalletHealthLabel.excellent));
      // 핫 1 + 보기 전용 0.5(노출도 2/3 → 25/45/18.75/11.25): 25 × 100 + 45 × 54 + 18.75 × 100 + 11.25 × 100 = 79.3
      final mixed = _evaluate([_hot(1), _watchOnly(2, balance: btc ~/ 2, used: true)]);
      expect((mixed.score, mixed.label), (79, WalletHealthLabel.good));
      // 핫만(30/45/15.625/9.375): 0 × 30 + 0 × 45 + 100 × 15.625 + 40 × 9.375 = 19.4
      final hot = _evaluate(
        [
          _hot(1, backup: false, reused: ['a', 'b', 'c', 'd'], dust: ['1', '2', '3', '4', '5']),
        ],
        appLock: false,
        update: AppUpdateStatus.available,
      );
      expect((hot.score, hot.label, hot.scoreCap), (19, WalletHealthLabel.actionNeeded, null));
    });

    test('renormalised over the scored categories; weightPercent is the share actually used', () {
      // 개인정보 점수 없음 → 30/45/15.625를 90.625로 나눔: (30 × 100 + 45 × 0 + 15.625 × 100) / 90.625 = 50.3
      final r = _evaluate([
        wallet(1, balance: btc, txs: [tx('s', height: 900)]),
      ]);
      expect((r.score, r.label), (50, WalletHealthLabel.needsAttention));
      expect(r.categories[SafetyCategory.app]!.weightPercent, closeTo(30 / 90.625 * 100, 1e-9));
      expect(r.categories[SafetyCategory.recovery]!.weightPercent, closeTo(45 / 90.625 * 100, 1e-9));
      expect(r.categories[SafetyCategory.activity]!.weightPercent, closeTo(15.625 / 90.625 * 100, 1e-9));
      expect(r.categories[SafetyCategory.privacy]!.weightPercent, 0);
    });

    test('app lock off keeps the score at 74 once a hot wallet holds 100,000 sats', () {
      // 30 × 20 + 70 × 100 = 76 → 상한 74
      final full = _evaluate([_hot(1)], appLock: false);
      expect((full.score, full.label, full.scoreCap), (74, WalletHealthLabel.needsAttention, 74));
      final justBelow = _evaluate([_hot(1, balance: 99999)], appLock: false);
      expect((justBelow.score, justBelow.scoreCap), (76, null));
      expect(_evaluate([_hot(1)]).scoreCap, isNull);
      // 콜드에 자금 대부분이 있어도 핫 잔액이 10만 이상이면 상한이 걸린다
      final mostlyCold = _evaluate(
        [_hot(1, balance: btc ~/ 100), _watchOnly(2, balance: btc, used: true)],
        state: SafetyState(watchOnlyVerifications: {2: _verified(2)}),
        appLock: false,
      );
      expect((mostlyCold.score, mostlyCold.scoreCap), (74, 74));
    });
  });

  group('outside the score', () {
    test('recommended checks, notes backup, server certificate and pending-at-baseline never change the score', () {
      final base = _evaluate([_hot(1)]).score;
      expect(base, 100);
      final noisy = _evaluate(
        [_hot(1)],
        state: SafetyState(
          baselines: {
            1: baseline(pendingSent: {'p'}),
          },
          recommendedDoneAt: {RecommendedCheckId.hotPhysicalBackup.key: testNow},
        ),
        tags: 3,
        cert: ServerCertObservation(
          applicable: true,
          pinned: 'aa',
          actual: 'aa',
          endValidity: testNow.subtract(const Duration(days: 1)),
          caValid: false,
        ),
      );
      expect(noisy.score, base);
      final changedCert = _evaluate([
        _hot(1),
      ], cert: const ServerCertObservation(applicable: true, pinned: 'aa', actual: 'bb', caValid: false));
      expect((changedCert.status, changedCert.score), (WalletHealthStatus.criticalOverride, base));
    });

    test(
      'outgoing at baseline (pending or recently confirmed): action needed until recognized, even after it confirms',
      () {
        final state = SafetyState(
          baselines: {
            1: baseline(pendingSent: {'p1', 'p2', 'p3', 'p4', 'gone'}),
          },
          recognizedTxids: const {'p3'},
          appTxidPrefixes: const {'p4'},
        );
        final w = wallet(
          1,
          balance: btc,
          backupVerified: true,
          txs: [tx('p1'), tx('p2', height: 1001), tx('p3'), tx('p4')],
        );
        final r = _evaluate([w], state: state);
        final item = _find(r, SafetyCheckId.pendingOutgoingAtBaseline, walletId: 1);
        // 확정된 p2도 남는다(레드팀 §2). 인지한 p3, 앱이 만든 p4, 지갑에 없는 거래는 빠진다
        expect(item.subjects, ['p1', 'p2']);
        expect(item.severity, SafetySeverity.actionNeeded);
        expect((r.actionNeededCount, r.attentionCount), (1, 1));
        final mine = _evaluate([w], state: state.copyWith(recognizedTxids: {'p1', 'p2', 'p3'}));
        expect(_all(mine).where((c) => c.id == SafetyCheckId.pendingOutgoingAtBaseline), isEmpty);
        // "모르는 거래예요"로 사건이 된 txid는 상태와 관계없이 검토 항목에서 빠진다
        for (final incident in [
          SafetyIncident(walletId: 1, txid: 'p1', detectedAt: testNow),
          SafetyIncident(
            walletId: 1,
            txid: 'p1',
            detectedAt: testNow,
          ).respond(IncidentResponseMode.free).complete(testNow),
        ]) {
          final r = _evaluate([w], state: state.copyWith(incidents: [incident]));
          final left = _all(r).where((c) => c.id == SafetyCheckId.pendingOutgoingAtBaseline);
          expect(left.single.subjects, ['p2'], reason: incident.state.name);
        }
      },
    );

    test('an own recorded payment pending at re-import never becomes a review item (R1-M2, no compaction)', () {
      // 지운 지갑에서 보낸 결제 t가 아직 대기 중일 때 같은 지갑을 다시 가져온다(새 id 2). 앱 생성 기록은 5000개를 넘는다
      final t = 'ef' * 32;
      var s = SafetyState(appTxidPrefixes: {SafetyState.txidPrefix(t), for (var i = 0; i < 5000; i++) 'other$i'});
      final pending = wallet(2, kind: SafetyWalletKind.watchOnly, balance: btc, txs: [tx(t)]);
      final confirmed = wallet(2, kind: SafetyWalletKind.watchOnly, balance: btc, txs: [tx(t, height: 1002)]);
      for (final (height, w) in [(1000, pending), (1001, pending), (1002, confirmed), (1003, confirmed)]) {
        s = IncidentDetector.detect(inputs(wallets: [w], state: s, height: height)).applyTo(s);
        final r = SafetyEngine.evaluate(inputs(wallets: [w], state: s, height: height));
        expect(_all(r).where((c) => c.id == SafetyCheckId.pendingOutgoingAtBaseline), isEmpty, reason: '$height');
        expect(r.criticalIncidents, isEmpty, reason: '$height');
      }
      expect(s.baselines[2]!.pendingSentAtBaseline, {t}, reason: 'kept for review if it were not ours');
      expect(s.isAppCreated(t), isTrue);
    });

    test('self transfers are never a review item, even ones an older version kept in the baseline', () {
      final state = SafetyState(
        baselines: {
          1: baseline(unexpectedSelf: {'s1'}),
        },
      );
      final w = wallet(
        1,
        balance: btc,
        backupVerified: true,
        txs: [tx('s1', type: TransactionType.self, height: 1001)],
      );
      final r = _evaluate([w], state: state);
      expect(_all(r).where((c) => c.id == SafetyCheckId.unexpectedSelfTransfer), isEmpty);
      expect((r.attentionCount, r.status), (0, WalletHealthStatus.scored));
    });

    test('notes & tags backup: none → not included; never exported or changed → recommended; same counts → done', () {
      expect(_find(_evaluate([_hot(1)]), SafetyCheckId.metadataBackup).reason, NotApplicableReason.noLabels);
      RecommendedItem item(SafetyState s, {int tags = 2, int memos = 1}) => _evaluate(
        [_hot(1)],
        state: s,
        tags: tags,
        memos: memos,
      ).recommended.singleWhere((i) => i.check?.id == SafetyCheckId.metadataBackup);
      final exported = SafetyState(metadataExport: (at: testNow, tagCount: 2, memoCount: 1));
      final never = item(const SafetyState());
      expect((never.done, never.check!.severity), (false, SafetySeverity.recommended));
      expect((never.check!.detail, never.check!.count), (SafetyCheckDetail.neverExported, null));
      expect(item(exported).done, isTrue);
      final changed = item(exported, tags: 3, memos: 0);
      expect(changed.done, isFalse);
      expect((changed.check!.detail, changed.check!.count), (SafetyCheckDetail.changed, 2));
    });

    test('server certificate: valid, expired, expiring within 30 days, identity change unless CA-valid', () {
      SafetyCheckResult cert({
        String pinned = 'AA:BB',
        String? actual = 'aabb',
        int? daysLeft = 100,
        bool caValid = false,
      }) => _find(
        _evaluate(
          [_hot(1)],
          cert: ServerCertObservation(
            applicable: true,
            pinned: pinned,
            actual: actual,
            endValidity: daysLeft == null ? null : testNow.add(Duration(days: daysLeft)),
            caValid: caValid,
          ),
        ),
        SafetyCheckId.serverCert,
      );
      expect(_find(_evaluate([_hot(1)]), SafetyCheckId.serverCert).reason, NotApplicableReason.notCustomServer);
      expect(cert().outcome, SafetyOutcome.passed, reason: 'fingerprint formatting is ignored');
      expect(cert(daysLeft: null).outcome, SafetyOutcome.passed);
      final expired = cert(daysLeft: -3);
      expect(
        (expired.severity, expired.detail, expired.count),
        (SafetySeverity.actionNeeded, SafetyCheckDetail.expired, 3),
      );
      final soon = cert(daysLeft: 10);
      expect((soon.severity, soon.detail, soon.count), (SafetySeverity.recommended, SafetyCheckDetail.expiresSoon, 10));
      expect(cert(daysLeft: 30).severity, SafetySeverity.recommended);
      expect(cert(daysLeft: 31).outcome, SafetyOutcome.passed);
      final changed = cert(actual: 'ccdd');
      expect((changed.severity, changed.detail), (SafetySeverity.critical, SafetyCheckDetail.identityChanged));
      expect(changed.subjects, ['AA:BB', 'ccdd']);
      expect(cert(actual: 'ccdd', caValid: true).outcome, SafetyOutcome.passed);
      expect(cert(actual: null).outcome, SafetyOutcome.unknown);
      // 만료 임박은 추천 목록에만
      final expiring = _evaluate(
        [_hot(1)],
        cert: ServerCertObservation(
          applicable: true,
          pinned: 'aa',
          actual: 'aa',
          endValidity: testNow.add(const Duration(days: 3)),
          caValid: true,
        ),
      );
      expect(expiring.reviewItems.where((i) => i.id == SafetyCheckId.serverCert), isEmpty);
      final today = _evaluate(
        [_hot(1)],
        cert: ServerCertObservation(
          applicable: true,
          pinned: 'aa',
          actual: 'aa',
          endValidity: testNow.add(const Duration(hours: 5)),
          caValid: true,
        ),
      );
      expect(_find(today, SafetyCheckId.serverCert).count, 0, reason: '0 = expires today');
      expect(expiring.recommended.where((i) => i.check?.id == SafetyCheckId.serverCert).single.done, isFalse);
    });

    test('recommended checks follow the wallet kinds and remember done', () {
      List<(RecommendedCheckId?, bool)> rec(
        List<SafetyWalletSnapshot> wallets, [
        SafetyState s = const SafetyState(),
      ]) => [
        for (final i in _evaluate(wallets, state: s).recommended)
          if (i.id != null) (i.id, i.done),
      ];
      expect(rec([_watchOnly(1)]), isEmpty);
      expect(
        rec([
          _hot(1, passphrase: true),
        ], SafetyState(recommendedDoneAt: {RecommendedCheckId.hotSafeStorage.key: testNow})),
        [
          (RecommendedCheckId.hotPhysicalBackup, false),
          (RecommendedCheckId.hotSafeStorage, true),
          (RecommendedCheckId.hotPassphraseOffline, false),
        ],
      );
      expect(
        rec([
          wallet(1, kind: SafetyWalletKind.multisig),
        ], SafetyState(metadataExport: (at: testNow, tagCount: 1, memoCount: 0))),
        [
          (RecommendedCheckId.multisigQuorumAccess, false),
          (RecommendedCheckId.multisigBackupSeparation, false),
          (RecommendedCheckId.metadataStoredOffsite, false),
        ],
      );
    });
  });

  test('hotPassphraseOffline: every hot wallet with funds or history, a stored passphrase is invisible (R14)', () {
    bool offered(List<SafetyWalletSnapshot> wallets) =>
        _evaluate(wallets).recommended.any((i) => i.id == RecommendedCheckId.hotPassphraseOffline);
    expect(offered([_hot(1)]), isTrue, reason: 'no passphrase on signing, funds');
    expect(offered([_hot(1, balance: 0)]), isTrue, reason: 'history only');
    expect(offered([_hot(1, passphrase: true)]), isTrue);
    expect(offered([wallet(1)]), isFalse, reason: 'no funds, no history');
    expect(offered([wallet(1, passphrase: true)]), isFalse, reason: 'empty even with a passphrase on signing');
    expect(offered([_watchOnly(1, balance: btc, used: true)]), isFalse);
  });

  test('review items: severity, then check order, then wallet (app first)', () {
    final r = _evaluate(
      [
        _hot(2, backup: false, reused: ['a']),
        _hot(1, backup: false),
      ],
      appLock: false,
      cert: const ServerCertObservation(applicable: true, pinned: 'aa', actual: 'bb', caValid: false),
    );
    expect(r.reviewItems.map((i) => (i.id, i.walletId, i.severity)), [
      (SafetyCheckId.serverCert, null, SafetySeverity.critical),
      (SafetyCheckId.appLock, null, SafetySeverity.actionNeeded),
      (SafetyCheckId.mnemonicBackup, 1, SafetySeverity.actionNeeded),
      (SafetyCheckId.mnemonicBackup, 2, SafetySeverity.actionNeeded),
      (SafetyCheckId.addressReuse, 2, SafetySeverity.warning),
    ]);
    expect(r.actionNeededCount, 3);
    expect(r.attentionCount, 4, reason: 'action needed + warning, not the critical certificate');
  });

  test('Premium is not an input: evaluate takes only SafetyInputs, and neither file knows the entitlement', () {
    const WalletHealthReport Function(SafetyInputs) evaluate = SafetyEngine.evaluate;
    expect(evaluate(inputs()).status, WalletHealthStatus.noWallet);
    for (final path in ['lib/services/safety/safety_engine.dart', 'lib/model/safety/safety_inputs.dart']) {
      final imports = File(path).readAsLinesSync().where((l) => l.startsWith('import '));
      expect(imports.where((l) => l.contains('premium') || l.contains('entitlement')), isEmpty, reason: path);
    }
  });

  test('same inputs → same report', () {
    final i = inputs(
      wallets: [
        _hot(1, reused: ['a']),
        _watchOnly(2, balance: 5000, used: true),
      ],
      tags: 1,
    );
    expect(SafetyEngine.evaluate(i), SafetyEngine.evaluate(i));
  });
}
