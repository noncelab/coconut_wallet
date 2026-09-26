import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/widgets/features/send/tag_inheritance_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<UtxoTag> tags(int count, {bool longNames = false}) => List.generate(
    count,
    (index) => UtxoTag(
      id: 'tag-$index',
      walletId: 1,
      name: longNames ? '아주 긴 태그 이름도 전체 내용을 확인할 수 있어야 합니다 $index' : 'Tag $index',
      colorIndex: index,
    ),
  );

  Future<void> openDialog(
    WidgetTester tester,
    List<UtxoTag> candidates,
    ValueChanged<List<String>?> onResult, {
    CoconutThemeVariant variant = CoconutThemeVariant.dark,
    double textScale = 1,
  }) async {
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('capture'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: buildCoconutThemeData(variant: variant),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      onResult(
                        await showDialog<List<String>>(
                          context: context,
                          builder: (_) => TagInheritanceDialog(tags: candidates, languageCode: 'ko'),
                        ),
                      );
                    },
                    child: const Text('Open', style: CoconutTypography.body2_14),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_TAG_INHERITANCE')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('capture')));
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('.local/utxo-tag-qa/evidence/ui-$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  setUpAll(() async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    final loader =
        FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.ttf'));
    await loader.load();
  });

  testWidgets('accepts all candidates when there are at most five', (tester) async {
    List<String>? result;
    await openDialog(tester, tags(5), (value) => result = value);
    await tester.tap(find.text(t.alert.tag_apply.btn_apply));
    await tester.pumpAndSettle();
    expect(result, ['tag-0', 'tag-1', 'tag-2', 'tag-3', 'tag-4']);
  });

  for (final count in [2, 6]) {
    testWidgets('explicit decline returns empty selection for $count candidates', (tester) async {
      List<String>? result;
      await openDialog(tester, tags(count), (value) => result = value);
      await tester.tap(find.text(t.alert.tag_apply.btn_without_tags));
      await tester.pumpAndSettle();
      expect(result, isEmpty);
    });

    testWidgets('back dismisses $count candidates without consenting', (tester) async {
      var completed = false;
      List<String>? result = [];
      await openDialog(tester, tags(count), (value) {
        completed = true;
        result = value;
      });
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(completed, isTrue);
      expect(result, isNull);
    });
  }

  testWidgets('barrier dismissal is distinct from declining inheritance', (tester) async {
    List<String>? result = [];
    await openDialog(tester, tags(2), (value) => result = value);
    await tester.tapAt(const Offset(1, 1));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('more than five start empty, cap selection at five, and allow replacing a choice', (tester) async {
    List<String>? result;
    await openDialog(tester, tags(6), (value) => result = value);
    expect(find.text('0 / 5'), findsOneWidget);
    final apply = find.widgetWithText(TextButton, t.alert.tag_apply.btn_apply);
    expect(tester.widget<TextButton>(apply).onPressed, isNull);
    for (var index = 0; index < 6; index++) {
      await tester.tap(find.byKey(ValueKey('tag-$index')));
      await tester.pump();
    }
    expect(find.text('5 / 5'), findsOneWidget);
    expect(tester.widget<CoconutChip>(find.byKey(const ValueKey('tag-5'))).isSelected, isFalse);
    await tester.tap(find.byKey(const ValueKey('tag-0')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tag-5')));
    await tester.pump();
    await tester.tap(apply);
    await tester.pumpAndSettle();
    expect(result, ['tag-1', 'tag-2', 'tag-3', 'tag-4', 'tag-5']);
  });

  testWidgets('large text keeps long tags scrollable and actions accessible', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openDialog(tester, tags(9, longNames: true), (_) {}, textScale: 2);
    expect(tester.takeException(), isNull);
    final description = find.byWidgetPredicate(
      (widget) => widget is Text && (widget.semanticsLabel ?? widget.data) == t.alert.tag_apply.description,
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: description, matching: find.byType(RichText)),
    );
    final displayedText = paragraph.text.toPlainText();
    for (final (first, last) in [('태', '를'), ('적', '?')]) {
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: displayedText.indexOf(first), extentOffset: displayedText.indexOf(last) + 1),
      );
      expect(boxes, hasLength(1), reason: 'Korean words must stay on one line at 2x text scale');
    }

    final chipParagraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byKey(const ValueKey('tag-0')), matching: find.byType(RichText)),
    );
    final chipText = chipParagraph.text.toPlainText();
    for (final (first, last) in [('전', '체'), ('있', '야')]) {
      expect(
        chipParagraph.getBoxesForSelection(
          TextSelection(baseOffset: chipText.indexOf(first), extentOffset: chipText.indexOf(last) + 1),
        ),
        hasLength(1),
        reason: 'Korean tag words should stay together when they fit on a line',
      );
    }

    await capture(tester, 'large-text-320');
    await tester.scrollUntilVisible(find.byKey(const ValueKey('tag-8')), 150);
    await tester.tap(find.byKey(const ValueKey('tag-8')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.alert.tag_apply.btn_apply));
    await tester.pumpAndSettle();
    expect(find.byType(TagInheritanceDialog), findsNothing);
    expect(tester.takeException(), isNull);

    final unbrokenName = List.filled(30, '가').join();
    final candidates = tags(6);
    candidates[5] = candidates[5].copyWith(name: unbrokenName);
    await openDialog(tester, candidates, (_) {}, textScale: 2);
    await tester.scrollUntilVisible(find.byKey(const ValueKey('tag-5')), 150);
    final unbrokenParagraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byKey(const ValueKey('tag-5')), matching: find.byType(RichText)),
    );
    final boxes = unbrokenParagraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: unbrokenParagraph.text.toPlainText().length),
    );
    expect(boxes.length, greaterThan(1));
    for (final box in boxes) {
      expect(box.left, greaterThanOrEqualTo(0));
      expect(box.right, lessThanOrEqualTo(unbrokenParagraph.size.width));
      expect(box.bottom, lessThanOrEqualTo(unbrokenParagraph.size.height));
    }
    final semantics = tester.ensureSemantics();
    final label = find.bySemanticsLabel('#$unbrokenName');
    expect(label, findsOneWidget);
    expect(tester.getSemantics(label).getSemanticsData().hasAction(ui.SemanticsAction.tap), isTrue);
    semantics.dispose();
    await tester.tap(find.byKey(const ValueKey('tag-5')));
    await tester.pumpAndSettle();
    expect(find.text('1 / 5'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final variant in [CoconutThemeVariant.dark, CoconutThemeVariant.light]) {
    testWidgets('consent and selection render with ${variant.name} tokens', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openDialog(tester, tags(5), (_) {}, variant: variant);
      await capture(tester, 'consent-${variant.name}-375');
      await tester.tap(find.text(t.alert.tag_apply.btn_apply));
      await tester.pumpAndSettle();
      await openDialog(tester, tags(6), (_) {}, variant: variant);
      await capture(tester, 'picker-empty-${variant.name}-375');
      for (var index = 0; index < 5; index++) {
        await tester.tap(find.byKey(ValueKey('tag-$index')));
        await tester.pump();
      }
      expect(find.text('5 / 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'picker-five-${variant.name}-375');
    });

    testWidgets('long labels wrap and scroll at narrow width in ${variant.name} theme', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openDialog(tester, tags(9, longNames: true), (_) {}, variant: variant);
      expect(tester.takeException(), isNull);
      await capture(tester, 'long-labels-${variant.name}-320');
      final dialog = tester.widget<Dialog>(find.byType(Dialog));
      expect(dialog.backgroundColor, resolveCoconutThemeExtension(variant: variant).colors.popupBackground);
      await tester.scrollUntilVisible(find.byKey(const ValueKey('tag-8')), 150);
      await tester.tap(find.byKey(const ValueKey('tag-8')));
      await tester.pumpAndSettle();
      expect(find.text('1 / 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture(tester, 'dialog-${variant.name}-320');
    });
  }
}
