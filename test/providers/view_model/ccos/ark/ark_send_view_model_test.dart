import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_payment_request.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_send_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../ccos/features/ark/ark_test_fakes.dart';

const _ark =
    'tark1pqma5v23zqqp5z47f6anpx0lp5vu757p3cnxzqx887t8zl3wacuvdgyeyee2puh3zqypf2680f7z8zau5ukptjaa7suxu0vadk0ncdyw4qdeazs9u29fddycffu4m9';
const _described =
    'lnbc1pvjluezsp5zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygspp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdpl2pkx2ctnv5sxxmmwwd5kgetjypeh2ursdae8g6twvus8g6rfwvs8qun0dfjkxaq9qrsgq357wnc5r2ueh7ck6q93dj32dlqnls087fxdwk8qakdyafkq3yap9us6v52vjjsrvywa6rt52cm9r9zqt8r2t7mlcwspyetp5h2tztugp9lfyql';
const _invoice =
    'lnbcrt300u1p4dtlwusp5nptqcasatxvy082yctgkamwtewxfdnuh3eemk48utk2cp6zz9umspp50rc6tq4889yrpqt5tlmssthes5qxrfzh3qh93fqm8h00j3sav27sdqqxqy9gcqcqzgq9qyysgqcjnlnm5mwfsf09uvnjraxzwj04c2l9gtduntevk95pec3vvkglv9wqu57rnw3mz8t37add2fsrs44llju7ncaty67ay3d2x9kayxxcsqertrwr';

ArkBalance _spendable(int sats) => ArkBalance(
  spendable: sats,
  pendingInRound: 0,
  pendingBoard: 0,
  pendingExit: 0,
  pendingLightningSend: 0,
  claimableLightningReceive: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeArkBackend backend;
  late ArkWalletProvider wallet;
  late ArkSendViewModel viewModel;

  setUpAll(() => NetworkType.setNetworkType(NetworkType.regtest));

  setUp(() async {
    backend = FakeArkBackend()..currentBalance = _spendable(50000);
    wallet = await fakeArkWalletProvider(backend: backend);
    await wallet.restore(
      Uint8List.fromList(
        'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about'.codeUnits,
      ),
    );
    viewModel = ArkSendViewModel(wallet, network: NetworkType.regtest, feeDelay: Duration.zero);
  });

  tearDown(() => viewModel.dispose());

  test('an Ark address needs an amount, then estimates the fee', () async {
    viewModel.setInput(_ark);
    expect(viewModel.rail, ArkPaymentRail.ark);
    expect(viewModel.needsAmount, isTrue);
    expect(viewModel.canContinue, isFalse);

    backend.sendFee = 0;
    await viewModel.setAmount(1000);

    expect(viewModel.fee, 0);
    expect(viewModel.canContinue, isTrue);
    expect(viewModel.total, 1000);
  });

  test('an invoice brings its own amount', () async {
    viewModel.setInput(_invoice);
    await Future<void>.delayed(Duration.zero);

    expect(viewModel.rail, ArkPaymentRail.lightningInvoice);
    expect(viewModel.needsAmount, isFalse);
    expect(viewModel.amountSats, 30000);
  });

  test('more than the balance cannot continue', () async {
    viewModel.setInput(_ark);
    await viewModel.setAmount(60000);

    expect(viewModel.problem, ArkSendProblem.notEnoughBalance);
    expect(viewModel.canContinue, isFalse);
  });

  test('an on-chain address alone is refused for now', () {
    viewModel.setInput('bcrt1q7kcrvjzszlxme7fgs2euvv6lkgf99jdu8zjnus');

    expect(viewModel.problem, ArkSendProblem.onchainNotYet);
    expect(viewModel.canContinue, isFalse);
  });

  test('sending passes the destination and amount', () async {
    viewModel.setInput(_ark);
    await viewModel.setAmount(1000);

    final result = await viewModel.send();

    expect(result.outcome, ArkSendOutcome.sent);
    expect(backend.sent.single, (ArkPaymentRail.ark, _ark, 1000));
  });

  group('memo', () {
    test('starts with the memo the request carries and resets with a new request', () {
      viewModel.setInput('bitcoin:?ark=$_ark&message=Lunch');
      expect(viewModel.memo, 'Lunch');

      viewModel.setMemo('Lunch with Mina');
      expect(viewModel.memo, 'Lunch with Mina');

      viewModel.setInput(_ark);
      expect(viewModel.memo, '');
    });

    test('an invoice description is the Lightning memo, not my own memo', () {
      final mainnet = ArkSendViewModel(wallet, network: NetworkType.mainnet, feeDelay: Duration.zero)
        ..setInput(_described);
      addTearDown(mainnet.dispose);

      expect(mainnet.lightningMemo, 'Please consider supporting this project');
      expect(mainnet.memo, '');
    });

    test('is saved on the movement the send made', () async {
      viewModel.setInput(_ark);
      await viewModel.setAmount(1000);
      viewModel.setMemo('Rent');

      final result = await viewModel.send();

      expect(wallet.memoOf(result.movementId!), 'Rent');
    });
  });
}
