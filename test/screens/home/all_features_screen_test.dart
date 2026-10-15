import 'dart:io';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/providers/view_model/home/all_features_view_model.dart';
import 'package:coconut_wallet/screens/home/all_features_screen.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoButton;
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    for (final (family, paths) in {
      'Pretendard': ['assets/fonts/Pretendard-Regular.ttf', 'assets/fonts/Pretendard-Bold.ttf'],
    }.entries.map((entry) => (entry.key, entry.value))) {
      final loader = FontLoader(family);
      for (final path in paths) {
        loader.addFont(Future.value(ByteData.sublistView(File(path).readAsBytesSync())));
      }
      await loader.load();
    }
  });
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
    expect(launched, ['settings.fiat']);

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

  testWidgets('zero wallets shows one add-wallet banner before categories and keeps guarded tap guidance', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final launched = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: AllFeaturesScreen(
            registry: registry,
            noWallets: true,
            onAddWallet: (_) async {},
            isDimmed: (feature) => feature.id == 'send',
            onLaunch: (_, feature) => launched.add(feature.id),
          ),
        ),
      ),
    );

    final banner = find.byKey(const Key('all-features-wallet-banner'));
    expect(banner, findsOneWidget);
    expect(find.text('지갑을 추가하면 모든 기능이 활성화돼요!'), findsOneWidget);
    expect(find.text(t.all_features.wallet_required), findsNothing);
    expect(
      tester.getRect(banner).bottom,
      lessThan(tester.getRect(find.byKey(const ValueKey('all-features-category-transactions'))).top),
    );
    final colors = tester.element(find.text('Send')).coconutColors;
    expect(tester.widget<Text>(find.text('Send')).style?.color, colors.secondaryText);
    expect(tester.widget<Text>(find.text('Settings')).style?.color, colors.primaryText);
    expect(find.ancestor(of: find.text('Send'), matching: find.byType(Opacity)), findsNothing);
    final action = tester.getSize(find.byKey(const Key('all-features-add-wallet')));
    expect(action.width, greaterThanOrEqualTo(48));
    expect(action.height, greaterThanOrEqualTo(48));
    expect(
      tester.getRect(find.byKey(const Key('all-features-add-wallet'))).top,
      lessThan(tester.getRect(find.text('지갑을 추가하면 모든 기능이 활성화돼요!')).bottom),
      reason: 'Normal phone width keeps the CTA beside a message of up to two lines',
    );

    await tester.tap(find.text('Send'));
    expect(launched, ['send']);
  });

  testWidgets('banner follows recent use and wraps at 320 with real fonts, large text and long translations', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));
    for (final locale in [AppLocale.ko, AppLocale.de]) {
      LocaleSettings.setLocaleSync(locale);
      for (final variant in [CoconutThemeVariant.dark, CoconutThemeVariant.light]) {
        for (final scale in [1.3, 2.0]) {
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          await tester.pumpWidget(
            MaterialApp(
              key: ValueKey('$locale-$variant-$scale'),
              theme: buildCoconutThemeData(variant: variant),
              home: Scaffold(
                body: AllFeaturesScreen(
                  registry: registry,
                  noWallets: true,
                  recentIds: const ['send', 'settings'],
                  onAddWallet: (_) async {},
                  isDimmed: (feature) => feature.id == 'send',
                  onLaunch: (_, __) {},
                ),
              ),
            ),
          );
          await tester.pump();
          final banner = find.byKey(const Key('all-features-wallet-banner'));
          expect(banner, findsOneWidget);
          expect(find.text(t.all_features.wallet_required), findsNothing);
          expect(
            tester.getRect(banner).top,
            greaterThan(tester.getRect(find.byKey(const Key('all-features-recent'))).bottom),
          );
          final recentSend = find.descendant(
            of: find.byKey(const ValueKey('all-features-recent-send')),
            matching: find.text('Send'),
          );
          expect(tester.widget<Text>(recentSend).style?.color, tester.element(recentSend).coconutColors.secondaryText);
          final action = find.byKey(const Key('all-features-add-wallet'));
          expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
          expect(tester.getRect(action).left, greaterThanOrEqualTo(16));
          expect(tester.getRect(action).right, lessThanOrEqualTo(304));
          expect(tester.takeException(), isNull, reason: '$locale $variant $scale');
        }
      }
    }
  });

  testWidgets('search shows one banner only for nonempty results and wallet arrival restores normal rows', (
    tester,
  ) async {
    var noWallets = true;
    late StateSetter rebuild;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return Scaffold(
              body: AllFeaturesScreen(
                registry: registry,
                noWallets: noWallets,
                onAddWallet: (_) async {},
                isDimmed: (feature) => noWallets && feature.id == 'send',
                onLaunch: (_, __) {},
              ),
            );
          },
        ),
      ),
    );
    final search = find.byKey(const Key('all-features-search'));
    await tester.enterText(search, 'send');
    await tester.pump();
    expect(find.byKey(const Key('all-features-wallet-banner')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('all-features-wallet-banner'))).bottom,
      lessThan(tester.getRect(find.byKey(const ValueKey('all-features-item-send'))).top),
    );
    expect(find.text(t.all_features.wallet_required), findsNothing);
    await tester.enterText(search, 'zzz');
    await tester.pump();
    expect(find.byKey(const Key('all-features-no-results')), findsOneWidget);
    expect(find.byKey(const Key('all-features-wallet-banner')), findsNothing);
    await tester.enterText(search, 'send');
    await tester.pump();
    rebuild(() => noWallets = false);
    await tester.pump();
    expect(find.byKey(const Key('all-features-wallet-banner')), findsNothing);
    expect(find.text('send'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Send')).style?.color,
      tester.element(find.text('Send')).coconutColors.primaryText,
    );
    rebuild(() => noWallets = true);
    await tester.pump();
    expect(find.byKey(const Key('all-features-wallet-banner')), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('Send')).style?.color,
      tester.element(find.text('Send')).coconutColors.secondaryText,
    );
    await tester.tap(find.byKey(const Key('all-features-search-clear')));
    await tester.pump();
    expect(find.byKey(const Key('all-features-wallet-banner')), findsOneWidget);
  });

  testWidgets('add-wallet CTA prevents duplicate routes and preserves the query after return', (tester) async {
    var pushes = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: AllFeaturesScreen(
            registry: registry,
            noWallets: true,
            onLaunch: (_, __) {},
            onAddWallet: (context) async {
              pushes++;
              await Navigator.of(
                context,
              ).push<void>(MaterialPageRoute(builder: (_) => const Scaffold(body: Text('Wallet add destination'))));
            },
          ),
        ),
      ),
    );
    await tester.enterText(find.byKey(const Key('all-features-search')), 'send');
    await tester.pump();
    final action = find.byKey(const Key('all-features-add-wallet'));
    final open = tester.widget<CupertinoButton>(action).onPressed!;
    open();
    open();
    await tester.pumpAndSettle();
    expect(pushes, 1);
    expect(find.text('Wallet add destination'), findsOneWidget);
    Navigator.of(tester.element(find.text('Wallet add destination'))).pop();
    await tester.pumpAndSettle();
    expect(find.text('send'), findsOneWidget);
    expect(find.byKey(const ValueKey('all-features-item-send')), findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(pushes, 2);
    Navigator.of(tester.element(find.text('Wallet add destination'))).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
