import 'dart:ui' as ui;

import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_inputs.dart';
import 'package:coconut_wallet/model/safety/safety_state.dart';
import 'package:coconut_wallet/model/safety/wallet_health_report.dart';
import 'package:coconut_wallet/screens/safety/wallet_health_screen.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/services/safety/safety_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/wallet_mock.dart';
import '../../model/safety/safety_fixtures.dart' as f;
import 'wallet_health_fixtures.dart' as wh;

/// 핫(백업 확인) + 보기 전용(QR 검증). 네 영역 모두 비중이 있고 앱 보호는 80(새 버전 있음)
WalletHealthReport _report() {
  final received = f.tx('r', type: TransactionType.received, height: 900);
  return SafetyEngine.evaluate(
    f.inputs(
      wallets: [
        f.wallet(1, balance: 17040000, backupVerified: true, txs: [received]),
        f.wallet(2, kind: SafetyWalletKind.watchOnly, balance: 82960000, txs: [received]),
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
      update: AppUpdateStatus.available,
    ),
  );
}

bool _isIncludedBox(Widget w) => '${w.runtimeType}' == '_IncludedBox';
bool _isFormula(Widget w) => '${w.runtimeType}' == '_ScoreFormula';

/// 글자마다 놓인 줄(줄 높이 상자의 위쪽 y). 폭이 없는 글자는 null
List<double?> _lineTops(RenderParagraph p) {
  final text = p.text.toPlainText();
  return [
    for (var i = 0; i < text.length; i++)
      p
          .getBoxesForSelection(
            TextSelection(baseOffset: i, extentOffset: i + 1),
            boxHeightStyle: ui.BoxHeightStyle.max,
          )
          .firstOrNull
          ?.top,
  ];
}

/// 단어 안의 이웃한 두 글자가 다른 줄에 놓인 곳("Readines|s"). 공백 앞뒤와 하이픈 뒤는 원래 끊을 수 있는 자리
List<String> _midWordBreaks(RenderParagraph p) {
  final text = p.text.toPlainText();
  final tops = _lineTops(p);
  final breaks = <String>[];
  int? previous;
  for (var i = 0; i < text.length; i++) {
    if (tops[i] == null) continue;
    final before = previous;
    previous = i;
    if (before == null || text[before].trim().isEmpty || text[i].trim().isEmpty || text[before] == '-') continue;
    if ((tops[before]! - tops[i]!).abs() > 0.5) breaks.add('${text.substring(0, i)}|${text.substring(i)}');
  }
  return breaks;
}

int _lineCount(RenderParagraph p) =>
    {
      for (final top in _lineTops(p))
        if (top != null) top.round(),
    }.length;

RenderParagraph _paragraphIn(WidgetTester tester, Element element) => tester.renderObject<RenderParagraph>(
  find.descendant(of: find.byWidget(element.widget), matching: find.byType(RichText)).first,
);

Future<void> _scrollAboutUntil(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 40 && target.evaluate().isEmpty; i++) {
    await tester.drag(find.byKey(const Key('wallet-health-about-sheet')), const Offset(0, -200));
    await tester.pumpAndSettle();
  }
}

/// M14: 비중이 "45%"에서 "45.0%"로 넓어지자 390dp·1.0×에서 "Recovery Readiness"가 "Readines|s"로 끊겼고, 2.0×에서는
/// 새 마지막 줄 이름 "Endbewertung"이 끊기고 결과 칸(40dp)의 "45.0"이 "45.|0"으로 갈라졌다. 실제 글꼴로 본다
/// (ja는 저장소에 글꼴이 없어 그림으로만 본다. 2.0×·320dp에서 계산식 줄의 영역 이름이 끊기는 것은 M14 전부터라 여기서 보지 않는다)
void main() {
  setUpAll(() async {
    for (final family in ['Pretendard', 'SpaceGrotesk']) {
      await (FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/$family-Bold.ttf')))
          .load();
    }
  });
  tearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  for (final locale in [AppLocale.ko, AppLocale.en, AppLocale.de, AppLocale.es]) {
    for (final width in [320.0, 390.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('category titles and the final row name keep words whole, results stay on one line: '
            '${locale.name} ${width.toInt()}dp ${scale}x', (tester) async {
          await wh.pumpWalletHealthApp(
            tester,
            const WalletHealthScreen(),
            report: _report(),
            width: width,
            textScale: scale,
            locale: locale,
            premium: const PremiumState(PremiumStatus.none),
            rescue: wh.FakeRescueReady(),
            wallets: [WalletMock.createSingleSigWalletItem(id: 1), WalletMock.createSingleSigWalletItem(id: 2)],
          );
          await tester.tap(find.byKey(const Key('wallet-health-info')));
          await tester.pumpAndSettle();

          final boxes = find.byWidgetPredicate(_isIncludedBox);
          await _scrollAboutUntil(tester, boxes);
          expect(boxes, findsNWidgets(4));
          for (final box in boxes.evaluate()) {
            final title = _paragraphIn(tester, box);
            expect(_midWordBreaks(title), isEmpty, reason: title.text.toPlainText());
          }

          final formula = find.byWidgetPredicate(_isFormula);
          await _scrollAboutUntil(tester, formula);
          final results = find.descendant(
            of: formula,
            matching: find.byWidgetPredicate((w) => w is Text && RegExp(r'^(\d+(\.\d)?|—)$').hasMatch(w.data ?? '')),
          );
          expect(results, findsAtLeastNWidgets(5));
          for (final result in results.evaluate()) {
            expect(_lineCount(_paragraphIn(tester, result)), 1, reason: (result.widget as Text).data);
          }
          final finalRow = find.ancestor(
            of: find.byKey(const Key('wallet-health-formula-final')),
            matching: find.byType(Row),
          );
          final finalName = _paragraphIn(
            tester,
            find.descendant(of: finalRow.first, matching: find.byType(Text)).evaluate().first,
          );
          expect(_midWordBreaks(finalName), isEmpty, reason: finalName.text.toPlainText());
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
