import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/widgets/common/text/animated_dots_text.dart';
import 'package:coconut_wallet/widgets/features/home/all_features_hint.dart';
import 'package:coconut_wallet/widgets/features/home/home_cube_pager.dart';
import 'package:coconut_wallet/widgets/features/wallet/amount/wallet_balance_sync_shimmer.dart';
import 'package:coconut_wallet/widgets/features/wallet/menu/long_pressed_menu_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shimmer/shimmer.dart';

void main() {
  for (final accessibleNavigation in [false, true]) {
    testWidgets('decorative loops stop and resume live: accessibleNavigation=$accessibleNavigation', (tester) async {
      final reduced = ValueNotifier(false);
      addTearDown(reduced.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(),
          home: ValueListenableBuilder<bool>(
            valueListenable: reduced,
            builder:
                (context, value, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations: !accessibleNavigation && value,
                    accessibleNavigation: accessibleNavigation && value,
                  ),
                  child: child!,
                ),
            child: Column(
              children: [
                AllFeaturesHint(onOpen: () {}, onClose: () {}),
                const AnimatedDotsText(text: 'Syncing', style: TextStyle()),
                const WalletBalanceSyncShimmer(isRefreshing: true, child: Text('Balance')),
                const LongPressedMenuWidget(isEditMode: true, menuItems: [], child: SizedBox(width: 100, height: 100)),
              ],
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      reduced.value = true;
      await tester.pumpAndSettle();
      expect(find.text('Syncing...'), findsOneWidget);
      expect(find.text('Balance'), findsOneWidget);
      expect(tester.widget<Shimmer>(find.byType(Shimmer)).enabled, isFalse);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.binding.transientCallbackCount, 0);
      reduced.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reduced motion cancels an in-flight peek and preserves page controls', (tester) async {
    final reduced = ValueNotifier(false);
    addTearDown(reduced.dispose);
    final key = GlobalKey<HomeCubePagerState>();
    VoidCallback? showHome;
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: reduced,
          builder:
              (context, value, child) =>
                  MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: value), child: child!),
          child: HomeCubePager(
            key: key,
            home: const Text('home'),
            allFeaturesBuilder: (callback) {
              showHome = callback;
              return const Text('all');
            },
          ),
        ),
      ),
    );
    double page() => tester.widget<PageView>(find.byType(PageView)).controller!.page!;
    final peek = key.currentState!.peek();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(page(), greaterThan(0));
    reduced.value = true;
    await tester.pumpAndSettle();
    await peek;
    expect(page(), 0);
    await key.currentState!.peek();
    await tester.pump(const Duration(seconds: 3));
    expect(page(), 0);
    expect(tester.binding.transientCallbackCount, 0);
    key.currentState!.showAllFeatures();
    await tester.pump();
    expect(page(), 1);
    showHome!();
    await tester.pump();
    expect(page(), 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening All Features cancels pending peek return', (tester) async {
    final key = GlobalKey<HomeCubePagerState>();
    await tester.pumpWidget(
      MaterialApp(
        home: HomeCubePager(key: key, home: const Text('home'), allFeaturesBuilder: (_) => const Text('all')),
      ),
    );
    final peek = key.currentState!.peek();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 160));
    key.currentState!.showAllFeatures();
    await tester.pumpAndSettle();
    await peek;
    await tester.pump(const Duration(seconds: 3));
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
  });
}
