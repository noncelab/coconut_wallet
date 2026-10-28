import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_dialog.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_screen.dart';
import 'package:coconut_wallet/screens/home/wallet_stack_list_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/home/wallet_widget_definitions.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../mock/wallet_mock.dart';

class _Home extends Fake with ChangeNotifier implements HomeWidgetsViewModel {
  @override
  final List<WalletItemBase> wallets;
  _Home(this.wallets);
  @override
  bool get isWalletDataLoading => false;
  @override
  List<WalletItemBase> get hotWallets => wallets;
  @override
  List<WalletItemBase> get watchOnlyWallets => wallets;
  @override
  BitcoinUnit get unit => BitcoinUnit.btc;
  @override
  int balanceOf(int id) => 0;
  @override
  DateTime? lastTransactionTime(int id) => null;
}

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  @override
  final List<WalletItemBase> walletItemList;
  _Wallets(this.walletItemList);
  @override
  Balance getWalletBalance(int id) => Balance(0, 0);
  @override
  List<TransactionRecord> getTransactionRecordList(int id) => const [];
  @override
  List<UtxoState> getUtxoList(int id) => const [];
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
  @override
  List<int> get walletOrder => const [];
}

const _boundaryKey = Key('capture-home-stack');

Future<void> _pump(
  WidgetTester tester, {
  required int count,
  List<WalletItemBase>? items,
  WalletStackKind kind = WalletStackKind.all,
  HomeSpan span = HomeSpan.small,
  bool dark = false,
  double textScale = 1,
  VoidCallback? onLongPress,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final wallets = items ?? [for (var i = 1; i <= count; i++) WalletMock.createSingleSigWalletItem(id: i)];
  final definition = WalletStackDefinition(kind);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<HomeWidgetsViewModel>.value(value: _Home(wallets)),
        ChangeNotifierProvider<WalletProvider>.value(value: _Wallets(wallets)),
        ChangeNotifierProvider<PreferenceProvider>.value(value: _Preferences()),
        Provider<AnalyticsService>.value(value: AnalyticsService(null, true)),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(variant: dark ? CoconutThemeVariant.dark : CoconutThemeVariant.light),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: _boundaryKey,
              child: GestureDetector(
                onLongPress: onLongPress,
                child: SizedBox(
                  width: span == HomeSpan.wide ? 352 : 172,
                  height: 172,
                  child: Builder(
                    builder:
                        (context) => definition.build(
                          context,
                          HomeItem(
                            id: 'test',
                            definitionId: definition.id,
                            kind: HomeItemKind.widget,
                            order: 0,
                            span: span,
                          ),
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

PageView _pager(WidgetTester tester) => tester.widget<PageView>(find.byType(PageView).first);

Future<void> _capture(WidgetTester tester, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_HOME_ADD')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundaryKey));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('.qa/home-add-page-20261015/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font = FontLoader('Pretendard');
    font.addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'));
    font.addFont(rootBundle.load('assets/fonts/Pretendard-Bold.ttf'));
    await font.load();
    final icons = FontLoader('packages/cupertino_icons/CupertinoIcons');
    icons.addFont(rootBundle.load('packages/cupertino_icons/assets/CupertinoIcons.ttf'));
    await icons.load();
  });

  testWidgets('swiping back from add opens the real wallet list with its original identity', (tester) async {
    await _pump(tester, count: 3);
    final homePager = _pager(tester);
    homePager.controller!.jumpToPage(3);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(homePager.controller!.page, 2);
    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();
    final list = tester.widget<WalletStackListScreen>(find.byType(WalletStackListScreen));
    expect(list.initialWalletId, 3);
    expect(list.heroTagOf, isNotNull);
    expect(find.byType(WalletAddDialog), findsNothing);
    Navigator.of(tester.element(find.byType(WalletStackListScreen))).pop();
    await tester.pumpAndSettle();
    expect(homePager.controller!.page, 2);
    expect(tester.widget<WalletCard>(find.byType(WalletCard)).wallet.id, 3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reordering while on add keeps the add page after cancellation', (tester) async {
    final one = WalletMock.createSingleSigWalletItem(id: 1);
    final two = WalletMock.createSingleSigWalletItem(id: 2);
    await _pump(tester, count: 2, items: [one, two]);
    final pager = _pager(tester);
    pager.controller!.jumpToPage(1);
    await tester.pumpAndSettle();
    pager.controller!.jumpToPage(2);
    await tester.pumpAndSettle();
    await _pump(tester, count: 2, items: [two, one]);
    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(WalletAddDialog))).pop();
    await tester.pumpAndSettle();
    expect(pager.controller!.page, 2);
    expect(find.byType(WalletCard), findsNothing);
    expect(find.byType(Hero), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('removing wallets on add stays safe and empty remains the existing CTA', (tester) async {
    await _pump(tester, count: 3);
    _pager(tester).controller!.jumpToPage(3);
    await tester.pumpAndSettle();
    await _pump(tester, count: 1);
    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();
    expect(find.byType(WalletAddDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(WalletAddDialog))).pop();
    await tester.pumpAndSettle();
    expect(_pager(tester).controller!.page, 1);
    expect(find.byType(WalletCard), findsNothing);
    await _pump(tester, count: 0);
    expect(find.byType(PageView), findsNothing);
    expect(find.text(t.home_widgets.add_wallet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final back in ['header', 'system']) {
    testWidgets('zero wallets can repeatedly open add and close via $back, then become one wallet', (tester) async {
      await _pump(tester, count: 0);
      for (var attempt = 0; attempt < 2; attempt++) {
        await tester.tap(find.byKey(const Key('all_wallet_stack-empty')));
        await tester.pumpAndSettle();
        expect(find.byType(WalletAddScreen), findsOneWidget);
        expect(find.byType(WalletAddDialog), findsNothing);
        if (back == 'header') {
          final appBar = tester.widget<AppBar>(find.byType(AppBar));
          await tester.tap(find.byWidget(appBar.leading!));
        } else {
          await tester.binding.handlePopRoute();
        }
        await tester.pumpAndSettle();
        expect(find.byType(WalletAddScreen), findsNothing);
        expect(find.byKey(const Key('all_wallet_stack-empty')), findsOneWidget);
        expect(find.byType(PageView), findsNothing);
        expect(tester.widget<WalletStackView>(find.byType(WalletStackView)).wallets, isEmpty);
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byKey(const Key('all_wallet_stack-empty')));
      await tester.pumpAndSettle();
      await _pump(tester, count: 1);
      expect(find.byType(WalletAddScreen), findsOneWidget);
      Navigator.of(tester.element(find.byType(WalletAddScreen))).pop();
      await tester.pumpAndSettle();
      final pager = _pager(tester);
      expect(pager.childrenDelegate.estimatedChildCount, 2);
      expect(pager.controller!.page, 0);
      expect(tester.widget<WalletCard>(find.byType(WalletCard)).wallet.id, 1);
      await tester.drag(find.byType(PageView), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(pager.controller!.page, 1);
      expect(find.byType(WalletCard), findsNothing);
      await tester.tap(find.byType(PageView));
      await tester.pumpAndSettle();
      expect(find.byType(WalletAddDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(WalletAddDialog))).pop();
      await tester.pumpAndSettle();
      expect(pager.controller!.page, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('wallet growth while add is open keeps indexes and new wallet identity valid', (tester) async {
    await _pump(tester, count: 1);
    final pager = _pager(tester);
    pager.controller!.jumpToPage(1);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PageView));
    await tester.pumpAndSettle();
    await _pump(tester, count: 2);
    expect(find.byType(WalletAddDialog), findsOneWidget);
    Navigator.of(tester.element(find.byType(WalletAddDialog))).pop();
    await tester.pumpAndSettle();
    expect(_pager(tester).childrenDelegate.estimatedChildCount, 3);
    expect(pager.controller!.page, 1);
    expect(tester.widget<WalletCard>(find.byType(WalletCard)).wallet.id, 2);
    await tester.drag(find.byType(PageView), const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(pager.controller!.page, 2);
    expect(find.byType(WalletCard), findsNothing);
    expect(find.byType(Hero), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('many wallets keep the trailing indicator within the small stack', (tester) async {
    await _pump(tester, count: 30);
    final pager = _pager(tester);
    expect(pager.childrenDelegate.estimatedChildCount, 31);
    pager.controller!.jumpToPage(30);
    await tester.pumpAndSettle();
    expect(find.byType(WalletCard), findsNothing);
    final indicator = find.byKey(const Key('all_wallet_stack-indicator'));
    final dots = find.descendant(of: indicator, matching: find.byType(AnimatedContainer));
    expect(dots, findsNWidgets(31));
    final bounds = tester.getRect(find.byType(PageView));
    for (final dot in dots.evaluate()) {
      final rect = tester.getRect(find.byWidget(dot.widget));
      expect(rect.left, greaterThanOrEqualTo(bounds.left));
      expect(rect.right, lessThanOrEqualTo(bounds.right));
    }
    expect(tester.takeException(), isNull);
  });

  for (final kind in WalletStackKind.values) {
    for (final span in [HomeSpan.small, HomeSpan.wide]) {
      for (final count in [1, 3]) {
        testWidgets('${kind.name} ${span.toJson()} $count wallets: all appends add; other kinds keep wallet pages', (
          tester,
        ) async {
          await _pump(tester, count: count, kind: kind, span: span);
          final pager = _pager(tester);
          expect(pager.childrenDelegate.estimatedChildCount, count + (kind == WalletStackKind.all ? 1 : 0));
          if (kind != WalletStackKind.all) {
            pager.controller!.jumpToPage(count - 1);
            await tester.pumpAndSettle();
            await tester.drag(find.byType(PageView), const Offset(-300, 0));
            await tester.pumpAndSettle();
            expect(pager.controller!.page, (count - 1).toDouble());
            expect(find.byType(WalletCard), findsOneWidget);
            expect(tester.takeException(), isNull);
            return;
          }
          final originalWallets = tester.widget<WalletStackView>(find.byType(WalletStackView)).wallets;
          expect(originalWallets, hasLength(count));
          for (var i = 1; i < count; i++) {
            await tester.drag(find.byType(PageView), Offset(span == HomeSpan.wide ? -300 : -150, 0));
            await tester.pumpAndSettle();
            expect(pager.controller!.page, closeTo(i.toDouble(), 0.01));
            expect(
              find.descendant(
                of: find.byKey(const ValueKey('all_wallet_stack-front')),
                matching: find.byKey(ValueKey('all_wallet_stack-card-${i + 1}')),
              ),
              findsOneWidget,
            );
          }
          await tester.drag(find.byType(PageView), Offset(span == HomeSpan.wide ? -300 : -150, 0));
          await tester.pumpAndSettle();
          expect(pager.controller!.page, closeTo(count.toDouble(), 0.01));
          expect(find.byType(WalletCard), findsNothing);
          expect(find.byType(Hero), findsNothing);
          if (kind == WalletStackKind.all && count == 3) await _capture(tester, 'all-${span.toJson()}-add-light');
          await tester.tap(find.byType(PageView));
          await tester.pumpAndSettle();
          expect(find.byType(WalletStackListScreen), findsNothing);
          expect(pager.controller!.page, closeTo(count.toDouble(), 0.01));
          final dialog = tester.widget<WalletAddDialog>(find.byType(WalletAddDialog));
          expect(dialog.mode, switch (kind) {
            WalletStackKind.all => WalletAddDialogMode.walletType,
            WalletStackKind.hot => WalletAddDialogMode.hotWalletAction,
            WalletStackKind.watchOnly => WalletAddDialogMode.watchOnlySource,
          });
          Navigator.of(tester.element(find.byType(WalletAddDialog))).pop();
          await tester.pumpAndSettle();
          expect(pager.controller!.page, closeTo(count.toDouble(), 0.01));
          expect(find.byType(WalletCard), findsNothing);
          expect(find.byType(Hero), findsNothing);
          expect(tester.widget<WalletStackView>(find.byType(WalletStackView)).wallets, same(originalWallets));
          expect(tester.takeException(), isNull);
        });
      }
    }
    testWidgets('${kind.name} empty stack keeps its single add prompt', (tester) async {
      await _pump(tester, count: 0, kind: kind);
      expect(find.byType(PageView), findsNothing);
      expect(find.byType(WalletCard), findsNothing);
      final stack = tester.widget<WalletStackView>(find.byType(WalletStackView));
      expect(find.text(stack.emptyActionText!), findsOneWidget);
      await tester.tap(find.text(stack.emptyActionText!));
      await tester.pumpAndSettle();
      if (kind == WalletStackKind.all) {
        expect(find.byType(WalletAddScreen), findsOneWidget);
      } else {
        expect(find.byType(WalletAddDialog), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final span in [HomeSpan.small, HomeSpan.wide]) {
    testWidgets('${span.toJson()} dark enlarged add card preserves parent long press and swipe back', (tester) async {
      var edited = 0;
      await _pump(tester, count: 1, span: span, dark: true, onLongPress: () => edited++);
      final pager = _pager(tester);
      pager.controller!.jumpToPage(1);
      await tester.pumpAndSettle();
      await _pump(tester, count: 1, span: span, dark: true, textScale: 2, onLongPress: () => edited++);
      expect(find.text(t.home_widgets.add_wallet), findsOneWidget);
      await _capture(tester, 'all-${span.toJson()}-add-dark-large-text');
      await tester.longPress(find.byType(PageView));
      await tester.pumpAndSettle();
      expect(edited, 1);
      expect(find.byType(WalletAddDialog), findsNothing);
      // Existing small wallet content overflows at 2x text; only the add page is under enlarged-text test.
      await _pump(tester, count: 1, span: span, dark: true, onLongPress: () => edited++);
      await tester.drag(find.byType(PageView), Offset(span == HomeSpan.wide ? 300 : 150, 0));
      await tester.pumpAndSettle();
      expect(pager.controller!.page, 0);
      expect(tester.widgetList<WalletCard>(find.byType(WalletCard)).first.wallet.id, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
