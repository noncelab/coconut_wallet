import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/ui/coconut/coconut_text_field.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final variant in CoconutThemeVariant.values) {
    testWidgets('$variant separates hint, counter, error, active and disabled controls', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);
      final semantics = tester.ensureSemantics();
      final colors = resolveCoconutThemeExtension(variant: variant).colors;
      var clears = 0;
      var scans = 0;

      Future<void> pump({bool enabled = true, bool error = false}) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCoconutThemeData(variant: variant),
            home: Scaffold(
              body: CoconutTextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: (_) {},
                placeholderText: 'Address',
                maxLength: 20,
                maxLines: 1,
                enabled: enabled,
                isError: error,
                errorText: 'Invalid address',
                clearButtonVisibility: CoconutTextFieldClearButtonVisibility.whenNotEmpty,
                onClear: () {
                  clears++;
                  controller.clear();
                },
                suffixIconAsset: CommonActionIconPath.scan,
                suffixSemanticLabel: 'Scan address QR',
                onSuffixPressed: () => scans++,
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pump();
      expect(tester.widget<Text>(find.text('Address')).style!.color, colors.inputPlaceholder);
      expect(tester.widget<Text>(find.text('0/20')).style!.color, colors.secondaryTextStrong);
      await tester.enterText(find.byType(EditableText), 'bc1test');
      await tester.pump();
      expect(find.bySemanticsLabel('Address'), findsOneWidget);
      final buttons = find.byType(CupertinoButton);
      expect(buttons, findsNWidgets(2));
      final clearButton = buttons.first;
      expect(tester.getSize(clearButton), const Size(44, 44));
      expect(tester.getSize(buttons.last), const Size(44, 44));
      expect(find.bySemanticsLabel('Clear'), findsOneWidget);
      final clearSemantics = tester.getSemantics(find.bySemanticsLabel('Clear')).getSemanticsData();
      expect(clearSemantics.label, 'Clear');
      expect(clearSemantics.flagsCollection.isButton, isTrue);
      expect(clearSemantics.hasAction(SemanticsAction.tap), isTrue);
      final clearSvg = tester.widget<SvgPicture>(find.descendant(of: clearButton, matching: find.byType(SvgPicture)));
      expect(clearSvg.colorFilter, ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn));
      expect(clearSvg.width, 14);
      await tester.tapAt(tester.getTopLeft(clearButton) + const Offset(3, 3));
      await tester.pump();
      expect(clears, 1);
      expect(controller.text, isEmpty);
      await tester.tap(find.byType(CupertinoButton));
      expect(scans, 1);

      controller.text = 'bc1test';
      await pump(error: true);
      expect(tester.widget<Text>(find.text('Invalid address')).style!.color, colors.dangerText);
      await pump(enabled: false);
      await tester.tap(find.byType(CupertinoButton).first);
      await tester.tap(find.byType(CupertinoButton).last);
      expect(clears, 1);
      expect(scans, 1);
      expect(controller.text, 'bc1test');
      expect(
        tester.getSemantics(find.bySemanticsLabel('Clear')).getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
      controller.clear();
      focusNode.unfocus();
      await pump(enabled: false);
      expect(tester.widget<Text>(find.text('Address')).style!.color, colors.mutedText);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      semantics.dispose();
    });
  }

  testWidgets('search clear and scan accept edge taps independently inside a narrow app bar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = TextEditingController(text: 'bc1test');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    var clears = 0;
    var scans = 0;
    var backs = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.coconutTheme),
        home: Scaffold(
          appBar: AppBar(
            toolbarHeight: 56,
            leading: IconButton(onPressed: () => backs++, icon: const Icon(Icons.arrow_back)),
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.only(right: 16, top: 4),
              child: CoconutTextField(
                controller: controller,
                focusNode: focusNode,
                onChanged: (_) {},
                size: CoconutTextFieldSize.search,
                prefix: const IgnorePointer(
                  child: IconButton(onPressed: null, icon: Icon(Icons.search_rounded), iconSize: 22),
                ),
                maxLines: 1,
                clearButtonVisibility: CoconutTextFieldClearButtonVisibility.whenNotEmpty,
                onClear: () {
                  clears++;
                  controller.clear();
                },
                suffixIconAsset: CommonActionIconPath.scan,
                onSuffixPressed: () => scans++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final buttons = find.byType(CupertinoButton);
    final clearRect = tester.getRect(buttons.first);
    final scanRect = tester.getRect(buttons.last);
    expect(clearRect.size, const Size(44, 44));
    expect(scanRect.size, const Size(44, 44));
    expect(clearRect.right, lessThanOrEqualTo(scanRect.left));
    await tester.tapAt(scanRect.bottomRight - const Offset(1, 1));
    expect(scans, 1);
    expect(clears, 0);
    expect(controller.text, 'bc1test');
    await tester.tapAt(clearRect.topLeft + const Offset(1, 1));
    await tester.pump();
    expect(clears, 1);
    expect(scans, 1);
    expect(backs, 0);
    expect(controller.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('focus border and persistent label follow a replaced focus node', (tester) async {
    final controller = TextEditingController();
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    Future<void> pump(FocusNode focusNode) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CoconutTextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: (_) {},
              placeholderText: 'Hint',
            ),
          ),
        ),
      );
    }

    await pump(first);
    first.requestFocus();
    await tester.pump();
    expect(find.text('Hint'), findsNothing);
    await pump(second);
    second.requestFocus();
    await tester.pump();
    expect(find.text('Hint'), findsNothing);
    second.unfocus();
    await tester.pump();
    expect(find.text('Hint'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

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
