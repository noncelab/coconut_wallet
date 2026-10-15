import 'dart:io';

import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/ccos_feature_runtime.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_contribute_screen.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_first_pow_scene.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_text_effects.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

String _plain(String value) => value.replaceAll('\u2060', '');

Finder _text(String source) =>
    find.byWidgetPredicate((widget) => widget is RichText && _plain(widget.text.toPlainText()) == source);

List<String> _lines(RenderParagraph paragraph) {
  final text = paragraph.text.toPlainText();
  final painter = TextPainter(
    text: paragraph.text,
    textDirection: paragraph.textDirection,
    textScaler: paragraph.textScaler,
    strutStyle: paragraph.strutStyle,
    textAlign: paragraph.textAlign,
  )..layout(minWidth: paragraph.size.width, maxWidth: paragraph.size.width);
  final rows = <int, String>{};
  for (var offset = 0; offset < text.length; offset++) {
    final range = painter.getLineBoundary(TextPosition(offset: offset));
    if (!range.isValid || range.isCollapsed) continue;
    rows[range.start] = _plain(text.substring(range.start, range.end)).replaceAll(RegExp(r'\s+'), '');
  }
  painter.dispose();
  return rows.values.toList();
}

void _expectGlyphsFit(RenderParagraph paragraph, String reason) {
  final text = paragraph.text.toPlainText();
  for (var offset = 0; offset < text.length; offset++) {
    if (text[offset].trim().isEmpty || text[offset] == '\u2060') continue;
    for (final box in paragraph.getBoxesForSelection(TextSelection(baseOffset: offset, extentOffset: offset + 1))) {
      expect(box.right, lessThanOrEqualTo(paragraph.size.width + 0.5), reason: '$reason ${text[offset]}');
    }
  }
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  CoconutThemeVariant get themeVariant => CoconutThemeVariant.dark;

  @override
  CcosFeatureAvailability getCcosFeatureAvailability(String featureId) => CcosFeatureAvailability(
    featureId: featureId,
    isVisible: false,
    isActivated: false,
    isEntitled: false,
    isAvailable: false,
  );
}

void main() {
  setUpAll(() async {
    for (final (family, names) in {
      'Pretendard': ['Pretendard-Regular.ttf', 'Pretendard-Bold.ttf'],
      'SpaceGrotesk': ['SpaceGrotesk-Regular.ttf', 'SpaceGrotesk-Bold.ttf'],
    }.entries.map((entry) => (entry.key, entry.value))) {
      final loader = FontLoader(family);
      for (final name in names) {
        loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$name').readAsBytesSync())));
      }
      await loader.load();
    }
  });

  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));
  tearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  testWidgets('CONTRIBUTE does not leave Korean endings alone after highlighted phrases', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final width in [320.0, 344.0, 390.0, 768.0]) {
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = Size(width, 1100);
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCoconutThemeData(),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  height: 650,
                  child: ContributeSceneBody(
                    animation: const AlwaysStoppedAnimation(1),
                    sceneDurationMs: 30000,
                    onStartPr: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        for (final source in [t.ccos.contribute_scene.line3, t.ccos.contribute_scene.line4]) {
          final paragraph = tester.renderObject<RenderParagraph>(_text(source));
          final lines = _lines(paragraph);
          expect(
            lines.where((line) => {'고,', '를'}.contains(line)),
            isEmpty,
            reason: 'width=$width scale=$scale $lines',
          );
          _expectGlyphsFit(paragraph, 'CONTRIBUTE width=$width scale=$scale');
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('DELIVERY Korean body does not leave 요 punctuation on its own line', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final width in [320.0, 390.0, 414.0, 768.0]) {
      for (final scale in [1.0, 1.3, 2.0]) {
        tester.view.physicalSize = Size(width, 1100);
        tester.platformDispatcher.textScaleFactorTestValue = 1;
        final preferences = _Preferences();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
              Provider<AnalyticsService>.value(value: AnalyticsService(null, true)),
            ],
            child: MaterialApp(
              theme: buildCoconutThemeData(),
              home: Scaffold(
                body: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: FirstPowSceneBody(
                    animation: const AlwaysStoppedAnimation(1),
                    sceneDurationMs: 30000,
                    listing: CcosFeatureRegistrySource.featuredListing,
                    isAdded: false,
                    isApplied: false,
                    isCurrentScene: false,
                    onAdd: () {},
                    onRemove: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        final deliveryImage = find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName == 'assets/images/ccos/delivery.png',
        );
        tester
            .widget<GestureDetector>(find.ancestor(of: deliveryImage, matching: find.byType(GestureDetector)).first)
            .onTap!();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 6));
        expect(tester.takeException(), isNull, reason: 'Default-scale route entry width=$width');
        final cards =
            tester
                .widgetList<Widget>(
                  find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_DeliveryStepCard'),
                )
                .toList();
        expect(cards, hasLength(3));
        final cardWidth = tester.getSize(find.byWidget(cards.first)).width;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCoconutThemeData(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: cardWidth,
                    child: Column(
                      children: [
                        for (final card in cards) ...[card, const SizedBox(height: 44)],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        for (final source in [
          t.ccos.first_pow_scene.delivery_detail.propose_body,
          t.ccos.first_pow_scene.delivery_detail.review_body,
          t.ccos.first_pow_scene.delivery_detail.intro_body,
        ]) {
          final paragraph = tester.renderObject<RenderParagraph>(_text(source));
          final lines = _lines(paragraph);
          expect(lines.where((line) => line == '요.'), isEmpty, reason: 'width=$width scale=$scale $lines');
          _expectGlyphsFit(paragraph, 'DELIVERY width=$width scale=$scale');
        }
        expect(tester.takeException(), isNull, reason: 'DELIVERY width=$width scale=$scale');
        await tester.pumpWidget(const SizedBox());
        preferences.dispose();
      }
    }
  });

  testWidgets('CONTRIBUTE retains typing progress, white emphasis and unchanged non-Korean text', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 1100);
    addTearDown(tester.view.reset);
    final controller = AnimationController(vsync: tester);
    addTearDown(controller.dispose);
    final lines = [
      t.ccos.contribute_scene.line1,
      t.ccos.contribute_scene.line2,
      t.ccos.contribute_scene.line3,
      t.ccos.contribute_scene.line4,
    ];
    final start = ContributeSceneBody.typingStartMs(lines)[2];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ContributeSceneBody(animation: controller, sceneDurationMs: 30000, onStartPr: () {}),
          ),
        ),
      ),
    );
    for (final prefix in ['여러분의 PoW는\n새', '여러분의 PoW는\n새로운 기', '여러분의 PoW는\n새로운 기능이 되어']) {
      controller.value = (start + prefix.characters.length * kTypewriterMsPerCharacter) / 30000;
      await tester.pump();
      final span = tester.widget<RichText>(_text(prefix)).text as TextSpan;
      final highlight = (span.children ?? []).whereType<TextSpan>().where((child) => child.style?.fontSize == 29.4);
      expect(highlight, isNotEmpty);
      expect(highlight.every((child) => child.style?.color == Colors.white), isTrue);
      expect(_plain(span.toPlainText()), prefix);
    }
    for (final locale in [AppLocale.en, AppLocale.ja, AppLocale.de]) {
      LocaleSettings.setLocaleSync(locale);
      controller.value = 1;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(locale),
          home: Scaffold(body: ContributeSceneBody(animation: controller, sceneDurationMs: 30000, onStartPr: () {})),
        ),
      );
      final span = tester.widget<RichText>(_text(t.ccos.contribute_scene.line3)).text;
      expect(span.toPlainText(), t.ccos.contribute_scene.line3);
      expect(span.toPlainText().contains('\u2060'), isFalse);
      expect(tester.takeException(), isNull);
    }
  });
}
