import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
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
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  List<UtxoState> utxos = [];
  bool fails = false;
  int reads = 0;

  @override
  List<UtxoState> getUtxoList(int walletId) {
    expect(walletId, 7);
    reads++;
    if (fails) throw StateError('fixture read failed');
    return utxos;
  }
}

class _Tags extends Fake with ChangeNotifier implements UtxoTagProvider {
  @override
  List<UtxoTag> getUtxoTagList(int walletId) => [
    const UtxoTag(id: 'unused', walletId: 7, name: 'unused', colorIndex: 0),
  ];

  @override
  List<UtxoTag> getUtxoTagsByUtxoId(int walletId, String utxoId) => [];
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  int? get bitcoinPriceKrw => null;
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

UtxoState _utxo(UtxoStatus status, {int amount = 10000}) => UtxoState(
  transactionHash: 'a' * 64,
  index: 0,
  amount: amount,
  derivationPath: "m/84'/0'/0'/0/0",
  blockHeight: status == UtxoStatus.incoming ? 0 : 1,
  to: 'public-fixture',
  timestamp: DateTime(2026, 1, 1),
  status: status,
);

Future<void> _capture(GlobalKey key, String name) async {
  const directory = String.fromEnvironment('EMPTY_STATE_RENDER_DIR');
  if (directory.isEmpty) return;
  await Directory(directory).create(recursive: true);
  final image = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$directory/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  } finally {
    image.dispose();
  }
}

void main() {
  setUpAll(() async {
    final loader = FontLoader('Pretendard');
    for (final filename in ['Pretendard-Regular.ttf', 'Pretendard-Bold.ttf']) {
      loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$filename').readAsBytesSync())));
    }
    await loader.load();
  });
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  Future<GlobalKey> pump(
    WidgetTester tester,
    _Wallets wallets, {
    CoconutThemeVariant variant = CoconutThemeVariant.dark,
    void Function(RouteSettings)? onRoute,
    List<UtxoState> selected = const [],
    bool split = false,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final boundary = GlobalKey();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>.value(value: wallets),
          ChangeNotifierProvider<UtxoTagProvider>(create: (_) => _Tags()),
          ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
          ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
          ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: variant),
          onGenerateRoute: (settings) {
            onRoute?.call(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => Scaffold(appBar: AppBar(), body: const Text('receive fixture')),
            );
          },
          home: RepaintBoundary(
            key: boundary,
            child: UtxoSelectionScreen(
              walletId: 7,
              currentUnit: BitcoinUnit.btc,
              selectedUtxoList: selected,
              isSplitMode: split,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return boundary;
  }

  for (final variant in CoconutThemeVariant.values) {
    testWidgets('${variant.name}: unfunded wallet opens receive for same wallet and returns to selection', (
      tester,
    ) async {
      RouteSettings? route;
      final boundary = await pump(tester, _Wallets(), variant: variant, onRoute: (value) => route = value);
      expect(find.text(t.utxo_selection_screen.empty_title), findsOneWidget);
      expect(find.text(t.utxo_selection_screen.reset_filter), findsNothing);
      await tester.runAsync(() => _capture(boundary, 'utxo-empty-${variant.name}'));
      await tester.tap(find.text(t.receive));
      await tester.pumpAndSettle();
      expect(route!.name, AppRouteNames.receiveAddress);
      expect((route!.arguments as ReceiveAddressRouteArgs).id, 7);
      Navigator.of(tester.element(find.text('receive fixture'))).pop();
      await tester.pumpAndSettle();
      expect(find.text(t.utxo_selection_screen.empty_title), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('pending-only wallet is empty, locked wallet remains visible and unselectable', (tester) async {
    await pump(tester, _Wallets()..utxos = [_utxo(UtxoStatus.incoming)]);
    expect(find.text(t.utxo_selection_screen.empty_description), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pump(tester, _Wallets()..utxos = [_utxo(UtxoStatus.locked)]);
    expect(find.text(t.utxo_selection_screen.empty_title), findsNothing);
    final card = tester.widget<UtxoSelectionCard>(find.byType(UtxoSelectionCard));
    expect(card.isLocked, isTrue);
    expect(card.onSelected, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty tag resets to all without altering selected coins or amount', (tester) async {
    final coin = _utxo(UtxoStatus.unspent);
    final boundary = await pump(tester, _Wallets()..utxos = [coin], selected: [coin]);
    await tester.tap(find.text('#unused'));
    await tester.pumpAndSettle();
    expect(find.text(t.utxo_selection_screen.empty_filtered_title), findsOneWidget);
    expect(find.text(t.receive), findsNothing);
    await tester.runAsync(() => _capture(boundary, 'utxo-filter-empty'));
    await tester.tap(find.text(t.utxo_selection_screen.reset_filter));
    await tester.pumpAndSettle();
    expect(find.byType(UtxoSelectionCard), findsOneWidget);
    expect(tester.widget<UtxoSelectionCard>(find.byType(UtxoSelectionCard)).isSelected, isTrue);
    final model = tester.element(find.byType(UtxoSelectionCard)).read<UtxoSelectionViewModel>();
    expect(model.selectedUtxoAmountSum, coin.amount);
    expect(model.selectedUtxoTagName, t.all);
    expect(model.hasSelectionChanged, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('real initialization failure shows retry and recovers to actual list', (tester) async {
    final wallets = _Wallets()..fails = true;
    final boundary = await pump(tester, wallets);
    expect(find.text(t.utxo_selection_screen.load_error_title), findsOneWidget);
    expect(find.text(t.utxo_selection_screen.empty_title), findsNothing);
    await tester.runAsync(() => _capture(boundary, 'utxo-read-error'));
    wallets.fails = false;
    wallets.utxos = [_utxo(UtxoStatus.unspent)];
    await tester.tap(find.text(t.retry));
    await tester.pumpAndSettle();
    expect(wallets.reads, 2);
    expect(find.byType(UtxoSelectionCard), findsOneWidget);
    expect(find.text(t.utxo_selection_screen.load_error_title), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('split mode retains small-coin restriction', (tester) async {
    await pump(tester, _Wallets()..utxos = [_utxo(UtxoStatus.unspent, amount: 999)], split: true);
    final ignore = tester.widget<IgnorePointer>(
      find.ancestor(of: find.byType(UtxoSelectionCard), matching: find.byType(IgnorePointer)).first,
    );
    expect(ignore.ignoring, isTrue);
    expect(find.text(t.utxo_selection_screen.empty_title), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
