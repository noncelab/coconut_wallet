import 'dart:math' show max;

import 'package:coconut_design_system/coconut_design_system.dart'
    show CoconutLayout, CoconutTypography, TextColorExtension;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/wallet_detail/transaction_list_screen.dart';
import 'package:coconut_wallet/widgets/common/loading/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {required bool syncing}) => tester.pumpWidget(
  MaterialApp(
    theme: buildCoconutThemeData(),
    home: Scaffold(body: Center(child: TransactionListSyncingIndicator(isSyncing: syncing))),
  ),
);

/// The label row of TransactionListScreen._buildTxListLabel, copied because the screen needs its providers to build.
Future<void> _pumpLabelRow(
  WidgetTester tester, {
  required bool syncing,
  required double textScale,
}) => tester.pumpWidget(
  MaterialApp(
    theme: buildCoconutThemeData(),
    builder:
        (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)), child: child!),
    home: Scaffold(
      body: Builder(
        builder:
            (context) => Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 4.0),
              child: SizedBox(
                height: 32,
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                t.tx_list,
                                style: CoconutTypography.heading4_18_Bold.setColor(context.coconutColors.primaryText),
                              ),
                            ),
                          ),
                          CoconutLayout.spacing_100w,
                          Text(
                            t.total_item_count(count: 123),
                            style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
                          ),
                        ],
                      ),
                    ),
                    TransactionListSyncingIndicator(isSyncing: syncing),
                  ],
                ),
              ),
            ),
      ),
    ),
  ),
);

/// 0 once the label is gone from the tree.
double _opacity(WidgetTester tester) {
  final opacity = find.ancestor(of: find.text(t.status_updating), matching: find.byType(Opacity));
  return opacity.evaluate().isEmpty ? 0 : tester.widget<Opacity>(opacity.first).opacity;
}

double _width(WidgetTester tester) => tester.getSize(find.byType(TransactionListSyncingIndicator)).width;

/// How far the item count reaches over the indicator's left end (its spinner), or null while the indicator is hidden.
double? _countOverlap(WidgetTester tester) {
  final spinner = find.byType(InlineLoadingIndicator);
  if (spinner.evaluate().isEmpty) return null;
  return tester.getRect(find.text(t.total_item_count(count: 123))).right - tester.getRect(spinner).left;
}

/// Draws a frame every 10 ms for [ms] and checks the label stays fully visible in each one.
Future<void> _expectOpaqueFor(WidgetTester tester, int ms, String phase) async {
  for (var elapsed = 10; elapsed <= ms; elapsed += 10) {
    await tester.pump(const Duration(milliseconds: 10));
    expect(_opacity(tester), 1, reason: '$phase, $elapsed ms');
  }
}

// Same timing as WalletRefreshIndicator: a 350 ms easeInOut fade, and a 300 ms hold before hiding.
void main() {
  setUpAll(() async {
    // The app's text font, so the label row is as tight as on a device.
    const family = CoconutTypography.kTextFontFamily;
    await (FontLoader(family)
          ..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/$family-Bold.ttf')))
        .load();
  });

  testWidgets('fades in over 350 ms easeInOut, at full width while visible', (tester) async {
    await _pump(tester, syncing: false);
    expect(find.text(t.status_updating), findsNothing);

    await _pump(tester, syncing: true);
    await tester.pump(const Duration(milliseconds: 105));
    expect(_opacity(tester), closeTo(Curves.easeInOut.transform(105 / 350), 0.001));
    final earlyWidth = _width(tester);
    await tester.pump(const Duration(milliseconds: 245));

    expect(_opacity(tester), 1);
    expect(earlyWidth, _width(tester), reason: 'full width while visible, so it never paints over its neighbours');
  });

  testWidgets('stays 300 ms after syncing stops, then fades out', (tester) async {
    await _pump(tester, syncing: true);
    await tester.pump(const Duration(milliseconds: 350));

    await _pump(tester, syncing: false);
    await _expectOpaqueFor(tester, 290, 'holding after the stop');

    await tester.pump(const Duration(milliseconds: 10)); // the hold ends
    await tester.pump(const Duration(milliseconds: 175));
    expect(_opacity(tester), closeTo(0.5, 0.01));

    await tester.pump(const Duration(milliseconds: 175));
    expect(find.text(t.status_updating), findsNothing);
    expect(_width(tester), 0);
  });

  testWidgets('a stop and restart within 300 ms does not flicker', (tester) async {
    await _pump(tester, syncing: true);
    await tester.pump(const Duration(milliseconds: 350));

    await _pump(tester, syncing: false);
    await _expectOpaqueFor(tester, 150, 'stopped');
    await _pump(tester, syncing: true);
    await _expectOpaqueFor(tester, 1000, 'restarted'); // past the cancelled hold and a whole fade
  });

  testWidgets('leaving the screen during the hold cancels the hide timer', (tester) async {
    await _pump(tester, syncing: true);
    await tester.pump(const Duration(milliseconds: 350));
    await _pump(tester, syncing: false);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(const SizedBox()); // flutter_test fails the test if the timer is still pending
  });

  testWidgets('a rebuild with the same value keeps the original hide deadline', (tester) async {
    await _pump(tester, syncing: true);
    await tester.pump(const Duration(milliseconds: 350));
    await _pump(tester, syncing: false);
    await tester.pump(const Duration(milliseconds: 200));
    await _pump(tester, syncing: false); // e.g. the tx count changed
    await tester.pump(const Duration(milliseconds: 100)); // the hold ends on time; a separate frame starts the fade
    await tester.pump(const Duration(milliseconds: 175));
    expect(_opacity(tester), closeTo(0.5, 0.01));
  });

  testWidgets('in the label row the indicator never paints over the item count', (tester) async {
    final previousLocale = LocaleSettings.currentLocale;
    addTearDown(() => LocaleSettings.setLocaleSync(previousLocale));
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    final overlaps = <String>[];
    for (final locale in [AppLocale.es, AppLocale.de, AppLocale.ja, AppLocale.en, AppLocale.ko]) {
      LocaleSettings.setLocaleSync(locale);
      for (final width in [320.0, 360.0, 390.0]) {
        tester.view.physicalSize = Size(width, 200);
        for (final textScale in [1.0, 1.3, 1.5]) {
          await tester.pumpWidget(const SizedBox());
          await _pumpLabelRow(tester, syncing: true, textScale: textScale);
          await tester.pump(const Duration(milliseconds: 350));
          // The fully shown row is laid out exactly as before the fade. Only es at 320 dp x1.5 overflows there (the
          // count does not fit beside the label); the fades may not make that worse.
          expect('${tester.takeException() ?? 'none'}', anyOf('none', contains('A RenderFlex overflowed')));
          final allowed = max(0.0, _countOverlap(tester)!);
          await _pumpLabelRow(tester, syncing: false, textScale: textScale);
          // A frame every 10 ms: the hold and the fade-out, then a restart at 800 ms and the fade-in.
          for (var ms = 10; ms <= 1200; ms += 10) {
            if (ms == 800) await _pumpLabelRow(tester, syncing: true, textScale: textScale);
            await tester.pump(const Duration(milliseconds: 10));
            final overlap = _countOverlap(tester);
            if (overlap != null && overlap > allowed + 0.01) {
              overlaps.add('${locale.name} ${width}dp x$textScale at $ms ms: ${overlap.toStringAsFixed(1)} px');
            }
          }
        }
      }
    }
    expect(overlaps, isEmpty, reason: overlaps.join('\n'));
  });
}
