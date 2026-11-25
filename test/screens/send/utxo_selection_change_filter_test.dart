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

  testWidgets('잔돈 필터를 켜지 않은 화면에는 잔돈 칩이 보이지 않는다', (tester) async {
    await pump(tester, [receive, change], showChangeFilter: false);

    expect(find.text(t.change), findsNothing);
    expect(find.byType(UtxoSelectionCard), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('태그가 없어도 잔돈 UTXO가 있으면 잔돈 칩이 보이고, 누르면 잔돈 UTXO만 남는다', (tester) async {
    await pump(tester, [receive, change, lockedChange], showChangeFilter: true);

    expect(find.text(t.all), findsOneWidget);
    expect(find.text(t.change), findsOneWidget);
    expect(find.text(t.utxo_detail_screen.utxo_locked), findsNothing);
    expect(find.byType(UtxoSelectionCard), findsNWidgets(3));

    await tester.tap(find.text(t.change));
    await tester.pumpAndSettle();

    expect(viewModelOf(tester).selectedUtxoFilter, UtxoFilter.change);
    expect(shownUtxoIds(tester), [change.utxoId, lockedChange.utxoId]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('잔돈 필터에서 전체 선택하면 잠기지 않은 잔돈 UTXO만 선택된다', (tester) async {
    await pump(tester, [receive, change, lockedChange], showChangeFilter: true);

    await tester.tap(find.text(t.change));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.select_all));
    await tester.pumpAndSettle();

    final viewModel = viewModelOf(tester);
    expect(viewModel.selectedUtxoList.map((utxo) => utxo.utxoId), [change.utxoId]);
    expect(viewModel.selectedUtxoAmountSum, change.amount);

    await tester.tap(find.text(t.all));
    await tester.pumpAndSettle();

    expect(find.byType(UtxoSelectionCard), findsNWidgets(3));
    expect(viewModelOf(tester).selectedUtxoList.map((utxo) => utxo.utxoId), [change.utxoId]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('잔돈 UTXO가 없으면 잔돈 필터를 켜도 칩이 보이지 않는다', (tester) async {
    await pump(tester, [receive], showChangeFilter: true);

    expect(find.text(t.change), findsNothing);
    expect(find.text(t.all), findsNothing);
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

    final allLeft = tester.getTopLeft(find.text(t.all)).dx;
    final changeLeft = tester.getTopLeft(find.text(t.change)).dx;
    final tagLeft = tester.getTopLeft(find.text('#cold')).dx;
    expect(allLeft < changeLeft && changeLeft < tagLeft, isTrue);
    expect(tester.takeException(), isNull);
  });
}
