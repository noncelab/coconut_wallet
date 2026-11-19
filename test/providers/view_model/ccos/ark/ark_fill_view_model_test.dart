import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_wallet/ccos/features/ark/ark_board.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_fill_source.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_fill_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../ccos/features/ark/ark_test_fakes.dart';

class _Source implements ArkFillSource {
  int confirmed = 100000;
  int onchainFee = 300;
  bool passphrase = false;
  bool broadcastOk = true;
  final List<(String, int, bool)> signed = [];
  final List<String> broadcasted = [];
  final List<String> marked = [];

  @override
  int get confirmedSats => confirmed;

  @override
  bool get needsPassphrase => passphrase;

  @override
  Future<bool> validatePassphrase(Uint8List passphrase) async => utf8.decode(passphrase) == 'right';

  @override
  int? quoteFee(String address, int amountSats, double feeRate, {bool sweep = false}) {
    if (sweep) return amountSats > onchainFee ? onchainFee : null;
    return amountSats + onchainFee <= confirmed ? onchainFee : null;
  }

  @override
  Future<ArkSignedFunding> sign(
    String address,
    int amountSats,
    double feeRate, {
    bool sweep = false,
    Uint8List? passphrase,
  }) async {
    signed.add((address, amountSats, sweep));
    return const ArkSignedFunding(unsignedPsbt: 'psbt', signedTxHex: 'rawtx', txid: 'txid');
  }

  @override
  Future<bool> broadcast(ArkSignedFunding funding) async {
    broadcasted.add(funding.txid);
    return broadcastOk;
  }

  @override
  Future<void> markSpent(ArkSignedFunding funding) async => marked.add(funding.txid);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeArkBackend backend;
  late ArkWalletProvider wallet;
  late _Source source;
  late ArkFillViewModel viewModel;

  setUp(() async {
    backend = FakeArkBackend();
    wallet = await fakeArkWalletProvider(backend: backend);
    await wallet.restore(Uint8List.fromList(utf8.encode('${'abandon ' * 11}about')));
    source = _Source();
    viewModel = ArkFillViewModel(wallet, source, feeRate: () async => 2, estimateDelay: Duration.zero);
    await viewModel.ready;
  });

  tearDown(() => viewModel.dispose());

  test('an amount shows both fees, what arrives in Ark and the confirmations it waits for', () async {
    await viewModel.setAmount(10000);

    expect(viewModel.onchainFee, 300);
    expect(viewModel.boardFee, 100);
    expect(viewModel.arrivalSats, 9900);
    expect(viewModel.requiredConfirmations, 2);
    expect(viewModel.canFill, isTrue);
  });

  test('all of it takes the on-chain fee out of the amount', () async {
    await viewModel.setAmount(source.confirmed, isMax: true);

    expect(viewModel.arrivalSats, 100000 - 300 - 100);
  });

  test('too much or too little cannot be filled', () async {
    await viewModel.setAmount(100000);
    expect(viewModel.problem, ArkFillProblem.notEnough);

    await viewModel.setAmount(500);
    expect(viewModel.problem, ArkFillProblem.belowMinimum);

    final capBackend =
        FakeArkBackend()
          ..terms = const ArkBoardTerms(minAmountSats: 1000, maxAmountSats: 20000, requiredConfirmations: 2);
    final capWallet = await fakeArkWalletProvider(backend: capBackend);
    await capWallet.restore(Uint8List.fromList(utf8.encode('${'abandon ' * 11}about')));
    final capped = ArkFillViewModel(capWallet, source, feeRate: () async => 2, estimateDelay: Duration.zero);
    addTearDown(capped.dispose);
    await capped.ready;
    await capped.setAmount(30000);
    expect(capped.problem, ArkFillProblem.aboveMaximum);
  });

  test('filling signs, registers the board before broadcasting and marks the coins spent', () async {
    await viewModel.setAmount(10000);

    await viewModel.fill();

    expect(source.signed.single, ('bcrt1pboard1', 10000, false));
    expect(backend.boarded.single.$1, 'psbt');
    expect(source.broadcasted, ['txid']);
    expect(source.marked, ['txid']);
    expect(backend.broadcasted, isEmpty);
  });

  test('if the node cannot broadcast, bark does', () async {
    source.broadcastOk = false;
    await viewModel.setAmount(10000);

    await viewModel.fill();

    expect(backend.broadcasted, ['rawtx']);
  });
}
