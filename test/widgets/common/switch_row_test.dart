import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/switch_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {required bool value, ValueChanged<bool>? onChanged}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home: Scaffold(
        body: SwitchRow(
          key: const Key('row'),
          title: '알림에 모을 수량 보여 주기',
          subtitle: '켜면 잠금 화면에서도 수량이 보여요',
          value: value,
          switchKey: const Key('switch'),
          onChanged: onChanged,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// 줄의 의미 노드(제목·보조 글이 원문으로 들어 있는 노드)
SemanticsNode _node(WidgetTester tester) => tester.getSemantics(find.byKey(const Key('row')));

void main() {
  setUp(() => LocaleSettings.setLocaleRawSync('ko'));

  testWidgets('쓸 수 있을 때: 줄 하나가 원문 제목·켜짐·눌림을 갖고, 글이나 스위치를 눌러도 한 번만 바뀐다', (tester) async {
    final handle = tester.ensureSemantics();
    final changes = <bool>[];
    await _pump(tester, value: false, onChanged: changes.add);

    expect(
      _node(tester),
      containsSemantics(
        label: '알림에 모을 수량 보여 주기\n켜면 잠금 화면에서도 수량이 보여요',
        hasToggledState: true,
        isToggled: false,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    // 안쪽 스위치는 따로 의미 노드를 만들지 않는다
    expect(find.bySemanticsLabel(RegExp('알림에 모을 수량')), findsOneWidget);

    await tester.tap(find.byWidgetPredicate((w) => w is Text && w.semanticsLabel == '알림에 모을 수량 보여 주기'));
    await tester.pump();
    expect(changes, [true]);
    await tester.tap(find.byKey(const Key('switch')), warnIfMissed: false);
    await tester.pump();
    expect(changes, [true, true]);
    handle.dispose();
  });

  testWidgets('비활성일 때: 줄이 비활성으로 읽히고 눌러도 바뀌지 않으며 안쪽 스위치도 포커스를 받지 않는다', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, value: true);

    expect(
      _node(tester),
      containsSemantics(
        hasToggledState: true,
        isToggled: true,
        hasEnabledState: true,
        isEnabled: false,
        hasTapAction: false,
      ),
    );
    // 줄의 포커스(바깥)는 꺼지고, 스위치 안쪽의 포커스는 ExcludeFocus 아래에 있어 받을 수 없다
    final detectors = find.descendant(of: find.byKey(const Key('row')), matching: find.byType(FocusableActionDetector));
    expect(tester.widget<FocusableActionDetector>(detectors.first).enabled, isFalse);
    expect(
      find.descendant(of: find.byType(ExcludeFocus), matching: find.byType(FocusableActionDetector)),
      findsOneWidget,
    );
    handle.dispose();
  });
}
