import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/info/inline_notice.dart';
import 'package:coconut_wallet/widgets/common/text/label_value_row.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Widget child, {double width = 320, double scale = 1}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, 800), textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => LocaleSettings.setLocaleRawSync('ko'));

  testWidgets('한국어 줄바꿈 막기는 보이는 글에만 하고 화면 읽기에는 원문을 준다', (tester) async {
    const label = '장기 보관 콜드 월렛';
    await _pump(
      tester,
      const LabelValueRow(label: label, labelStyle: TextStyle(fontSize: 14), value: '26.8%', valueStyle: TextStyle()),
    );
    final text = tester.widget<Text>(find.byWidgetPredicate((w) => w is Text && w.semanticsLabel == label));
    expect(text.data, contains('⁠'));
    expect(find.bySemanticsLabel(label), findsOneWidget);
  });

  testWidgets('이름과 값이 안 들어가면 값이 다음 줄로 가고 이름은 한 줄로 남는다', (tester) async {
    LocaleSettings.setLocaleRawSync('de');
    const label = 'Zieldatum';
    await _pump(
      tester,
      const LabelValueRow(
        label: label,
        labelStyle: TextStyle(fontSize: 12),
        value: '2027.06.30',
        valueStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        valueKey: Key('value'),
      ),
      // 테스트 글꼴은 글자마다 1em이라 이름 216px. 이름은 들어가지만(268) 이름 + 값(468)은 안 들어가는 폭
      width: 300,
      scale: 2,
    );
    final labelBox = tester.getRect(find.text(label));
    final valueBox = tester.getRect(find.byKey(const Key('value')));
    // 값이 이름 아래에 있고, 이름은 한 줄(줄 높이 하나)이다.
    expect(valueBox.top, greaterThanOrEqualTo(labelBox.bottom));
    expect(labelBox.height, lessThan(12 * 2 * 1.6));
  });

  testWidgets('안내 칸: 아이콘은 글 첫 줄에, 화면 읽기에는 원문, 버튼은 44 이상', (tester) async {
    const message = '기기 설정에서 이 앱의 알림이 꺼져 있어요';
    for (final width in [390.0, 220.0]) {
      await _pump(
        tester,
        InlineNotice(
          icon: CupertinoIcons.bell_slash,
          iconKey: const Key('icon'),
          message: message,
          actionLabel: '설정 열기',
          actionKey: const Key('action'),
          onAction: () {},
        ),
        width: width,
      );
      final text = tester.getRect(find.byWidgetPredicate((w) => w is Text && w.semanticsLabel == message));
      final iconBox = tester.getRect(find.byKey(const Key('icon')));
      final icon = tester.getRect(find.descendant(of: find.byKey(const Key('icon')), matching: find.byType(Icon)));
      expect(iconBox.top, closeTo(text.top, 0.5), reason: 'width $width');
      expect(icon.center.dy, closeTo(iconBox.center.dy, 0.5), reason: 'width $width');
      expect(find.bySemanticsLabel(message), findsOneWidget);
      expect(tester.getSize(find.byKey(const Key('action'))).height, greaterThanOrEqualTo(44));
    }
  });
}
