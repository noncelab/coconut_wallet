import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:flutter/rendering.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart' show formatHomeRelativeTime;
import '../../mock/transaction_mock.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/send/select_wallet_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../mock/wallet_mock.dart';

class _Wallets extends ChangeNotifier implements WalletProvider {
  int balanceOffset = 0;
  List<UtxoState> utxos = [];
  List<TransactionRecord> transactions = [];

  void updateData(DateTime lastTransaction) {
    balanceOffset = 100000000;
    utxos = [
      for (final status in [UtxoStatus.unspent, UtxoStatus.locked])
        UtxoState(
          transactionHash: 'a' * 64,
          index: status.index,
          amount: status == UtxoStatus.unspent ? 100000000 : 200000000,
          derivationPath: "m/84'/1'/0'/0/0",
          blockHeight: 1,
          to: 'fixture',
          timestamp: lastTransaction,
          status: status,
        ),
    ];
    transactions = [TransactionMock.createMockTransactionRecord(timestamp: lastTransaction)];
    notifyListeners();
  }

  void updateDataWithoutTransaction() {
    transactions = [];
    notifyListeners();
  }

  @override
  final List<WalletItemBase> walletItemList = [
    for (var i = 1; i <= 8; i++) WalletMock.createSingleSigWalletItem(id: i, name: 'Wallet $i'),
  ];
  @override
  Map<int, Balance> fetchWalletBalanceMap() => {
    for (final wallet in walletItemList) wallet.id: Balance(wallet.id * 1000 + balanceOffset, 100),
  };
  @override
  List<UtxoState> getUtxoList(int walletId) => utxos;
  @override
  List<TransactionRecord> getTransactionRecordList(int walletId) => transactions;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Nodes extends ChangeNotifier implements NodeProvider {
  @override
  final currentBlockNotifier = ValueNotifier<BlockTimestamp?>(null);
  void emitSyncUpdate() => notifyListeners();
  @override
  void dispose() {
    currentBlockNotifier.dispose();
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preferences extends ChangeNotifier implements PreferenceProvider {
  // Missing IDs in an older saved order must not hide newly added wallets.
  @override
  List<int> get walletOrder => [8, 7, 6, 5];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _open(
  WidgetTester tester, {
  int initial = 8,
  List<int>? candidates,
  ValueChanged<int>? onSelected,
  bool p2p = false,
  double scale = 1,
  bool sheet = false,
  BalanceMode balanceMode = BalanceMode.includingPending,
  _Nodes? nodes,
}) async {
  final wallets = _Wallets();
  final preferences = _Preferences();
  addTearDown(wallets.dispose);
  addTearDown(preferences.dispose);
  final selector =
      p2p
          ? P2PSelectWalletBottomSheet(
            onWalletSelected: onSelected ?? (_) {},
            currentUnit: BitcoinUnit.btc,
            balanceMode: balanceMode,
            showOnlyMfpWallets: false,
          )
          : SelectWalletBottomSheet(
            walletId: initial,
            onWalletChanged: onSelected ?? (_) {},
            currentUnit: BitcoinUnit.btc,
            showOnlyMfpWallets: false,
            candidateWalletIds: candidates,
            balanceMode: balanceMode,
          );
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        if (nodes != null) ChangeNotifierProvider<NodeProvider>.value(value: nodes),
        ChangeNotifierProvider<WalletProvider>.value(value: wallets),
        ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.values.first),
        builder:
            (context, child) =>
                MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        home:
            sheet
                ? Builder(
                  builder:
                      (context) => Scaffold(
                        body: TextButton(
                          onPressed:
                              () => SelectWalletBottomSheet.show<void>(
                                context: context,
                                screenName: 'test-wallet-selector',
                                child: selector,
                              ),
                          child: const Text('Open selector'),
                        ),
                      ),
                )
                : selector,
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (sheet) {
    await tester.tap(find.text('Open selector'));
    await tester.pumpAndSettle();
  }
}

Finder _card(int id) => find.byKey(ValueKey('select-wallet-card-$id'));
final _toggle = find.byKey(const Key('select-wallet-layout-toggle'));
FixedBottomButton _button(WidgetTester tester) => tester.widget(find.byType(FixedBottomButton));

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsRepository().init();
    LocaleSettings.setLocaleSync(AppLocale.en);
  });
  tearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  testWidgets('carousel swipes and confirms the centered wallet', (tester) async {
    int? selected;
    await _open(tester, onSelected: (id) => selected = id);
    expect(_button(tester).isActive, isFalse);
    expect(find.text(t.wallet_stack_list.no_transaction), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(_button(tester).isActive, isTrue);
    final index = tester.widget<PageView>(find.byType(PageView)).controller!.page!.round();
    await tester.tap(find.text(t.complete));
    await tester.pumpAndSettle();
    expect(selected, [8, 7, 6, 5, 1, 2, 3, 4][index]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('grid toggles one wallet, preserves it on layout change and remembers layout', (tester) async {
    await _open(tester);
    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(_button(tester).isActive, isFalse);
    expect(find.byKey(const ValueKey('select-wallet-selected-8')), findsNothing);
    expect(tester.widgetList<WalletCard>(find.byType(WalletCard)).map((card) => card.wallet.id), [
      8,
      7,
      6,
      5,
      1,
      2,
      3,
      4,
    ]);
    await tester.tap(_card(7));
    await tester.pumpAndSettle();
    expect(_button(tester).isActive, isTrue);
    expect(find.byKey(const ValueKey('select-wallet-selected-7')), findsOneWidget);
    await tester.tap(_card(7));
    await tester.pumpAndSettle();
    expect(_button(tester).isActive, isFalse);
    await tester.tap(_card(7));
    await tester.pumpAndSettle();
    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await _open(tester);
    expect(find.byType(GridView), findsOneWidget);
    expect(_button(tester).isActive, isFalse);
    expect(find.byKey(const ValueKey('select-wallet-selected-8')), findsNothing);
    expect(SharedPrefsRepository().getBool(SharedPrefKeys.kSelectWalletGridView), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final grid in [false, true]) {
    testWidgets('320px with large text and keyboard: grid=$grid', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 160);
      addTearDown(tester.view.reset);
      await SharedPrefsRepository().setBool(SharedPrefKeys.kSelectWalletGridView, grid);
      await _open(tester, scale: 2);
      expect(find.text(t.complete).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('carousel cards rotate continuously while dragging', (tester) async {
    await _open(tester);
    final center = find.byKey(const ValueKey('select-wallet-carousel-transform-0'));
    final neighbor = find.byKey(const ValueKey('select-wallet-carousel-transform-1'));
    expect(tester.widget<Transform>(center).transform.entry(0, 2), closeTo(0, .0001));
    expect(tester.widget<Transform>(neighbor).transform.entry(0, 2).abs(), greaterThan(.1));
    final drag = await tester.startGesture(tester.getCenter(find.byType(PageView)));
    await drag.moveBy(const Offset(-24, 0));
    await tester.pump();
    await drag.moveBy(const Offset(-24, 0));
    await tester.pump();
    expect(tester.widget<Transform>(center).transform.entry(0, 2).abs(), greaterThan(.01));
    await drag.up();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('modal keeps carousel height in grid mode, including after reopening', (tester) async {
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _open(tester, sheet: true);
    final carouselHeight = tester.getSize(find.byType(SelectWalletBottomSheet)).height;
    expect(carouselHeight, lessThan(796));
    expect(find.text(t.complete).hitTestable(), findsOneWidget);
    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(SelectWalletBottomSheet)).height, closeTo(carouselHeight, 1));
    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(SelectWalletBottomSheet)).height, closeTo(carouselHeight, 1));
    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await _open(tester, sheet: true);
    expect(find.byType(GridView), findsOneWidget);
    expect(tester.getSize(find.byType(SelectWalletBottomSheet)).height, closeTo(carouselHeight, 1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('grid scroll stays at initial maximum and a partial collapse snaps back', (tester) async {
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await SharedPrefsRepository().setBool(SharedPrefKeys.kSelectWalletGridView, true);
    await _open(tester, sheet: true);
    final sheet = tester.widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet));
    final controller = sheet.controller!;
    final initialExtent = controller.size;
    final outerScroll =
        find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable)).first;
    final position = tester.state<ScrollableState>(outerScroll).position;
    final viewport = tester.getRect(outerScroll);
    final gesture = await tester.startGesture(Offset(viewport.center.dx, viewport.top + 130));
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(0, -24));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.size, closeTo(initialExtent, .001));
    expect(position.pixels, greaterThan(0));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 24));
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(position.pixels, closeTo(0, 1));
    expect(controller.size, lessThan(initialExtent));
    expect(tester.state<ScrollableState>(outerScroll).position, same(position));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.size, closeTo(initialExtent, .001));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('app bar drag snaps back or dismisses and cannot grow above opening height', (tester) async {
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _open(tester, sheet: true);
    final controller = tester.widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet)).controller!;
    final maximum = controller.size;
    var gesture = await tester.startGesture(tester.getCenter(find.text(t.send_screen.select_wallet)));
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    expect(controller.size, lessThan(maximum));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.size, closeTo(maximum, .001));
    gesture = await tester.startGesture(tester.getCenter(find.text(t.send_screen.select_wallet)));
    await gesture.moveBy(const Offset(0, -24));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -80));
    await tester.pump();
    expect(controller.size, closeTo(maximum, .001));
    await gesture.up();
    await tester.pumpAndSettle();
    gesture = await tester.startGesture(tester.getCenter(find.text(t.send_screen.select_wallet)));
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 360));
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.byType(SelectWalletBottomSheet), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final cancel in [false, true]) {
    testWidgets('full app bar drag closes only the sheet, cancel=$cancel', (tester) async {
      tester.view.physicalSize = const Size(414, 896);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _open(tester);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      navigator.push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Underlying page'))));
      await tester.pumpAndSettle();
      SelectWalletBottomSheet.show<void>(
        context: tester.element(find.text('Underlying page')),
        screenName: 'wallet-selector-dismiss-regression',
        child: SelectWalletBottomSheet(
          walletId: 8,
          currentUnit: BitcoinUnit.btc,
          showOnlyMfpWallets: false,
          onWalletChanged: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(tester.getCenter(find.text(t.send_screen.select_wallet)));
      await gesture.moveBy(const Offset(0, 24));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 650));
      // The minimum extent already started popping the sheet, but the pointer is still held.
      await tester.pump(const Duration(milliseconds: 16));
      if (cancel) {
        await gesture.cancel();
      } else {
        await gesture.up();
      }
      await tester.pumpAndSettle();
      expect(find.text('Underlying page'), findsOneWidget);
      expect(find.byType(SelectWalletBottomSheet), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final mode in BalanceMode.values) {
    testWidgets('balance, UTXO count and last transaction update together: $mode', (tester) async {
      await _open(tester, balanceMode: mode);
      final wallets = tester.element(find.byType(SelectWalletBottomSheet)).read<WalletProvider>() as _Wallets;
      final pager = tester.widget<PageView>(find.byType(PageView)).controller;
      final last = DateTime.now().subtract(const Duration(days: 2));
      expect(find.text(t.wallet_stack_list.no_transaction), findsOneWidget);
      wallets.updateData(last);
      await tester.pumpAndSettle();
      final expected = mode == BalanceMode.includingPending ? 100008100 : 100000000;
      expect(
        tester.widget<WalletCard>(_card(8)).balanceDisplay,
        BitcoinUnit.btc.displayBitcoinAmount(expected, withUnit: true),
      );
      expect(find.text('2'), findsOneWidget);
      expect(find.text(formatHomeRelativeTime(last, DateTime.now())), findsOneWidget);
      expect(find.text(t.wallet_stack_list.no_transaction), findsNothing);
      expect(tester.widget<PageView>(find.byType(PageView)).controller, same(pager));
      expect(pager!.page, 0);
      expect(_button(tester).isActive, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      // A late provider event must not call a disposed view model or state.
      wallets.notifyListeners();
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('live update in grid preserves explicit selection and refreshes carousel details', (tester) async {
    await _open(tester);
    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    await tester.tap(_card(7));
    await tester.pumpAndSettle();
    final wallets = tester.element(find.byType(SelectWalletBottomSheet)).read<WalletProvider>() as _Wallets;
    final last = DateTime.now().subtract(const Duration(days: 3));
    wallets.updateData(last);
    await tester.pumpAndSettle();
    expect(
      tester.widget<WalletCard>(_card(7)).balanceDisplay,
      BitcoinUnit.btc.displayBitcoinAmount(100007100, withUnit: true),
    );
    expect(find.byKey(const ValueKey('select-wallet-selected-7')), findsOneWidget);
    expect(_button(tester).isActive, isTrue);
    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
    expect(find.text('2'), findsOneWidget);
    expect(find.text(formatHomeRelativeTime(last, DateTime.now())), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('live update wraps text without changing opening height or resetting an active drag', (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _open(tester, sheet: true, scale: 2);
    final controller = tester.widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet)).controller!;
    final opening = controller.size;
    final wallets = tester.element(find.byType(SelectWalletBottomSheet)).read<WalletProvider>() as _Wallets;
    final last = DateTime.now().subtract(const Duration(days: 2));
    wallets.walletItemList[7].name = 'Family savings 2026A';
    wallets.updateData(last);
    await tester.pumpAndSettle();
    expect(controller.size, closeTo(opening, .001));
    expect(
      tester.widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet)).maxChildSize,
      closeTo(opening, .001),
    );
    final scroll = find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable)).first;
    expect(tester.state<ScrollableState>(scroll).position.maxScrollExtent, greaterThan(0));
    final gesture = await tester.startGesture(tester.getCenter(find.text(t.send_screen.select_wallet)));
    await gesture.moveBy(const Offset(0, 24));
    await tester.pump();
    await gesture.moveBy(const Offset(0, 60));
    await tester.pump();
    final draggedExtent = controller.size;
    // A provider update now makes the last-transaction text shorter again.
    wallets.walletItemList[7].name = 'Wallet 8';
    wallets.updateDataWithoutTransaction();
    await tester.pumpAndSettle();
    expect(controller.size, closeTo(draggedExtent, .001));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.size, closeTo(opening, .001));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('switching from scrolled grid resets vertical offset and shows carousel immediately', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await SharedPrefsRepository().setBool(SharedPrefKeys.kSelectWalletGridView, true);
    await _open(tester, sheet: true, scale: 2);
    final sheetController = tester.widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet)).controller!;
    final opening = sheetController.size;
    final scroll = find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable)).first;
    final position = tester.state<ScrollableState>(scroll).position;
    position.jumpTo(position.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(position.pixels, greaterThan(0));
    await tester.tap(_toggle);
    await tester.pump();
    expect(position.pixels, closeTo(0, .001));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(PageView)).top, greaterThanOrEqualTo(tester.getRect(find.byType(AppBar)).bottom));
    expect(sheetController.size, closeTo(opening, .001));
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('details show full name first followed by UTXOs, last transaction and type', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _open(tester, sheet: true);
    final wallets = tester.element(find.byType(SelectWalletBottomSheet)).read<WalletProvider>() as _Wallets;
    const fullName = 'Family savings 2026A';
    wallets.walletItemList[7].name = fullName;
    wallets.updateDataWithoutTransaction();
    await tester.pumpAndSettle();
    final nameLabel = tester.getRect(find.text(t.name));
    final utxosLabel = tester.getRect(find.text(t.wallet_stack_list.utxos));
    final transactionLabel = tester.getRect(find.text(t.wallet_stack_list.last_transaction));
    final typeLabel = tester.getRect(find.text(t.wallet_stack_list.type));
    expect(nameLabel.left, lessThan(utxosLabel.left));
    expect(nameLabel.top, closeTo(utxosLabel.top, .1));
    expect(transactionLabel.top, greaterThan(nameLabel.top));
    expect(transactionLabel.left, closeTo(nameLabel.left, .1));
    expect(typeLabel.left, closeTo(utxosLabel.left, .1));
    expect(typeLabel.top, closeTo(transactionLabel.top, .1));
    final text = find.descendant(of: find.byType(PageView), matching: find.text(fullName));
    expect(text, findsOneWidget);
    final fullNameDetails = find.text(fullName).last;
    expect(tester.renderObject<RenderParagraph>(fullNameDetails).didExceedMaxLines, isFalse);
    expect(tester.widget<Text>(fullNameDetails).maxLines, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('opening in grid and changing view preserves caller current wallet', (tester) async {
    await SharedPrefsRepository().setBool(SharedPrefKeys.kSelectWalletGridView, true);
    await _open(tester, initial: 4, sheet: true);
    expect(_button(tester).isActive, isFalse);
    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 7);
    expect(_button(tester).isActive, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('grid deselection returns to last viewed wallet while explicit selection takes priority', (tester) async {
    tester.view.physicalSize = const Size(414, 896);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _open(tester, initial: 8);
    tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(1);
    await tester.pumpAndSettle();
    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    expect(_button(tester).isActive, isFalse);
    await tester.tap(_card(6));
    await tester.pumpAndSettle();
    await tester.tap(_card(6));
    await tester.pumpAndSettle();
    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 1);
    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    await tester.tap(_card(6));
    await tester.pumpAndSettle();
    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 2);
    expect(_button(tester).isActive, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final mode in BalanceMode.values) {
    testWidgets('node-only and block-only updates refresh picker data and release listeners: $mode', (tester) async {
      final nodes = _Nodes();
      addTearDown(nodes.dispose);
      await _open(tester, nodes: nodes, balanceMode: mode);
      final wallets = tester.element(find.byType(SelectWalletBottomSheet)).read<WalletProvider>() as _Wallets;
      final last = DateTime.now().subtract(const Duration(days: 2));
      wallets.balanceOffset = 100000000;
      wallets.transactions = [TransactionMock.createMockTransactionRecord(timestamp: last)];
      wallets.utxos = [
        UtxoState(
          transactionHash: 'a' * 64,
          index: 0,
          amount: 50000000,
          derivationPath: "m/84'/1'/0'/0/0",
          blockHeight: 1,
          to: 'fixture',
          timestamp: last,
          status: UtxoStatus.unspent,
        ),
      ];
      // Repositories changed without a WalletProvider notification.
      nodes.emitSyncUpdate();
      await tester.pumpAndSettle();
      expect(
        tester.widget<WalletCard>(_card(8)).balanceDisplay,
        BitcoinUnit.btc.displayBitcoinAmount(
          mode == BalanceMode.includingPending ? 100008100 : 50000000,
          withUnit: true,
        ),
      );
      expect(find.text('1'), findsOneWidget);
      expect(find.text(formatHomeRelativeTime(last, DateTime.now())), findsOneWidget);
      wallets.balanceOffset = 200000000;
      wallets.utxos.clear();
      wallets.transactions.clear();
      nodes.currentBlockNotifier.value = BlockTimestamp(100, DateTime.now());
      await tester.pumpAndSettle();
      expect(
        tester.widget<WalletCard>(_card(8)).balanceDisplay,
        BitcoinUnit.btc.displayBitcoinAmount(mode == BalanceMode.includingPending ? 200008100 : 0, withUnit: true),
      );
      expect(find.text('0'), findsOneWidget);
      expect(find.text(t.wallet_stack_list.no_transaction), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      // Verify merged listeners were detached after the sheet was disposed.
      // ignore: invalid_use_of_protected_member
      expect(nodes.hasListeners, isFalse);
      // ignore: invalid_use_of_protected_member
      expect(nodes.currentBlockNotifier.hasListeners, isFalse);
      nodes.emitSyncUpdate();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('empty candidate list cannot confirm', (tester) async {
    int? selected;
    await _open(tester, candidates: [], onSelected: (id) => selected = id);
    expect(_button(tester).isActive, isFalse);
    await tester.tap(find.text(t.complete));
    await tester.pumpAndSettle();
    expect(selected, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('candidate filtering survives layout changes', (tester) async {
    await _open(tester, initial: 7, candidates: [6, 7]);
    await tester.tap(_toggle);
    await tester.pumpAndSettle();
    expect(tester.widgetList<WalletCard>(find.byType(WalletCard)).map((card) => card.wallet.id), [7, 6]);
    expect(_button(tester).isActive, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('P2P selector confirms a valid first wallet', (tester) async {
    int? selected;
    await _open(tester, p2p: true, onSelected: (id) => selected = id);
    expect(_button(tester).isActive, isTrue);
    await tester.tap(find.text(t.complete));
    await tester.pumpAndSettle();
    expect(selected, 8);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
