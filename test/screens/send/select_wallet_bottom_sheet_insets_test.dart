import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_lib/coconut_lib.dart' show Checksum;
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/select_wallet_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../mock/wallet_mock.dart';

const _phase = String.fromEnvironment('PICKER_PHASE', defaultValue: 'current');

class _Wallets extends ChangeNotifier implements WalletProvider {
  @override
  final List<WalletItemBase> walletItemList = [
    for (var i = 1; i <= 8; i++) WalletMock.createSingleSigWalletItem(id: i, name: 'Wallet '),
  ];

  @override
  Map<int, Balance> fetchWalletBalanceMap() => {
    for (final wallet in walletItemList) wallet.id: Balance(1000 * wallet.id, 100),
  };

  @override
  List<UtxoState> getUtxoList(int id) => [
    for (final status in UtxoStatus.values)
      UtxoState(
        transactionHash: List.filled(64, '0').join(),
        index: status.index,
        amount: 2000 + status.index,
        derivationPath: "m/84'/1'/0'/0/0",
        blockHeight: 1,
        to: 'public-fixture-address',
        timestamp: DateTime.utc(2026),
        status: status,
      ),
  ];

  @override
  List<TransactionRecord> getTransactionRecordList(int walletId) => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preferences extends ChangeNotifier implements PreferenceProvider {
  @override
  List<int> get walletOrder => [8, 7, 6, 5, 4, 3, 2, 1];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Fixture {
  const _Fixture(this.id, this.size, this.inset);
  final String id;
  final Size size;
  final double inset;
}

class _Host {
  final capture = GlobalKey();
  final navigator = GlobalKey<NavigatorState>();
  final wallets = _Wallets();
  final preferences = _Preferences();
  ScrollController? scroll;
  DraggableScrollableController? draggable;
  int? selected;
  bool closed = false;
  int callerWalletId = -1;

  Future<void> open(
    WidgetTester tester,
    _Fixture fixture,
    CoconutThemeVariant variant,
    double scale, {
    int initialWallet = -1,
    bool grid = false,
    List<int>? candidates,
    bool onlyMfp = false,
    BalanceMode balanceMode = BalanceMode.includingPending,
  }) async {
    callerWalletId = initialWallet;
    await SharedPrefsRepository().setSelectWalletGridView(grid);
    tester.view.physicalSize = fixture.size;
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(top: 44, bottom: 34);
    setInset(tester, fixture.inset);
    addTearDown(tester.view.reset);
    addTearDown(wallets.dispose);
    addTearDown(preferences.dispose);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>.value(value: wallets),
          ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          theme: buildCoconutThemeData(variant: variant),
          builder:
              (context, child) => RepaintBoundary(
                key: capture,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
              ),
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: Center(
                    child: TextButton(
                      onPressed:
                          () => unawaited(
                            SelectWalletBottomSheet.show<int>(
                              context: context,
                              screenName: 'home-shortcut-select-wallet-sheet',
                              child: SelectWalletBottomSheet(
                                walletId: initialWallet,
                                onWalletChanged: (id) => Navigator.pop(context, id),
                                currentUnit: BitcoinUnit.btc,
                                showOnlyMfpWallets: onlyMfp,
                                candidateWalletIds: candidates,
                                balanceMode: balanceMode,
                              ),
                            ).then((value) {
                              selected = value;
                              if (value != null) callerWalletId = value;
                              closed = true;
                            }),
                          ),
                      child: const Text('Open picker'),
                    ),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    draggable = tester.widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet)).controller!;
    final content = find.descendant(
      of: find.byType(SelectWalletBottomSheet),
      matching: find.byType(SingleChildScrollView),
    );
    scroll = tester.widget<SingleChildScrollView>(content).controller!;
  }

  void setInset(WidgetTester tester, double inset) {
    tester.view.viewInsets = FakeViewPadding(bottom: inset);
    tester.view.padding = FakeViewPadding(top: 44, bottom: (34 - inset).clamp(0, 34).toDouble());
  }
}

Finder _card(int id) => find.byKey(ValueKey('select-wallet-card-$id'));
Finder _cardTap(int id) => _card(id);
Finder get _button => find.descendant(of: find.byType(FixedBottomButton), matching: find.byType(ShrinkAnimationButton));
bool _buttonActive(WidgetTester tester) => tester.widget<FixedBottomButton>(find.byType(FixedBottomButton)).isActive;

List<Map<String, Object>> _overflows() {
  final found = <Map<String, Object>>[];
  for (final element in find.byWidgetPredicate((widget) => widget is Flex).evaluate()) {
    final render = element.findRenderObject();
    if (render is! RenderFlex || render.direction != Axis.vertical || !render.hasSize) continue;
    var bottom = 0.0;
    var child = render.firstChild;
    while (child != null) {
      final data = child.parentData! as FlexParentData;
      final edge = data.offset.dy + child.size.height;
      if (edge > bottom) bottom = edge;
      child = data.nextSibling;
    }
    if (bottom > render.size.height + .1) found.add({'height': render.size.height, 'childBottom': bottom});
  }
  return found;
}

Future<void> _record(WidgetTester tester, _Host host, String name, Map<String, Object?> values) async {
  if (!const bool.fromEnvironment('PICKER_CAPTURE_EVIDENCE')) return;
  await tester.runAsync(() async {
    final directory = Directory('.omo/evidence/select-wallet-insets/$_phase');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.json').writeAsString(jsonEncode(values));
    final image = await (host.capture.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${directory.path}/$name.png').writeAsBytes(data!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void _insidePicker(WidgetTester tester, Finder target) {
  final rect = tester.getRect(target);
  final picker = tester.getRect(find.byType(SelectWalletBottomSheet));
  final size = tester.view.physicalSize / tester.view.devicePixelRatio;
  var available = picker.intersect(Rect.fromLTRB(0, 44, size.width, size.height - tester.view.viewInsets.bottom));
  final scrollView = find.ancestor(of: target, matching: find.byType(SingleChildScrollView));
  if (scrollView.evaluate().isNotEmpty) {
    expect(scrollView, findsOneWidget);
    available = available.intersect(tester.getRect(scrollView));
  }
  expect(rect.left, greaterThanOrEqualTo(available.left - .1));
  expect(rect.top, greaterThanOrEqualTo(available.top - .1));
  expect(rect.right, lessThanOrEqualTo(available.right + .1));
  expect(rect.bottom, lessThanOrEqualTo(available.bottom + .1));
  final widget = tester.widget(target);
  final tapTarget = widget is WalletCard ? _cardTap(widget.wallet.id) : target;
  expect(tapTarget, findsOneWidget);
  expect(
    tapTarget.hitTestable(),
    findsOneWidget,
    reason: 'Full bounds $rect; interactive bounds ${tester.getRect(tapTarget)}; available $available',
  );
}

Future<void> _revealCard(WidgetTester tester, _Host host, int id, String captureName) async {
  final pages = find.byKey(const Key('select-wallet-carousel'));
  if (pages.evaluate().isNotEmpty) {
    final candidates = host.wallets.walletItemList.map((wallet) => wallet.id).toSet();
    final ids = host.preferences.walletOrder.where(candidates.contains).toList();
    tester.widget<PageView>(pages).controller!.jumpToPage(ids.indexOf(id));
    await tester.pumpAndSettle();
  }
  final maximum = tester.widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet)).maxChildSize;
  await tester.ensureVisible(_card(id));
  await tester.pumpAndSettle();
  expect(host.draggable!.size, lessThanOrEqualTo(maximum + .001));
  await _record(tester, host, captureName, {
    'extent': host.draggable!.size,
    'scrollOffset': host.scroll!.offset,
    'cardHitTestable': _card(id).hitTestable().evaluate().isNotEmpty,
  });
  _insidePicker(tester, _card(id));
}

void main() {
  setUpAll(() async {
    for (final family in ['Pretendard', 'SpaceGrotesk']) {
      final loader =
          FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/$family-Bold.ttf'));
      await loader.load();
    }
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsRepository().init();
    LocaleSettings.setLocaleSync(AppLocale.de);
  });
  tearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  const fixtures = [
    _Fixture('normal', Size(414, 896), 0),
    _Fixture('initial-ime', Size(414, 896), 320),
    _Fixture('shorter-ime', Size(414, 740), 320),
    _Fixture('short-ime', Size(320, 568), 160),
  ];
  for (final variant in CoconutThemeVariant.values) {
    for (final scale in [.85, 1.0, 2.0]) {
      for (final fixture in fixtures) {
        for (final grid in [false, true]) {
          final id = '${variant.name}-$scale-${fixture.id}-grid=$grid';
          testWidgets('picker cards and confirm remain reachable $id', (tester) async {
            final host = _Host();
            await host.open(tester, fixture, variant, scale, initialWallet: 8, grid: grid);
            final error = tester.takeException();
            final overflow = _overflows();
            await _record(tester, host, '$id-open', {
              'fixture': fixture.id,
              'scale': scale,
              'theme': variant.name,
              'inset': fixture.inset,
              'extent': host.draggable!.size,
              'frameworkError': error?.runtimeType.toString(),
              'verticalOverflows': overflow,
            });
            expect(error, isNull);
            expect(overflow, isEmpty);
            final sheet = tester.widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet));
            expect(host.draggable!.size, closeTo(sheet.maxChildSize, .001));
            expect(host.scroll!.hasClients, isTrue);
            expect(host.scroll!.positions.length, 1);
            final button = _button;
            expect(_buttonActive(tester), isFalse);
            double? stickyInset;
            if (fixture.id == 'normal') {
              _insidePicker(tester, button);
              stickyInset = tester.getRect(find.byType(SelectWalletBottomSheet)).bottom - tester.getRect(button).bottom;
            }
            await _revealCard(tester, host, 1, id);
            _insidePicker(tester, _card(1));
            await tester.tap(_cardTap(1).hitTestable());
            await tester.pumpAndSettle();
            expect(_buttonActive(tester), isTrue);
            if (stickyInset != null) {
              final after = tester.getRect(find.byType(SelectWalletBottomSheet)).bottom - tester.getRect(button).bottom;
              expect(after, closeTo(stickyInset, .1));
            }
            await tester.ensureVisible(button);
            await tester.pumpAndSettle();
            _insidePicker(tester, button);
            expect(_overflows(), isEmpty);
            await _record(tester, host, '$id-confirm', {
              'selectedPublicFixture': 1,
              'buttonVisibleAndHitTestable': true,
              'controllerAttached': host.scroll!.hasClients,
            });
            await tester.tap(button.hitTestable());
            await tester.pumpAndSettle();
            expect(host.closed, isTrue);
            expect(host.selected, 1);
            expect(find.byType(SelectWalletBottomSheet), findsNothing);
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
          });
        }
      }
    }
  }

  for (final mode in BalanceMode.values) {
    for (final grid in [false, true]) {
      testWidgets('picker preserves current selection, candidate order, MFP filter and $mode balances: grid=$grid', (
        tester,
      ) async {
        final host = _Host();
        final existing = host.wallets.walletItemList[2];
        final descriptorBody = existing.descriptor.split('#').first.replaceFirst('D45AA182', '00000000');
        host.wallets.walletItemList[2] = SinglesigWalletItem(
          id: 3,
          name: 'Wallet 3',
          colorIndex: 0,
          iconIndex: 0,
          descriptor: '$descriptorBody#${Checksum.getChecksum(descriptorBody)}',
        );
        await host.open(
          tester,
          fixtures.first,
          CoconutThemeVariant.values.first,
          1,
          initialWallet: 4,
          candidates: [2, 3, 4],
          onlyMfp: true,
          balanceMode: mode,
          grid: grid,
        );
        final cards = tester.widgetList<WalletCard>(find.byType(WalletCard)).toList();
        expect(cards.map((card) => card.wallet.id), [4, 2]);
        expect(cards.map((card) => card.balanceDisplay), [
          for (final amount in mode == BalanceMode.includingPending ? [4100, 2100] : [2000, 2000])
            BitcoinUnit.btc.displayBitcoinAmount(amount, withUnit: true),
        ]);
        final button = _button;
        expect(_buttonActive(tester), isFalse);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(host.closed, isFalse);
        if (!grid) {
          tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(1);
          await tester.pumpAndSettle();
        }
        await tester.tap(_cardTap(2));
        await tester.pumpAndSettle();
        expect(_buttonActive(tester), isTrue);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(host.selected, 2);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  for (final grid in [false, true]) {
    testWidgets('picker selection and primary controller survive keyboard dismissal: grid=$grid', (tester) async {
      final host = _Host();
      await host.open(tester, fixtures[2], CoconutThemeVariant.values.first, 2, grid: grid);
      expect(tester.takeException(), isNull);
      expect(_overflows(), isEmpty);
      final suppliedController = host.scroll;
      await _revealCard(tester, host, 1, 'keyboard-dismissal');
      _insidePicker(tester, _card(1));
      await tester.tap(_cardTap(1));
      await tester.pumpAndSettle();
      host.setInset(tester, 0);
      await tester.pumpAndSettle();
      final content = find.descendant(
        of: find.byType(SelectWalletBottomSheet),
        matching: find.byType(SingleChildScrollView),
      );
      expect(tester.widget<SingleChildScrollView>(content).controller, same(suppliedController));
      expect(host.scroll!.positions.length, 1);
      final button = _button;
      expect(_buttonActive(tester), isTrue);
      _insidePicker(tester, button);
      expect(_overflows(), isEmpty);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(host.selected, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('picker cancellation preserves the caller selection: grid=$grid', (tester) async {
      final host = _Host();
      await host.open(tester, fixtures.first, CoconutThemeVariant.values.first, 1, initialWallet: 4, grid: grid);
      if (grid) {
        await tester.tap(_card(8));
      } else {
        tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(0);
      }
      await tester.pumpAndSettle();
      expect(_buttonActive(tester), isTrue);
      host.navigator.currentState!.pop();
      await tester.pumpAndSettle();
      expect(host.closed, isTrue);
      expect(host.selected, isNull);
      expect(host.callerWalletId, 4);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('picker continuous grid drag preserves controller and respects opening maximum height', (tester) async {
    final host = _Host();
    await host.open(tester, fixtures[2], CoconutThemeVariant.values.first, 2, initialWallet: 8, grid: true);
    final supplied = host.scroll!;
    final position = supplied.position;
    final content = find.descendant(
      of: find.byType(SelectWalletBottomSheet),
      matching: find.byType(SingleChildScrollView),
    );
    final scrollable = find.descendant(of: content, matching: find.byType(Scrollable)).first;
    final state = tester.state<ScrollableState>(scrollable);
    final maximum = host.draggable!.size;
    final viewport = tester.getRect(content);
    final pointer = await tester.startGesture(Offset(viewport.center.dx, viewport.bottom - 130));
    var largestOffset = 0.0;
    for (final direction in [-1, 1]) {
      for (var i = 0; i < (direction == -1 ? 20 : 10); i++) {
        await pointer.moveBy(Offset(0, direction * 16.0));
        await tester.pump(const Duration(milliseconds: 16));
        if (supplied.offset > largestOffset) largestOffset = supplied.offset;
        expect(tester.widget<SingleChildScrollView>(content).controller, same(supplied));
        expect(supplied.positions.length, 1);
        expect(supplied.position, same(position));
        expect(tester.state<ScrollableState>(scrollable), same(state));
        expect(host.draggable!.size, lessThanOrEqualTo(maximum + .001));
      }
    }
    await pointer.up();
    await tester.pumpAndSettle();
    expect(largestOffset, greaterThan(0));
    expect(_buttonActive(tester), isFalse);
    expect(_overflows(), isEmpty);
    await _revealCard(tester, host, 1, 'continuous-grid-drag');
    await tester.tap(_cardTap(1));
    await tester.pumpAndSettle();
    expect(_buttonActive(tester), isTrue);
    _insidePicker(tester, _button);
    await tester.tap(_button);
    await tester.pumpAndSettle();
    expect(host.selected, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
