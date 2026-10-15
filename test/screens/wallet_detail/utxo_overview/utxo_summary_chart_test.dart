import 'dart:io';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_bucket.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_summary_chart.dart';
import 'package:coconut_wallet/utils/utxo_tier_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  UtxoTierTheme get utxoTierTheme => UtxoTierThemes.pastelWallet;
}

void main() {
  setUpAll(() async {
    for (final family in ['Pretendard', 'SpaceGrotesk']) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Bold']) {
        loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$family-$weight.ttf').readAsBytesSync())));
      }
      await loader.load();
    }
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('interval names and unchanged ranges fit 320px at scale $scale', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final locale = LocaleSettings.currentLocale;
      LocaleSettings.setLocaleSync(AppLocale.en);
      addTearDown(() => LocaleSettings.setLocaleSync(locale));
      final preferences = _Preferences();
      addTearDown(preferences.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<PreferenceProvider>.value(
          value: preferences,
          child: MaterialApp(
            theme: buildCoconutThemeData(),
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
            home: const Scaffold(
              body: UtxoSummaryChart(
                buckets: [UtxoBucket(label: 'dust', minSats: 0, maxSats: 546, utxos: [])],
                totalSats: 0,
                coinCount: 0,
                availableCount: 0,
                availableSats: 0,
                lockedCount: 0,
                lockedSats: 0,
                currentUnit: BitcoinUnit.btc,
                dustThreshold: 546,
                showBalanceHeader: false,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byIcon(Icons.info_outline_rounded));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('meduim'), findsNothing);
      const expected = [
        ('whale', 1000000000, 2100000000000000),
        ('whole', 100000000, 999999999),
        ('huge', 10000000, 99999999),
        ('large', 1000001, 9999999),
        ('medium', 100001, 1000000),
        ('small', 10001, 100000),
        ('tiny', 547, 10000),
        ('dust', 0, 546),
      ];
      expect(getUtxoBucketRanges(dustThreshold: 546).map((r) => (r.label, r.min, r.max)), expected);
      final sheet = find.byType(BottomSheet);
      final texts = find.descendant(of: sheet, matching: find.byType(Text));
      for (final (label, _, _) in expected) {
        final name = find.descendant(of: sheet, matching: find.text(label));
        expect(name, findsOneWidget);
        final paragraph = tester.renderObject<RenderParagraph>(name);
        expect(paragraph.didExceedMaxLines, isFalse);
        expect(paragraph.size.width, greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity) - 0.01));
        final group = find.ancestor(of: name, matching: find.byType(Column)).first;
        final labels = find.descendant(of: group, matching: find.byType(Text));
        expect(labels, findsNWidgets(2));
        final range = labels.at(1);
        expect(tester.getRect(range).top, greaterThanOrEqualTo(tester.getRect(name).bottom));
      }
      for (final element in texts.evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
      }
      final dust = find.descendant(of: sheet, matching: find.text('dust'));
      await tester.ensureVisible(dust);
      await tester.pumpAndSettle();
      final dustRange = find.descendant(of: sheet, matching: find.text('0 ~ 546 sats'));
      expect(dustRange, findsOneWidget);
      await tester.ensureVisible(dustRange);
      await tester.pumpAndSettle();
      expect(tester.getRect(dustRange).bottom, lessThanOrEqualTo(800));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('coins', skipOffstage: false), findsNWidgets(2));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
