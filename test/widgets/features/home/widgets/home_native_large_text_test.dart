import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_widget_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _labels = ['10/10', '10/11', '10/12', '10/13', '10/14', '10/15', '10/16'];
const _captureKey = Key('native-text-capture');

class _Chart extends HomeItemDefinition {
  _Chart()
    : super(
        id: 'chart',
        kind: HomeItemKind.widget,
        supportedSpans: const [HomeSpan.wide],
        category: HomeItemCategory.balance,
      );

  @override
  Widget build(BuildContext context, HomeItem item) => const BalanceChangeOverTimeView(
    balance: HomeAmount('0', 'BTC'),
    fiatText: '₩ 0',
    rate: 0,
    deltaText: '+ 0 BTC',
    deltaSign: 0,
    values: [0, 0, 0, 0, 0, 0, 0],
    dayLabels: _labels,
  );
}

void main() {
  setUpAll(() async {
    LocaleSettings.setLocale(AppLocale.ko);
    for (final entry
        in {
          'Pretendard': ['Regular', 'Bold'],
          'SpaceGrotesk': ['Regular', 'Bold'],
        }.entries) {
      final loader = FontLoader(entry.key);
      for (final weight in entry.value) {
        loader.addFont(
          Future.value(ByteData.sublistView(File('assets/fonts/${entry.key}-$weight.ttf').readAsBytesSync())),
        );
      }
      await loader.load();
    }
  });

  for (final variant in CoconutThemeVariant.values) {
    for (final viewport in [320.0, 904 / 2.625]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('$variant ${viewport.toStringAsFixed(3)}dp ${scale}x dates and shortcuts fit actual home grid', (
          tester,
        ) async {
          tester.view.physicalSize = Size(viewport, 700);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final semantics = tester.ensureSemantics();
          try {
            var taps = 0;
            final features = FeatureRegistry.builtin();
            final registry =
                HomeItemRegistry()
                  ..register(_Chart())
                  ..registerShortcuts(features, onTap: (_, __) => taps++);
            final items = [
              const HomeItem(
                id: 'chart',
                definitionId: 'chart',
                kind: HomeItemKind.widget,
                order: 0,
                span: HomeSpan.wide,
              ),
              for (final (index, id) in [FeatureIds.receive, FeatureIds.send].indexed)
                HomeItem(
                  id: id,
                  definitionId: HomeItemIds.shortcut(id),
                  kind: HomeItemKind.shortcut,
                  order: index + 1,
                  span: HomeSpan.shortcut,
                ),
            ];
            await tester.pumpWidget(
              MaterialApp(
                theme: buildCoconutThemeData(variant: variant),
                home: MediaQuery(
                  data: MediaQueryData(size: Size(viewport, 700), textScaler: TextScaler.linear(scale)),
                  child: Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(16),
                      child: RepaintBoundary(
                        key: _captureKey,
                        child: HomeItemsView(configuration: HomeConfiguration(items: items), registry: registry),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            final chart = tester.getRect(find.byType(BalanceChangeOverTimeView));
            Rect? previous;
            for (final label in _labels) {
              final rect = tester.getRect(find.text(label));
              expect(rect.left, greaterThanOrEqualTo(chart.left + 16 - .01));
              expect(rect.right, lessThanOrEqualTo(chart.right - 16 + .01));
              if (previous != null) expect(rect.left, greaterThanOrEqualTo(previous.right + 2 - .01));
              previous = rect;
              expect(find.bySemanticsLabel(label), findsOneWidget);
            }
            for (final id in [FeatureIds.receive, FeatureIds.send]) {
              final label = features.byId(id)!.shortcutLabel();
              final card = tester.getRect(find.byKey(ValueKey('shortcut-background-$id')));
              final text = tester.getRect(find.text(label));
              final icon = tester.getRect(find.byKey(ValueKey('shortcut-icon-$id')));
              expect(text.bottom, lessThanOrEqualTo(card.bottom - 4 + .01));
              expect(text.right, lessThanOrEqualTo(card.right - 4 + .01));
              expect(text.left, greaterThanOrEqualTo(card.left + 4 - .01));
              expect(text.top - icon.bottom, closeTo(6, .01));
              expect(icon.height, closeTo(24 * features.byId(id)!.iconScale, .01));
              expect(find.bySemanticsLabel(label), findsOneWidget);
              await tester.tap(find.text(label));
              await tester.pumpAndSettle();
            }
            expect(taps, 2);
            const captureDir = String.fromEnvironment('NATIVE_TEXT_CAPTURE_DIR');
            const referenceDir = String.fromEnvironment('NATIVE_TEXT_REFERENCE_DIR');
            if (captureDir.isNotEmpty || (referenceDir.isNotEmpty && scale == 1)) {
              final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
              final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
              final raw = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
              final name = '${variant.name}-${viewport.toStringAsFixed(3)}-${scale}x';
              if (referenceDir.isNotEmpty && scale == 1) {
                expect(raw.buffer.asUint8List(), File('$referenceDir/$name.rgba').readAsBytesSync());
              }
              if (captureDir.isNotEmpty) {
                final png = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png)))!;
                Directory(captureDir).createSync(recursive: true);
                File('$captureDir/$name.rgba').writeAsBytesSync(raw.buffer.asUint8List());
                File('$captureDir/$name.png').writeAsBytesSync(png.buffer.asUint8List());
              }
              image.dispose();
            }
          } finally {
            semantics.dispose();
          }
        });
      }
    }
  }
}
