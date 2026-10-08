import 'package:coconut_wallet/design_system/tokens/coconut_colors.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_extension.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/utils/wallet_visual_style_util.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/activity_widget_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_widget_views.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../../mock/wallet_mock.dart';

const _small = Size(156, 156);
const _wide = Size(328, 156);

Future<void> _pump(WidgetTester tester, Size size, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home: Scaffold(body: Center(child: SizedBox.fromSize(size: size, child: child))),
    ),
  );
}

String _btc(int sats) => '${(sats / 100000000).toStringAsFixed(8)} BTC';

const _fiatRows = [
  HomeFiatRow(fiat: FiatCode.KRW, amountText: '105,111,720', rate: 0.02),
  HomeFiatRow(fiat: FiatCode.USD, amountText: '76,216', rate: -0.01),
  HomeFiatRow(fiat: FiatCode.EUR, amountText: '66,520'),
  HomeFiatRow(fiat: FiatCode.JPY, amountText: '115,014,436'),
];

void main() {
  final now = DateTime(2026, 9, 1, 15);
  final days = [for (var i = 0; i < 7; i++) DateTime(2026, 8, 26 + i)];

  testWidgets('balance widgets fit their sizes', (tester) async {
    await _pump(
      tester,
      _small,
      const BitcoinBalanceTrendView(
        balance: HomeAmount('21.1234 5678', 'BTC'),
        fiatText: '₩ 2,214,892,000',
        rate: 0.05,
        values: [1, 3, 2, 5, 4, 6, 7],
      ),
    );
    expect(find.text('↑'), findsOneWidget);
    expect(find.text('5%'), findsOneWidget);
    expect(find.text('21.1234 5678 BTC', findRichText: true), findsOneWidget);

    await _pump(
      tester,
      _small,
      const BitcoinBalanceByFiatView(balance: HomeAmount('21.1234 5678', 'BTC'), rows: _fiatRows),
    );
    expect(find.text('KRW'), findsOneWidget);
    expect(find.text('JPY'), findsOneWidget);

    await _pump(
      tester,
      _small,
      const FiatPriceTrendView(
        price: HomeAmount('105,111,720', '₩', unitFirst: true),
        pairLabel: 'BTC · KRW',
        rate: -0.05,
        values: [5, 4, 6, 3],
      ),
    );
    expect(find.text('↓'), findsOneWidget);
    expect(find.text('5%'), findsOneWidget);
    expect(find.text('₩ 105,111,720', findRichText: true), findsOneWidget);
    expect(find.text('BTC · KRW'), findsOneWidget);

    await _pump(tester, _small, FiatValuesView(rows: _fiatRows.take(3).toList()));
    expect(find.text('76,216'), findsOneWidget);
    expect(find.byKey(const ValueKey('fiat-values-divider-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('fiat-values-divider-2')), findsOneWidget);
    final arrowToCode =
        tester.getTopLeft(find.text('USD')).dx - tester.getRect(find.byKey(const Key('fiat-rate-down'))).right;
    expect(arrowToCode, greaterThanOrEqualTo(3));
    expect(arrowToCode, lessThan(6));
    expect(tester.widget<Text>(find.text('USD')).style!.fontSize, 12);

    await _pump(
      tester,
      _wide,
      BalanceChangeOverTimeView(
        balance: const HomeAmount('1.5284 0000', 'BTC'),
        fiatText: '₩ 214,892,000',
        rate: 0.0521,
        deltaText: '+ 0.0753 BTC',
        deltaSign: 1,
        values: const [1, 2, 3, 2, 4, 5, 6],
        dayLabels: [for (final day in days) formatHomeShortDate(day)],
      ),
    );
    expect(find.text('↑'), findsOneWidget);
    expect(find.text('5.21%'), findsOneWidget);
    expect(find.text('8/26'), findsOneWidget);
  });

  testWidgets('measured columns account for the surrounding text style, so no text is clipped', (tester) async {
    void expectNotClipped(String text) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      expect(
        paragraph.size.width,
        greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity) - 0.01),
        reason: text,
      );
    }

    Future<void> pumpWithSpacing(Widget child) => tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: DefaultTextStyle.merge(
            style: const TextStyle(letterSpacing: 1.5),
            child: Center(child: SizedBox.fromSize(size: _small, child: child)),
          ),
        ),
      ),
    );

    await pumpWithSpacing(
      const UtxoStatusView(
        buckets: HomeUtxoBuckets([9, 9, 1, 2]),
        bucketColors: [Color(0xFFF9DA94), Color(0xFF98A8D0), Color(0xFFDAF8E7), Color(0xFFD2E6FB)],
      ),
    );
    for (final text in [...UtxoStatusView.bucketLabels, '1 (4.8%)', '2 (9.5%)']) {
      expectNotClipped(text);
    }

    await pumpWithSpacing(FiatValuesView(rows: _fiatRows.take(3).toList()));
    for (final row in _fiatRows.take(3)) {
      expectNotClipped(row.amountText);
      expectNotClipped(row.fiat.code);
    }
  });

  testWidgets('first-line texts sit at the same height in every widget', (tester) async {
    Future<double> centerFromTop(Widget view, Finder text) async {
      await _pump(tester, _small, view);
      final card = tester.getRect(find.byWidget(view));
      return tester.getRect(text).center.dy - card.top;
    }

    final goal = await centerFromTop(
      const SavingsGoalView(goal: null, amountText: _btc),
      find.text(t.home_widgets.savings_goal),
    );
    final utxo = await centerFromTop(
      const UtxoStatusView(
        buckets: HomeUtxoBuckets([1, 0, 0, 0]),
        bucketColors: [Color(0xFFF9DA94), Color(0xFF98A8D0), Color(0xFFDAF8E7), Color(0xFFD2E6FB)],
      ),
      find.text(t.home_widgets.utxo_count(count: 1)),
    );
    final wallet = await centerFromTop(
      WalletCard(
        wallet: WalletMock.createSingleSigWalletItem(id: 1),
        appearance: const WalletAppearance(colorIndex: 0, iconIndex: 0),
        size: WalletCardSize.small,
        secondaryText: '11일 전',
      ),
      find.text('11일 전'),
    );

    expect(utxo, closeTo(goal, 0.5));
    expect(wallet, closeTo(goal, 0.5));
    expect(goal, closeTo(16 + kHomeWidgetHeaderHeight / 2, 0.5));
  });

  testWidgets('utxo status leaves room between the title and the first bucket', (tester) async {
    await _pump(
      tester,
      _small,
      const UtxoStatusView(
        buckets: HomeUtxoBuckets([1, 0, 0, 0]),
        bucketColors: [Color(0xFFF9DA94), Color(0xFF98A8D0), Color(0xFFDAF8E7), Color(0xFFD2E6FB)],
      ),
    );
    final header = tester.getRect(find.byType(HomeWidgetHeader));
    final firstRow = tester.getRect(find.byKey(const ValueKey('utxo-status-bucket-0')));
    expect(firstRow.top - header.bottom, greaterThanOrEqualTo(14));
  });

  testWidgets('side by side, fiat values and the bitcoin balance trend start and end at the same height', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.fromSize(
                  size: _small,
                  child: const BitcoinBalanceTrendView(
                    balance: HomeAmount('1.2345', 'BTC'),
                    fiatText: '₩ 214,892,000',
                    rate: 0.05,
                    values: [1, 2, 3],
                  ),
                ),
                SizedBox.fromSize(size: _small, child: FiatValuesView(rows: _fiatRows.take(3).toList())),
              ],
            ),
          ),
        ),
      ),
    );

    final trendBottom = tester.getRect(find.byKey(const Key('home-trend-footer'))).bottom;
    final valuesBottom =
        tester.getRect(find.ancestor(of: find.text('66,520'), matching: find.byType(Row)).first).bottom;
    final trendTop = tester.getRect(find.text('1.2345 BTC', findRichText: true)).top;
    final valuesTop = tester.getRect(find.text('KRW')).top;

    expect(valuesBottom, closeTo(trendBottom, 0.5));
    expect(valuesTop, closeTo(trendTop, 3));
  });

  testWidgets('row widgets end on the same bottom padding as other widgets', (tester) async {
    Future<void> expectBottomPadding(Widget view, Finder lastRow) async {
      await _pump(tester, _small, view);
      final card = tester.getRect(find.byType(HomeWidgetCard));
      expect(card.bottom - tester.getRect(lastRow).bottom, closeTo(16, 0.5), reason: '$view');
    }

    await expectBottomPadding(
      const UtxoStatusView(
        buckets: HomeUtxoBuckets([9, 9, 1, 2]),
        bucketColors: [Color(0xFFF9DA94), Color(0xFF98A8D0), Color(0xFFDAF8E7), Color(0xFFD2E6FB)],
      ),
      find.byKey(const ValueKey('utxo-status-bucket-3')),
    );
    await expectBottomPadding(
      const BitcoinBalanceByFiatView(balance: HomeAmount('21.1234 5678', 'BTC'), rows: _fiatRows),
      find.ancestor(of: find.text('JPY'), matching: find.byType(Row)).first,
    );
  });

  testWidgets('utxo status never overflows at any card size', (tester) async {
    for (var side = 120.0; side <= 200; side += 1) {
      for (final counts in const [
        [9, 9, 1, 2],
        [123, 4567, 89, 1],
      ]) {
        await _pump(
          tester,
          Size(side, side),
          UtxoStatusView(
            buckets: HomeUtxoBuckets(counts),
            bucketColors: const [Color(0xFFF9DA94), Color(0xFF98A8D0), Color(0xFFDAF8E7), Color(0xFFD2E6FB)],
          ),
        );
        expect(tester.takeException(), isNull, reason: 'side $side counts $counts');
      }
    }
  });

  testWidgets('the trend footer keeps the label in place, with the arrow 2px left of the rate', (tester) async {
    Future<({Rect price, Rect arrow, Rect percent})> layout(String price, double rate) async {
      await _pump(
        tester,
        _small,
        FiatPriceTrendView(
          price: const HomeAmount('105,111,720', '₩', unitFirst: true),
          pairLabel: price,
          rate: rate,
          values: const [1, 2, 3],
        ),
      );
      expect(tester.widget<Text>(find.text(price)).overflow, isNot(TextOverflow.ellipsis));
      return (
        price: tester.getRect(find.text(price)),
        arrow: tester.getRect(find.textContaining(RegExp('[↑↓]'))),
        percent: tester.getRect(find.textContaining('%')),
      );
    }

    final first = await layout('BTC · KRW', 0.05);
    final second = await layout('BTC · USD', -0.1234);

    expect(second.price.left, first.price.left);
    expect(second.price.height, first.price.height);
    expect(second.percent.right, closeTo(first.percent.right, 0.01));
    expect(first.percent.left - first.arrow.right, closeTo(2, 0.01));
    expect(second.percent.left - second.arrow.right, greaterThan(0));
    expect(first.arrow.left - first.price.right, greaterThanOrEqualTo(8));
  });

  testWidgets('the rate is smaller than the arrow', (tester) async {
    await _pump(tester, _small, const HomeTrendChange(rate: 0.05));

    expect(
      tester.widget<Text>(find.text('5%')).style!.fontSize,
      lessThan(tester.widget<Text>(find.text('↑')).style!.fontSize!),
    );
  });

  test('the compact rate drops trailing zeros', () {
    expect(formatHomeRateCompact(0.05), '5%');
    expect(formatHomeRateCompact(-0.0521), '5.21%');
    expect(formatHomeRateCompact(0.105), '10.5%');
    expect(formatHomeRateCompact(0.1), '10%');
  });

  testWidgets('the amount is a big bold number with a small regular unit', (tester) async {
    await _pump(
      tester,
      _small,
      const HomeAmountText(
        amount: HomeAmount('21.1234 5678', 'BTC'),
        numberStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        unitStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      ),
    );

    final spans = (tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan).children!.cast<TextSpan>();
    final number = spans.firstWhere((span) => span.text == '21.1234 5678');
    final unit = spans.firstWhere((span) => span.text == 'BTC');
    expect(number.style!.fontSize, greaterThan(unit.style!.fontSize!));
    expect(number.style!.fontWeight, FontWeight.w700);
    expect(unit.style!.fontWeight, FontWeight.w400);
  });

  testWidgets('no change shows a neutral dash', (tester) async {
    await _pump(
      tester,
      _small,
      const FiatValuesView(rows: [HomeFiatRow(fiat: FiatCode.KRW, amountText: '1', rate: 0)]),
    );

    expect(find.byKey(const Key('fiat-rate-neutral')), findsOneWidget);
    expect(find.byKey(const Key('fiat-rate-up')), findsNothing);
    expect(find.byKey(const Key('fiat-rate-down')), findsNothing);
  });

  testWidgets('fiat amounts share one font size, shrunk to fit the longest amount', (tester) async {
    const rows = [
      HomeFiatRow(fiat: FiatCode.KRW, amountText: '1,013,111,720,000'),
      HomeFiatRow(fiat: FiatCode.USD, amountText: '76,216'),
      HomeFiatRow(fiat: FiatCode.EUR, amountText: '66,520'),
      HomeFiatRow(fiat: FiatCode.JPY, amountText: '115,014,436'),
    ];
    for (final view in const [
      BitcoinBalanceByFiatView(balance: HomeAmount('21.1234 5678', 'BTC'), rows: rows),
      FiatValuesView(rows: rows),
    ]) {
      await _pump(tester, _small, view);

      final heights = {for (final row in rows) (tester.getRect(find.text(row.amountText)).height * 100).round()};
      expect(heights, hasLength(1), reason: '$view');
      expect(tester.takeException(), isNull);
      for (final row in rows) {
        final amount = tester.getRect(find.text(row.amountText));
        final card = tester.getRect(find.byType(view.runtimeType));
        expect(amount.right, lessThanOrEqualTo(card.right), reason: row.amountText);
      }
    }
  });

  test('the home widget shadow is a light glow on the dark theme and a dark shadow on light themes', () {
    for (final variant in CoconutThemeVariant.values) {
      final colors = buildCoconutThemeData(variant: variant).extension<CoconutThemeExtension>()!.colors;
      final shadow = HSLColor.fromColor(colors.homeWidgetShadow).lightness;
      final background = HSLColor.fromColor(colors.homeBackground).lightness;
      expect(shadow > background, variant == CoconutThemeVariant.dark, reason: '$variant');
    }
  });

  testWidgets('widgets use the home color tokens in every theme', (tester) async {
    for (final variant in CoconutThemeVariant.values) {
      final colors = buildCoconutThemeData(variant: variant).extension<CoconutThemeExtension>()!.colors;
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(variant: variant),
          home: Scaffold(
            body: Center(
              child: SizedBox.fromSize(
                size: _small,
                child: const FiatValuesView(rows: [HomeFiatRow(fiat: FiatCode.KRW, amountText: '1', rate: 0.1)]),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final card = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(HomeWidgetCard), matching: find.byType(DecoratedBox)).first,
      );
      expect((card.decoration as BoxDecoration).color, colors.homeSurface, reason: '$variant');
      final up = homePriceColors(tester.element(find.byType(FiatValuesView))).up;
      expect(tester.widget<Text>(find.text('1')).style!.color, up, reason: '$variant');
      expect(tester.widget<Icon>(find.byKey(const Key('fiat-rate-up'))).color, up, reason: '$variant');
    }
  });

  testWidgets('prices rise in bitcoin orange and fall in its complement, in every language', (tester) async {
    await _pump(tester, _small, const SizedBox());
    final context = tester.element(find.byType(SizedBox).last);

    for (final locale in [AppLocale.ko, AppLocale.en]) {
      LocaleSettings.setLocale(locale);
      expect(homePriceColors(context), (up: kCoconutPriceUp, down: kCoconutPriceDown));
    }
    LocaleSettings.setLocale(AppLocale.ko);
  });

  testWidgets('the trend footer stays at the same place however long the fiat value gets', (tester) async {
    Future<({Rect footer, double textBottom})> layout(String fiatText) async {
      await _pump(
        tester,
        _small,
        BitcoinBalanceTrendView(
          balance: const HomeAmount('1', 'BTC'),
          fiatText: fiatText,
          rate: 0.05,
          values: const [1, 2],
        ),
      );
      return (
        footer: tester.getRect(find.byKey(const Key('home-trend-footer'))),
        textBottom: tester.getRect(find.text(fiatText)).bottom,
      );
    }

    final short = await layout('₩ 2,214');
    final long = await layout('₩ 2,214,892,000,000,000');

    expect(long.footer, short.footer);
    expect(long.textBottom, closeTo(short.textBottom, 0.01));
  });

  testWidgets('the fiat value under the bitcoin balance trend uses the chart color', (tester) async {
    for (final rate in [0.05, -0.05, null]) {
      await _pump(
        tester,
        _small,
        BitcoinBalanceTrendView(
          balance: const HomeAmount('1', 'BTC'),
          fiatText: '₩ 214,892,000',
          rate: rate,
          values: const [1, 2],
        ),
      );
      final context = tester.element(find.byType(BitcoinBalanceTrendView));
      expect(tester.widget<Text>(find.text('₩ 214,892,000')).style!.color, context.coconutColors.homeChartLine);
    }
  });

  testWidgets('bitcoin balance and fiat values draw the arrow, gap, and fiat code the same way', (tester) async {
    Future<({double arrowSize, double gap, double codeSize})> measure(Widget view) async {
      await _pump(tester, _small, view);
      final arrow = tester.widget<Icon>(find.byKey(const Key('fiat-rate-up')).first);
      final arrowRect = tester.getRect(find.byKey(const Key('fiat-rate-up')).first);
      final codeRect = tester.getRect(find.text('KRW'));
      return (
        arrowSize: arrow.size!,
        gap: codeRect.left - arrowRect.right,
        codeSize: tester.widget<Text>(find.text('KRW')).style!.fontSize!,
      );
    }

    const rows = [HomeFiatRow(fiat: FiatCode.KRW, amountText: '1', rate: 0.1)];
    final balance = await measure(const BitcoinBalanceByFiatView(balance: HomeAmount('1', 'BTC'), rows: rows));
    final values = await measure(const FiatValuesView(rows: rows));

    expect(balance, values);
    expect(values.codeSize, 12);
    expect(values.arrowSize, values.codeSize);
  });

  testWidgets('in each fiat row the arrow, fiat code and amount share one vertical center', (tester) async {
    for (final view in [
      const BitcoinBalanceByFiatView(balance: HomeAmount('1', 'BTC'), rows: _fiatRows),
      FiatValuesView(rows: _fiatRows.take(3).toList()),
    ]) {
      await _pump(tester, _small, view);
      final arrow = tester.getRect(find.byKey(const Key('fiat-rate-up')).first).center.dy;
      final code = tester.getRect(find.text('KRW')).center.dy;
      final amount = tester.getRect(find.text(_fiatRows.first.amountText)).center.dy;
      expect(arrow, closeTo(code, 0.5), reason: '${view.runtimeType}');
      expect(amount, closeTo(code, 0.5), reason: '${view.runtimeType}');
    }
  });

  testWidgets('the fiat price trend shows the pair label in the tertiary color whatever the rate', (tester) async {
    for (final rate in [0.05, -0.05, null]) {
      await _pump(
        tester,
        _small,
        FiatPriceTrendView(
          price: const HomeAmount('105,111,720', '₩', unitFirst: true),
          pairLabel: 'BTC · KRW',
          rate: rate,
          values: const [1, 2],
        ),
      );
      final context = tester.element(find.byType(FiatPriceTrendView));
      expect(tester.widget<Text>(find.text('BTC · KRW')).style!.color, context.coconutColors.tertiaryText);
    }
  });

  testWidgets('a missing rate also shows the neutral dash', (tester) async {
    await _pump(tester, _small, const FiatValuesView(rows: [HomeFiatRow(fiat: FiatCode.JPY, amountText: '1')]));

    expect(find.byKey(const Key('fiat-rate-neutral')), findsOneWidget);
    expect(find.byKey(const Key('fiat-rate-up')), findsNothing);
    expect(find.byKey(const Key('fiat-rate-down')), findsNothing);
  });

  testWidgets('balance by wallet shows a two-line total and 4-decimal amounts with percentages', (tester) async {
    await _pump(
      tester,
      _wide,
      BalanceByWalletView(
        shares: const [
          HomeBalanceShare(walletId: 1, name: 'Main', balance: 75000000, colorIndex: 2),
          HomeBalanceShare(walletId: null, name: 'Others', balance: 25000000),
        ],
        total: const HomeAmount('1.0000', 'BTC'),
        amountText: (sats) => (sats / 100000000).toStringAsFixed(4),
      ),
    );

    expect(find.text('Main'), findsOneWidget);
    expect(find.text('75.0%'), findsOneWidget);
    expect(find.text('0.7500 BTC'), findsOneWidget);
    final total = find.byKey(const Key('balance-by-wallet-total'));
    expect(
      tester.getTopLeft(find.descendant(of: total, matching: find.text('BTC'))).dy,
      greaterThan(tester.getTopLeft(find.descendant(of: total, matching: find.text('1.0000'))).dy),
    );
    final dots = tester.widgetList<Container>(
      find.byWidgetPredicate((w) => w is Container && w.constraints?.maxWidth == 10),
    );
    expect((dots.first.decoration! as BoxDecoration).color, WalletVisualStyleUtil.getColorByIndex(2));
  });

  testWidgets('recent transactions show three full rows and open the tapped wallet', (tester) async {
    final tapped = <int>[];
    await _pump(
      tester,
      _wide,
      RecentTransactionsView(
        transactions: [
          for (var i = 0; i < 5; i++)
            HomeRecentTransaction(
              walletId: 10 + i,
              walletName: 'Wallet $i',
              amount: i.isEven ? 1000 : -2000,
              time: now.subtract(Duration(hours: i)),
              type: i.isEven ? TransactionType.received : TransactionType.sent,
            ),
        ],
        amountText: _btc,
        now: now,
        onTransactionTap: tapped.add,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('- ${_btc(2000)}'), findsWidgets);
    expect(find.byKey(const ValueKey('recent-transactions-icon-received')), findsWidgets);
    expect(find.byKey(const ValueKey('recent-transactions-icon-sent')), findsWidgets);
    final card = tester.getRect(find.byKey(const Key('recent-transactions-list')));
    final third = tester.getRect(find.byKey(const ValueKey('recent-transactions-row-2')));
    expect(third.bottom, closeTo(card.bottom, 0.5));
    expect(find.byKey(const ValueKey('recent-transactions-row-3')), findsNothing);
    expect(find.byKey(const Key('recent-transactions-waiting')), findsNothing);

    final pressed = await tester.startGesture(tester.getCenter(find.text('Wallet 1')));
    await tester.pump(const Duration(milliseconds: 150));
    final pressedBox = tester.widget<AnimatedContainer>(
      find.descendant(
        of: find.byKey(const ValueKey('recent-transactions-row-1')),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(((pressedBox.decoration! as BoxDecoration).color!).a, greaterThan(0));
    await pressed.up();
    await tester.pump(const Duration(milliseconds: 150));
    expect(tapped, [11]);

    await _pump(tester, _wide, RecentTransactionsView(transactions: const [], amountText: _btc, now: now));
    expect(find.text(t.home_widgets.no_recent_transactions), findsOneWidget);

    await _pump(
      tester,
      _wide,
      RecentTransactionsView(
        transactions: [
          HomeRecentTransaction(
            walletId: 1,
            walletName: 'Only',
            amount: 1000,
            time: now,
            type: TransactionType.received,
          ),
        ],
        amountText: _btc,
        now: now,
      ),
    );
    final list = tester.getRect(find.byKey(const Key('recent-transactions-list')));
    final only = tester.getRect(find.byKey(const ValueKey('recent-transactions-row-0')));
    final waiting = tester.getRect(find.byKey(const Key('recent-transactions-waiting')));
    expect(only.height, closeTo((list.height - 2) / 3, 0.5));
    expect(waiting.bottom, closeTo(list.bottom, 0.5));
    expect(find.text(t.home_widgets.waiting_for_transactions), findsOneWidget);
  });

  testWidgets('a yearly transaction activity labels each bar with its month', (tester) async {
    await _pump(
      tester,
      _wide,
      TransactionActivityView(
        monthly: true,
        days: [
          for (var month = 1; month <= 12; month++) HomeDailyActivity(day: DateTime(2026, month), received: month),
        ],
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text(t.home_widgets.months_short[0]), findsOneWidget);
    expect(find.text(t.home_widgets.months_short[11]), findsOneWidget);
  });

  testWidgets('transaction activity shows totals per type', (tester) async {
    await _pump(
      tester,
      _wide,
      TransactionActivityView(
        days: [
          for (final day in days) HomeDailyActivity(day: day, received: 1, sent: 2, organized: day.day == 1 ? 3 : 0),
        ],
      ),
    );

    expect(find.text('7'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('8/26 ~ 9/1'), findsOneWidget);
    final legend = tester.getRect(find.byKey(const Key('transaction-activity-legend')));
    final dividers = find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey &&
          '${(widget.key as ValueKey).value}'.startsWith('transaction-activity-legend-divider'),
    );
    expect(dividers, findsNWidgets(2));
    final cellWidth = (legend.width - 2) / 3;
    expect(tester.getRect(dividers.first).left, closeTo(legend.left + cellWidth, 1));
    expect(tester.getCenter(find.text('14')).dx, closeTo(legend.left + cellWidth * 1.5 + 1, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction activity without any transaction in the period shows an empty state', (tester) async {
    await _pump(tester, _wide, TransactionActivityView(days: [for (final day in days) HomeDailyActivity(day: day)]));

    expect(find.byKey(const Key('transaction-activity-empty')), findsOneWidget);
    expect(find.text(t.home_widgets.no_period_transactions), findsOneWidget);
    expect(find.text('8/26 ~ 9/1'), findsOneWidget);
  });

  testWidgets('savings goal shows progress or asks to set a goal', (tester) async {
    await _pump(
      tester,
      _small,
      const SavingsGoalView(goal: HomeSavingsGoal(balance: 25000000, target: 100000000), amountText: _btc),
    );
    expect(find.text('25.0%'), findsOneWidget);
    expect(find.byKey(const Key('savings-goal-icon')), findsOneWidget);

    await _pump(tester, _small, const SavingsGoalView(goal: null, amountText: _btc));
    expect(find.byKey(const Key('savings-goal-empty')), findsOneWidget);
  });

  testWidgets('utxo status shows the count and each bucket', (tester) async {
    await _pump(
      tester,
      _small,
      const UtxoStatusView(
        buckets: HomeUtxoBuckets([9, 9, 1, 2]),
        bucketColors: [Color(0xFFF9DA94), Color(0xFF98A8D0), Color(0xFFDAF8E7), Color(0xFFD2E6FB)],
      ),
    );

    expect(find.text(t.home_widgets.utxo_count(count: 21)), findsOneWidget);
    expect(find.byKey(const Key('utxo-status-icon')), findsOneWidget);
    expect(find.text('9 (42.9%)'), findsNWidgets(2));
    final rights = {
      for (final text in ['9 (42.9%)', '1 (4.8%)', '2 (9.5%)'])
        for (final element in find.text(text).evaluate()) tester.getRect(find.byWidget(element.widget)).right,
    };
    expect(rights.reduce((a, b) => a > b ? a : b) - rights.reduce((a, b) => a < b ? a : b), lessThanOrEqualTo(1));
    final dot = tester.widget<Container>(
      find.descendant(of: find.byKey(const ValueKey('utxo-status-bucket-0')), matching: find.byType(Container)).first,
    );
    expect((dot.decoration! as BoxDecoration).color, isNot(const Color(0xFF000000)));
    double heightOf(String text) => tester.getRect(find.text(text).first).height;
    expect({for (final label in UtxoStatusView.bucketLabels) heightOf(label)}, hasLength(1));
    expect({
      for (final count in ['9 (42.9%)', '1 (4.8%)', '2 (9.5%)']) heightOf(count),
    }, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  test('the smooth chart line never goes beyond the highest and lowest points', () {
    final points = [
      const Offset(0, 50),
      const Offset(10, 50),
      const Offset(20, 10),
      const Offset(30, 10),
      const Offset(40, 90),
      const Offset(50, 40),
    ];
    final bounds = smoothPath(points).getBounds();
    expect(bounds.top, greaterThanOrEqualTo(10 - 0.01));
    expect(bounds.bottom, lessThanOrEqualTo(90 + 0.01));
    expect(bounds.left, 0);
    expect(bounds.right, 50);
  });

  testWidgets('balance change keeps the fiat and the change amount on one bottom line with the rate right above', (
    tester,
  ) async {
    await _pump(
      tester,
      _wide,
      BalanceChangeOverTimeView(
        balance: const HomeAmount('1.2345', 'BTC'),
        fiatText: '₩ 123,456,789',
        rate: 0.0521,
        deltaText: '+ 0.0753 BTC',
        deltaSign: 1,
        values: const [1, 2, 3, 2, 4, 5, 6],
        dayLabels: const ['1', '2', '3', '4', '5', '6', '7'],
      ),
    );
    final fiat = tester.getRect(find.byKey(const Key('balance-change-fiat')));
    final delta = tester.getRect(find.byKey(const Key('balance-change-delta')));
    final rate = tester.getRect(find.byKey(const Key('balance-change-rate')));
    expect(fiat.bottom, closeTo(delta.bottom, 0.5));
    expect(delta.top - rate.bottom, closeTo(2, 0.5));
  });
}
