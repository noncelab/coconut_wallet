import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/model/safety/safety_inputs.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_screen.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/services/safety/safety_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/wallet_mock.dart';
import '../../model/safety/safety_fixtures.dart' as f;
import 'wallet_health_fixtures.dart' as wh;

/// 핫(백업 확인) + 보기 전용(QR 검증), 둘 다 받은 거래 있음. 새 버전이 있으면 앱 보호 80, 나머지 100
WalletHealthReport _twoWallets({
  required int hotSats,
  required int watchSats,
  bool appLock = true,
  AppUpdateStatus update = AppUpdateStatus.available,
}) {
  final received = f.tx('r', type: TransactionType.received, height: 900);
  return SafetyEngine.evaluate(
    f.inputs(
      wallets: [
        f.wallet(1, balance: hotSats, backupVerified: true, txs: [received]),
        f.wallet(2, kind: SafetyWalletKind.watchOnly, balance: watchSats, txs: [received]),
      ],
      state: SafetyState(
        baselines: {1: f.baseline(), 2: f.baseline()},
        watchOnlyVerifications: {
          2: WatchOnlyVerification(
            method: VerificationMethod.qr,
            result: VerificationResult.match,
            descriptorHash: 'descriptor-2',
            at: f.testNow,
          ),
        },
      ),
      appLock: appLock,
      update: update,
    ),
  );
}

Future<void> _openFormula(
  WidgetTester tester,
  WalletHealthReport report, {
  double width = 390,
  double textScale = 1,
  AppLocale locale = AppLocale.ko,
}) async {
  await wh.pumpWalletHealthApp(
    tester,
    const WalletHealthScreen(),
    report: report,
    width: width,
    textScale: textScale,
    locale: locale,
    premium: const PremiumState(PremiumStatus.none),
    rescue: wh.FakeRescueReady(),
    wallets: [WalletMock.createSingleSigWalletItem(id: 1), WalletMock.createSingleSigWalletItem(id: 2)],
  );
  await tester.tap(find.byKey(const Key('wallet-health-info')));
  await tester.pumpAndSettle();
}

/// About 시트는 필요한 줄만 그리는 목록이라, [target]이 화면에 들 때까지(없으면 끝까지) 조금씩 내린다
Future<void> _scrollAboutTo(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 40 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.drag(find.byKey(const Key('wallet-health-about-sheet')), const Offset(0, -120));
    await tester.pumpAndSettle();
  }
}

Finder _inAbout(String text) =>
    find.descendant(of: find.byKey(const Key('wallet-health-about-sheet')), matching: find.text(text));

/// 계산식 줄의 값(상한·최종 점수). 그 줄이 없으면 null
String? _resultOf(WidgetTester tester, String key) {
  final value = find.byKey(Key(key));
  return value.evaluate().isEmpty ? null : tester.widget<Text>(value).data;
}

/// 화면 글에서 한국어 이음 문자(U+2060)를 뺀 것
String _plain(Text text) =>
    String.fromCharCodes((text.data ?? text.textSpan?.toPlainText() ?? '').runes.where((r) => r != 0x2060));

/// 계산식 줄(값에 [key])의 이름·값 글
List<Text> _rowTexts(WidgetTester tester, String key) => [
  ...tester.widgetList<Text>(
    find.descendant(
      of: find.ancestor(of: find.byKey(Key(key)), matching: find.byType(Row)).first,
      matching: find.byType(Text),
    ),
  ),
];

void main() {
  tearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  group('M12 "not enough data" note', () {
    // 자금·사용 기록이 없는 보기 전용 지갑은 점수 있는 영역이 2개여도 총점이 없다(엔진 조건: 활동 && 2개 이상)
    test('a fresh watch-only wallet has two scored categories but no score yet', () {
      final report = SafetyEngine.evaluate(
        f.inputs(
          wallets: [f.wallet(1, kind: SafetyWalletKind.watchOnly)],
          state: const SafetyState(),
          update: AppUpdateStatus.upToDate,
        ),
      );
      expect(report.status, WalletHealthStatus.notEnoughData);
      expect(report.score, isNull);
      expect(report.categories.values.where((c) => c.score != null).length, greaterThanOrEqualTo(2));
    });

    // 그래서 About 안내는 차례로 세 가지를 말한다: 활동(비트코인·잔액이나 거래 기록), 4개 영역 중 2개 이상, 그 전 점검도 영역별로 반영
    for (final (locale, meaning) in [
      (AppLocale.ko, ['비트코인이나 거래 기록이 있고', '4개 영역 중 2개 이상', '그 전에 한 점검도 영역별 결과에 반영']),
      (
        AppLocale.en,
        [
          'bitcoin or transaction history',
          'at least 2 of the 4 categories',
          'before then still count in each category',
        ],
      ),
      (AppLocale.ja, ['残高か取引履歴があり', '4つの分野のうち2つ以上', 'それまでに行ったチェックも分野ごとの結果に反映']),
      (
        AppLocale.es,
        [
          'bitcoin o historial de transacciones',
          'al menos 2 de las 4 categorías',
          'antes también cuentan en cada categoría',
        ],
      ),
      (
        AppLocale.de,
        ['Bitcoin oder einen Transaktionsverlauf', 'mindestens 2 der 4 Bereiche', 'vorher machst, zählen trotzdem'],
      ),
    ]) {
      test('says activity, 2 of 4 categories and earlier checks still count, in ${locale.name}', () {
        LocaleSettings.setLocaleSync(locale);
        expect(t.wallet_health.about.min_coverage, stringContainsInOrder(meaning));
      });
    }
  });

  group('M14 score formula', () {
    // Astra 반례: 비중 17.556%는 17.6%, 기여 14.0448은 14.0으로 보이지만 80 × 17.6% = 14.08. 마지막 줄은 엔진의 최종 점수
    testWidgets('shows the weight with one decimal and ends with the final score', (tester) async {
      final report = _twoWallets(hotSats: 17040000, watchSats: 82960000);
      expect(report.categories[SafetyCategory.app]!.weightPercent, closeTo(17.556, 0.001));
      await _openFormula(tester, report);
      final appRow = find.ancestor(of: _inAbout('80 × 17.6%'), matching: find.byType(Row)).first;
      expect(find.descendant(of: appRow, matching: find.text('14.0')), findsOneWidget);
      expect(_resultOf(tester, 'wallet-health-formula-final'), '${report.score}');
      expect(tester.takeException(), isNull);
    });

    // Codex 반례: 정확한 합계 96.4999. 예전 표는 합계 96.5와 머리 점수 96을 같이 보여 서로 어긋나 보였다
    testWidgets('no longer shows a rounded sum that disagrees with the header score', (tester) async {
      final report = _twoWallets(hotSats: 16670000, watchSats: 83330000);
      expect(report.score, 96);
      await _openFormula(tester, report);
      expect(_inAbout('96.5'), findsNothing);
      expect(_resultOf(tester, 'wallet-health-formula-final'), '96');
    });

    // 앱 잠금이 꺼져 있고 핫월렛에 10만 sats 이상이면 총점은 74로 묶인다: 상한 줄과 최종 점수를 따로 보인다
    testWidgets('a capped score shows the cap as its own row, then the final score', (tester) async {
      final report = _twoWallets(hotSats: 17040000, watchSats: 82960000, appLock: false);
      expect((report.scoreCap, report.score), (74, 74));
      await _openFormula(tester, report);
      expect(_resultOf(tester, 'wallet-health-formula-cap'), '74');
      expect(_resultOf(tester, 'wallet-health-formula-final'), '74');
      expect(_inAbout('74.0'), findsNothing);
    });

    // 상한 줄은 구분선 아래·최종 점수 줄 위에 있고, 굵은 글은 최종 점수 줄(이름·값)뿐
    testWidgets('the cap row sits between the divider and the final row, and only the final row is bold', (
      tester,
    ) async {
      await _openFormula(tester, _twoWallets(hotSats: 17040000, watchSats: 82960000, appLock: false));
      final formula = find.byWidgetPredicate((w) => '${w.runtimeType}' == '_ScoreFormula');
      double top(Finder finder) => tester.getTopLeft(finder).dy;
      final dividerTop = top(find.descendant(of: formula, matching: find.byType(Divider)));
      final capTop = top(find.byKey(const Key('wallet-health-formula-cap')));
      expect(capTop, greaterThan(dividerTop));
      expect(top(find.byKey(const Key('wallet-health-formula-final'))), greaterThan(capTop));

      final cap = _rowTexts(tester, 'wallet-health-formula-cap');
      final last = _rowTexts(tester, 'wallet-health-formula-final');
      expect(_plain(cap.first), t.wallet_health.about.formula_cap);
      final regular = CoconutTypography.body3_12, bold = CoconutTypography.body3_12_Bold;
      expect(bold.fontWeight, isNot(regular.fontWeight));
      expect([cap.first.style?.fontWeight, cap.last.style?.fontWeight], [regular.fontWeight, regular.fontWeight]);
      expect([last.first.style?.fontWeight, last.last.style?.fontWeight], [bold.fontWeight, bold.fontWeight]);
    });

    // Astra N1: 마지막 줄 이름과 반올림 안내를 언어마다 글자로 고정한다(예전 "합계"로 되돌리거나 안내를 빼면 잡힌다)
    for (final (locale, last, note) in [
      (AppLocale.ko, '최종 점수', ['반올림해 보여 주는 근삿값', '반올림 전 값으로 계산한 최종 점수']),
      (AppLocale.en, 'Final score', ['rounded for display', 'final score, which uses the unrounded values']),
      (AppLocale.ja, '最終スコア', ['四捨五入した概算値', '四捨五入前の値で計算する最終スコア']),
      (AppLocale.es, 'Puntuación final', ['se muestran redondeados', 'que usa los valores sin redondear']),
      (AppLocale.de, 'Endbewertung', ['gerundet angezeigt', 'mit den ungerundeten Werten berechnet']),
    ]) {
      testWidgets('the last row is "$last" and the note says weights are rounded (${locale.name})', (tester) async {
        await _openFormula(tester, _twoWallets(hotSats: 17040000, watchSats: 82960000), locale: locale);
        expect(_plain(_rowTexts(tester, 'wallet-health-formula-final').first), last);
        final noteText = find.descendant(
          of: find.byKey(const Key('wallet-health-about-sheet')),
          matching: find.byWidgetPredicate((w) => w is Text && _plain(w).contains(note.first)),
        );
        await _scrollAboutTo(tester, noteText);
        expect(_plain(tester.widget<Text>(noteText)), stringContainsInOrder(note));
      });
    }

    for (final locale in [AppLocale.ko, AppLocale.de]) {
      testWidgets('fits a 320 dp screen at 2.0× text in ${locale.name}', (tester) async {
        final report = _twoWallets(hotSats: 17040000, watchSats: 82960000, appLock: false);
        await _openFormula(tester, report, width: 320, textScale: 2, locale: locale);
        await _scrollAboutTo(tester, find.byKey(const Key('wallet-health-formula-final')));
        expect(find.byKey(const Key('wallet-health-formula-final')).hitTestable(), findsOneWidget);
        expect(find.byKey(const Key('wallet-health-formula-cap')).hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
