import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/services/home/builtin_home_widgets.dart';
import 'package:coconut_wallet/services/home/wallet_widget_definitions.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/wallet_mock.dart';

SinglesigWalletItem _hot(int id) {
  final base = WalletMock.createSingleSigWalletItem(id: id);
  return SinglesigWalletItem(
    id: id,
    name: base.name,
    colorIndex: 0,
    iconIndex: 0,
    descriptor: base.descriptor,
    hotWalletMetadata: HotWalletMetadata(
      walletId: id,
      secureStorageKey: 'key',
      masterFingerprint: 'D45AA182',
      derivationPath: "m/84'/1'/0'",
      accountIndex: 0,
      backupVerified: true,
      enterPassphraseWhenSigning: false,
      createdAt: DateTime(2026),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  List<WalletItemBase> wallets, {
  VoidCallback? onPressed,
  WalletCardSize size = WalletCardSize.small,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home: Center(
        child: SizedBox(
          width: size == WalletCardSize.wide ? 352 : 172,
          height: 172,
          child: WalletStackView(
            keyPrefix: 'stack',
            wallets: wallets,
            size: size,
            emptyText: 'empty',
            balanceTextOf: (wallet) => '${wallet.id} BTC',
            onPressed: onPressed,
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('hot, watch-only and all-wallet stacks are one widget each that can be 2×2 or 4×2', () {
    final definitions = walletStackDefinitions();

    expect(definitions.map((definition) => definition.id), [
      HomeItemIds.allWalletStack,
      HomeItemIds.watchOnlyWalletStack,
      HomeItemIds.hotWalletStack,
    ]);
    for (final definition in definitions) {
      expect(definition.supportedSpans, [HomeSpan.small, HomeSpan.wide]);
      expect(definition.allowsMultipleInstances, isFalse);
      expect(definition.needsConfigureBeforeAdd, isTrue);
      expect(definition.settings.sizes, [HomeSpan.wide, HomeSpan.small]);
      expect(definition.category, HomeItemCategory.wallets);
    }
  });

  test('every built-in widget has a unique id and only widgets with a size choice offer two sizes', () {
    final definitions = builtinHomeWidgets();
    final ids = definitions.map((definition) => definition.id).toList();

    expect(ids.toSet(), hasLength(ids.length));
    expect(
      definitions.every(
        (definition) =>
            definition.supportedSpans.length == 1 ||
            definition.settings.sizes.toSet().containsAll(definition.supportedSpans),
      ),
      isTrue,
    );
    expect(definitions.any((definition) => definition.category == HomeItemCategory.safety), isFalse);
    for (final id in [HomeItemIds.recentTransactions, HomeItemIds.transactionActivity]) {
      expect(definitions.firstWhere((definition) => definition.id == id).category, HomeItemCategory.activities);
    }
    expect(definitions.firstWhere((definition) => definition.id == HomeItemIds.bitcoinBalanceTrend).supportedSpans, [
      HomeSpan.small,
      HomeSpan.wide,
    ]);
  });

  test('stack wallets keep only one type, in wallet order; multisig and other watch-only go to watch-only', () {
    final wallets = [
      WalletMock.createSingleSigWalletItem(id: 1),
      _hot(2),
      WalletMock.createMultiSigWalletItem(id: 3),
      WalletMock.createSingleSigWalletItem(id: 4),
      _hot(5),
    ];

    expect(orderStackWallets(wallets, [4, 2, 1], kind: WalletStackKind.watchOnly).map((wallet) => wallet.id), [
      4,
      1,
      3,
    ]);
    expect(orderStackWallets(wallets, [4, 5, 2], kind: WalletStackKind.hot).map((wallet) => wallet.id), [5, 2]);
    expect(orderStackWallets(wallets, const [], kind: WalletStackKind.hot).map((wallet) => wallet.id), [2, 5]);
    expect(orderStackWallets(wallets, [4, 5, 2], kind: WalletStackKind.all).map((wallet) => wallet.id).toSet(), {
      for (final wallet in wallets) wallet.id,
    });
    expect(orderStackWallets(wallets, [4, 5, 2], kind: WalletStackKind.all).take(3).map((wallet) => wallet.id), [
      4,
      5,
      2,
    ]);
  });

  testWidgets('shows the first wallet with no arrow buttons', (tester) async {
    await _pump(tester, [WalletMock.createSingleSigWalletItem(id: 7), WalletMock.createSingleSigWalletItem(id: 8)]);

    expect(find.byKey(const ValueKey('stack-card-7')), findsOneWidget);
    expect(find.byKey(const Key('stack-next')), findsNothing);
    expect(find.byKey(const Key('stack-previous')), findsNothing);
    expect(find.byType(CupertinoButton), findsNothing);
  });

  testWidgets('swiping horizontally moves to the next wallet', (tester) async {
    await _pump(tester, [WalletMock.createSingleSigWalletItem(id: 7), WalletMock.createSingleSigWalletItem(id: 8)]);

    await tester.drag(find.byKey(const Key('stack-pager')), const Offset(-150, 0));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('stack-card-8')), findsOneWidget);
  });

  testWidgets('while swiping left, the front card shrinks away and the next card grows in from the right', (
    tester,
  ) async {
    await _pump(tester, [WalletMock.createSingleSigWalletItem(id: 7), WalletMock.createSingleSigWalletItem(id: 8)]);
    final fullWidth = tester.getRect(find.byKey(const ValueKey('stack-card-7'))).width;
    final restingBackRect = tester.getRect(find.byKey(const ValueKey('stack-card-8')));
    final restingBack = restingBackRect.width;
    expect(restingBack, closeTo(fullWidth * WalletStackView.backStartScale, 0.5));
    final restingFront = tester.getRect(find.byKey(const ValueKey('stack-card-7')));
    expect(restingBackRect.center.dx, greaterThan(restingFront.center.dx));

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('stack-pager'))));
    await gesture.moveBy(const Offset(-30, 0));
    await gesture.moveBy(const Offset(-40, 0));
    await tester.pump();

    final front = tester.getRect(find.byKey(const ValueKey('stack-card-7'))).width;
    final back = tester.getRect(find.byKey(const ValueKey('stack-card-8'))).width;
    expect(front, lessThan(fullWidth));
    expect(back, greaterThan(restingBack));
    expect(back, lessThan(fullWidth));
    final backCenter = tester.getRect(find.byKey(const ValueKey('stack-card-8'))).center.dx;
    expect(backCenter, lessThan(restingBackRect.center.dx));
    expect(backCenter, greaterThan(restingFront.center.dx));

    await gesture.moveBy(const Offset(-40, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const ValueKey('stack-card-8'))).width, closeTo(fullWidth, 0.5));
    expect(find.byKey(const ValueKey('stack-card-7')), findsNothing);
  });

  testWidgets('the page indicator fades in only while swiping', (tester) async {
    await _pump(tester, [
      WalletMock.createSingleSigWalletItem(id: 7),
      WalletMock.createSingleSigWalletItem(id: 8),
      WalletMock.createSingleSigWalletItem(id: 9),
    ]);
    double opacity() => tester.widget<AnimatedOpacity>(find.byKey(const Key('stack-indicator'))).opacity;

    expect(opacity(), 0);

    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('stack-pager'))));
    await gesture.moveBy(const Offset(-30, 0));
    await gesture.moveBy(const Offset(-30, 0));
    await tester.pump();
    expect(opacity(), 1);

    await gesture.up();
    await tester.pumpAndSettle();
    expect(opacity(), 1);

    await tester.pump(const Duration(milliseconds: 900));
    expect(opacity(), 0);
  });

  testWidgets('a single wallet has no page indicator', (tester) async {
    await _pump(tester, [WalletMock.createSingleSigWalletItem(id: 7)]);

    expect(find.byKey(const Key('stack-indicator')), findsNothing);
  });

  testWidgets('the wide card shows its balance', (tester) async {
    await _pump(tester, [WalletMock.createSingleSigWalletItem(id: 9)], size: WalletCardSize.wide);

    expect(find.text('9 BTC'), findsOneWidget);
  });

  testWidgets('an empty stack shows the empty message and is still tappable', (tester) async {
    var tapped = 0;
    await _pump(tester, const [], onPressed: () => tapped++);

    expect(find.text('empty'), findsOneWidget);
    await tester.tap(find.byKey(const Key('stack-empty')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tapped, 1);
  });

  testWidgets('an empty stack offers to add a wallet and tapping it adds instead of opening the list', (tester) async {
    var opened = 0;
    var added = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Center(
          child: SizedBox(
            width: 172,
            height: 172,
            child: WalletStackView(
              keyPrefix: 'stack',
              wallets: const [],
              size: WalletCardSize.small,
              emptyText: 'No hot wallets',
              emptyActionText: 'Add Hot Wallet',
              onPressed: () => opened++,
              onEmptyPressed: () => added++,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Add Hot Wallet'), findsOneWidget);
    expect(find.text('No hot wallets'), findsNothing);

    await tester.tap(find.byKey(const Key('stack-empty')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(added, 1);
    expect(opened, 0);
  });

  testWidgets('tapping a card calls onPressed', (tester) async {
    var tapped = 0;
    await _pump(tester, [WalletMock.createSingleSigWalletItem(id: 9)], onPressed: () => tapped++);

    await tester.tap(find.byKey(const ValueKey('stack-card-9')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tapped, 1);
  });
}
