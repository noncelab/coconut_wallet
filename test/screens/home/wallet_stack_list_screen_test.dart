import 'dart:ui' as ui;

import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/app/theme/app_cupertino_theme.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/converter/utxo.dart';
import 'package:coconut_wallet/screens/home/wallet_stack_list_screen.dart';
import 'package:coconut_wallet/services/home/wallet_widget_definitions.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../mock/utxo_mock.dart';
import '../../mock/wallet_mock.dart';

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  final List<WalletItemBase> wallets;

  _Wallets(this.wallets);

  @override
  List<WalletItemBase> get walletItemList => wallets;

  @override
  Balance getWalletBalance(int walletId) => Balance(walletId * 100000000, 0);

  @override
  List<TransactionRecord> getTransactionRecordList(int walletId) => const [];

  @override
  List<UtxoState> getUtxoList(int walletId) => [
    for (var i = 0; i < walletId; i++)
      mapRealmToUtxoState(UtxoMock.createMockUtxo(walletId: walletId, address: 'a$walletId-$i', amount: 1000)),
  ];
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;

  @override
  List<int> get walletOrder => const [];

  @override
  bool get isFakeBalanceActive => true;
}

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

final _wallets = <WalletItemBase>[
  WalletMock.createSingleSigWalletItem(id: 1),
  WalletMock.createSingleSigWalletItem(id: 2),
  _hot(3),
];

Future<void> _pumpHome(WidgetTester tester, {WalletStackKind kind = WalletStackKind.all, WalletCardSize? stack}) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final wallets = orderStackWallets(_wallets, const [], kind: kind);
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>.value(value: _Wallets(_wallets)),
        ChangeNotifierProvider<PreferenceProvider>.value(value: _Preferences()),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: stack == WalletCardSize.wide ? 352 : 172,
                    height: 172,
                    child: WalletStackView(
                      keyPrefix: 'stack',
                      wallets: wallets,
                      size: stack ?? WalletCardSize.small,
                      emptyText: 'empty',
                      onOpen: (request) => WalletStackListScreen.open(context, kind: kind, request: request),
                    ),
                  ),
                ),
              ),
        ),
      ),
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('stack-pager')));
  await tester.pump();
  await tester.pump(WalletStackListScreen.transitionDuration);
  await tester.pump(const Duration(milliseconds: 50));
}

const _paintBoundaryKey = ValueKey('wallet-stack-paint-boundary');
const _detailKey = ValueKey('wallet-stack-detail-destination');

Future<_Wallets> _pumpCupertinoHome(
  WidgetTester tester, {
  WalletCardSize size = WalletCardSize.small,
  bool reducedMotion = false,
  List<WalletItemBase>? items,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final wallets = _Wallets(items ?? _wallets);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>.value(value: wallets),
        ChangeNotifierProvider<PreferenceProvider>.value(value: _Preferences()),
      ],
      child: CupertinoApp(
        theme: buildAppCupertinoTheme(),
        localizationsDelegates: const [
          DefaultMaterialLocalizations.delegate,
          DefaultWidgetsLocalizations.delegate,
          DefaultCupertinoLocalizations.delegate,
        ],
        builder:
            (context, child) => Theme(
              data: buildCoconutThemeData(),
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion),
                child: RepaintBoundary(key: _paintBoundaryKey, child: child),
              ),
            ),
        routes: {
          AppRouteNames.walletDetail:
              (_) => const Scaffold(key: _detailKey, body: Center(child: Text('Synthetic detail destination'))),
        },
        home: Builder(
          builder:
              (context) => Scaffold(
                body: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: size == WalletCardSize.wide ? 352 : 172,
                      height: 172,
                      child: WalletStackView(
                        keyPrefix: 'stack',
                        wallets: wallets.wallets,
                        size: size,
                        emptyText: 'empty',
                        onOpen:
                            (request) =>
                                WalletStackListScreen.open(context, kind: WalletStackKind.all, request: request),
                      ),
                    ),
                    TextButton(
                      key: const Key('open-list-without-hero'),
                      onPressed: () => WalletStackListScreen.open(context, kind: WalletStackKind.all),
                      child: const Text('Open list'),
                    ),
                  ],
                ),
              ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return wallets;
}

Future<double> _paintedCardFraction(WidgetTester tester, Key key, {required String phase}) async {
  final card = find.byKey(key);
  expect(card, findsOneWidget, reason: phase);
  final rect = tester.getRect(card);
  expect(rect.isFinite, isTrue, reason: phase);
  expect(rect.width, greaterThan(100), reason: phase);
  final background = tester.element(card).coconutColors.background;
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_paintBoundaryKey));
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
  try {
    final pixels = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    final sample = Rect.fromLTRB(
      rect.left + rect.width * 0.2,
      rect.top + rect.height * 0.25,
      rect.right - rect.width * 0.2,
      rect.bottom - rect.height * 0.25,
    ).intersect(Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()));
    var painted = 0;
    var sampled = 0;
    for (var y = sample.top.ceil(); y < sample.bottom.floor(); y++) {
      for (var x = sample.left.ceil(); x < sample.right.floor(); x++) {
        final offset = (y * image.width + x) * 4;
        final distance =
            (pixels.getUint8(offset) - (background.r * 255).round()).abs() +
            (pixels.getUint8(offset + 1) - (background.g * 255).round()).abs() +
            (pixels.getUint8(offset + 2) - (background.b * 255).round()).abs();
        if (distance > 6) painted++;
        sampled++;
      }
    }
    expect(sampled, greaterThan(1000), reason: '$phase must sample an on-screen card body.');
    return painted / sampled;
  } finally {
    image.dispose();
  }
}

Future<void> _expectCardPainted(WidgetTester tester, Key key, {required String phase}) async {
  expect(
    await _paintedCardFraction(tester, key, phase: phase),
    greaterThan(0.85),
    reason: '$phase must paint its card body before any scroll, not just retain a Widget or Rect.',
  );
}

void main() {
  for (final walletCount in [9, 40]) {
    testWidgets('bounded indicator follows first middle and add pages with $walletCount wallets', (tester) async {
      await _pumpCupertinoHome(
        tester,
        items: [for (var id = 1; id <= walletCount; id++) WalletMock.createSingleSigWalletItem(id: id)],
      );
      await _open(tester);
      expect(tester.takeException(), isNull);
      final pager = tester.widget<PageView>(find.byKey(const Key('wallet-stack-list-pager')));
      for (final page in [0, walletCount ~/ 2, walletCount]) {
        pager.controller!.jumpToPage(page);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'page $page of ${walletCount + 1}');
        final indicator = find.byKey(const Key('wallet-stack-list-indicator'));
        expect(find.byKey(ValueKey('wallet-stack-list-indicator-dot-$page')), findsOneWidget);
        final selected = tester.widget<Container>(find.byKey(ValueKey('wallet-stack-list-indicator-dot-$page')));
        expect(selected.constraints!.maxHeight, 20);
        final bounds = tester.getRect(indicator);
        expect(bounds.height, lessThanOrEqualTo(120));
        final dots = find.descendant(
          of: indicator,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key! as ValueKey<String>).value.startsWith('wallet-stack-list-indicator-dot-'),
          ),
        );
        expect(dots.evaluate().length, lessThanOrEqualTo(9));
        final rects = [for (final dot in dots.evaluate()) tester.getRect(find.byWidget(dot.widget))];
        expect(rects.where((rect) => rect.height > 20).length, 1);
        for (final rect in rects) {
          expect(rect.top, greaterThanOrEqualTo(bounds.top));
          expect(rect.bottom, lessThanOrEqualTo(bounds.bottom));
          expect(rect.width, 6);
        }
        if (page < walletCount) {
          expect(find.byKey(ValueKey('wallet-stack-list-facts-${page + 1}')), findsOneWidget);
        } else {
          expect(find.byKey(const Key('wallet-stack-list-add-card')), findsOneWidget);
        }
      }
    });
  }

  for (final size in WalletCardSize.values) {
    for (final initialPage in [0, 1, 2]) {
      for (final reducedMotion in [false, true]) {
        testWidgets(
          'Cupertino entry paints its selected card ($size, page=$initialPage, reducedMotion=$reducedMotion)',
          (tester) async {
            await _pumpCupertinoHome(tester, size: size, reducedMotion: reducedMotion);
            final homePager = tester.widget<PageView>(find.byKey(const Key('stack-pager')));
            homePager.controller!.jumpToPage(initialPage);
            await tester.pumpAndSettle();
            final walletId = _wallets[initialPage].id;
            await _expectCardPainted(tester, ValueKey('stack-card-$walletId'), phase: 'source');

            await _open(tester);
            expect(find.byKey(ValueKey('wallet-stack-list-facts-$walletId')), findsOneWidget);
            await _expectCardPainted(tester, ValueKey('wallet-stack-list-card-$walletId'), phase: 'entry complete');
            await tester.pump(const Duration(seconds: 3));
            await _expectCardPainted(
              tester,
              ValueKey('wallet-stack-list-card-$walletId'),
              phase: 'idle without scrolling',
            );

            // The transparent PageView receives input over the painted card.
            await tester.tapAt(tester.getCenter(find.byKey(ValueKey('wallet-stack-list-card-$walletId'))));
            await tester.pumpAndSettle();
            final detail = tester.element(find.byKey(_detailKey));
            expect((ModalRoute.of(detail)!.settings.arguments! as WalletDetailRouteArgs).id, walletId);
            Navigator.of(detail).pop();
            await tester.pumpAndSettle();
            await _expectCardPainted(
              tester,
              ValueKey('wallet-stack-list-card-$walletId'),
              phase: 'detail route return',
            );

            Navigator.of(tester.element(find.byKey(const Key('wallet-stack-list-wheel')))).pop();
            await tester.pumpAndSettle();
            await _expectCardPainted(tester, ValueKey('stack-card-$walletId'), phase: 'source return');
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('the pixel oracle detects a hidden middle card even while its Widget and Rect remain', (tester) async {
    await _pumpCupertinoHome(tester);
    await _open(tester);
    const key = ValueKey('wallet-stack-list-card-1');
    final rect = tester.getRect(find.byKey(key));
    final opacity = tester.renderObject<RenderOpacity>(
      find.descendant(of: find.byKey(const ValueKey('wallet-stack-list-slot-0')), matching: find.byType(Opacity)).first,
    );
    await _expectCardPainted(tester, key, phase: 'negative control before hiding');
    try {
      opacity.opacity = 0;
      await tester.pump();
      expect(find.byKey(key), findsOneWidget);
      expect(tester.getRect(find.byKey(key)), rect);
      expect(await _paintedCardFraction(tester, key, phase: 'negative control hidden'), lessThan(0.5));
    } finally {
      opacity.opacity = 1;
      await tester.pump();
    }
    await _expectCardPainted(tester, key, phase: 'negative control restored');
  });

  for (final elapsed in [16, 80, 240]) {
    testWidgets('Cupertino fast Back after ${elapsed}ms paints the source and reentered card', (tester) async {
      await _pumpCupertinoHome(tester);
      await tester.tap(find.byKey(const Key('stack-pager')));
      await tester.pump();
      await tester.pump(Duration(milliseconds: elapsed));
      Navigator.of(tester.element(find.byKey(const Key('wallet-stack-list-wheel')))).pop();
      await tester.pumpAndSettle();
      await _expectCardPainted(tester, const ValueKey('stack-card-1'), phase: 'fast Back source');
      await _open(tester);
      await _expectCardPainted(tester, const ValueKey('wallet-stack-list-card-1'), phase: 'fast reentry');
      expect(tester.takeException(), isNull);
    });
  }

  for (final count in [1, 3]) {
    testWidgets('Cupertino menu entry paints the first card with $count wallets and no Hero source', (tester) async {
      final wallets = await _pumpCupertinoHome(tester, items: _wallets.take(count).toList());
      await tester.tap(find.byKey(const Key('open-list-without-hero')));
      await tester.pumpAndSettle();
      await _expectCardPainted(tester, const ValueKey('wallet-stack-list-card-1'), phase: 'menu entry');
      wallets.notifyListeners();
      await tester.pumpAndSettle();
      await _expectCardPainted(tester, const ValueKey('wallet-stack-list-card-1'), phase: 'provider update');
    });
  }

  testWidgets('tapping the stack flies its front card into the middle of the wheel and fans out the rest', (
    tester,
  ) async {
    await _pumpHome(tester);
    final stackRect = tester.getRect(find.byKey(const ValueKey('stack-card-1')));

    await tester.tap(find.byKey(const Key('stack-pager')));
    await tester.pump();
    await tester.pump(WalletStackListScreen.transitionDuration ~/ 2);
    expect(find.byType(Hero), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pump(WalletStackListScreen.transitionDuration);
    final card = tester.getRect(find.byKey(const ValueKey('wallet-stack-list-card-1')));
    expect(card.width, greaterThan(stackRect.width));
    expect(card.width, closeTo(card.height, 0.5));
    final below = tester.getRect(find.byKey(const ValueKey('wallet-stack-list-slot-1')));
    expect(below.center.dy, greaterThan(card.center.dy));
    expect(below.center.dx, greaterThan(card.center.dx));
  });

  testWidgets('a 4×2 stack card shrinks to the square wheel card without errors', (tester) async {
    await _pumpHome(tester, stack: WalletCardSize.wide);

    await tester.tap(find.byKey(const Key('stack-pager')));
    await tester.pump();
    for (var i = 0; i < 6; i++) {
      await tester.pump(WalletStackListScreen.transitionDuration ~/ 5);
    }

    expect(tester.takeException(), isNull);
    final card = tester.getRect(find.byKey(const ValueKey('wallet-stack-list-card-1')));
    expect(card.width, closeTo(card.height, 0.5));
  });

  testWidgets('the wheel shows real balances and the facts of the middle wallet, with the type only for all wallets', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _open(tester);

    expect(find.text('1 BTC'), findsOneWidget);
    expect(find.text(t.wallet_stack_list.utxos), findsOneWidget);
    expect(find.text(t.wallet_stack_list.no_transaction), findsOneWidget);
    expect(find.text(t.wallet_stack_list.type), findsOneWidget);
    expect(
      find.text('${t.wallet_home_screen.wallet_filter.watch_only} • ${t.wallet_stack_list.single_sig}'),
      findsOneWidget,
    );
  });

  testWidgets('a watch-only list shows only how the wallet signs', (tester) async {
    await _pumpHome(tester, kind: WalletStackKind.watchOnly);
    await _open(tester);

    expect(find.text(t.wallet_stack_list.type), findsOneWidget);
    expect(find.text(t.wallet_stack_list.single_sig), findsOneWidget);
  });

  testWidgets('a hot wallet list shows no type, since every hot wallet is single-sig', (tester) async {
    await _pumpHome(tester, kind: WalletStackKind.hot);
    await _open(tester);

    expect(find.text(t.wallet_stack_list.utxos), findsOneWidget);
    expect(find.text(t.wallet_stack_list.type), findsNothing);
  });

  testWidgets('swiping up brings the next wallet to the middle, moves the stack along, and ends at an add card', (
    tester,
  ) async {
    await _pumpHome(tester);
    await _open(tester);

    for (var i = 0; i < 2; i++) {
      await tester.drag(find.byKey(const Key('wallet-stack-list-pager')), const Offset(0, -400));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('wallet-stack-list-facts-3')), findsOneWidget);
    expect(find.text('${t.wallet_home_screen.wallet_filter.hot} • ${t.wallet_stack_list.single_sig}'), findsOneWidget);

    await tester.drag(find.byKey(const Key('wallet-stack-list-pager')), const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-stack-list-add-card')), findsOneWidget);
    expect(find.text(t.wallet_stack_list.utxos), findsNothing);

    await tester.drag(find.byKey(const Key('wallet-stack-list-pager')), const Offset(0, 400));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byKey(const Key('wallet-stack-list-wheel')))).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('stack-card-3')), findsOneWidget);
  });

  testWidgets('opened from My Wallets, the wheel shows its title', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>.value(value: _Wallets(_wallets)),
          ChangeNotifierProvider<PreferenceProvider>.value(value: _Preferences()),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          home: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () => WalletStackListScreen.open(context, kind: WalletStackKind.all, title: 'My Wallets'),
                  child: const Text('open'),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('My Wallets'), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-stack-list-card-1')), findsOneWidget);
  });
}
