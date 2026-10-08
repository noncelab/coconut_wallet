import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/screens/home/all_features_screen.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:flutter/material.dart';
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
}
