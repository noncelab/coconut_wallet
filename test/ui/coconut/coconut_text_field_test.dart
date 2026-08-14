import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
}
