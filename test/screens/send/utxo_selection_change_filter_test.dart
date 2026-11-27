import 'dart:io';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_filter.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/utxo_selection_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/send/utxo_selection_screen.dart';
import 'package:coconut_wallet/widgets/features/utxo/card/utxo_selection_card.dart';
import 'package:coconut_wallet/widgets/features/utxo/selector/custom_tag_horizontal_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

const int _walletId = 7;

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  _Wallets(this.utxos);

  final List<UtxoState> utxos;

  @override
  List<UtxoState> getUtxoList(int walletId) => utxos;
}

class _Tags extends Fake with ChangeNotifier implements UtxoTagProvider {
  _Tags(this.tags);

  final List<UtxoTag> tags;

  @override
  List<UtxoTag> getUtxoTagList(int walletId) => tags;

  @override
  List<UtxoTag> getUtxoTagsByUtxoId(int walletId, String utxoId) => [];
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  int? getBitcoinPriceForFiat(FiatCode fiatCode) => null;
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  UtxoOrder get utxoSortOrder => UtxoOrder.byAmountDesc;

  @override
  String get language => 'ko';

  @override
  Future<void> setLastUtxoOrder(UtxoOrder order) async {}
}

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isInternetOn => true;
}

UtxoState _utxo(int index, int amount, {bool isChange = false, UtxoStatus status = UtxoStatus.unspent}) => UtxoState(
  transactionHash: index.toRadixString(16).padLeft(64, '0'),
  index: 0,
  amount: amount,
  derivationPath: "m/84'/1'/0'/${isChange ? 1 : 0}/$index",
  blockHeight: 1,
  to: 'public-fixture',
  timestamp: DateTime(2026, 1, 1).add(Duration(minutes: index)),
  status: status,
);

void main() {
  setUpAll(() async {
    final loader = FontLoader('Pretendard');
    for (final filename in ['Pretendard-Regular.ttf', 'Pretendard-Bold.ttf']) {
      loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$filename').readAsBytesSync())));
    }
    await loader.load();
  });
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  final receive = _utxo(1, 50000);
  final change = _utxo(2, 20000, isChange: true);
  final lockedChange = _utxo(3, 30000, isChange: true, status: UtxoStatus.locked);

  Future<void> pump(
    WidgetTester tester,
    List<UtxoState> utxos, {
    required bool showChangeFilter,
    List<UtxoTag> tags = const [],
    int? minimumSelectableUtxoAmount,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>(create: (_) => _Wallets(utxos)),
          ChangeNotifierProvider<UtxoTagProvider>(create: (_) => _Tags(tags)),
          ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
          ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
          ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          home: UtxoSelectionScreen(
            walletId: _walletId,
            currentUnit: BitcoinUnit.btc,
            selectedUtxoList: const [],
            showChangeFilter: showChangeFilter,
            minimumSelectableUtxoAmount: minimumSelectableUtxoAmount,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  UtxoSelectionViewModel viewModelOf(WidgetTester tester) =>
      tester.element(find.byType(UtxoSelectionCard).first).read<UtxoSelectionViewModel>();

  List<String> shownUtxoIds(WidgetTester tester) =>
      tester.widgetList<UtxoSelectionCard>(find.byType(UtxoSelectionCard)).map((card) => card.utxo.utxoId).toList();

  Finder filterChip(String text) =>
      find.descendant(of: find.byType(CustomTagHorizontalSelector), matching: find.text(text));

  testWidgets('잔돈 필터를 켜지 않은 화면에는 잔돈 칩이 보이지 않는다', (tester) async {
    await pump(tester, [receive, change], showChangeFilter: false);

    expect(filterChip(t.change), findsNothing);
    expect(find.byType(UtxoSelectionCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('태그가 없어도 잔돈 UTXO가 있으면 잔돈 칩이 보이고, 누르면 잔돈 UTXO만 남는다', (tester) async {
    await pump(tester, [receive, change, lockedChange], showChangeFilter: true);

    expect(filterChip(t.all), findsOneWidget);
    expect(filterChip(t.change), findsOneWidget);
    expect(filterChip(t.utxo_detail_screen.utxo_locked), findsNothing);
    expect(find.byType(UtxoSelectionCard), findsNWidgets(3));

    await tester.tap(filterChip(t.change));
    await tester.pumpAndSettle();

    expect(viewModelOf(tester).selectedUtxoFilter, UtxoFilter.change);
    expect(shownUtxoIds(tester), [change.utxoId, lockedChange.utxoId]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('잔돈 필터에서 전체 선택하면 잠기지 않은 잔돈 UTXO만 선택된다', (tester) async {
    await pump(tester, [receive, change, lockedChange], showChangeFilter: true);

    await tester.tap(filterChip(t.change));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.select_all));
    await tester.pumpAndSettle();

    final viewModel = viewModelOf(tester);
    expect(viewModel.selectedUtxoList.map((utxo) => utxo.utxoId), [change.utxoId]);
    expect(viewModel.selectedUtxoAmountSum, change.amount);

    await tester.tap(filterChip(t.all));
    await tester.pumpAndSettle();

    expect(find.byType(UtxoSelectionCard), findsNWidgets(3));
    expect(viewModelOf(tester).selectedUtxoList.map((utxo) => utxo.utxoId), [change.utxoId]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('잔돈 UTXO가 없으면 잔돈 필터를 켜도 칩이 보이지 않는다', (tester) async {
    await pump(tester, [receive], showChangeFilter: true);

    expect(filterChip(t.change), findsNothing);
    expect(filterChip(t.all), findsNothing);
    expect(find.byType(UtxoSelectionCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('사용자 태그와 함께 있을 때 잔돈 칩은 전체 칩 바로 뒤에 온다', (tester) async {
    await pump(
      tester,
      [receive, change],
      showChangeFilter: true,
      tags: const [UtxoTag(id: 'tag-1', walletId: _walletId, name: 'cold', colorIndex: 0)],
    );

    final allLeft = tester.getTopLeft(filterChip(t.all)).dx;
    final changeLeft = tester.getTopLeft(filterChip(t.change)).dx;
    final tagLeft = tester.getTopLeft(filterChip('#cold')).dx;
    expect(allLeft < changeLeft && changeLeft < tagLeft, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('잔돈 UTXO 카드에는 태그 줄 맨 앞에 잔돈 칩이 붙는다', (tester) async {
    await pump(tester, [receive, change, lockedChange], showChangeFilter: true);

    Finder cardChip(UtxoState utxo) => find.descendant(
      of: find.byWidgetPredicate((widget) => widget is UtxoSelectionCard && widget.utxo.utxoId == utxo.utxoId),
      matching: find.text(t.change),
    );

    expect(cardChip(change), findsOneWidget);
    expect(cardChip(lockedChange), findsOneWidget);
    expect(cardChip(receive), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // UTXO 나누기는 1000 sats 미만 UTXO를 고를 수 없게 한 채로 이 화면을 엽니다.
  group('최소 선택 금액이 1000 sats인 화면(UTXO 나누기)', () {
    const minimumAmount = 1000;
    final dustChange = _utxo(4, 600, isChange: true);

    Finder card(UtxoState utxo) =>
        find.byWidgetPredicate((widget) => widget is UtxoSelectionCard && widget.utxo.utxoId == utxo.utxoId);

    Finder cardChip(UtxoState utxo) => find.descendant(of: card(utxo), matching: find.text(t.change));

    List<String> selectedUtxoIds(WidgetTester tester) =>
        viewModelOf(tester).selectedUtxoList.map((utxo) => utxo.utxoId).toList();

    testWidgets('1000 sats 이상인 잔돈이 있으면 잔돈 칩이 보이고, 누르면 잔돈 UTXO만 남는다', (tester) async {
      await pump(
        tester,
        [receive, change, dustChange, lockedChange],
        showChangeFilter: true,
        minimumSelectableUtxoAmount: minimumAmount,
      );

      expect(filterChip(t.change), findsOneWidget);

      await tester.tap(filterChip(t.change));
      await tester.pumpAndSettle();

      expect(shownUtxoIds(tester), [change.utxoId, dustChange.utxoId, lockedChange.utxoId]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('잔돈 필터의 전체 선택·해제는 1000 sats 이상인 잔돈에만 적용되고, 필터 밖에서 고른 UTXO는 남는다', (tester) async {
      await pump(
        tester,
        [receive, change, dustChange, lockedChange],
        showChangeFilter: true,
        minimumSelectableUtxoAmount: minimumAmount,
      );

      await tester.tap(card(receive));
      await tester.pumpAndSettle();
      expect(selectedUtxoIds(tester), [receive.utxoId]);

      await tester.tap(filterChip(t.change));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.select_all));
      await tester.pumpAndSettle();

      expect(selectedUtxoIds(tester), [receive.utxoId, change.utxoId]);
      expect(viewModelOf(tester).selectedUtxoAmountSum, receive.amount + change.amount);

      await tester.tap(find.text(t.unselect_all));
      await tester.pumpAndSettle();

      expect(selectedUtxoIds(tester), [receive.utxoId]);
      expect(tester.takeException(), isNull);
    });

    testWidgets('잔돈이 1000 sats 미만뿐이면 잔돈 칩은 숨기고, 카드의 잔돈 표시는 남긴다', (tester) async {
      await pump(tester, [receive, dustChange], showChangeFilter: true, minimumSelectableUtxoAmount: minimumAmount);

      expect(filterChip(t.change), findsNothing);
      expect(filterChip(t.all), findsNothing);
      expect(find.byType(UtxoSelectionCard), findsNWidgets(2));
      expect(cardChip(dustChange), findsOneWidget);
      expect(cardChip(receive), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
