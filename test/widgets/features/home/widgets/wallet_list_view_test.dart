import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../mock/wallet_mock.dart';

List<WalletItemBase> _wallets(int count) => [
  for (var id = 1; id <= count; id++) WalletMock.createSingleSigWalletItem(id: id, name: 'wallet $id'),
];

Future<void> _pump(
  WidgetTester tester,
  List<WalletItemBase> wallets, {
  void Function(WalletItemBase wallet)? onWalletPressed,
  VoidCallback? onShowAllPressed,
  VoidCallback? onAddPressed,
  VoidCallback? onEmptyPressed,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home: Center(
        child: SizedBox(
          width: 352,
          height: 172,
          child: WalletListView(
            wallets: wallets,
            balanceTextOf: (wallet) => '${wallet.id}0 BTC',
            onWalletPressed: onWalletPressed ?? (_) {},
            onShowAllPressed: onShowAllPressed ?? () {},
            emptyText: 'empty',
            emptyActionText: 'add first wallet',
            onEmptyPressed: onEmptyPressed,
            onAddPressed: onAddPressed,
          ),
        ),
      ),
    ),
  );
}

Finder _row(int walletId) => find.byKey(ValueKey('wallet-list-row-$walletId'));

void main() {
  testWidgets('no wallets shows the add action', (tester) async {
    var added = 0;
    await _pump(tester, const [], onEmptyPressed: () => added++);

    expect(find.byKey(const Key('wallet-list-empty')), findsOneWidget);
    await tester.tap(find.text('add first wallet'));
    expect(added, 1);
  });

  testWidgets('fewer wallets than rows end with an add row', (tester) async {
    var added = 0;
    await _pump(tester, _wallets(2), onAddPressed: () => added++);

    expect(_row(1), findsOneWidget);
    expect(_row(2), findsOneWidget);
    expect(find.text('20 BTC'), findsOneWidget);
    expect(find.byKey(const Key('wallet-list-show-all')), findsNothing);
    expect(tester.getTopLeft(find.byKey(const Key('wallet-list-add'))).dy, greaterThan(tester.getTopLeft(_row(2)).dy));
    await tester.tap(find.byKey(const Key('wallet-list-add')));
    expect(added, 1);
  });

  testWidgets('one wallet and the add row split the height in half', (tester) async {
    await _pump(tester, _wallets(1), onAddPressed: () {});

    final card = tester.getRect(find.byType(WalletListView));
    expect(tester.getTopLeft(_row(1)).dy, moreOrLessEquals(card.top + 8));
    expect(tester.getSize(_row(1)).height, moreOrLessEquals((card.height - 16 - 1) / 2));
    expect(tester.getBottomLeft(find.byKey(const Key('wallet-list-add'))).dy, moreOrLessEquals(card.bottom - 8));
  });

  testWidgets('two wallets and the add row split the height into thirds', (tester) async {
    await _pump(tester, _wallets(2), onAddPressed: () {});

    final card = tester.getRect(find.byType(WalletListView));
    final rowHeight = (card.height - 16 - 2) / 3;
    expect(tester.getTopLeft(_row(1)).dy, moreOrLessEquals(card.top + 8));
    expect(tester.getSize(_row(1)).height, moreOrLessEquals(rowHeight));
    expect(tester.getBottomLeft(find.byKey(const Key('wallet-list-add'))).dy, moreOrLessEquals(card.bottom - 8));
  });

  testWidgets('three wallets and the add row fill the card from the top', (tester) async {
    await _pump(tester, _wallets(3), onAddPressed: () {});

    expect(tester.getTopLeft(_row(1)).dy, moreOrLessEquals(tester.getTopLeft(find.byType(WalletListView)).dy + 8));
  });

  testWidgets('without an add action, fewer wallets leave the rest empty', (tester) async {
    await _pump(tester, _wallets(2));

    expect(find.byKey(const Key('wallet-list-add')), findsNothing);
  });

  testWidgets('exactly four wallets fill every row', (tester) async {
    await _pump(tester, _wallets(4), onAddPressed: () {});

    for (var id = 1; id <= 4; id++) {
      expect(_row(id), findsOneWidget);
    }
    expect(find.byKey(const Key('wallet-list-add')), findsNothing);
    expect(find.byKey(const Key('wallet-list-show-all')), findsNothing);
    expect(tester.getBottomLeft(_row(4)).dy, lessThanOrEqualTo(tester.getBottomLeft(find.byType(WalletListView)).dy));
  });

  testWidgets('more wallets than rows show three and a show-all row with the total', (tester) async {
    var shownAll = 0;
    await _pump(tester, _wallets(7), onAddPressed: () {}, onShowAllPressed: () => shownAll++);

    expect(_row(3), findsOneWidget);
    expect(_row(4), findsNothing);
    expect(find.byKey(const Key('wallet-list-add')), findsNothing);
    expect(find.text(t.home_widgets.wallet_list_show_all(count: 7)), findsOneWidget);
    await tester.tap(find.byKey(const Key('wallet-list-show-all')));
    expect(shownAll, 1);
  });

  testWidgets('tapping a row opens that wallet', (tester) async {
    WalletItemBase? opened;
    await _pump(tester, _wallets(3), onWalletPressed: (wallet) => opened = wallet);

    await tester.tap(_row(2));
    expect(opened?.id, 2);
  });
}
