import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('label cut points 90 / 75 / 50', () {
    expect(WalletHealthLabel.of(100), WalletHealthLabel.excellent);
    expect(WalletHealthLabel.of(90), WalletHealthLabel.excellent);
    expect(WalletHealthLabel.of(89), WalletHealthLabel.good);
    expect(WalletHealthLabel.of(75), WalletHealthLabel.good);
    expect(WalletHealthLabel.of(74), WalletHealthLabel.needsAttention);
    expect(WalletHealthLabel.of(50), WalletHealthLabel.needsAttention);
    expect(WalletHealthLabel.of(49), WalletHealthLabel.actionNeeded);
    expect(WalletHealthLabel.of(0), WalletHealthLabel.actionNeeded);
  });

  test('weight profiles are 20/45/25/10, 10/40/30/20, 15/45/25/15', () {
    List<int> weights(WeightProfile p) => [for (final c in SafetyCategory.values) p.weightOf(c)];
    expect(weights(WeightProfile.hotFunded), [20, 45, 25, 10]);
    expect(weights(WeightProfile.watchOnlyOnly), [10, 40, 30, 20]);
    expect(weights(WeightProfile.mixed), [15, 45, 25, 15]);
  });

  test('report equality ignores evaluatedAt only', () {
    WalletHealthReport report(DateTime at, {int score = 80}) => WalletHealthReport(
      status: WalletHealthStatus.scored,
      score: score,
      label: WalletHealthLabel.of(score),
      profile: WeightProfile.hotFunded,
      evaluatedAt: at,
    );
    expect(report(DateTime(2026, 10, 20)), report(DateTime(2026, 10, 21)));
    expect(report(DateTime(2026, 10, 20)), isNot(report(DateTime(2026, 10, 20), score: 81)));
  });

  test('attentionCount = action needed + warning review items; actionNeededCount = action needed only', () {
    final report = WalletHealthReport(
      status: WalletHealthStatus.criticalOverride,
      profile: WeightProfile.hotFunded,
      evaluatedAt: DateTime(2026, 10, 20),
      reviewItems: const [
        SafetyCheckResult(SafetyCheckId.serverCert, SafetyOutcome.failed, severity: SafetySeverity.critical),
        SafetyCheckResult(SafetyCheckId.appLock, SafetyOutcome.failed, severity: SafetySeverity.actionNeeded),
        SafetyCheckResult(
          SafetyCheckId.addressReuse,
          SafetyOutcome.failed,
          walletId: 1,
          severity: SafetySeverity.warning,
        ),
        SafetyCheckResult(SafetyCheckId.metadataBackup, SafetyOutcome.failed, severity: SafetySeverity.recommended),
      ],
    );
    expect((report.attentionCount, report.actionNeededCount), (2, 1));
  });

  test('keys', () {
    expect(const SafetyCheckResult(SafetyCheckId.appLock, SafetyOutcome.passed).key, 'check:appLock:app');
    expect(
      const SafetyCheckResult(SafetyCheckId.mnemonicBackup, SafetyOutcome.failed, walletId: 3).key,
      'check:mnemonicBackup:3',
    );
    expect(RecommendedCheckId.hotPhysicalBackup.key, 'rec.hotPhysicalBackup');
  });

  test('baseline review items, server certificate and metadata are outside the score', () {
    expect(
      [
        for (final id in SafetyCheckId.values)
          if (id.category == null) id,
      ],
      [
        SafetyCheckId.pendingOutgoingAtBaseline,
        SafetyCheckId.unexpectedSelfTransfer,
        SafetyCheckId.serverCert,
        SafetyCheckId.metadataBackup,
      ],
    );
  });
}
