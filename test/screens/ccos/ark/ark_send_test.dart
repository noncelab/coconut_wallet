import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_send_confirm_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_send_result_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_send_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../ccos/ccos_store_test_fakes.dart';
import '../../../ccos/features/ark/ark_test_fakes.dart';

const _invoice =
    'lnbcrt300u1p4dtlwusp5nptqcasatxvy082yctgkamwtewxfdnuh3eemk48utk2cp6zz9umspp50rc6tq4889yrpqt5tlmssthes5qxrfzh3qh93fqm8h00j3sav27sdqqxqy9gcqcqzgq9qyysgqcjnlnm5mwfsf09uvnjraxzwj04c2l9gtduntevk95pec3vvkglv9wqu57rnw3mz8t37add2fsrs44llju7ncaty67ay3d2x9kayxxcsqertrwr';

class _Auth extends Fake implements AuthProvider {
  @override
  bool get isAuthEnabled => false;
}

void main() {
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
    await tester.pumpAndSettle();

    expect(find.byType(ArkSendConfirmScreen), findsOneWidget);
    expect(find.text(t.ark_wallet.confirm_lightning), findsOneWidget);
    await tester.tap(find.text(t.send).last);
    await tester.pumpAndSettle();

    expect(backend.sent.single.$1, ArkPaymentRail.lightningInvoice);
    expect(find.byType(ArkSendResultScreen), findsOneWidget);
  });

  testWidgets('an on-chain address shows why it cannot be sent', (tester) async {
    await pump(tester, 'bcrt1q7kcrvjzszlxme7fgs2euvv6lkgf99jdu8zjnus');

    expect(find.text(t.ark_wallet.problem_onchain), findsOneWidget);
  });
}
