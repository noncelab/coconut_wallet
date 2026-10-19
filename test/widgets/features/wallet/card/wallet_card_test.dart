import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_metadata.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../mock/wallet_mock.dart';

SinglesigWalletItem _hotWallet() {
  final base = WalletMock.createSingleSigWalletItem();
  return SinglesigWalletItem(
    id: base.id,
    name: base.name,
    colorIndex: 0,
    iconIndex: 0,
    descriptor: base.descriptor,
    hotWalletMetadata: HotWalletMetadata(
      walletId: base.id,
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

Future<void> _pump(
  WidgetTester tester,
  WalletItemBase wallet,
  WalletCardSize size, {
  String? balance,
  String? secondary,
  VoidCallback? onPressed,
  double textScale = 1,
  double edge = 172,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      builder:
          (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size == WalletCardSize.wide ? 356 : edge,
            height: edge,
            child: WalletCard(
              wallet: wallet,
              appearance: WalletAppearance.of(wallet),
              size: size,
              balanceDisplay: balance,
              secondaryText: secondary,
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('wide card shows name, MFP subtitle and balance', (tester) async {
    final wallet = WalletMock.createSingleSigWalletItem();
    await _pump(tester, wallet, WalletCardSize.wide, balance: '0.1234 5678 BTC');

    expect(find.text(wallet.name), findsOneWidget);
    expect(find.text('D45A A182'), findsOneWidget);
    expect(find.byKey(const Key('wallet-card-balance')), findsOneWidget);
  });

  testWidgets('small card without a balance shows the secondary text', (tester) async {
    final wallet = WalletMock.createSingleSigWalletItem();
    await _pump(tester, wallet, WalletCardSize.small, secondary: '2 days ago');

    expect(find.byKey(const Key('wallet-card-balance')), findsNothing);
    expect(find.text('2 days ago'), findsOneWidget);
    expect(find.text(wallet.name), findsOneWidget);
    final mfp = find.byKey(const Key('wallet-card-mfp'));
    expect(mfp, findsOneWidget);
    expect(tester.widget<Text>(mfp).data, matches(RegExp(r'^[0-9A-F]{4} [0-9A-F]{4}$')));
    expect(tester.getRect(mfp).top, greaterThanOrEqualTo(tester.getRect(find.text(wallet.name)).bottom));

    final secondary = tester.getRect(find.text('2 days ago'));
    final card = tester.getRect(find.byType(WalletCard));
    final name = tester.getRect(find.text(wallet.name));
    expect(secondary.top, lessThan(name.top));
    expect(secondary.top - card.top, lessThan(card.height / 3));
    expect(card.right - secondary.right, lessThan(20));
  });

  testWidgets('a small card given a balance shows it between the header and the name, as in the wallet wheel', (
    tester,
  ) async {
    final wallet = WalletMock.createSingleSigWalletItem();
    await _pump(tester, wallet, WalletCardSize.small, balance: '0.1234 5678 BTC', secondary: '2 days ago');

    final balance = tester.getRect(find.byKey(const Key('wallet-card-balance')));
    expect(balance.top, greaterThan(tester.getRect(find.text('2 days ago')).bottom));
    expect(balance.bottom, lessThan(tester.getRect(find.text(wallet.name)).top));
  });

  testWidgets('watch-only wallet shows the watch-only glyph', (tester) async {
    await _pump(tester, WalletMock.createSingleSigWalletItem(), WalletCardSize.small);

    expect(find.byKey(const Key('wallet-card-glyph-watch-only')), findsOneWidget);
    expect(find.byKey(const Key('wallet-card-glyph-hot')), findsNothing);
    final glyph = find.byKey(const Key('wallet-card-glyph-watch-only'));
    expect(
      tester.widget<SvgPicture>(glyph).colorFilter,
      ColorFilter.mode(tester.element(glyph).coconutColors.secondaryText, BlendMode.srcIn),
    );
  });

  testWidgets('hot wallet shows the hot glyph', (tester) async {
    await _pump(tester, _hotWallet(), WalletCardSize.wide);

    expect(find.byKey(const Key('wallet-card-glyph-hot')), findsOneWidget);
  });

  testWidgets('multisig wallet has no MFP subtitle', (tester) async {
    await _pump(tester, WalletMock.createMultiSigWalletItem(), WalletCardSize.wide);

    expect(find.byKey(const Key('wallet-card-mfp')), findsNothing);
  });

  for (final size in WalletCardSize.values) {
    for (final scale in [1.0, 1.3, 2.0]) {
      testWidgets('$size retains balance and fingerprint at text scale $scale', (tester) async {
        await _pump(
          tester,
          WalletMock.createSingleSigWalletItem(),
          size,
          balance: '21.0000 0000 BTC',
          secondary: '2 days ago',
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        final card = tester.getRect(find.byType(WalletCard));
        for (final key in ['wallet-card-balance', 'wallet-card-mfp']) {
          final finder = find.byKey(Key(key));
          final rect = tester.getRect(finder);
          expect(rect.top, greaterThanOrEqualTo(card.top));
          expect(rect.bottom, lessThanOrEqualTo(card.bottom));
          final paragraph = tester.renderObject<RenderParagraph>(finder);
          expect(paragraph.didExceedMaxLines, isFalse);
        }
      });
    }
  }

  testWidgets('a narrow home card keeps the full amount and fingerprint visible at 2x', (tester) async {
    await _pump(
      tester,
      WalletMock.createSingleSigWalletItem(),
      WalletCardSize.small,
      balance: '21.0000 0000 BTC',
      secondary: '2 days ago',
      textScale: 2,
      edge: 138,
    );
    expect(tester.takeException(), isNull);
    final card = tester.getRect(find.byType(WalletCard));
    for (final key in ['wallet-card-balance', 'wallet-card-mfp']) {
      final rect = tester.getRect(find.byKey(Key(key)));
      expect(rect.height, greaterThan(0));
      expect(rect.left, greaterThanOrEqualTo(card.left));
      expect(rect.right, lessThanOrEqualTo(card.right));
      expect(rect.top, greaterThanOrEqualTo(card.top));
      expect(rect.bottom, lessThanOrEqualTo(card.bottom));
    }
  });

  testWidgets('tapping the card calls onPressed', (tester) async {
    var tapped = 0;
    await _pump(tester, WalletMock.createSingleSigWalletItem(), WalletCardSize.small, onPressed: () => tapped++);

    await tester.tap(find.byType(WalletCard));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tapped, 1);
  });
}
