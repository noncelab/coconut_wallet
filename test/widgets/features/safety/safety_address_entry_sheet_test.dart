import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_address_entry_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _address = 'bcrt1qxa3vg30kvqsd73knsv0dj8z26jx223chv8fzcx';
const _field = Key('entry-field'), _action = Key('entry-action');

/// R1 이음 문자를 빼고 비교(시트가 오류 문장을 safetyKoText로 감싼다)
Finder _plainText(String text) =>
    find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().replaceAll('\u2060', '') == text);

void main() {
  late List<String> confirmed;
  late Future<String?> result;

  Future<void> open(WidgetTester tester, {String? Function(String)? validate, String? rejectOnConfirm}) async {
    confirmed = [];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed:
                      () =>
                          result = showSafetyAddressEntrySheet(
                            context,
                            screenName: '/test/address',
                            actionText: t.next,
                            fieldKey: _field,
                            actionKey: _action,
                            validate: validate ?? (address) => address.startsWith('bcrt1') ? null : 'format',
                            confirm: (address) async {
                              confirmed.add(address);
                              return address == rejectOnConfirm ? 'rejected' : null;
                            },
                          ),
                  child: const Text('open'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  bool actionActive(WidgetTester tester) => tester.widget<InlineActionButton>(find.byKey(_action)).isActive;

  testWidgets('GPT M3: 320dp·2.0배 글자·키보드가 올라와도 넘치지 않고 확인 버튼까지 스크롤된다', (tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await open(tester);
    await tester.enterText(find.byKey(_field), 'not-an-address-and-quite-long-so-the-error-wraps');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(_action));
    await tester.pumpAndSettle();
    expect(find.byKey(_action).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('형식 오류는 입력란 아래, 버튼 비활성. BIP21은 주소만(bech32 소문자)으로 넘긴다', (tester) async {
    await open(tester);
    expect(actionActive(tester), isFalse);
    await tester.enterText(find.byKey(_field), 'nope');
    await tester.pump();
    expect(_plainText('format'), findsOneWidget);
    expect(actionActive(tester), isFalse);

    await tester.enterText(find.byKey(_field), 'bitcoin:${_address.toUpperCase()}?amount=0.1');
    await tester.pump();
    expect(_plainText('format'), findsNothing);
    expect(actionActive(tester), isTrue);
    await tester.tap(find.byKey(_action));
    await tester.pumpAndSettle();
    expect(confirmed, [_address]);
    expect(await result, _address);
  });

  testWidgets('확인 단계가 거절하면 그 주소인 동안 이유를 보이고 닫지 않는다. 고치면 사라진다', (tester) async {
    await open(tester, rejectOnConfirm: _address);
    await tester.enterText(find.byKey(_field), _address);
    await tester.pump();
    await tester.tap(find.byKey(_action));
    await tester.pumpAndSettle();
    expect(_plainText('rejected'), findsOneWidget);
    expect(find.byKey(_field), findsOneWidget); // 시트가 그대로

    await tester.enterText(find.byKey(_field), '${_address}x');
    await tester.pump();
    expect(_plainText('rejected'), findsNothing);
  });
}
