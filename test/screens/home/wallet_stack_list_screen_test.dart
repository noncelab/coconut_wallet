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
import 'package:flutter/material.dart';
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

void main() {
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
}
