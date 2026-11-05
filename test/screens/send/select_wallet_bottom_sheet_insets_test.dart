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
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_item_card.dart';
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
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preferences extends ChangeNotifier implements PreferenceProvider {
  @override
  List<int> get walletOrder => [8, 7, 6, 5, 4, 3, 2, 1];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Fixture {
  const _Fixture(this.id, this.size, this.inset, this.extent);
  final String id;
  final Size size;
  final double inset;
  final double extent;
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

  Future<void> open(
    WidgetTester tester,
    _Fixture fixture,
    CoconutThemeVariant variant,
    double scale, {
    int initialWallet = -1,
    List<int>? candidates,
    bool onlyMfp = false,
    BalanceMode balanceMode = BalanceMode.includingPending,
  }) async {
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
                            CommonBottomSheets.showDraggableBottomSheet<int>(
                              context: context,
                              screenName: 'home-shortcut-select-wallet-sheet',
                              initialChildSize: fixture.extent,
                              onControllerReady: (controller) => draggable = controller,
                              childBuilder: (controller) {
                                scroll = controller;
                                return SelectWalletBottomSheet(
                                  walletId: initialWallet,
                                  onWalletChanged: (id) => Navigator.pop(context, id),
                                  currentUnit: BitcoinUnit.btc,
                                  showOnlyMfpWallets: onlyMfp,
                                  scrollController: controller,
                                  candidateWalletIds: candidates,
                                  balanceMode: balanceMode,
                                );
                              },
                            ).then((value) {
                              selected = value;
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
  }

  void setInset(WidgetTester tester, double inset) {
    tester.view.viewInsets = FakeViewPadding(bottom: inset);
    tester.view.padding = FakeViewPadding(top: 44, bottom: (34 - inset).clamp(0, 34).toDouble());
  }
}

Finder _card(int id) => find.byWidgetPredicate((widget) => widget is WalletItemCard && widget.walletItem.id == id);

Finder _cardTap(int id) => find.descendant(
  of: _card(id),
  matching: find.byWidgetPredicate((widget) => widget is GestureDetector && widget.onTap != null),
);

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
  await tester.runAsync(() async {
    final directory = Directory('.omo/evidence/address-search-overflow-triage/picker-fix/$_phase');
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
  final tapTarget = widget is WalletItemCard ? _cardTap(widget.walletItem.id) : target;
  expect(tapTarget, findsOneWidget);
  expect(
    tapTarget.hitTestable(),
    findsOneWidget,
    reason: 'Full bounds $rect; interactive bounds ${tester.getRect(tapTarget)}; available $available',
  );
}

Future<void> _revealCard(WidgetTester tester, _Host host, int id, String captureName) async {
  final card = _card(id);
  final scrollView = find.ancestor(of: card, matching: find.byType(SingleChildScrollView));
  List<double> bounds(Rect rect) => [rect.left, rect.top, rect.right, rect.bottom];
  Map<String, Object?> geometry() => {
    'extent': host.draggable!.size,
    'viewport': bounds(tester.getRect(scrollView)),
    'card': bounds(tester.getRect(card)),
    'scrollOffset': host.scroll!.offset,
    'gestureOwnerHitTestable': _cardTap(id).hitTestable().evaluate().length == 1,
  };
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  final snappedExtent = host.draggable!.size;
  await _record(tester, host, '$captureName-before-post-snap-reveal', geometry());
  await tester.ensureVisible(card);
  await tester.pumpAndSettle();
  await _record(tester, host, '$captureName-after-post-snap-reveal', geometry());
  expect(host.draggable!.size, closeTo(snappedExtent, .001));
  _insidePicker(tester, card);
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
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.de));
  tearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  const fixtures = [
    _Fixture('normal', Size(414, 896), 0, .55),
    _Fixture('initial-ime', Size(414, 896), 320, .55),
    _Fixture('minimum-ime', Size(414, 896), 320, .5),
    _Fixture('short-ime', Size(320, 568), 160, .5),
  ];
  for (final variant in CoconutThemeVariant.values) {
    for (final scale in [.85, 1.0, 2.0]) {
      for (final fixture in fixtures) {
        final id = '${variant.name}-$scale-${fixture.id}';
        testWidgets('picker cards and confirm remain reachable $id', (tester) async {
          final host = _Host();
          await host.open(tester, fixture, variant, scale);
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
          expect(host.draggable!.size, closeTo(fixture.extent, .001));
          expect(host.scroll!.hasClients, isTrue);
          expect(host.scroll!.positions.length, 1);
          final button = find.byType(InlineActionButton);
          expect(tester.widget<InlineActionButton>(button).isActive, isFalse);
          double? stickyInset;
          if (fixture.id == 'normal') {
            _insidePicker(tester, button);
            stickyInset = tester.getRect(find.byType(SelectWalletBottomSheet)).bottom - tester.getRect(button).bottom;
          }
          await _revealCard(tester, host, 1, id);
          _insidePicker(tester, _card(1));
          await tester.tap(_cardTap(1).hitTestable());
          await tester.pumpAndSettle();
          expect(tester.widget<InlineActionButton>(button).isActive, isTrue);
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

  for (final mode in BalanceMode.values) {
    testWidgets('picker preserves current selection, candidate order, MFP filter and $mode balances', (tester) async {
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
      );
      final cards = tester.widgetList<WalletItemCard>(find.byType(WalletItemCard)).toList();
      expect(cards.map((card) => card.walletItem.id), [4, 2]);
      expect(
        cards.map((card) => card.animatedBalanceData.current),
        mode == BalanceMode.includingPending ? [4100, 2100] : [2000, 2000],
      );
      final button = find.byType(InlineActionButton);
      expect(tester.widget<InlineActionButton>(button).isActive, isFalse);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(host.closed, isFalse);
      await tester.tap(_cardTap(2));
      await tester.pumpAndSettle();
      expect(tester.widget<InlineActionButton>(button).isActive, isTrue);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(host.selected, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('picker selection and supplied controller survive keyboard dismissal', (tester) async {
    final host = _Host();
    await host.open(tester, fixtures[2], CoconutThemeVariant.values.first, 2);
    expect(tester.takeException(), isNull);
    expect(_overflows(), isEmpty);
    final suppliedController = host.scroll;
    await _revealCard(tester, host, 1, 'keyboard-dismissal');
    _insidePicker(tester, _card(1));
    await tester.tap(_cardTap(1));
    await tester.pumpAndSettle();
    host.setInset(tester, 0);
    await tester.pumpAndSettle();
    expect(host.scroll, same(suppliedController));
    expect(host.scroll!.positions.length, 1);
    final button = find.byType(InlineActionButton);
    expect(tester.widget<InlineActionButton>(button).isActive, isTrue);
    _insidePicker(tester, button);
    expect(_overflows(), isEmpty);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(host.selected, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('picker cancellation preserves the caller selection', (tester) async {
    final host = _Host();
    await host.open(tester, fixtures.first, CoconutThemeVariant.values.first, 1, initialWallet: 4);
    host.navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(host.closed, isTrue);
    expect(host.selected, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('picker continuous pointer survives compact and sticky layout boundaries', (tester) async {
    final host = _Host();
    await host.open(tester, fixtures[2], CoconutThemeVariant.values.first, 2, initialWallet: 8);
    expect(tester.takeException(), isNull);
    expect(_overflows(), isEmpty);
    final supplied = host.scroll!;
    final position = supplied.position;
    final scrollable = find.descendant(of: find.byType(SelectWalletBottomSheet), matching: find.byType(Scrollable));
    final state = tester.state<ScrollableState>(scrollable);
    final button = find.byType(InlineActionButton);
    expect(tester.widget<InlineActionButton>(button).isActive, isFalse);
    expect(tester.widget<WalletItemCard>(_card(8)).rightWidget, isNot(isA<Container>()));
    final viewport = tester.getRect(scrollable);
    final pointer = await tester.startGesture(Offset(viewport.center.dx, viewport.bottom - 12));
    final samples = <Map<String, Object?>>[];
    void sample(String direction) {
      samples.add({
        'direction': direction,
        'extent': host.draggable!.size,
        'controllerIdentical': identical(host.scroll, supplied),
        'attachedPositions': supplied.positions.length,
        'positionIdentical': identical(supplied.position, position),
        'scrollableStateIdentical': identical(tester.state<ScrollableState>(scrollable), state),
        'pixels': supplied.position.pixels,
      });
    }

    sample('start');
    for (var i = 0; i < 20; i++) {
      await pointer.moveBy(const Offset(0, -16));
      await tester.pump(const Duration(milliseconds: 16));
      sample('expand');
    }
    final expanded = host.draggable!.size;
    for (var i = 0; i < 17; i++) {
      await pointer.moveBy(const Offset(0, 16));
      await tester.pump(const Duration(milliseconds: 16));
      sample('collapse');
    }
    final collapsed = host.draggable!.size;
    await _record(tester, host, 'continuous-boundary-drag', {
      'onePointerWithoutRegrab': true,
      'expandedExtentBeforeRelease': expanded,
      'collapsedExtentBeforeRelease': collapsed,
      'samples': samples,
      'verticalOverflows': _overflows(),
    });
    await pointer.up();
    await tester.pumpAndSettle();
    expect(expanded, greaterThan(.8));
    expect(collapsed, lessThan(.57));
    for (final value in samples) {
      expect(value['controllerIdentical'], isTrue);
      expect(value['attachedPositions'], 1);
      expect(value['positionIdentical'], isTrue);
      expect(value['scrollableStateIdentical'], isTrue);
      expect(value['pixels'] as double, closeTo(0, .1));
    }
    expect(tester.widget<InlineActionButton>(button).isActive, isFalse);
    expect(tester.widget<WalletItemCard>(_card(8)).rightWidget, isNot(isA<Container>()));
    expect(_overflows(), isEmpty);
    expect(tester.takeException(), isNull);
    await _revealCard(tester, host, 1, 'continuous-boundary');
    _insidePicker(tester, _card(1));
    await tester.tap(_cardTap(1));
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    _insidePicker(tester, button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(host.selected, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
