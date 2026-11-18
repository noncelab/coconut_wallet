import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/screens/send/ark_payment_screen.dart';
import 'package:coconut_wallet/widgets/features/send/send_output_detail_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _FakeArk extends ChangeNotifier implements ArkProvider {
  @override
  final ValueNotifier<int> cacheRevision = ValueNotifier(0);

  @override
  void setFastSync(int walletId, bool fast) {}

  @override
  Future<bool> isServerReachable(int walletId) async => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
  @override
  String get language => 'ko';
}

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isInternetOn => true;
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  String getFiatPrice(int satoshiAmount, {FiatCode? fiatCode, bool showCurrencySymbol = true}) => '';
  @override
  int? get bitcoinPriceKrw => null;
}

const _review = ArkPaymentReview(
  headline: '아크로 송금할게요',
  recipient: 'tark1p4vaqaxpzqqpsl8v53gddrlrjvka4ptfm6pxeccldar5ga3uwg4uww3y8ph8m0cezq',
  amountSats: 20000,
  feeSats: 0,
  unit: BitcoinUnit.btc,
  sourceDescription: '아크 내에서 주고받을 땐 수수료가 없어요',
);

Future<void> _pump(
  WidgetTester tester, {
  required Future<ArkPaymentStart> Function() pay,
  Future<bool> Function()? authenticate,
  ArkPaymentReview review = _review,
}) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ArkProvider>(create: (_) => _FakeArk()),
        ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
        ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
        ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(),
        home: ArkPaymentScreen(
          walletId: 1,
          pay: pay,
          isSendStart: (route) => route.isFirst,
          review: review,
          authenticate: authenticate,
        ),
      ),
    ),
  );
  await tester.pump();
}

String _totalLine(int sats) => t.send_confirm_screen.total_required_amount(
  n: ' ${BitcoinUnit.btc.displayBitcoinAmount(sats)} ${BitcoinUnit.btc.symbol}',
);

String _feeText(int sats) => '${BitcoinUnit.btc.displayBitcoinAmount(sats)} ${BitcoinUnit.btc.symbol}';

void main() {
  testWidgets('a reviewed payment shows the recipient and pays nothing until Send is tapped', (tester) async {
    var paid = 0;
    await _pump(
      tester,
      pay: () async {
        paid++;
        return const ArkPaymentStart(isDone: true);
      },
    );
    await tester.pump(const Duration(seconds: 3));

    expect(find.text(t.broadcasting_screen.title), findsOneWidget);
    expect(find.byType(SendOutputDetailCard), findsNothing);
    expect(find.text(t.receiver), findsOneWidget);
    expect(find.text(t.estimated_fee), findsNothing);
    expect(find.text(_review.headline), findsOneWidget);
    expect(find.text(t.broadcasting_screen.description), findsNothing);
    expect(find.text(_review.recipient!), findsOneWidget);
    expect(find.text(_review.sourceDescription), findsOneWidget);
    expect(find.text(_totalLine(_review.amountSats)), findsNothing);
    expect(paid, 0);

    await tester.tap(find.text(t.broadcasting_screen.btn_submit));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(paid, 1);
    expect(find.text(_review.recipient!), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('a failed authentication keeps the review and pays nothing', (tester) async {
    var paid = 0;
    await _pump(
      tester,
      pay: () async {
        paid++;
        return const ArkPaymentStart(isDone: true);
      },
      authenticate: () async => false,
    );

    await tester.tap(find.text(t.broadcasting_screen.btn_submit));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(paid, 0);
    expect(find.text(t.broadcasting_screen.title), findsOneWidget);
  });

  testWidgets('a payment with a fee shows the total and which balance pays', (tester) async {
    const review = ArkPaymentReview(
      headline: '온체인으로 송금할게요',
      recipient: 'bcrt1qp9jwm7f89j4wyddwdn6kmcyyxldlflg0xf6kva',
      amountSats: 20000,
      feeSats: 300,
      unit: BitcoinUnit.btc,
      sourceDescription: '아크 잔액을 비트코인 주소로 보내요',
    );
    await _pump(tester, pay: () async => const ArkPaymentStart(isDone: true), review: review);

    expect(find.text(_totalLine(20300)), findsOneWidget);
    expect(find.text(t.estimated_fee), findsOneWidget);
    expect(find.text(_feeText(300)), findsOneWidget);
    expect(find.text(review.sourceDescription), findsOneWidget);
  });

  testWidgets('a move review has no recipient card and its own button', (tester) async {
    var paid = 0;
    const review = ArkPaymentReview(
      headline: '아크로 옮길게요',
      amountSats: 100000,
      feeSats: 450,
      unit: BitcoinUnit.btc,
      sourceDescription: '블록 1개 확정 뒤 아크 잔액이 돼요',
      submitText: '옮기기',
    );
    await _pump(
      tester,
      pay: () async {
        paid++;
        return const ArkPaymentStart(isDone: true);
      },
      review: review,
    );

    expect(find.text(t.receiver), findsNothing);
    expect(find.text(t.broadcasting_screen.btn_submit), findsNothing);
    expect(find.text(_totalLine(100450)), findsOneWidget);
    expect(find.text(t.estimated_fee), findsOneWidget);
    expect(find.text(_feeText(450)), findsOneWidget);

    await tester.tap(find.text('옮기기'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));

    expect(paid, 1);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });
}
