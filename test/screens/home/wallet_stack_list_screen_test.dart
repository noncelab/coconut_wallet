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
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_stack_list_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/card_detail/wallet_detail_expand_transition.dart';
import 'package:coconut_wallet/services/home/wallet_widget_definitions.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  List<int> walletOrder = const [];

  @override
  bool get isFakeBalanceActive => true;

  @override
  Future<void> setWalletOrder(List<int> walletOrder) async {
    this.walletOrder = walletOrder;
    notifyListeners();
  }
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

Future<void> _pumpHome(
  WidgetTester tester, {
  WalletStackKind kind = WalletStackKind.all,
  WalletCardSize? stack,
  CoconutThemeVariant variant = CoconutThemeVariant.dark,
  List<WalletItemBase>? walletItems,
}) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final sourceWallets = walletItems ?? _wallets;
  final wallets = orderStackWallets(sourceWallets, const [], kind: kind);
  return tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<WalletProvider>.value(value: _Wallets(sourceWallets)),
        ChangeNotifierProvider<PreferenceProvider>.value(value: _Preferences()),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(variant: variant),
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
  for (final back in ['header', 'system', 'navigator']) {
    testWidgets('add card closes without a wallet Hero flight via $back Back', (tester) async {
      await _pumpCupertinoHome(tester);
      await _open(tester);
      final pager = tester.widget<PageView>(find.byKey(const Key('wallet-stack-list-pager')));
      pager.controller!.jumpToPage(2);
      await tester.pumpAndSettle();
      pager.controller!.jumpToPage(3);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wallet-stack-list-add-card')), findsOneWidget);
      if (back == 'header') {
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        await tester.tap(find.byWidget(appBar.leading!));
      } else if (back == 'system') {
        await tester.binding.handlePopRoute();
      } else {
        Navigator.of(tester.element(find.byKey(const Key('wallet-stack-list-wheel')))).pop();
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final flyingCards = find.byType(WalletCard).evaluate().where((element) => ModalRoute.of(element) == null);
      expect(flyingCards, isEmpty, reason: 'The add card has no wallet counterpart on Home.');
      expect(find.byKey(const Key('wallet-stack-list-add-card')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('wallet-stack-list-wheel')), findsNothing);
      expect(find.byKey(const ValueKey('stack-card-3')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('returning from the add card to a wallet restores its normal Hero flight', (tester) async {
    await _pumpCupertinoHome(tester);
    await _open(tester);
    final pager = tester.widget<PageView>(find.byKey(const Key('wallet-stack-list-pager')));
    pager.controller!.jumpToPage(3);
    await tester.pumpAndSettle();
    pager.controller!.jumpToPage(1);
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byKey(const Key('wallet-stack-list-wheel')))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final flyingCards = find.byType(WalletCard).evaluate().where((element) => ModalRoute.of(element) == null);
    expect(flyingCards, isNotEmpty, reason: 'The selected real wallet must still fly back to Home.');
    await tester.pumpAndSettle();
    await _expectCardPainted(tester, const ValueKey('stack-card-2'), phase: 'real wallet return after add');
    expect(tester.takeException(), isNull);
  });

  testWidgets('holding a swiped home wallet card repeats every 450ms and release stops it', (tester) async {
    await _pumpHome(
      tester,
      walletItems: [for (var id = 1; id <= 8; id++) WalletMock.createSingleSigWalletItem(id: id)],
    );
    await tester.pumpAndSettle();
    final controller = tester.widget<PageView>(find.byKey(const Key('stack-pager'))).controller!;
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('stack-card-slider'))));
    await gesture.moveBy(const Offset(-24, 0));
    await gesture.moveBy(const Offset(-24, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(controller.page, closeTo(1, 0.01));
    await tester.pump(const Duration(milliseconds: 229));
    expect(controller.page, closeTo(1, 0.01));
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 220));
    expect(controller.page, closeTo(2, 0.01));
    await tester.pump(const Duration(milliseconds: 230));
    await tester.pump(const Duration(milliseconds: 220));
    expect(controller.page, closeTo(3, 0.01));
    expect(tester.widget<AnimatedOpacity>(find.byKey(const Key('stack-indicator'))).opacity, 1);
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(3, 0.01));
    expect(find.byType(WalletStackListScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('held card swipes clamp at the edge and reverse direction before cancelling', (tester) async {
    await _pumpHome(tester);
    await tester.pumpAndSettle();
    final controller = tester.widget<PageView>(find.byKey(const Key('stack-pager'))).controller!;
    controller.jumpToPage(2);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('stack-card-slider'))));
    await gesture.moveBy(const Offset(-24, 0));
    await gesture.moveBy(const Offset(-24, 0));
    await tester.pump(const Duration(milliseconds: 900));
    expect(controller.page, closeTo(2, 0.01));
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));
    expect(controller.page, closeTo(1, 0.01));
    await gesture.cancel();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(1, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home indicator uses distance at the first two pages and 500ms repeats through to the edge', (
    tester,
  ) async {
    await _pumpHome(
      tester,
      walletItems: [for (var id = 1; id <= 8; id++) WalletMock.createSingleSigWalletItem(id: id)],
    );
    await tester.pumpAndSettle();
    final controller = tester.widget<PageView>(find.byKey(const Key('stack-pager'))).controller!;
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('stack-indicator-scrubber'))));
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();
    expect(controller.page, closeTo(1, 0.01));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(controller.page, closeTo(1, 0.01), reason: 'holding at the second page must not repeat');
    await gesture.moveBy(const Offset(180, 0));
    await tester.pump();
    expect(controller.page, closeTo(2, 0.01), reason: 'distance-based movement stops on entering the middle');
    await gesture.moveBy(const Offset(180, 0));
    await tester.pump();
    expect(controller.page, closeTo(2, 0.01), reason: 'extra distance is ignored in the middle');
    await tester.pump(const Duration(milliseconds: 499));
    expect(controller.page, closeTo(2, 0.01));
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.page, closeTo(3, 0.01));
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.page, closeTo(4, 0.01));
    await gesture.moveBy(const Offset(-24, 0));
    await tester.pump();
    expect(controller.page, closeTo(3, 0.01));
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.page, closeTo(2, 0.01));
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.page, closeTo(1, 0.01));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(controller.page, closeTo(0, 0.01), reason: 'automatic movement continues through the first two pages');
    await gesture.up();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(0, 0.01));
    final secondGesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('stack-indicator-scrubber'))),
    );
    await secondGesture.moveBy(const Offset(24, 0));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(controller.page, closeTo(1, 0.01), reason: 'a new drag at the edge returns to distance-based movement');
    await secondGesture.up();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('home indicator uses distance at the last two pages and repeats from the third-last', (tester) async {
    await _pumpHome(
      tester,
      walletItems: [for (var id = 1; id <= 8; id++) WalletMock.createSingleSigWalletItem(id: id)],
    );
    await tester.pumpAndSettle();
    final controller = tester.widget<PageView>(find.byKey(const Key('stack-pager'))).controller!;
    controller.jumpToPage(7);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('stack-indicator-scrubber'))));
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(controller.page, closeTo(7, 0.01));
    await gesture.moveBy(const Offset(-18, 0));
    await tester.pump();
    expect(controller.page, closeTo(6, 0.01));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(controller.page, closeTo(6, 0.01));
    await gesture.moveBy(const Offset(-18, 0));
    await tester.pump();
    expect(controller.page, closeTo(5, 0.01));
    await tester.pump(const Duration(milliseconds: 499));
    expect(controller.page, closeTo(5, 0.01));
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.page, closeTo(4, 0.01));
    await gesture.moveBy(const Offset(18, 0));
    await tester.pump();
    expect(controller.page, closeTo(5, 0.01));
    await tester.pump(const Duration(milliseconds: 500));
    expect(controller.page, closeTo(6, 0.01));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(controller.page, closeTo(7, 0.01), reason: 'automatic movement continues through the last two pages');
    await gesture.cancel();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(controller.page, closeTo(7, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('home wallet indicator slides five markers and stops shifting near either end', (tester) async {
    await _pumpHome(
      tester,
      walletItems: [for (var id = 1; id <= 9; id++) WalletMock.createSingleSigWalletItem(id: id)],
    );
    await tester.pumpAndSettle();
    final controller = tester.widget<PageView>(find.byKey(const Key('stack-pager'))).controller!;
    final window = find.byKey(const Key('stack-indicator-window'));
    Finder slot(int page) => find.byKey(ValueKey('stack-indicator-slot-$page'));
    double left(int page) => tester.getTopLeft(slot(page)).dx - tester.getTopLeft(window).dx;
    int visibleCount() =>
        find
            .descendant(of: window, matching: find.byType(Opacity))
            .evaluate()
            .where((element) => (element.widget as Opacity).opacity > 0)
            .length;

    expect(visibleCount(), 5);
    expect(left(0), closeTo(0, 0.01));
    controller.jumpToPage(2);
    await tester.pumpAndSettle();
    expect(left(0), closeTo(0, 0.01));
    controller.jumpToPage(3);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(left(0), closeTo(0, 0.01), reason: 'the selected marker changes before the row moves');
    await tester.pump(const Duration(milliseconds: 100));
    expect(left(0), lessThan(0));
    expect(left(1), greaterThan(0));
    final incoming = tester.widget<Opacity>(find.descendant(of: slot(5), matching: find.byType(Opacity)));
    expect(incoming.opacity, greaterThan(0));
    expect(incoming.opacity, lessThan(1));
    final incomingScale = tester.widget<Transform>(find.descendant(of: slot(5), matching: find.byType(Transform)));
    expect(incomingScale.transform.storage[0], closeTo(incoming.opacity, 0.001));
    final departingScale = tester.widget<Transform>(find.descendant(of: slot(0), matching: find.byType(Transform)));
    expect(departingScale.transform.storage[0], lessThan(1));
    await tester.pumpAndSettle();
    expect(left(1), closeTo(0, 0.01));
    expect(visibleCount(), 5);

    for (final page in [6, 7, 8, 7, 6]) {
      controller.jumpToPage(page);
      await tester.pumpAndSettle();
      expect(left(4), closeTo(0, 0.01), reason: 'the final two pages keep the window still');
      expect(visibleCount(), 5);
    }
    controller.jumpToPage(5);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(left(4), greaterThan(0), reason: 'moving back slides the markers to the right');
    await tester.pumpAndSettle();
    expect(left(3), closeTo(0, 0.01));
    for (final page in [2, 1, 0]) {
      controller.jumpToPage(page);
      await tester.pumpAndSettle();
      expect(left(0), closeTo(0, 0.01));
      expect(visibleCount(), 5);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('home wallet indicator switches whole pages and stays visible during scrubbing', (tester) async {
    await _pumpHome(tester);
    await tester.pumpAndSettle();
    final pager = tester.widget<PageView>(find.byKey(const Key('stack-pager')));
    final indicator = find.byKey(const Key('stack-indicator'));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('stack-indicator-scrubber'))));
    await gesture.moveBy(const Offset(24, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(12, 0));
    await tester.pump();
    expect(pager.controller!.page, closeTo(0, 0.01));
    await gesture.moveBy(const Offset(6, 0));
    await tester.pump();
    expect(pager.controller!.page, closeTo(1, 0.01));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<AnimatedOpacity>(indicator).opacity, 1);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 801));
    expect(pager.controller!.page, closeTo(1, 0.01));
    expect(tester.widget<AnimatedOpacity>(indicator).opacity, 0);
    expect(find.byType(WalletStackListScreen), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('home wallet indicator clamps and reverses at the first and last wallet', (tester) async {
    await _pumpHome(tester);
    await tester.pumpAndSettle();
    final pager = tester.widget<PageView>(find.byKey(const Key('stack-pager')));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('stack-indicator-scrubber'))));
    await gesture.moveBy(const Offset(24, 0));
    await gesture.moveBy(const Offset(120, 0));
    await tester.pump();
    expect(pager.controller!.page, closeTo(2, 0.01));
    await gesture.moveBy(const Offset(-18, 0));
    await tester.pump();
    expect(pager.controller!.page, closeTo(1, 0.01));
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    expect(pager.controller!.page, closeTo(0, 0.01));
    await gesture.moveBy(const Offset(18, 0));
    await tester.pump();
    expect(pager.controller!.page, closeTo(1, 0.01));
    await gesture.cancel();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(pager.controller!.page, closeTo(1, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('indicator scrubbing switches whole pages only at each movement threshold', (tester) async {
    await _pumpHome(tester);
    await _open(tester);
    final pager = tester.widget<PageView>(find.byKey(const Key('wallet-stack-list-pager')));
    final scrubber = find.byKey(const Key('wallet-stack-list-indicator-scrubber'));
    final gesture = await tester.startGesture(tester.getCenter(scrubber));
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    final start = pager.controller!.page!;
    await gesture.moveBy(const Offset(0, 12));
    await tester.pump();
    expect(pager.controller!.page, closeTo(start, 0.01));
    await gesture.moveBy(const Offset(0, 6));
    await tester.pump();
    expect(pager.controller!.page, closeTo(start + 1, 0.01));
    await gesture.moveBy(const Offset(0, 17));
    await tester.pump();
    expect(pager.controller!.page, closeTo(start + 1, 0.01));
    await gesture.moveBy(const Offset(0, 1));
    await tester.pump();
    expect(pager.controller!.page, closeTo(start + 2, 0.01));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(pager.controller!.page, closeTo(start + 2, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('indicator scrubbing clamps at the add page and reverses immediately at either end', (tester) async {
    await _pumpHome(tester);
    await _open(tester);
    final pager = tester.widget<PageView>(find.byKey(const Key('wallet-stack-list-pager')));
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('wallet-stack-list-indicator-scrubber'))),
    );
    await gesture.moveBy(const Offset(0, 24));
    await gesture.moveBy(const Offset(0, 120));
    await tester.pump();
    expect(pager.controller!.page, closeTo(3, 0.01));
    expect(find.byKey(const Key('wallet-stack-list-add-card')), findsOneWidget);
    await gesture.moveBy(const Offset(0, -9));
    await tester.pump();
    expect(pager.controller!.page, closeTo(3, 0.01));
    await gesture.moveBy(const Offset(0, -9));
    await tester.pump();
    expect(pager.controller!.page, closeTo(2, 0.01));
    await gesture.moveBy(const Offset(0, -120));
    await tester.pump();
    expect(pager.controller!.page, closeTo(0, 0.01));
    await gesture.moveBy(const Offset(0, 9));
    await tester.pump();
    expect(pager.controller!.page, closeTo(0, 0.01));
    await gesture.moveBy(const Offset(0, 9));
    await tester.pump();
    expect(pager.controller!.page, closeTo(1, 0.01));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(pager.controller!.page, closeTo(1, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wheel indicator switches from distance to 500ms repeat at the fifth page', (tester) async {
    await _pumpCupertinoHome(
      tester,
      items: [for (var id = 1; id <= 12; id++) WalletMock.createSingleSigWalletItem(id: id)],
    );
    await _open(tester);
    final controller = tester.widget<PageView>(find.byKey(const Key('wallet-stack-list-pager'))).controller!;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('wallet-stack-list-indicator-scrubber'))),
    );
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.page, closeTo(1, 0.01));
    await gesture.moveBy(const Offset(0, 72));
    await tester.pump();
    expect(controller.page, closeTo(4, 0.01));
    await gesture.moveBy(const Offset(0, 180));
    await tester.pump(const Duration(milliseconds: 499));
    expect(controller.page, closeTo(4, 0.01));
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.page, closeTo(5, 0.01));
    await tester.pump(const Duration(milliseconds: 200));
    final departing = tester.getTopLeft(find.byKey(const ValueKey('wallet-stack-list-indicator-slot-0'))).dy;
    final window = tester.getTopLeft(find.byKey(const Key('wallet-stack-list-indicator'))).dy;
    expect(departing, lessThan(window));
    final incomingSlot = find.byKey(const ValueKey('wallet-stack-list-indicator-slot-9'));
    final incomingOpacity = tester.widget<Opacity>(find.descendant(of: incomingSlot, matching: find.byType(Opacity)));
    final incomingScale = tester.widget<Transform>(find.descendant(of: incomingSlot, matching: find.byType(Transform)));
    expect(incomingOpacity.opacity, greaterThan(0));
    expect(incomingScale.transform.storage[0], closeTo(incomingOpacity.opacity, 0.001));
    expect(incomingScale.transform.storage[0], lessThan(1));
    final departingSlot = find.byKey(const ValueKey('wallet-stack-list-indicator-slot-0'));
    final departingScale = tester.widget<Transform>(
      find.descendant(of: departingSlot, matching: find.byType(Transform)),
    );
    expect(departingScale.transform.storage[0], lessThan(1));
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump();
    expect(controller.page, closeTo(4, 0.01));
    for (final page in [3, 2, 1, 0]) {
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.page, closeTo(page, 0.01));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(controller.page, closeTo(0, 0.01));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('wheel indicator starts with distance near the end and auto repeat continues to the add page', (
    tester,
  ) async {
    await _pumpCupertinoHome(
      tester,
      items: [for (var id = 1; id <= 12; id++) WalletMock.createSingleSigWalletItem(id: id)],
    );
    await _open(tester);
    final controller = tester.widget<PageView>(find.byKey(const Key('wallet-stack-list-pager'))).controller!;
    controller.jumpToPage(12);
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('wallet-stack-list-indicator-scrubber'))),
    );
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump(const Duration(seconds: 1));
    expect(controller.page, closeTo(12, 0.01));
    await gesture.moveBy(const Offset(0, -72));
    await tester.pump();
    expect(controller.page, closeTo(8, 0.01));
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    expect(controller.page, closeTo(9, 0.01));
    for (final page in [10, 11, 12]) {
      await tester.pump(const Duration(milliseconds: 500));
      expect(controller.page, closeTo(page, 0.01));
    }
    await tester.pump(const Duration(seconds: 1));
    expect(controller.page, closeTo(12, 0.01));
    await gesture.cancel();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-stack-list-add-card')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
        final visibleDots = dots.evaluate().where(
          (element) => element.findAncestorWidgetOfExactType<Opacity>()!.opacity > 0,
        );
        expect(visibleDots.length, lessThanOrEqualTo(9));
        final rects = [for (final dot in visibleDots) tester.getRect(find.byWidget(dot.widget))];
        expect(rects.where((rect) => rect.height > 6).length, 1);
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

  for (final variant in CoconutThemeVariant.values) {
    testWidgets('$variant wallet list uses home background and keeps card surfaces without borders', (tester) async {
      await _pumpHome(tester, variant: variant);
      await _open(tester);
      final page = find.byType(WalletStackListScreen);
      final colors = tester.element(page).coconutColors;
      final scaffold = tester.widget<Scaffold>(find.descendant(of: page, matching: find.byType(Scaffold)));
      expect(scaffold.backgroundColor, colors.homeBackground);
      final cards = find.descendant(of: page, matching: find.byType(WalletCard));
      for (final element in cards.evaluate()) {
        final card = find.byWidget(element.widget);
        final box = tester.widget<DecoratedBox>(find.descendant(of: card, matching: find.byType(DecoratedBox)).first);
        expect((box.decoration as BoxDecoration).color, colors.homeSurface);
        expect((box.decoration as BoxDecoration).border, isNull);
      }
      expect(tester.takeException(), isNull);
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

  testWidgets('returning from wallet detail shows the wallet the detail screen ended on', (tester) async {
    await _pumpCupertinoHome(tester);
    await _open(tester);
    final firstId = _wallets.first.id;
    await tester.tapAt(tester.getCenter(find.byKey(ValueKey('wallet-stack-list-card-$firstId'))));
    await tester.pumpAndSettle();

    final detail = tester.element(find.byKey(_detailKey));
    final args = ModalRoute.of(detail)!.settings.arguments! as WalletDetailRouteArgs;
    expect(args.walletIds, isNotEmpty);
    final otherId = args.walletIds![2];
    args.onFocusChanged!(otherId);
    await tester.pump();
    Navigator.of(detail).pop();
    await tester.pumpAndSettle();

    expect(find.byKey(ValueKey('wallet-stack-list-facts-$otherId')), findsOneWidget);
    expect(tester.takeException(), isNull);
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

  Future<void> openMyWallets(
    WidgetTester tester, {
    WalletStackListMode mode = WalletStackListMode.wheel,
    List<WalletItemBase>? wallets,
    _Preferences? preferences,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>.value(value: _Wallets(wallets ?? _wallets)),
          ChangeNotifierProvider<PreferenceProvider>.value(value: preferences ?? _Preferences()),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          routes: {AppRouteNames.walletDetail: (_) => const Scaffold(key: _detailKey)},
          home: Builder(
            builder:
                (context) => TextButton(
                  onPressed: () => WalletStackListScreen.open(context, kind: WalletStackKind.all, mode: mode),
                  child: const Text('open'),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('list mode shows every wallet as its own wide card and switches back to the wheel', (tester) async {
    await openMyWallets(tester, mode: WalletStackListMode.list);

    final rows = find.byKey(const Key('wallet-stack-list-rows'));
    final cards = find.descendant(of: rows, matching: find.byType(WalletCard));
    expect(cards.hitTestable(), findsNWidgets(_wallets.length));
    for (final card in tester.widgetList<WalletCard>(cards)) {
      expect(card.size, WalletCardSize.wide);
    }
    for (final (index, wallet) in _wallets.indexed) {
      final rect = tester.getRect(find.byKey(ValueKey('wallet-stack-list-wide-card-${wallet.id}')));
      expect(rect.height, WalletCard.wideHeightOf(tester.element(rows)));
      final balance = tester.getRect(
        find.descendant(
          of: find.byKey(ValueKey('wallet-stack-list-wide-card-${wallet.id}')),
          matching: find.byKey(const Key('wallet-card-balance')),
        ),
      );
      expect(balance.right, moreOrLessEquals(rect.right - 16, epsilon: 1));
      if (index > 0) {
        final previous = tester.getRect(find.byKey(ValueKey('wallet-stack-list-wide-card-${_wallets[index - 1].id}')));
        expect(rect.top - previous.bottom, greaterThan(0));
      }
    }
    expect(find.byKey(const Key('wallet-stack-list-rows-add')), findsNothing);
    expect(find.byKey(const Key('wallet-stack-list-wheel')).hitTestable(), findsNothing);

    await tester.tap(find.byKey(const Key('wallet-stack-list-mode')));
    await tester.pumpAndSettle();

    expect(rows, findsNothing);
    expect(find.byKey(const Key('wallet-stack-list-wheel')).hitTestable(), findsOneWidget);
  });

  testWidgets('long-pressing a list card and dragging it saves the new wallet order', (tester) async {
    final preferences = _Preferences();
    await openMyWallets(tester, mode: WalletStackListMode.list, preferences: preferences);

    final first = find.byKey(ValueKey('wallet-stack-list-wide-card-${_wallets[0].id}'));
    final third = find.byKey(ValueKey('wallet-stack-list-wide-card-${_wallets[2].id}'));
    final gesture = await tester.startGesture(tester.getCenter(first));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    final distance = tester.getBottomLeft(third).dy - tester.getCenter(first).dy + 20;
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(0, distance / 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 300));
    await gesture.up();
    await tester.pumpAndSettle();

    expect(preferences.walletOrder, [_wallets[1].id, _wallets[2].id, _wallets[0].id]);
    expect(
      tester.getTopLeft(find.byKey(ValueKey('wallet-stack-list-wide-card-${_wallets[0].id}'))).dy,
      greaterThan(tester.getTopLeft(find.byKey(ValueKey('wallet-stack-list-wide-card-${_wallets[2].id}'))).dy),
    );
  });

  testWidgets('a quick tap on a list card still opens the wallet instead of reordering', (tester) async {
    final preferences = _Preferences();
    await openMyWallets(tester, mode: WalletStackListMode.list, preferences: preferences);

    await tester.tap(find.byKey(ValueKey('wallet-stack-list-wide-card-${_wallets[1].id}')));
    await tester.pumpAndSettle();

    expect(find.byKey(_detailKey), findsOneWidget);
    expect(preferences.walletOrder, isEmpty);
  });

  for (final scale in [1.0, 1.3, 1.6, 2.0]) {
    testWidgets('list mode cards fit their content at text scale $scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openMyWallets(tester, mode: WalletStackListMode.list);

      expect(tester.takeException(), isNull);
      final card = tester.getRect(find.byKey(ValueKey('wallet-stack-list-wide-card-${_wallets.first.id}')));
      expect(card.height, WalletCard.wideHeightOf(tester.element(find.byKey(const Key('wallet-stack-list-rows')))));
    });
  }

  testWidgets('app bar actions use the home action width and trailing gap, with a 24px mode icon', (tester) async {
    await openMyWallets(tester);

    final mode = tester.getRect(find.byKey(const Key('wallet-stack-list-mode')));
    final add = tester.getRect(find.byKey(const Key('wallet-stack-list-add')));
    expect(mode.width, CoconutAppBarActionButton.actionWidth);
    expect(add.width, CoconutAppBarActionButton.actionWidth);
    expect(add.left, mode.right);
    expect(add.right, 390 - 8);
    final icon = find.descendant(
      of: find.byKey(const Key('wallet-stack-list-mode')),
      matching: find.byType(SvgPicture),
    );
    expect(tester.getSize(icon), const Size(24, 24));
  });

  for (final mode in WalletStackListMode.values) {
    testWidgets('without wallets, $mode shows the wallet add options and no app bar actions', (tester) async {
      await openMyWallets(tester, mode: mode, wallets: const []);

      expect(
        find.descendant(of: find.byKey(const Key('wallet-stack-list-empty')), matching: find.byType(WalletAddOptions)),
        findsOneWidget,
      );
      expect(find.byKey(const Key('wallet-add-air-gapped')), findsOneWidget);
      expect(find.byKey(const Key('wallet-add-hot-create')), findsOneWidget);
      expect(find.byKey(const Key('wallet-stack-list-mode')), findsNothing);
      expect(find.byKey(const Key('wallet-stack-list-add')), findsNothing);
      expect(find.byKey(const Key('wallet-stack-list-wheel')), findsNothing);
      expect(find.byKey(const Key('wallet-stack-list-rows')), findsNothing);
    });
  }

  testWidgets('opening a wallet expands its card background from the card to the whole screen', (tester) async {
    await _pumpCupertinoHome(tester);
    await _open(tester);
    await tester.pumpAndSettle();
    final firstId = _wallets.first.id;
    final card = tester.getRect(find.byKey(ValueKey('wallet-stack-list-card-$firstId')));
    await tester.tapAt(card.center);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final layer = tester.getRect(
      find.descendant(of: find.byType(WalletDetailExpandTransition), matching: find.byType(ClipRRect)).first,
    );
    final screen = Offset.zero & tester.view.physicalSize;
    expect(layer.width, greaterThan(card.width));
    expect(layer.width, lessThanOrEqualTo(screen.width));
    expect(layer.contains(card.center), isTrue);

    await tester.pumpAndSettle();
    expect(find.byKey(_detailKey), findsOneWidget);
  });
}
