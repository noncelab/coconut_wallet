import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _note = 'The mnemonic phrase stored on this device will be deleted.';

Widget _app({required bool selected, bool reduced = false}) => MaterialApp(
  theme: buildCoconutThemeData(variant: CoconutThemeVariant.values.first),
  builder:
      (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reduced), child: child!),
  home: Scaffold(
    body: CoconutPopup(
      title: 'This wallet already exists',
      description: '',
      languageCode: 'en',
      checkboxText: 'Remove the existing hot wallet',
      isCheckboxSelected: selected,
      onCheckboxChanged: (_) {},
      checkboxNote: _note,
      onTapRight: () {},
    ),
  ),
);

Opacity _noteOpacity(WidgetTester tester) =>
    tester.widget<Opacity>(find.ancestor(of: find.textContaining(_note), matching: find.byType(Opacity)).first);

void main() {
  testWidgets('checkbox note stays hidden until selected, grows in gradually, and folds back', (tester) async {
    await tester.pumpWidget(_app(selected: false));
    expect(find.textContaining(_note), findsNothing);

    await tester.pumpWidget(_app(selected: true));
    await tester.pump(const Duration(milliseconds: 110));
    expect(_noteOpacity(tester).opacity, inExclusiveRange(0, 1));

    await tester.pumpAndSettle();
    expect(_noteOpacity(tester).opacity, 1);

    await tester.pumpWidget(_app(selected: false));
    await tester.pumpAndSettle();
    expect(find.textContaining(_note), findsNothing);
  });

  testWidgets('reduce motion shows the checkbox note at once', (tester) async {
    await tester.pumpWidget(_app(selected: false, reduced: true));
    await tester.pumpWidget(_app(selected: true, reduced: true));
    await tester.pump();
    expect(_noteOpacity(tester).opacity, 1);
  });

  koreanAndSemanticsTests();
}

const _koNote = '이 기기에 저장된 니모닉이 삭제돼요. 백업하지 않았다면 되돌릴 수 없어요.';

void koreanAndSemanticsTests() {
  testWidgets('Korean note keeps words together and is announced as a live region', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.values.first),
        home: Scaffold(
          body: CoconutPopup(
            title: '같은 지갑이 이미 있어요',
            description: '',
            languageCode: 'ko',
            checkboxText: '기존 핫월렛 삭제하기',
            isCheckboxSelected: true,
            onCheckboxChanged: (_) {},
            checkboxNote: _koNote,
            onTapRight: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining(TextUtils.preventLineBreakInsideWords(_koNote)), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel(_koNote)), containsSemantics(isLiveRegion: true));
    // addTearDown은 testWidgets의 핸들 정리 검사보다 늦게 돌아서, 본문 끝에서 바로 정리한다
    handle.dispose();
  });
}
