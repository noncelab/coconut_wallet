import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/providers/view_model/home/all_features_view_model.dart';
import 'package:coconut_wallet/screens/home/all_features_screen.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final registry = FeatureRegistry([
    FeatureItem(id: 'send', label: () => 'Send', category: FeatureCategory.transactions),
    FeatureItem(id: 'settings', label: () => 'Settings', category: FeatureCategory.settings),
    FeatureItem(id: 'settings.fiat', label: () => 'Currency', keywords: ['Currency'], parentId: 'settings'),
  ]);

  Future<List<String>> pump(WidgetTester tester) async {
    final launched = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(body: AllFeaturesScreen(registry: registry, onLaunch: (_, feature) => launched.add(feature.id))),
      ),
    );
    return launched;
  }

  testWidgets('fake balance search opens its own action in every locale', (tester) async {
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));
    var opened = 0;
    for (final locale in AppLocale.values) {
      LocaleSettings.setLocaleSync(locale);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(),
          home: Scaffold(
            body: AllFeaturesScreen(registry: registry, onLaunch: (_, __) {}, onFakeBalanceTap: (_) async => opened++),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('all-features-search')),
        t.all_features.fake_balance_search_terms.split(',').first,
      );
      await tester.pump();

      expect(find.byKey(const Key('all-features-fake-balance-result')), findsOneWidget, reason: '$locale');
      expect(find.text(t.all_features.fake_balance_applies_to_home), findsOneWidget, reason: '$locale');
      for (final alias in ['decoy balance', '가짜', '페이크']) {
        await tester.enterText(find.byKey(const Key('all-features-search')), alias);
        await tester.pump();
        expect(find.byKey(const Key('all-features-fake-balance-result')), findsOneWidget, reason: '$locale: $alias');
      }
      await tester.tap(find.byKey(const Key('all-features-fake-balance-result')));
      expect(opened, locale.index + 1);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('fake balance appears in recent use and opens again from there', (tester) async {
    final saved = <List<String>>[];
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: AllFeaturesScreen(
            registry: registry,
            onLaunch: (_, __) {},
            onFakeBalanceTap: (_) async => opened++,
            saveRecentIds: saved.add,
          ),
        ),
      ),
    );

    await tester.enterText(find.byKey(const Key('all-features-search')), 'decoy balance');
    await tester.pump();
    await tester.tap(find.byKey(const Key('all-features-fake-balance-result')));
    await tester.pump();
    expect(opened, 1);
    expect(saved.last, [AllFeaturesViewModel.fakeBalanceRecentId]);

    await tester.tap(find.byKey(const Key('all-features-search-clear')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('all-features-recent-${AllFeaturesViewModel.fakeBalanceRecentId}')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('all-features-recent-${AllFeaturesViewModel.fakeBalanceRecentId}')));
    await tester.pump();
    expect(opened, 2);
    expect(saved.last, [AllFeaturesViewModel.fakeBalanceRecentId]);
  });

  testWidgets('fake balance is listed under Settings with the mask icon', (tester) async {
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));
    LocaleSettings.setLocaleSync(AppLocale.en);
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: AllFeaturesScreen(registry: registry, onLaunch: (_, __) {}, onFakeBalanceTap: (_) async => opened++),
        ),
      ),
    );

    final fakeBalance = find.byKey(const ValueKey('all-features-item-${AllFeaturesViewModel.fakeBalanceRecentId}'));
    expect(fakeBalance, findsOneWidget);
    expect(find.text('Fake Balance'), findsOneWidget);
    expect(find.descendant(of: fakeBalance, matching: find.byType(SvgPicture)), findsOneWidget);
    expect(
      tester.getTopLeft(fakeBalance).dy,
      greaterThan(tester.getTopLeft(find.byKey(const ValueKey('all-features-category-settings'))).dy),
    );
    await tester.tap(fakeBalance);
    expect(opened, 1);
  });

  testWidgets('shows the search field on top and features by category', (tester) async {
    final launched = await pump(tester);
    expect(find.byKey(const Key('all-features-search')), findsOneWidget);
    expect(find.text(t.all_features.categories.transactions), findsOneWidget);
    expect(find.text(t.all_features.categories.settings), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('all-features-search'))).dy,
      lessThan(tester.getTopLeft(find.text('Send')).dy),
    );

    await tester.tap(find.text('Send'));
    expect(launched, ['send']);
  });

  testWidgets('searching shows the matched path and an empty message when nothing matches', (tester) async {
    final launched = await pump(tester);
    await tester.enterText(find.byKey(const Key('all-features-search')), 'curr');
    await tester.pump();
    expect(find.text('Settings › Currency'), findsOneWidget);
    expect(find.text(t.all_features.categories.transactions), findsNothing);
    await tester.tap(find.byKey(const ValueKey('all-features-item-settings')));
    expect(launched, ['settings']);

    await tester.enterText(find.byKey(const Key('all-features-search')), 'zzz');
    await tester.pump();
    expect(find.byKey(const Key('all-features-no-results')), findsOneWidget);

    final field = tester.getRect(find.byKey(const Key('all-features-search')));
    final clearIcon = tester.getRect(
      find.descendant(of: find.byKey(const Key('all-features-search-clear')), matching: find.byType(Icon)),
    );
    expect(field.right - clearIcon.right, closeTo(14, 0.5));
    expect(clearIcon.center.dy, closeTo(field.center.dy, 0.5));
    await tester.tap(find.byKey(const Key('all-features-search-clear')));
    await tester.pump();
    expect(find.text(t.all_features.categories.transactions), findsOneWidget);
    expect(find.byKey(const Key('all-features-search-clear')), findsNothing);
  });

  testWidgets('recently used features sit above the categories and update when one is opened', (tester) async {
    final launched = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: AllFeaturesScreen(
            registry: registry,
            recentIds: const ['settings'],
            onLaunch: (_, feature) => launched.add(feature.id),
          ),
        ),
      ),
    );

    expect(find.text(t.all_features.recent), findsOneWidget);
    expect(find.byKey(const ValueKey('all-features-recent-settings')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const Key('all-features-recent'))).dy,
      lessThan(tester.getTopLeft(find.text(t.all_features.categories.transactions)).dy),
    );
    final search = tester.getRect(find.byKey(const Key('all-features-search')));
    expect(tester.getTopLeft(find.text(t.all_features.recent)).dy - search.bottom, lessThanOrEqualTo(24));
    final divider = tester.getRect(find.byKey(const Key('all-features-recent-divider')));
    expect(divider.top - tester.getRect(find.byKey(const Key('all-features-recent'))).bottom, 20);
    expect(tester.getTopLeft(find.text(t.all_features.categories.transactions)).dy - divider.bottom, 20);

    await tester.tap(find.text('Send'));
    await tester.pump();
    expect(launched, ['send']);
    expect(find.byKey(const ValueKey('all-features-recent-send')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('all-features-recent-send'))).dx,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('all-features-recent-settings'))).dx),
    );
  });

  testWidgets('with no history there is no recent row', (tester) async {
    await pump(tester);
    expect(find.text(t.all_features.recent), findsNothing);
  });

  testWidgets('dimmed features stay tappable and are drawn faded', (tester) async {
    final launched = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: AllFeaturesScreen(
            registry: registry,
            isDimmed: (feature) => feature.id == 'send',
            onLaunch: (_, feature) => launched.add(feature.id),
          ),
        ),
      ),
    );

    final send = find.ancestor(of: find.text('Send'), matching: find.byType(Opacity));
    expect(tester.widget<Opacity>(send.first).opacity, lessThan(1));
    expect(find.ancestor(of: find.text('Settings'), matching: find.byType(Opacity)), findsNothing);

    await tester.tap(find.text('Send'));
    expect(launched, ['send']);
  });
}
