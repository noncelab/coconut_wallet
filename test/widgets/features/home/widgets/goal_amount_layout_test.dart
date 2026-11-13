import 'dart:io';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_amount_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/goal_plan_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 글꼴을 불러온다. 기본 테스트 글꼴은 글자 폭이 달라 넘침을 숨긴다.
Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync())));
  }
  await loader.load();
}

/// 지갑 이름 칸이 받는 길이(20자)에 가까운 이름
const _names = ['장기 보관용 콜드 월렛 지갑입니다', 'Long-term cold store', 'Langfristige Reserve'];

Future<void> _pump(
  WidgetTester tester, {
  required String locale,
  required double scale,
  required double width,
  required Widget child,
}) async {
  LocaleSettings.setLocaleRawSync(locale);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 2000);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    await _font('Pretendard', ['Pretendard-Regular.ttf', 'Pretendard-Bold.ttf']);
    await _font('SpaceGrotesk', [
      'SpaceGrotesk-Light.ttf',
      'SpaceGrotesk-Regular.ttf',
      'SpaceGrotesk-Medium.ttf',
      'SpaceGrotesk-Bold.ttf',
    ]);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsRepository().init();
  });

  for (final locale in AppLocale.values) {
    for (final scale in [1.0, 2.0]) {
      final label = '${locale.languageCode}, ${scale}x, 320 wide';

      testWidgets('goal legend with long wallet names stays inside the card ($label)', (tester) async {
        final shares = [
          for (var i = 0; i < _names.length; i++)
            HomeGoalShare(
              walletId: i + 1,
              name: _names[i],
              balance: [12000000, 30000000, 3500000][i],
              target: [50000000, 100000000, 20000000][i],
              colorIndex: i * 3,
            ),
        ];
        await _pump(
          tester,
          locale: locale.languageCode,
          scale: scale,
          width: 320,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GoalAmountSummary(
              goal: HomeSavingsGoal(
                balance: shares.fold(0, (sum, share) => sum + share.balance),
                target: shares.fold(0, (sum, share) => sum + share.target!),
              ),
              shares: shares,
              amountNumber: (sats) => '$sats',
              amountText: (sats) => '$sats sats',
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        // 범례는 색 점과 이름만 보인다. %는 진행 줄의 달성률 하나뿐이다.
        expect(find.textContaining('%'), findsOneWidget);
        for (final name in _names) {
          expect(find.text(name), findsOneWidget);
        }
      });

      testWidgets('saving plan card stays inside the screen ($label)', (tester) async {
        await _pump(
          tester,
          locale: locale.languageCode,
          scale: scale,
          width: 320,
          child: GoalPlanCard(
            remainingSats: 123456789,
            clock: () => DateTime(2026, 11, 12),
            amountText: (sats) => '$sats sats',
            fiatText: (_) => '₩ 1,234,567',
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('goal bar with tiny balances does not overflow while it fills', (tester) async {
    for (final reveal in [0.001, 0.5, 1.0]) {
      await _pump(
        tester,
        locale: 'en',
        scale: 1,
        width: 332,
        child: GoalSegmentsBar(
          shares: const [
            HomeGoalShare(walletId: 1, name: 'A', balance: 1, target: 100000000, colorIndex: 0),
            HomeGoalShare(walletId: 2, name: 'B', balance: 1, target: 100000000, colorIndex: 3),
          ],
          target: 200000000,
          reveal: reveal,
        ),
      );
      expect(tester.takeException(), isNull, reason: 'reveal $reveal');
    }
  });

  testWidgets('a normal goal bar keeps a 2px gap between wallets', (tester) async {
    await _pump(
      tester,
      locale: 'en',
      scale: 1,
      width: 332,
      child: const GoalSegmentsBar(
        shares: [
          HomeGoalShare(walletId: 1, name: 'A', balance: 100000000, target: 100000000, colorIndex: 0),
          HomeGoalShare(walletId: 2, name: 'B', balance: 100000000, target: 100000000, colorIndex: 3),
        ],
        target: 200000000,
      ),
    );
    final first = tester.getRect(find.byKey(const ValueKey('goal-segment-1')));
    final second = tester.getRect(find.byKey(const ValueKey('goal-segment-2')));
    expect(second.left - first.right, closeTo(GoalSegmentsBar.segmentGap, 0.001));
    expect(first.width, closeTo(149, 0.001));
    expect(second.width, closeTo(149, 0.001));
  });

  testWidgets('goal bar with no, one or many wallets does not overflow at any fill', (tester) async {
    for (final wallets in [0, 1, 5]) {
      for (final reveal in [0.0, 0.001, 0.5, 1.0]) {
        await _pump(
          tester,
          locale: 'en',
          scale: 1,
          width: 332,
          child: GoalSegmentsBar(
            shares: [
              for (var i = 0; i < wallets; i++)
                HomeGoalShare(walletId: i + 1, name: '$i', balance: 1, target: 40000000, colorIndex: i),
            ],
            target: 200000000,
            reveal: reveal,
          ),
        );
        expect(tester.takeException(), isNull, reason: '$wallets wallets, reveal $reveal');
      }
    }
  });
}
