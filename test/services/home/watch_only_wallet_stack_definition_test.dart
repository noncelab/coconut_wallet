import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/services/home/watch_only_wallet_stack_definition.dart';
import 'package:coconut_wallet/widgets/features/home/watch_only_wallet_stack_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/wallet_mock.dart';

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

Future<void> _pump(WidgetTester tester, List<WalletItemBase> wallets, {VoidCallback? onPressed}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home: Center(
        child: SizedBox(
          width: 172,
          height: 172,
          child: WatchOnlyWalletStackView(wallets: wallets, onPressed: onPressed),
        ),
      ),
    ),
  );
}

void main() {
  test('the definition is a single 2×2 watch-only stack widget', () {
    final definition = WatchOnlyWalletStackDefinition();

    expect(definition.id, HomeItemIds.watchOnlyWalletStack);
    expect(definition.kind, HomeItemKind.widget);
    expect(definition.supportedSpans, [HomeSpan.small]);
    expect(definition.allowsMultipleInstances, isFalse);
  });

  test('only watch-only wallets are kept, in wallet order', () {
    final wallets = [
      WalletMock.createSingleSigWalletItem(id: 1),
      _hot(2),
      WalletMock.createSingleSigWalletItem(id: 3),
      WalletMock.createSingleSigWalletItem(id: 4),
    ];

    final ordered = orderWatchOnlyWallets(wallets, [4, 2, 1]);

    expect(ordered.map((wallet) => wallet.id), [4, 1, 3]);
  });

  test('without a saved order the original order is kept', () {
    final wallets = [WalletMock.createSingleSigWalletItem(id: 5), WalletMock.createSingleSigWalletItem(id: 6)];

    expect(orderWatchOnlyWallets(wallets, const []).map((wallet) => wallet.id), [5, 6]);
  });

  testWidgets('shows the first wallet as a card', (tester) async {
    await _pump(tester, [WalletMock.createSingleSigWalletItem(id: 7), WalletMock.createSingleSigWalletItem(id: 8)]);

    expect(find.byKey(const ValueKey('watch-only-stack-card-7')), findsOneWidget);
    expect(find.byKey(const ValueKey('watch-only-stack-card-8')), findsNothing);
  });

  testWidgets('shows a card with the empty message when there is no watch-only wallet', (tester) async {
    await _pump(tester, const []);

    expect(find.byKey(const Key('watch-only-stack-empty')), findsOneWidget);
    expect(find.text(t.wallet_list.empty_watch_only), findsOneWidget);
  });

  testWidgets('tapping the card calls onPressed', (tester) async {
    var tapped = 0;
    await _pump(tester, [WalletMock.createSingleSigWalletItem(id: 9)], onPressed: () => tapped++);

    await tester.tap(find.byKey(const ValueKey('watch-only-stack-card-9')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tapped, 1);
  });

  testWidgets('tapping the empty stack also calls onPressed', (tester) async {
    var tapped = 0;
    await _pump(tester, const [], onPressed: () => tapped++);

    await tester.tap(find.byKey(const Key('watch-only-stack-empty')));
    await tester.pump();

    expect(tapped, 1);
  });
}
