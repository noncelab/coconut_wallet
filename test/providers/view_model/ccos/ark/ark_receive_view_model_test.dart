import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_receive_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../ccos/features/ark/ark_test_fakes.dart';

ArkMovement _paid(String hash, int sats) => ArkMovement.fromBark(
  bark.Movement(
    id: 7,
    status: 'successful',
    subsystemName: 'bark.lightning_receive',
    subsystemKind: 'receive',
    metadataJson: '{}',
    intendedBalanceSats: sats,
    effectiveBalanceSats: sats,
    offchainFeeSats: 0,
    sentToAddresses: const [],
    receivedOnAddresses: const [],
    inputVtxoIds: const [],
    outputVtxoIds: const [],
    exitedVtxoIds: const [],
    createdAt: '2026-11-18T10:00:00Z',
    updatedAt: '2026-11-18T10:00:00Z',
    paymentHash: hash,
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeArkBackend backend;
  late ArkWalletProvider wallet;
  late ArkReceiveViewModel viewModel;

  setUp(() async {
    backend = FakeArkBackend();
    wallet = await fakeArkWalletProvider(backend: backend);
    await wallet.createNew();
    await wallet.syncNow();
    viewModel = ArkReceiveViewModel(wallet);
  });

  tearDown(() => viewModel.dispose());

  test('without an amount it shows the Ark address', () {
    expect(viewModel.format, ArkReceiveFormat.arkAddress);
    expect(viewModel.qrData, backend.address);
    expect(viewModel.availableFormats, [ArkReceiveFormat.arkAddress]);
  });

  test('an amount makes an invoice and shows the payment request', () async {
    await viewModel.setAmount(2100);

    expect(backend.invoiceAmounts, [2100]);
    expect(viewModel.format, ArkReceiveFormat.paymentRequest);
    expect(viewModel.qrData, startsWith('bitcoin:?ark=${backend.address}&lightning='));
    expect(viewModel.qrData, contains('amount=0.000021'));
    expect(viewModel.availableFormats, [
      ArkReceiveFormat.paymentRequest,
      ArkReceiveFormat.lightningInvoice,
      ArkReceiveFormat.arkAddress,
    ]);

    viewModel.select(ArkReceiveFormat.lightningInvoice);
    expect(viewModel.qrData, 'lightning:${viewModel.invoice!.invoice}'.toUpperCase());
  });

  test('a paid invoice resets the amount', () async {
    await viewModel.setAmount(2100);

    backend.movements = [_paid(viewModel.invoice!.paymentHash, 2100)];
    await wallet.syncNow();
    await wallet.syncNow();

    expect(viewModel.amountSats, isNull);
    expect(viewModel.format, ArkReceiveFormat.arkAddress);
  });

  test('clearing the amount goes back to the Ark address, still waiting for the invoice already shown', () async {
    await viewModel.setAmount(2100);
    await viewModel.setAmount(null);

    expect(viewModel.invoice, isNull);
    expect(viewModel.format, ArkReceiveFormat.arkAddress);
    expect(wallet.syncInterval, const Duration(seconds: 3));
  });

  test('a Lightning memo goes into the invoice for the payer to see', () async {
    await viewModel.setAmount(2100, memo: ' Coffee ');
    expect(backend.invoiceDescriptions.last, 'Coffee');
    expect(viewModel.invoiceMemo, 'Coffee');

    await viewModel.setAmount(2100, memo: '');
    expect(backend.invoiceDescriptions.last, isNull);
  });
}
