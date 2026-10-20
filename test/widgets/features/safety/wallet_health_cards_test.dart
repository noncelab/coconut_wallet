import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_health_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../screens/safety/wallet_health_fixtures.dart';

Color _textColor(WidgetTester tester, String text) => tester.widget<Text>(find.text(text).first).style!.color!;

Future<void> _pump(WidgetTester tester, Widget child, {CoconutThemeVariant variant = CoconutThemeVariant.light}) =>
    pumpWalletHealthApp(tester, Scaffold(body: SingleChildScrollView(child: child)), variant: variant, width: 320);

void main() {
  for (final variant in CoconutThemeVariant.values) {
    final colors = resolveCoconutThemeExtension(variant: variant).colors;

    group(variant.name, () {
      testWidgets('category cards: score + biggest cause, waiting reason, no-wallet "사용 가능"', (tester) async {
        await _pump(
          tester,
          WalletHealthCategoryGrid(report: scoredReport(), isChecking: false, onTap: (_) {}),
          variant: variant,
        );
        expect(find.text('80'), findsOneWidget);
        expect(_textColor(tester, t.wallet_health.category.addresses_reused(n: 2)), colors.warningText);
        expect(_textColor(tester, t.wallet_health.summary.items_need_attention(n: 1)), colors.warningText);
        expect(find.text(t.wallet_health.summary.no_issues_found), findsNWidgets(2));
        expect(_textColor(tester, t.wallet_health.summary.no_issues_found), colors.success);

        await _pump(
          tester,
          WalletHealthCategoryGrid(report: noWalletReport(), isChecking: false, onTap: (_) {}),
          variant: variant,
        );
        expect(find.text(t.wallet_health.category.available), findsOneWidget);
        expect(find.text('100'), findsNothing); // 지갑 0개는 숫자 대신 "사용 가능"
        expect(find.text(t.wallet_health.category.reason_add_wallet), findsOneWidget);
        expect(_textColor(tester, t.wallet_health.category.reason_add_wallet), colors.secondaryText);
        expect(find.text(t.wallet_health.category.waiting), findsNWidgets(3));
      });

      testWidgets('review row: warning icon, issue text, pill; the whole row is the button', (tester) async {
        var taps = 0;
        const item = SafetyCheckResult(
          SafetyCheckId.appLock,
          SafetyOutcome.failed,
          severity: SafetySeverity.actionNeeded,
        );
        await _pump(
          tester,
          SafetyListCard(rows: [SafetyReviewRow(check: item, onTap: () => taps++)]),
          variant: variant,
        );
        expect(find.text(t.wallet_health.check.app_lock.issue), findsOneWidget);
        expect(_textColor(tester, t.wallet_health.cta.set_up), colors.warningText);
        await tester.tap(find.text(t.wallet_health.check.app_lock.issue));
        await tester.pumpAndSettle();
        expect(taps, 1);
      });

      testWidgets('passed row: verified is green, completed-by-you is grey', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pump(
          tester,
          const SafetyListCard(
            rows: [
              SafetyPassedRow(item: SafetyCheckResult(SafetyCheckId.appLock, SafetyOutcome.passed)),
              SafetyPassedRow(
                item: SafetyCheckResult(
                  SafetyCheckId.watchOnlyVerify,
                  SafetyOutcome.passed,
                  walletId: 1,
                  evidence: SafetyEvidence.userConfirmed,
                  points: 60,
                ),
              ),
            ],
          ),
          variant: variant,
        );
        expect(_textColor(tester, t.wallet_health.check.app_lock.enabled), colors.success);
        expect(_textColor(tester, t.wallet_health.evidence.completed_by_you), colors.secondaryText);
        // 색만으로 구분하지 않게 체크 아이콘에도 의미 라벨
        expect(find.bySemanticsLabel(t.wallet_health.evidence.verified_a11y), findsOneWidget);
        expect(find.bySemanticsLabel(t.wallet_health.evidence.completed_by_you_a11y), findsOneWidget);
        semantics.dispose();
      });

      testWidgets('Free Premium card: chip, three value lines, no monitoring promise', (tester) async {
        var taps = 0;
        await _pump(tester, WalletHealthPremiumCard(onTap: () => taps++), variant: variant);
        expect(find.byType(PremiumChip), findsOneWidget);
        expect(find.text(t.premium.card.point_prepare), findsOneWidget);
        expect(find.text(t.premium.card.point_rescue), findsOneWidget);
        expect(find.text(t.premium.card.point_guide), findsOneWidget);
        expect(_textColor(tester, t.premium.card.title), colors.premiumText);
        for (final text in tester.widgetList<Text>(find.byType(Text))) {
          expect(text.data ?? '', isNot(contains('모니터링')));
        }
        await tester.tap(find.text(t.premium.card.explore));
        await tester.pumpAndSettle();
        expect(taps, 1);
      });
    });
  }

  testWidgets('header card: check again normally, add wallet when there is no wallet, offline note', (tester) async {
    var checks = 0, adds = 0;
    Widget header(WalletHealthReport report) => WalletHealthHeaderCard(
      report: report,
      isChecking: false,
      onCheckAgain: () => checks++,
      onAddWallet: () => adds++,
    );

    await _pump(tester, header(scoredReport(connected: false)));
    expect(find.byKey(const Key('wallet-health-add-wallet')), findsNothing);
    expect(find.text(t.wallet_health.hero.offline_line), findsOneWidget);
    expect(
      find.text('${t.wallet_health.hero.wallets_checked(n: 2)} · ${t.wallet_health.hero.funded_wallets(n: 1)}'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('wallet-health-check-again')));
    expect(checks, 1);

    await _pump(tester, header(noWalletReport()));
    expect(find.byKey(const Key('wallet-health-check-again')), findsNothing);
    expect(find.text(t.home_widgets.add_wallet), findsOneWidget);
    expect(find.textContaining(t.wallet_health.hero.wallets_checked(n: 0)), findsNothing);
    await tester.tap(find.byKey(const Key('wallet-health-add-wallet')));
    expect(adds, 1);
  });

  testWidgets('checking turns the cards into skeletons and disables check again', (tester) async {
    await _pump(
      tester,
      Column(
        children: [
          WalletHealthHeaderCard(report: scoredReport(), isChecking: true, onCheckAgain: () {}, onAddWallet: () {}),
          WalletHealthCategoryGrid(report: scoredReport(), isChecking: true, onTap: (_) {}),
        ],
      ),
    );
    expect(find.byKey(const Key('wallet-health-card-skeleton')), findsNWidgets(4));
    expect(find.text('80'), findsNothing);
    expect(find.text(t.wallet_health.summary.checking), findsNWidgets(2)); // 게이지 라벨 + 버튼
  });

  testWidgets('review copy comes from the engine detail: rescan, BSMS update, cert days, notes changed', (
    tester,
  ) async {
    const rows = [
      SafetyCheckResult(
        SafetyCheckId.watchOnlyVerify,
        SafetyOutcome.failed,
        walletId: 1,
        severity: SafetySeverity.actionNeeded,
        detail: SafetyCheckDetail.mismatch,
      ),
      SafetyCheckResult(
        SafetyCheckId.bsmsBackup,
        SafetyOutcome.failed,
        walletId: 2,
        severity: SafetySeverity.actionNeeded,
        detail: SafetyCheckDetail.updateRequired,
      ),
      SafetyCheckResult(
        SafetyCheckId.pendingOutgoingAtBaseline,
        SafetyOutcome.failed,
        walletId: 1,
        severity: SafetySeverity.actionNeeded,
        subjects: ['tx'],
      ),
    ];
    await _pump(tester, SafetyListCard(rows: [for (final c in rows) SafetyReviewRow(check: c, onTap: () {})]));
    expect(find.text(t.wallet_health.check.watch_only_verify.issue_mismatch), findsOneWidget);
    expect(find.text(t.wallet_health.cta.rescan), findsOneWidget);
    expect(find.text(t.wallet_health.check.bsms_backup.issue_update_required), findsOneWidget);
    expect(find.text(t.wallet_health.check.recent_at_add.issue), findsOneWidget);
    expect(
      safetyIssueText(
        const SafetyCheckResult(
          SafetyCheckId.metadataBackup,
          SafetyOutcome.failed,
          severity: SafetySeverity.recommended,
          detail: SafetyCheckDetail.changed,
          count: 3,
        ),
      ),
      t.wallet_health.check.metadata_backup.changed(n: 3),
    );
  });

  testWidgets('self-transfer made outside Coconut reads as a review item with a review pill', (tester) async {
    const check = SafetyCheckResult(
      SafetyCheckId.unexpectedSelfTransfer,
      SafetyOutcome.failed,
      walletId: 1,
      severity: SafetySeverity.actionNeeded,
      subjects: ['tx'],
    );
    await _pump(tester, SafetyListCard(rows: [SafetyReviewRow(check: check, onTap: () {})]));
    expect(find.text(t.wallet_health.check.self_transfer.issue), findsOneWidget);
    expect(find.text(t.wallet_health.cta.review), findsOneWidget);
    expect(safetyCheckName(check.id), t.wallet_health.check.self_transfer.name);
    expect(
      safetyPassedText(const SafetyCheckResult(SafetyCheckId.unexpectedSelfTransfer, SafetyOutcome.passed)).text,
      t.wallet_health.check.none_found,
    );
  });

  testWidgets('not-included card lists waiting checks with reasons and the grey band', (tester) async {
    await _pump(
      tester,
      WalletHealthNotIncludedCard(
        items: notEnoughDataReport().notIncluded.take(2).toList(),
        footer: t.wallet_health.section.not_included_footer_usage,
      ),
    );
    expect(find.text(t.wallet_health.check.mnemonic_backup.name), findsOneWidget);
    expect(find.text(t.wallet_health.about.excluded_no_bitcoin), findsOneWidget);
    expect(find.text(t.wallet_health.section.not_included_footer_usage), findsOneWidget);
  });
}
