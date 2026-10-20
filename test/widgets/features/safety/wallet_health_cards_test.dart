import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_health_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../screens/safety/wallet_health_fixtures.dart';

/// 글자 찾기. 앱은 한국어 단어가 중간에서 끊기지 않게 글자 사이에 U+2060을 넣으므로(safetyKoText) 그 문자를 빼고 비교한다
Finder _text(String text) =>
    find.byWidgetPredicate((w) => w is Text && (w.data ?? w.textSpan?.toPlainText())?.replaceAll('\u2060', '') == text);

/// 글자 일부 찾기(U+2060 이음 문자를 빼고 비교)
Finder _textContaining(Pattern pattern) => find.byWidgetPredicate(
  (w) => w is Text && ((w.data ?? w.textSpan?.toPlainText())?.replaceAll('\u2060', '').contains(pattern) ?? false),
);

Color _textColor(WidgetTester tester, String text) => tester.widget<Text>(_text(text).first).style!.color!;

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
        expect(_text('80'), findsOneWidget);
        expect(_textColor(tester, t.wallet_health.category.addresses_reused(n: 2)), colors.warningText);
        expect(_textColor(tester, t.wallet_health.summary.items_need_attention(n: 1)), colors.warningText);
        expect(_text(t.wallet_health.summary.no_issues_found), findsNWidgets(2));
        expect(_textColor(tester, t.wallet_health.summary.no_issues_found), colors.success);

        await _pump(
          tester,
          WalletHealthCategoryGrid(report: noWalletReport(), isChecking: false, onTap: (_) {}),
          variant: variant,
        );
        expect(_text(t.wallet_health.category.available), findsOneWidget);
        expect(_text('100'), findsNothing); // 지갑 0개는 숫자 대신 "사용 가능"
        expect(_text(t.wallet_health.category.reason_add_wallet), findsOneWidget);
        expect(_textColor(tester, t.wallet_health.category.reason_add_wallet), colors.secondaryText);
        expect(_text(t.wallet_health.category.waiting), findsNWidgets(3));
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
        expect(_text(t.wallet_health.check.app_lock.issue), findsOneWidget);
        expect(_textColor(tester, t.wallet_health.cta.set_up), colors.warningText);
        await tester.tap(_text(t.wallet_health.check.app_lock.issue));
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

      testWidgets(
        'Free Premium card (C4): gem, three value lines, the whole card is the button, no monitoring promise',
        (tester) async {
          var taps = 0;
          await _pump(tester, WalletHealthPremiumCard(onTap: () => taps++), variant: variant);
          expect(find.byType(PremiumChip), findsNothing); // Premium 바탕 위에는 칩을 두지 않는다
          expect(find.byType(PremiumMark), findsOneWidget);
          expect(tester.widget<PremiumSurface>(find.byType(PremiumSurface)).ringWidth, 1);
          expect(_text(t.premium.card.point_prepare), findsOneWidget);
          expect(_text(t.premium.card.point_rescue), findsOneWidget);
          expect(_text(t.premium.card.point_guide), findsOneWidget);
          expect(_textColor(tester, t.premium.card.title), colors.primaryText);
          expect(_textColor(tester, t.premium.card.point_rescue), colors.secondaryTextStrong);
          for (final text in tester.widgetList<Text>(find.byType(Text))) {
            expect((text.data ?? '').replaceAll('\u2060', ''), isNot(contains('모니터링')));
          }
          // 안쪽 버튼은 없다: 카드 어디를 눌러도 같은 한 동작
          expect(find.byType(ShrinkAnimationButton), findsOneWidget);
          await tester.tap(_text(t.premium.card.point_rescue));
          await tester.pumpAndSettle();
          await tester.tap(_text(t.premium.card.explore));
          await tester.pumpAndSettle();
          expect(taps, 2);

          await _pump(tester, WalletHealthPremiumCard(critical: true, onTap: () {}), variant: variant);
          expect(tester.widget<PremiumSurface>(find.byType(PremiumSurface)).ringWidth, 0); // 위급(S3)은 링 없이
        },
      );
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
    expect(_text(t.wallet_health.hero.offline_line), findsOneWidget);
    expect(
      _text('${t.wallet_health.hero.wallets_checked(n: 2)} · ${t.wallet_health.hero.funded_wallets(n: 1)}'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('wallet-health-check-again')));
    expect(checks, 1);

    await _pump(tester, header(noWalletReport()));
    expect(find.byKey(const Key('wallet-health-check-again')), findsNothing);
    expect(_text(t.home_widgets.add_wallet), findsOneWidget);
    expect(_textContaining(t.wallet_health.hero.wallets_checked(n: 0)), findsNothing);
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
    // 지난 결과는 틀(크기)로만 남고 보이지 않는다(C14)
    expect(
      tester.widget<Visibility>(find.ancestor(of: _text('80'), matching: find.byType(Visibility))).visible,
      isFalse,
    );
    expect(_text(t.wallet_health.summary.checking), findsNWidgets(2)); // 게이지 라벨 + 버튼
  });

  testWidgets('C14: re-checking keeps each card the size of its last result (no layout jump)', (tester) async {
    Widget grid({required bool checking}) =>
        WalletHealthCategoryGrid(report: scoredReport(), isChecking: checking, onTap: (_) {});
    final card = find.byKey(const Key('wallet-health-category-recovery'));
    await _pump(tester, grid(checking: false));
    final settled = tester.getSize(card);
    await _pump(tester, grid(checking: true));
    expect(tester.getSize(card), settled);
    expect(find.descendant(of: card, matching: find.byKey(const Key('wallet-health-card-skeleton'))), findsOneWidget);
    // 첫 검사(결과 없음)는 스켈레톤만
    await _pump(tester, WalletHealthCategoryGrid(report: null, isChecking: true, onTap: (_) {}));
    expect(find.byType(Visibility), findsNothing);
  });

  testWidgets('C13: skeleton bars use surfaceMuted so they show on homeSurface (reduce motion too)', (tester) async {
    for (final variant in CoconutThemeVariant.values) {
      await _pump(tester, WalletHealthCategoryGrid(report: null, isChecking: true, onTap: (_) {}), variant: variant);
      final bar = tester.widget<Container>(
        find
            .descendant(
              of: find.byKey(const Key('wallet-health-card-skeleton')).first,
              matching: find.byType(Container),
            )
            .first,
      );
      expect(
        (bar.decoration! as BoxDecoration).color,
        resolveCoconutThemeExtension(variant: variant).colors.surfaceMuted,
      );
    }
  });

  testWidgets('C9/C22: the big value and the category name scale down on one line instead of wrapping', (tester) async {
    await _pump(tester, WalletHealthCategoryGrid(report: scoredReport(), isChecking: false, onTap: (_) {}));
    for (final text in ['80', safetyCategoryName(SafetyCategory.recovery)]) {
      final fitted = find.ancestor(of: _text(text), matching: find.byType(FittedBox));
      expect(fitted, findsOneWidget);
      expect(tester.widget<FittedBox>(fitted).fit, BoxFit.scaleDown);
    }
  });

  testWidgets('C6: the passed value sits at the right end of its row', (tester) async {
    await _pump(
      tester,
      const SafetyListCard(
        rows: [SafetyPassedRow(item: SafetyCheckResult(SafetyCheckId.appLock, SafetyOutcome.passed))],
      ),
    );
    final row = tester.getRect(find.byType(SafetyPassedRow));
    final value = tester.getRect(_text(t.wallet_health.check.app_lock.enabled));
    expect(value.right, closeTo(row.right - 20, 0.5)); // 행 안쪽 여백 20
    expect(tester.widget<Text>(_text(t.wallet_health.check.app_lock.enabled)).textAlign, TextAlign.end);
  });

  testWidgets('C25: icons and dots stay centred on the first line as text grows', (tester) async {
    final tops = <double>[];
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Builder(
            builder: (context) {
              tops.add(safetyFirstLineTop(context, CoconutTypography.body3_12, 14));
              return const SizedBox();
            },
          ),
        ),
      );
    }
    expect(tops[0], closeTo((12 * 1.4 - 14) / 2, 1e-9)); // 1.0×: 예전 고정값 2와 거의 같다
    expect(tops[1], closeTo((24 * 1.4 - 14) / 2, 1e-9));
  });

  testWidgets('C12: the not-included band text uses secondaryTextStrong in every theme', (tester) async {
    for (final variant in CoconutThemeVariant.values) {
      await _pump(
        tester,
        WalletHealthNotIncludedCard(items: const [], footer: t.wallet_health.section.not_included_footer_usage),
        variant: variant,
      );
      expect(
        _textColor(tester, t.wallet_health.section.not_included_footer_usage),
        resolveCoconutThemeExtension(variant: variant).colors.secondaryTextStrong,
      );
    }
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
    expect(_text(t.wallet_health.check.watch_only_verify.issue_mismatch), findsOneWidget);
    expect(_text(t.wallet_health.cta.rescan), findsOneWidget);
    expect(_text(t.wallet_health.check.bsms_backup.issue_update_required), findsOneWidget);
    expect(_text(t.wallet_health.check.recent_at_add.issue), findsOneWidget);
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
    expect(_text(t.wallet_health.check.self_transfer.issue), findsOneWidget);
    expect(_text(t.wallet_health.cta.review), findsOneWidget);
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
    expect(_text(t.wallet_health.check.mnemonic_backup.name), findsOneWidget);
    expect(_text(t.wallet_health.about.excluded_no_bitcoin), findsOneWidget);
    expect(_text(t.wallet_health.section.not_included_footer_usage), findsOneWidget);
  });

  testWidgets('C7: a long action label stays one line inside a capped pill instead of pushing the issue text', (
    tester,
  ) async {
    await _pump(tester, const SafetyActionPill(text: 'Escanear de nuevo otra vez'));
    expect(tester.getSize(find.byType(SafetyActionPill)).width, lessThanOrEqualTo(96 + 24)); // 글 96 + 좌우 여백
    expect(tester.widget<Text>(_text('Escanear de nuevo otra vez')).maxLines, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('C17: only the digits use the number font', (tester) async {
    const words = TextStyle(fontFamily: 'Body');
    const digits = TextStyle(fontFamily: 'Number');
    final spans = safetyNumberSpans('복구 86점', words, digits).children!.cast<TextSpan>();
    expect([for (final span in spans) span.text], ['복구 ', '86', '점']);
    expect([for (final span in spans) span.style!.fontFamily], ['Body', 'Number', 'Body']);
  });

  testWidgets('D23: with a 36 icon box the review text starts where the 36-circle incident rows start', (tester) async {
    const check = SafetyCheckResult(SafetyCheckId.appLock, SafetyOutcome.failed, severity: SafetySeverity.actionNeeded);
    double textStart() =>
        tester.getTopLeft(_text(safetyIssueText(check))).dx - tester.getTopLeft(find.byType(SafetyReviewRow)).dx;
    await _pump(tester, SafetyListCard(rows: [SafetyReviewRow(check: check, onTap: () {})]));
    final plain = textStart();
    await _pump(tester, SafetyListCard(rows: [SafetyReviewRow(check: check, onTap: () {}, iconBox: 36)]));
    // 알림 사건 줄과 같은 꼴: SafetyIconCircle 36 + spacing_300w 뒤에 글(16 아이콘 자리보다 20 오른쪽)
    expect(textStart(), plain + 20);
    final icon = find.descendant(of: find.byType(SafetyReviewRow), matching: find.byType(SvgPicture)).first;
    final rowLeft = tester.getTopLeft(find.byType(SafetyReviewRow)).dx;
    expect(tester.getCenter(icon).dx - rowLeft, textStart() - 12 - 18); // 36 자리 가운데
  });

  test('C44: an exported but unverified BSMS backup reads as such, not as never verified', () {
    const exported = SafetyCheckResult(
      SafetyCheckId.bsmsBackup,
      SafetyOutcome.failed,
      walletId: 2,
      severity: SafetySeverity.actionNeeded,
      detail: SafetyCheckDetail.exportedNotVerified,
    );
    final c = t.wallet_health.check.bsms_backup;
    expect(safetyIssueText(exported), c.issue_exported_not_verified);
    expect(safetyFailedResultText(exported), c.exported_not_verified);
    const never = SafetyCheckResult(SafetyCheckId.bsmsBackup, SafetyOutcome.failed, walletId: 2);
    expect(safetyFailedResultText(never), c.not_verified);
  });
}
