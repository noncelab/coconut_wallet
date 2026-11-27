import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_send_view_model.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_move_parts.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_send_confirm_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_send_screen.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_info_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../ccos/ccos_store_test_fakes.dart';
import '../../../ccos/features/ark/ark_test_fakes.dart';

const _ark =
    'tark1pqma5v23zqqp5z47f6anpx0lp5vu757p3cnxzqx887t8zl3wacuvdgyeyee2puh3zqypf2680f7z8zau5ukptjaa7suxu0vadk0ncdyw4qdeazs9u29fddycffu4m9';
const _invoice =
    'lnbcrt300u1p4dtlwusp5nptqcasatxvy082yctgkamwtewxfdnuh3eemk48utk2cp6zz9umspp50rc6tq4889yrpqt5tlmssthes5qxrfzh3qh93fqm8h00j3sav27sdqqxqy9gcqcqzgq9qyysgqcjnlnm5mwfsf09uvnjraxzwj04c2l9gtduntevk95pec3vvkglv9wqu57rnw3mz8t37add2fsrs44llju7ncaty67ay3d2x9kayxxcsqertrwr';

class _Auth extends Fake implements AuthProvider {
  @override
  bool get isAuthEnabled => false;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUp(() => ArkPaymentRequest.clock = () => DateTime.utc(2026, 10, 19, 12));
  tearDown(() => ArkPaymentRequest.clock = DateTime.now);
  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    NetworkType.setNetworkType(NetworkType.regtest);
  });

  Future<FakeArkBackend> pump(WidgetTester tester, String input) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend =
        FakeArkBackend()
          ..sendFee = 12
          ..currentBalance = const ArkBalance(
            spendable: 100000,
            pendingInRound: 0,
            pendingBoard: 0,
            pendingExit: 0,
            pendingLightningSend: 0,
            claimableLightningReceive: 0,
          );
    final wallet = await fakeArkWalletProvider(backend: backend);
    await wallet.restore(Uint8List.fromList(utf8.encode('${'abandon ' * 11}about')));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: FakeStorePreferences()),
          ChangeNotifierProvider<ArkWalletProvider>.value(value: wallet),
          InheritedProvider<AuthProvider>.value(value: _Auth()),
          ...fakeArkPriceProviders(),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          home: ArkSendScreen(initialInput: input),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    return backend;
  }

  testWidgets('an invoice goes through confirm to a sent result', (tester) async {
    final backend = await pump(tester, _invoice);

    expect(find.text(t.ark_wallet.parsed_lightning), findsOneWidget);
    await tester.tap(find.text(t.next));
    await settle(tester);

    expect(find.byType(ArkSendConfirmScreen), findsOneWidget);
    expect(find.text(t.ark_wallet.confirm_lightning), findsOneWidget);
    expect(find.byKey(const Key('ark-send-icon-${FeatureArkIconPath.txLightningSending}')), findsOneWidget);
    expect(find.byKey(const Key('ark-send-icon-progress')), findsOneWidget);
    expect(find.descendant(of: find.byType(ArkInfoBox), matching: find.text(t.ark_wallet.invoice)), findsOneWidget);
    expect(find.text(t.ark_wallet.recipient), findsNothing);
    await tester.tap(find.text(t.send).last);
    await settle(tester);

    expect(backend.sent.single.$1, ArkPaymentRail.lightningInvoice);
    expect(find.text(t.ark_wallet.result_sent), findsOneWidget);
    expect(find.descendant(of: find.byType(ArkInfoBox), matching: find.text(t.ark_wallet.invoice)), findsOneWidget);
  });

  testWidgets('an invoice description shows as the Lightning memo on confirm and result', (tester) async {
    ArkPaymentRequest.clock = () => DateTime.utc(2017, 6, 1, 11);
    NetworkType.setNetworkType(NetworkType.mainnet);
    await pump(
      tester,
      'lnbc1pvjluezsp5zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygspp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdpl2pkx2ctnv5sxxmmwwd5kgetjypeh2ursdae8g6twvus8g6rfwvs8qun0dfjkxaq9qrsgq357wnc5r2ueh7ck6q93dj32dlqnls087fxdwk8qakdyafkq3yap9us6v52vjjsrvywa6rt52cm9r9zqt8r2t7mlcwspyetp5h2tztugp9lfyql',
    );
    unawaited(
      Provider.of<ArkSendViewModel>(
        tester.element(find.byKey(const Key('ark-send-memo'))),
        listen: false,
      ).setAmount(1000),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.byKey(const Key('ark-send-lightning-memo')), findsOneWidget);
    expect(find.textContaining('Please consider supporting this project'), findsOneWidget);
    await tester.tap(find.text(t.next));
    await settle(tester);

    final box = find.byType(ArkInfoBox);
    expect(find.descendant(of: box, matching: find.text(t.ark_wallet.lightning_memo)), findsOneWidget);
    expect(find.descendant(of: box, matching: find.text('Please consider supporting this project')), findsOneWidget);
    await tester.tap(find.text(t.send).last);
    await settle(tester);
    expect(find.descendant(of: box, matching: find.text(t.ark_wallet.lightning_memo)), findsOneWidget);
  });

  testWidgets('the amount is typed in place, with the balance at the end of its label and no sending wallet card', (
    tester,
  ) async {
    await pump(tester, _ark);

    expect(find.byType(ArkMoveRoute), findsNothing);
    expect(find.byKey(const Key('ark-send-balance')), findsOneWidget);
    expect(find.textContaining(t.ark_wallet.available(amount: '').trim()), findsNothing);
    await tester.enterText(
      find.descendant(of: find.byKey(const Key('ark-move-amount')), matching: find.byType(EditableText)),
      '1000',
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final viewModel = Provider.of<ArkSendViewModel>(
      tester.element(find.byKey(const Key('ark-send-memo'))),
      listen: false,
    );
    expect(viewModel.amountSats, 1000);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('an invoice with its own amount shows it without an amount field', (tester) async {
    await pump(tester, _invoice);

    expect(find.byKey(const Key('ark-move-amount')), findsNothing);
    expect(find.byKey(const Key('ark-send-fixed-amount')), findsOneWidget);
  });

  testWidgets('an on-chain address shows why it cannot be sent', (tester) async {
    await pump(tester, 'bcrt1q7kcrvjzszlxme7fgs2euvv6lkgf99jdu8zjnus');

    expect(find.text(TextUtils.preventLineBreakInsideWords(t.ark_wallet.problem_onchain)), findsOneWidget);
  });

  testWidgets('the memo a request carries is filled in, shown on confirm and kept on the movement', (tester) async {
    await pump(tester, 'lightning:${_invoice.toUpperCase()}');
    await tester.enterText(
      find.descendant(of: find.byKey(const Key('ark-send-memo')), matching: find.byType(EditableText)),
      'Pizza',
    );
    await settle(tester);
    await tester.tap(find.text(t.next));
    await settle(tester);

    expect(find.text('Pizza'), findsOneWidget);
    await tester.tap(find.text(t.send).last);
    await settle(tester);

    final wallet = Provider.of<ArkWalletProvider>(tester.element(find.byType(ArkSendConfirmScreen)), listen: false);
    expect(wallet.memoOf(99), 'Pizza');
  });
}
