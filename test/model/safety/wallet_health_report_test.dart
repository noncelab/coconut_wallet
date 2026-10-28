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

  test('category weights: watch-only 10/40/30/20, hot 15→30 by exposure with Recovery fixed at 45', () {
    List<double> weights(CategoryWeights w) => [for (final c in SafetyCategory.values) w.weightOf(c)];
    expect(weights(CategoryWeights.watchOnly), [10, 40, 30, 20]);
    expect(weights(CategoryWeights.withHotWallet(0)), [15, 45, 25, 15]);
    expect(weights(CategoryWeights.withHotWallet(1)), [30, 45, 15.625, 9.375]);
  });

  test('report equality ignores evaluatedAt only', () {
    WalletHealthReport report(DateTime at, {int score = 80}) => WalletHealthReport(
      status: WalletHealthStatus.scored,
      score: score,
      label: WalletHealthLabel.of(score),
      evaluatedAt: at,
    );
    expect(report(DateTime(2026, 10, 20)), report(DateTime(2026, 10, 21)));
    expect(report(DateTime(2026, 10, 20)), isNot(report(DateTime(2026, 10, 20), score: 81)));
  });

  test('attentionCount = action needed + warning review items; actionNeededCount = action needed only', () {
    final report = WalletHealthReport(
      status: WalletHealthStatus.criticalOverride,
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
