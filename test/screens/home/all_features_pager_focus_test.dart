import 'dart:async';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/screens/home/all_features_screen.dart';
import 'package:coconut_wallet/services/feature/feature_launcher.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/widgets/features/home/home_cube_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/wallet_mock.dart';

enum _LeaveSearch { swipe, back, programmatic }

void main() {
  late GlobalKey<HomeCubePagerState> pagerKey;
  late VoidCallback showHome;
  var walletLaunches = 0;
  final search = find.byKey(const Key('all-features-search'));
  final registry = FeatureRegistry([
    FeatureItem(id: 'settings', label: () => 'Settings', category: FeatureCategory.settings),
    FeatureItem(id: 'settings.unit', label: () => 'Unit', parentId: 'settings'),
    FeatureItem(
      id: 'send',
      label: () => 'Send',
      category: FeatureCategory.transactions,
      context: FeatureContext.wallet,
      launch: (_, __) async => walletLaunches++,
    ),
  ]);

  FocusNode searchFocus(WidgetTester tester) =>
      tester.widget<EditableText>(find.descendant(of: search, matching: find.byType(EditableText))).focusNode;

  double page(WidgetTester tester) => tester.widget<PageView>(find.byType(PageView)).controller!.page!;

  Future<void> pump(WidgetTester tester, {void Function(BuildContext, FeatureItem)? onLaunch}) async {
    pagerKey = GlobalKey<HomeCubePagerState>();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: HomeCubePager(
            key: pagerKey,
            home: const ColoredBox(color: Colors.black, child: SizedBox.expand(child: Text('Home'))),
            allFeaturesBuilder: (callback) {
              showHome = callback;
              return AllFeaturesScreen(registry: registry, onLaunch: onLaunch ?? (_, __) {});
            },
          ),
        ),
      ),
    );
    pagerKey.currentState!.showAllFeatures();
    await tester.pumpAndSettle();
    await tester.enterText(search, 'unit');
    await tester.pump();
    expect(searchFocus(tester).hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  }

  for (final leave in _LeaveSearch.values) {
    testWidgets(
      'leaving search by ${leave.name} dismisses keyboard and keeps query on return',
      (tester) async {
        await pump(tester);
        final focus = searchFocus(tester);
        switch (leave) {
          case _LeaveSearch.swipe:
            await tester.fling(find.byType(PageView), const Offset(600, 0), 1000);
          case _LeaveSearch.back:
            await tester.binding.handlePopRoute();
          case _LeaveSearch.programmatic:
            showHome();
        }
        await tester.pumpAndSettle();
        expect(page(tester), 0);
        expect(focus.hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);

        pagerKey.currentState!.showAllFeatures();
        await tester.pumpAndSettle();
        expect(page(tester), 1);
        expect(
          tester.widget<EditableText>(find.descendant(of: search, matching: find.byType(EditableText))).controller.text,
          'unit',
        );
        expect(searchFocus(tester).hasFocus, isFalse);
        expect(tester.testTextInput.isVisible, isFalse);
        await tester.tap(search);
        await tester.pump();
        expect(searchFocus(tester).hasFocus, isTrue);
        expect(tester.testTextInput.isVisible, isTrue);
      },
      variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
    );
  }

  testWidgets('canceling a partial page swipe retains the active search focus', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byType(PageView)));
    await gesture.moveBy(const Offset(100, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(page(tester), 1);
    expect(searchFocus(tester).hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('a destination sheet keeps its own focus while the underlying pager changes', (tester) async {
    final destinationFocus = FocusNode();
    addTearDown(destinationFocus.dispose);
    await pump(
      tester,
      onLaunch: (context, item) {
        expect(item.id, 'settings.unit');
        unawaited(
          showModalBottomSheet<void>(
            context: context,
            builder:
                (_) => TextField(key: const Key('destination-input'), focusNode: destinationFocus, autofocus: true),
          ),
        );
      },
    );
    final focus = searchFocus(tester);
    await tester.tap(find.byKey(const ValueKey('all-features-item-settings')));
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
    expect(destinationFocus.hasFocus, isTrue);
    showHome();
    await tester.pumpAndSettle();
    expect(page(tester), 0);
    expect(destinationFocus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    Navigator.of(tester.element(find.byKey(const Key('destination-input')))).pop();
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('wallet picker cancellation keeps its search restoration and leaving then dismisses focus', (
    tester,
  ) async {
    walletLaunches = 0;
    FeatureLaunchResult? result;
    await pump(
      tester,
      onLaunch: (context, item) {
        unawaited(
          FeatureLauncher(
            wallets: () => [WalletMock.createSingleSigWalletItem(id: 1), WalletMock.createSingleSigWalletItem(id: 2)],
            pickWallet:
                (context, _) => showModalBottomSheet<int>(
                  context: context,
                  builder:
                      (context) => TextButton(
                        key: const Key('cancel-wallet-picker'),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                ),
          ).launch(context, item).then((value) => result = value),
        );
      },
    );
    await tester.enterText(search, 'send');
    await tester.pump();
    final focus = searchFocus(tester);
    await tester.tap(find.byKey(const ValueKey('all-features-item-send')));
    await tester.pumpAndSettle();
    expect(searchFocus(tester).hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    await tester.tap(find.byKey(const Key('cancel-wallet-picker')));
    await tester.pumpAndSettle();
    expect(result, FeatureLaunchResult.cancelled);
    expect(walletLaunches, 0);
    expect(page(tester), 1);
    expect(searchFocus(tester).hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(
      tester.widget<EditableText>(find.descendant(of: search, matching: find.byType(EditableText))).controller.text,
      'send',
    );
    showHome();
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  });
}
