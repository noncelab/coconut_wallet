import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_export_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../ccos/features/ark/ark_test_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeArkBackend backend;
  late ArkWalletProvider wallet;
  late ArkExportViewModel viewModel;

  setUp(() async {
    backend =
        FakeArkBackend()
          ..currentBalance = const ArkBalance(
            spendable: 20000,
            pendingInRound: 0,
            pendingBoard: 0,
            pendingExit: 0,
            pendingLightningSend: 0,
            claimableLightningReceive: 0,
          );
    wallet = await fakeArkWalletProvider(backend: backend);
    await wallet.restore(Uint8List.fromList(utf8.encode('${'abandon ' * 11}about')));
    viewModel = ArkExportViewModel(wallet, address: 'bcrt1qmine', dustThreshold: 294, estimateDelay: Duration.zero);
  });

  tearDown(() => viewModel.dispose());

  test('an amount adds the server fee on top and arrives whole', () async {
    await viewModel.setAmount(5000);

    expect(viewModel.fee, 50);
    expect(viewModel.arrivalSats, 5000);
    expect(viewModel.spendSats, 5050);
    expect(viewModel.canExport, isTrue);
  });

  test('changing where it goes keeps the amount, estimates again and exports there', () async {
    await viewModel.setAmount(5000);

    await viewModel.setDestination('bcrt1qother', dustThreshold: 546);

    expect(viewModel.address, 'bcrt1qother');
    expect(viewModel.amountSats, 5000);
    expect(viewModel.arrivalSats, 5000);
    await viewModel.export();
    expect(backend.exported.single.$1, 'bcrt1qother');
  });

  test('without a destination yet nothing can be exported', () async {
    final noDestination = ArkExportViewModel(wallet, address: null, dustThreshold: 546, estimateDelay: Duration.zero);
    addTearDown(noDestination.dispose);

    await noDestination.setAmount(5000);

    expect(noDestination.fee, isNull);
    expect(noDestination.canExport, isFalse);
  });

  test('all of it takes the fee out of what arrives', () async {
    await viewModel.setAmount(20000, isMax: true);

    expect(viewModel.arrivalSats, 19950);
    expect(viewModel.spendSats, 20000);
  });

  test(
    'more than the balance with the fee, a fee over the whole balance, or dust cannot be exported, keeping the fee to show why',
    () async {
      await viewModel.setAmount(19990);
      expect(viewModel.problem, ArkExportProblem.overBalance);
      expect(viewModel.fee, 50);

      await viewModel.setAmount(30, isMax: true);
      expect(viewModel.problem, ArkExportProblem.feeOverBalance);
      expect(viewModel.fee, 50);

      await viewModel.setAmount(200);
      expect(viewModel.problem, ArkExportProblem.belowDust);
    },
  );

  test('exporting sends the amount, or everything, to the chosen wallet', () async {
    await viewModel.setAmount(5000);
    expect(await viewModel.export(), 'txid-export');

    await viewModel.setAmount(20000, isMax: true);
    await viewModel.export();

    expect(backend.exported, [('bcrt1qmine', 5000), ('bcrt1qmine', null)]);
  });
}
