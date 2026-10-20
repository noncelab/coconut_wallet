import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/features/home/add_wallet_hint.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 무한 애니메이션 등으로 멈추면 공유 레인을 오래 잡지 않게
const _timeout = Timeout(Duration(seconds: 60));

/// 말풍선은 단어 안에서 줄이 안 바뀌게 글자 사이에 단어 결합 문자를 넣는다
Finder _text(String text) => find.text(TextUtils.preventLineBreakInsideWords(text));

Future<void> _pump(WidgetTester tester, AddWalletHint hint) => tester.pumpWidget(
  MaterialApp(theme: buildCoconutThemeData(), home: Scaffold(body: Align(alignment: Alignment.topLeft, child: hint))),
);

void main() {
  testWidgets('the wallet health hint reuses the bubble with its own copy, a left tail and a labelled close', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var closed = 0;
    await _pump(
      tester,
      AddWalletHint(
        title: t.wallet_health.first_hint.title,
        description: t.wallet_health.first_hint.description,
        closeLabel: t.wallet_health.first_hint.close_a11y,
        tailFromRight: AddWalletHint.width - 16,
        nudges: 0,
        onClose: () => closed++,
      ),
    );

    expect(_text(t.wallet_health.first_hint.title), findsOneWidget);
    expect(_text(t.wallet_health.first_hint.description), findsOneWidget);
    expect(_text(t.add_wallet_hint.title), findsNothing);
    final tail = find.descendant(of: find.byType(AddWalletHint), matching: find.byType(CustomPaint)).first;
    expect(tester.getRect(tail).center.dx - tester.getRect(find.byType(AddWalletHint)).left, 16);

    await tester.tap(find.bySemanticsLabel(t.wallet_health.first_hint.close_a11y));
    expect(closed, 1);
    handle.dispose();
  }, timeout: _timeout);

  testWidgets('the add wallet hint keeps its copy when no text is given', (tester) async {
    await _pump(tester, AddWalletHint(tailFromRight: 24, nudges: 0, onClose: () {}));
    expect(_text(t.add_wallet_hint.title), findsOneWidget);
    expect(_text(t.add_wallet_hint.description), findsOneWidget);
  }, timeout: _timeout);
}
