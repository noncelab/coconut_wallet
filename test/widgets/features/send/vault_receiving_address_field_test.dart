import 'dart:ui' as ui;

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/widgets/features/send/vault_receiving_address_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

final _longAddress = 'bc1${'q' * 100}';

Future<void> _pumpField(
  WidgetTester tester, {
  required TargetPlatform platform,
  required CoconutThemeVariant variant,
  required VoidCallback onTap,
  String? address,
  double width = 200,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(variant: variant).copyWith(platform: platform),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: const ValueKey('capture'),
            child: SizedBox(
              width: width,
              child: VaultReceivingAddressField(
                address: address ?? _longAddress,
                placeholder: 'Select address',
                onTap: onTap,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _expectUnshadedMargins(WidgetTester tester, CoconutThemeVariant variant) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('capture')));
  final background = resolveCoconutThemeExtension(variant: variant).colors.background.toARGB32();
  final expected = [(background >> 16) & 255, (background >> 8) & 255, background & 255, 255];
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    try {
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
      // Sample blank space above/below the glyphs, including both old fade regions.
      for (final y in [8, image.height - 8]) {
        for (final x in [18, 24, 30, image.width - 18, image.width - 24, image.width - 30]) {
          final offset = (y * image.width + x) * 4;
          expect(bytes.sublist(offset, offset + 4), expected, reason: '${variant.name} background at ($x, $y)');
        }
      }
    } finally {
      image.dispose();
    }
  });
}

void main() {
  tearDown(() => buildCoconutThemeData());

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final variant in CoconutThemeVariant.values) {
      testWidgets(
        '${platform.name} ${variant.name} scrolls without shadows, editing or accidental selection',
        (tester) async {
          var taps = 0;
          await _pumpField(tester, platform: platform, variant: variant, onTap: () => taps++);
          final field = find.byType(VaultReceivingAddressField);
          final editable = tester.widget<EditableText>(find.byType(EditableText));
          final scroll = editable.scrollController!;
          expect(tester.getSize(field).height, 52);
          expect(editable.readOnly, isTrue);
          expect(editable.enableInteractiveSelection, isFalse);
          expect(scroll.offset, 0);
          expect(scroll.position.maxScrollExtent, greaterThan(0));
          final editableRect = tester.getRect(find.byType(EditableText));
          expect(editableRect.contains(tester.getCenter(field)), isTrue, reason: 'Editable area: $editableRect');
          await _expectUnshadedMargins(tester, variant);

          await tester.drag(field, const Offset(-80, 0));
          await tester.pumpAndSettle();
          expect(scroll.offset, greaterThan(0));
          expect(scroll.offset, lessThan(scroll.position.maxScrollExtent));
          expect(taps, 0);
          await _expectUnshadedMargins(tester, variant);

          await tester.drag(field, const Offset(-2000, 0));
          await tester.pumpAndSettle();
          expect(scroll.offset, closeTo(scroll.position.maxScrollExtent, 0.1));
          expect(taps, 0);
          await _expectUnshadedMargins(tester, variant);

          await tester.tap(field);
          await tester.pump();
          expect(taps, 1);
          expect(editable.focusNode.hasFocus, isFalse);
          expect(tester.testTextInput.isVisible, isFalse);
          expect(editable.controller.text, _longAddress);
        },
        variant: TargetPlatformVariant({platform}),
      );
    }

    testWidgets(
      '${platform.name} preserves press feedback, address reset and accessible selection',
      (tester) async {
        var taps = 0;
        void selectAddress() => taps++;
        await _pumpField(tester, platform: platform, variant: CoconutThemeVariant.dark, onTap: selectAddress);
        final field = find.byType(VaultReceivingAddressField);
        EditableText editable() => tester.widget<EditableText>(find.byType(EditableText));
        final colors = resolveCoconutThemeExtension(variant: CoconutThemeVariant.dark).colors;
        final scroll = editable().scrollController!;

        final press = await tester.startGesture(tester.getCenter(field));
        await tester.pump(const Duration(milliseconds: 150));
        expect(editable().style.color, colors.secondaryText);
        await press.moveBy(const Offset(-20, 0));
        await press.moveBy(const Offset(-60, 0));
        await tester.pump();
        expect(editable().style.color, colors.primaryText);
        await press.up();
        await tester.pumpAndSettle();
        expect(taps, 0);
        expect(scroll.offset, greaterThan(0));

        await _pumpField(tester, platform: platform, variant: CoconutThemeVariant.coconutTheme, onTap: selectAddress);
        expect(scroll.offset, greaterThan(0));
        await _expectUnshadedMargins(tester, CoconutThemeVariant.coconutTheme);

        final nextAddress = 'bc1${'p' * 40}';
        await _pumpField(
          tester,
          platform: platform,
          variant: CoconutThemeVariant.coconutTheme,
          address: nextAddress,
          onTap: selectAddress,
        );
        expect(editable().controller.text, nextAddress);
        expect(scroll.offset, 0);
        await _pumpField(
          tester,
          platform: platform,
          variant: CoconutThemeVariant.coconutTheme,
          address: nextAddress,
          width: 750,
          onTap: selectAddress,
        );
        expect(scroll.position.maxScrollExtent, 0);

        final semantics = tester.ensureSemantics();
        final node = tester.getSemantics(find.bySemanticsLabel(nextAddress));
        expect(node.flagsCollection.isButton, isTrue);
        node.owner!.performAction(node.id, ui.SemanticsAction.tap);
        await tester.pump();
        expect(taps, 1);
        expect(editable().focusNode.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        semantics.dispose();
      },
      variant: TargetPlatformVariant({platform}),
    );
  }
}
