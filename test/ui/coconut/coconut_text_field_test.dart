import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final showScrollFades in [false, true]) {
    testWidgets('preserves the clear fade and button with scroll fades=$showScrollFades', (tester) async {
      final controller = TextEditingController(text: 'bc1${'q' * 100}');
      final focusNode = FocusNode();
      final scrollController = ScrollController();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      addTearDown(scrollController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(),
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: CoconutTextField(
                controller: controller,
                focusNode: focusNode,
                scrollController: scrollController,
                showScrollFades: showScrollFades,
                backgroundColor: Colors.white,
                clearButtonVisibility: CoconutTextFieldClearButtonVisibility.whenNotEmpty,
                onClear: controller.clear,
                onChanged: (_) {},
                maxLines: 1,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(scrollController.position.maxScrollExtent, greaterThan(0));
      final gradients =
          tester
              .widgetList<DecoratedBox>(find.byType(DecoratedBox))
              .map((box) => box.decoration)
              .whereType<BoxDecoration>()
              .map((decoration) => decoration.gradient)
              .whereType<LinearGradient>();
      expect(gradients, hasLength(1));
      expect(gradients.single.end, Alignment.centerRight);
      expect(gradients.single.colors.last, Colors.white);
      await tester.tap(find.byType(CupertinoButton));
      await tester.pumpAndSettle();
      expect(controller.text, isEmpty);
      expect(find.byType(CupertinoButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  for (final style in CoconutTextFieldStyle.values) {
    for (final hasPrefix in [false, true]) {
      testWidgets('${style.name} lays out and accepts input with prefix=$hasPrefix', (tester) async {
        final controller = TextEditingController();
        final focusNode = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focusNode.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: buildCoconutThemeData(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: CoconutTextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (_) {},
                  style: style,
                  prefix: hasPrefix ? const Icon(Icons.search) : null,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final height = tester.getSize(find.byType(CoconutTextField)).height;
        expect(height, style == CoconutTextFieldStyle.bordered ? 52 : inExclusiveRange(0, 52));
        await tester.tap(find.byType(CoconutTextField));
        await tester.pump();
        expect(focusNode.hasFocus, isTrue);
        await tester.enterText(find.byType(EditableText), 'bc1qexample');
        expect(controller.text, 'bc1qexample');
      });
    }
  }

  testWidgets('disables contextual font shaping for default Pretendard input text', (tester) async {
    final controller = TextEditingController(text: '1x2');
    final focusNode = FocusNode();

    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(body: CoconutTextField(controller: controller, focusNode: focusNode, onChanged: (_) {})),
      ),
    );

    final editableText = tester.widget<EditableText>(find.byType(EditableText));

    expect(editableText.style.fontFamily, 'Pretendard');
    expect(editableText.style.fontFeatures, contains(const FontFeature.disable('calt')));
    expect(editableText.style.fontFeatures, contains(const FontFeature.disable('frac')));
    expect(editableText.style.fontFeatures, contains(const FontFeature.disable('sups')));
    expect(editableText.controller, isA<LiteralTextEditingController>());

    final renderedTextSpan = editableText.controller.buildTextSpan(
      context: tester.element(find.byType(EditableText)),
      style: editableText.style,
      withComposing: false,
    );

    expect(renderedTextSpan.children, hasLength(3));
    expect(renderedTextSpan.toPlainText(), '1x2');
  });

  testWidgets('keeps the external controller synced while rendering literal text', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(body: CoconutTextField(controller: controller, focusNode: focusNode, onChanged: (_) {})),
      ),
    );

    await tester.enterText(find.byType(EditableText), '1x2');
    await tester.pump();

    expect(controller.text, '1x2');
  });

  testWidgets('does not call setState when removed after an input change', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();

    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(body: CoconutTextField(controller: controller, focusNode: focusNode, onChanged: (_) {})),
      ),
    );

    controller.text = 'passphrase';
    await tester.pumpWidget(MaterialApp(theme: buildCoconutThemeData(), home: const Scaffold()));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
