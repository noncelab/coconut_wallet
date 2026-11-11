import 'dart:math' as math;

import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/safety/safety_check.dart';
import 'package:coconut_wallet/widgets/features/safety/wallet_health_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../screens/safety/wallet_health_fixtures.dart';

List<TextBox> _boxes(RenderParagraph p) =>
    p.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: p.text.toPlainText().length));

/// 글자가 그려진 가로 범위(전역 좌표). FittedBox로 줄인 제목도 그대로 잰다
(double, double) _ink(RenderParagraph p) {
  final boxes = _boxes(p);
  final left = boxes.map((b) => b.left).reduce(math.min);
  final right = boxes.map((b) => b.right).reduce(math.max);
  return (p.localToGlobal(Offset(left, 0)).dx, p.localToGlobal(Offset(right, 0)).dx);
}

int _lines(RenderParagraph p) => _boxes(p).map((b) => b.top.round()).toSet().length;

/// 지갑 점검 화면처럼 양옆 16 · 카드 사이 12로 카테고리 카드 네 개를 그린다(한국어)
Future<void> _pumpGrid(WidgetTester tester, double width, {bool isChecking = false}) => pumpWalletHealthApp(
  tester,
  Scaffold(
    body: SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: WalletHealthCategoryGrid(report: scoredReport(), isChecking: isChecking, onTap: (_) {}),
      ),
    ),
  ),
  width: width,
);

// 앱 글꼴로 잰다(줄바꿈은 글꼴 폭에 달려 있다). 다른 테스트 파일의 글꼴에 영향이 없게 파일을 따로 둔다
void main() {
  setUpAll(() async {
    for (final family in ['Pretendard', 'SpaceGrotesk']) {
      await (FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/$family-Bold.ttf')))
          .load();
    }
  });

  // 맥스 11/11(B안): 카테고리 카드 네 개 모두 아이콘·제목 묶음, 숫자, 상태 글이 카드 가운데에 그려진다(전에는 왼쪽 위,
  // 숫자·상태는 28 들여씀). 320dp에서도 "주소 재사용 2건"은 한 줄(전에는 들여쓰기로 글 칸이 76이라 두 줄).
  // 한국어, 화면처럼 양옆 16 · 카드 사이 12
  for (final width in [390.0, 320.0]) {
    testWidgets('at ${width.toInt()} dp every category card centers its icon and title, score and status', (
      tester,
    ) async {
      await _pumpGrid(tester, width);
      // 어긋난 곳을 모아 한 번에 본다(카드 · 부분 · 카드 가운데에서 벗어난 px)
      final off = <String>[];
      for (final category in SafetyCategory.values) {
        final card = find.byKey(Key('wallet-health-category-${category.name}'));
        final center = tester.getRect(card).center.dx;
        void check(String part, double x) {
          if ((x - center).abs() > 1) off.add('${category.name} $part ${(x - center).toStringAsFixed(1)}');
        }

        // 제목 · 숫자 · 상태 순서
        final texts =
            tester
                .renderObjectList<RenderParagraph>(find.descendant(of: card, matching: find.byType(RichText)))
                .toList();
        expect(texts, hasLength(3), reason: category.name);
        final icon = tester.getRect(find.descendant(of: card, matching: find.byType(SvgPicture)));
        check('icon+title', (icon.left + _ink(texts[0]).$2) / 2);
        check('score', (_ink(texts[1]).$1 + _ink(texts[1]).$2) / 2);
        check('status', (_ink(texts[2]).$1 + _ink(texts[2]).$2) / 2);
        if (category == SafetyCategory.privacy) {
          expect(texts[2].text.toPlainText().replaceAll('\u2060', ''), t.wallet_health.category.addresses_reused(n: 2));
          if (_lines(texts[2]) != 1) off.add('privacy status lines ${_lines(texts[2])}');
        }
      }
      expect(off, isEmpty);
    });

    // 맥스 11/11(11-7): 다시 검사하는 동안 카드를 덮는 자리표시 막대 세 개도 카드 가운데에 둔다(전에는 왼쪽 정렬)
    testWidgets('at ${width.toInt()} dp the re-check skeleton bars sit in the middle of every category card', (
      tester,
    ) async {
      await _pumpGrid(tester, width, isChecking: true);
      final off = <String>[];
      for (final category in SafetyCategory.values) {
        final card = find.byKey(Key('wallet-health-category-${category.name}'));
        final center = tester.getRect(card).center.dx;
        final bars = find.descendant(
          of: find.descendant(of: card, matching: find.byKey(const Key('wallet-health-card-skeleton'))),
          matching: find.byType(Container),
        );
        expect(bars, findsNWidgets(3), reason: category.name);
        for (var i = 0; i < 3; i++) {
          final x = tester.getRect(bars.at(i)).center.dx;
          if ((x - center).abs() > 1) off.add('${category.name} bar$i ${(x - center).toStringAsFixed(1)}');
        }
      }
      expect(off, isEmpty);
    });
  }
}
