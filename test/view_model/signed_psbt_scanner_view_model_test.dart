import 'dart:convert';
import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/bb_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/bc_ur_qr_scan_data_handler.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/send/air-gapped/signed_psbt_scanner_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestWallet extends WalletBase {
  final String? _changeAddress;

  _TestWallet({String? changeAddress}) : _changeAddress = changeAddress, super(AddressType.p2wpkh, "m/84'/1'/0'");

  @override
  String addSignatureToPsbt(String psbt) => throw UnimplementedError();

  @override
  String getAddress(int addressIndex, {bool isChange = false}) => throw UnimplementedError();

  @override
  String getAddressWithDerivationPath(String derivationPath) {
    final changeAddress = _changeAddress;
    if (changeAddress == null) throw UnimplementedError();
    return changeAddress;
  }

  @override
  String getKeyOriginExpression() => throw UnimplementedError();

  @override
  bool hasPublicKeyInPsbt(String psbt) => throw UnimplementedError();
}

class _TestWalletItem extends Fake implements WalletItemBase {
  @override
  final WalletBase walletBase;

  _TestWalletItem({String? changeAddress}) : walletBase = _TestWallet(changeAddress: changeAddress);
}

class _TestWalletProvider extends Fake implements WalletProvider {
  final WalletItemBase walletItem;

  _TestWalletProvider({String? changeAddress}) : walletItem = _TestWalletItem(changeAddress: changeAddress);

  @override
  WalletItemBase getWalletById(int id) => walletItem;
}

void main() {
  late Map<String, dynamic> bitboxFixture;
  late Map<String, dynamic> trezorFixture;
  late Map<String, dynamic> rawFixture;
  late Map<String, dynamic> passportCoreFixture;
  late Map<String, dynamic> seedSignerFixture;

  setUpAll(() {
    NetworkType.setNetworkType(NetworkType.regtest);
    bitboxFixture = _readFixture('bitbox02_usb');
    trezorFixture = _readFixture('trezor_usb');
    rawFixture = _readFixture('coldcard_raw');
    passportCoreFixture = _readFixture('passport_core_ur_crypto_psbt');
    seedSignerFixture = _readFixture('seedsigner_ur_crypto_psbt');
  });

  tearDownAll(() {
    NetworkType.setNetworkType(NetworkType.testnet);
  });

  late SendInfoProvider sendInfoProvider;
  late SignedPsbtScannerViewModel viewModel;

  setUp(() {
    sendInfoProvider =
        SendInfoProvider()
          ..setWalletId(1)
          ..setIsMultisig(false);
    viewModel = SignedPsbtScannerViewModel(sendInfoProvider, _TestWalletProvider());
  });

  void configureViewModelWithFixtureChangeOutputForWalletOwnershipTest(Map<String, dynamic> fixture) {
    final unsignedPsbt = Psbt.parse(fixture['unsignedPsbt'] as String);
    final changeOutput = unsignedPsbt.outputs.firstWhere(
      (output) => output.bip32Derivations.any((derivation) => derivation.path.split('/').reversed.skip(1).first == '1'),
    );
    viewModel = SignedPsbtScannerViewModel(
      sendInfoProvider,
      _TestWalletProvider(changeAddress: changeOutput.outAddress),
    );
    sendInfoProvider.setTxWaitingForSign(fixture['unsignedPsbt'] as String);
  }

  group('processUrSigningResult', () {
    test('accepts the captured Passport Prime UR crypto-psbt', () {
      final fixture = _readFixture('passport_prime_ur_crypto_psbt');
      configureViewModelWithFixtureChangeOutputForWalletOwnershipTest(fixture);
      final handler = BcUrQrScanDataHandler(expectedUrType: [UrType.cryptoPsbt, UrType.psbt]);

      for (final fragment in fixture['fragments'] as List<dynamic>) {
        expect(handler.joinData(fragment as String), isTrue);
      }

      expect(handler.isCompleted(), isTrue);

      final result = viewModel.processUrSigningResult(handler.result);

      expect(result.isSuccess, isTrue);
      expect(sendInfoProvider.signedResult, isNotNull);
    });

    test('accepts the captured Passport Core Testnet UR crypto-psbt', () {
      configureViewModelWithFixtureChangeOutputForWalletOwnershipTest(passportCoreFixture);
      final handler = BcUrQrScanDataHandler(expectedUrType: [UrType.cryptoPsbt, UrType.psbt]);

      for (final fragment in passportCoreFixture['fragments'] as List<dynamic>) {
        expect(handler.joinData(fragment as String), isTrue);
      }

      expect(handler.isCompleted(), isTrue);

      final result = viewModel.processUrSigningResult(handler.result);

      expect(result.isSuccess, isTrue);
      expect(sendInfoProvider.signedResult, isNotNull);
    });

    test('accepts the captured SeedSigner UR crypto-psbt', () {
      configureViewModelWithFixtureChangeOutputForWalletOwnershipTest(seedSignerFixture);
      final handler = BcUrQrScanDataHandler(expectedUrType: [UrType.cryptoPsbt, UrType.psbt]);

      for (final fragment in seedSignerFixture['fragments'] as List<dynamic>) {
        expect(handler.joinData(fragment as String), isTrue);
      }

      expect(handler.isCompleted(), isTrue);

      final result = viewModel.processUrSigningResult(handler.result);

      expect(result.isSuccess, isTrue);
      expect(sendInfoProvider.signedResult, isNotNull);
    });
  });

  group('processBbQrSigningResult', () {
    test('accepts a matching BitBox02 PSBT through the default check', () {
      configureViewModelWithFixtureChangeOutputForWalletOwnershipTest(bitboxFixture);

      final result = viewModel.processBbQrSigningResult(bitboxFixture['returnedPayload'] as String);

      expect(result.isSuccess, isTrue);
      expect(sendInfoProvider.signedResult, Psbt.parse(bitboxFixture['returnedPayload'] as String).serialize());
    });

    test('accepts a matching Trezor PSBT through the default check', () {
      configureViewModelWithFixtureChangeOutputForWalletOwnershipTest(trezorFixture);

      final result = viewModel.processBbQrSigningResult(trezorFixture['returnedPayload'] as String);

      expect(result.isSuccess, isTrue);
      expect(sendInfoProvider.signedResult, Psbt.parse(trezorFixture['returnedPayload'] as String).serialize());
    });

    test('accepts the captured Coldcard BBQR T transaction', () {
      final fixture = _readFixture('coldcard_bbqr_t');
      final expectedRawTransaction = fixture['expectedRawTransaction'] as String;
      sendInfoProvider.setTxWaitingForSign(fixture['unsignedPsbt'] as String);
      final handler = BbQrScanDataHandler();

      for (final fragment in fixture['fragments'] as List<dynamic>) {
        expect(handler.joinData(fragment as String), isTrue);
      }

      expect(handler.isCompleted(), isTrue);
      expect(handler.result, expectedRawTransaction);

      final result = viewModel.processBbQrSigningResult(handler.result);

      expect(result.isSuccess, isTrue);
      expect(sendInfoProvider.signedResult, expectedRawTransaction);
    });

    test('accepts a matching raw transaction and stores the original payload', () {
      final returnedPayload = rawFixture['returnedPayload'] as String;
      sendInfoProvider.setTxWaitingForSign(rawFixture['unsignedPsbt'] as String);

      final result = viewModel.processBbQrSigningResult(returnedPayload);

      expect(result.isSuccess, isTrue);
      expect(sendInfoProvider.signedResult, returnedPayload);
    });

    test('rejects a PSBT with changed intent without storing it', () {
      sendInfoProvider.setTxWaitingForSign(bitboxFixture['unsignedPsbt'] as String);

      final result = viewModel.processBbQrSigningResult(_psbtWithChangedOutputAmount(bitboxFixture));

      expect(result.error, SignedScanProcessingError.transactionIntentMismatch);
      expect(sendInfoProvider.signedResult, isNull);
    });

    test('rejects an invalid payload without storing it', () {
      sendInfoProvider.setTxWaitingForSign(bitboxFixture['unsignedPsbt'] as String);

      final result = viewModel.processBbQrSigningResult('not-a-signing-result');

      expect(result.error, SignedScanProcessingError.invalidPayload);
      expect(sendInfoProvider.signedResult, isNull);
    });
  });

  group('processRawSigningResult', () {
    test('accepts a matching raw transaction and stores it', () {
      final returnedPayload = rawFixture['returnedPayload'] as String;
      sendInfoProvider.setTxWaitingForSign(rawFixture['unsignedPsbt'] as String);

      final result = viewModel.processRawSigningResult(returnedPayload);

      expect(result.isSuccess, isTrue);
      expect(sendInfoProvider.signedResult, returnedPayload);
    });

    test('rejects a raw transaction with changed intent without storing it', () {
      sendInfoProvider.setTxWaitingForSign(rawFixture['unsignedPsbt'] as String);

      final result = viewModel.processRawSigningResult(_rawTransactionWithChangedOutputAmount(rawFixture));

      expect(result.error, SignedScanProcessingError.transactionIntentMismatch);
      expect(sendInfoProvider.signedResult, isNull);
    });

    test('rejects a PSBT payload without storing it', () {
      sendInfoProvider.setTxWaitingForSign(bitboxFixture['unsignedPsbt'] as String);

      final result = viewModel.processRawSigningResult(bitboxFixture['returnedPayload'] as String);

      expect(result.error, SignedScanProcessingError.invalidPayload);
      expect(sendInfoProvider.signedResult, isNull);
    });

    test('rejects an invalid payload without storing it', () {
      sendInfoProvider.setTxWaitingForSign(rawFixture['unsignedPsbt'] as String);

      final result = viewModel.processRawSigningResult('not-a-raw-transaction');

      expect(result.error, SignedScanProcessingError.invalidPayload);
      expect(sendInfoProvider.signedResult, isNull);
    });
  });
}

Map<String, dynamic> _readFixture(String name) {
  return jsonDecode(File('test/fixtures/signing/$name.json').readAsStringSync()) as Map<String, dynamic>;
}

String _psbtWithChangedOutputAmount(Map<String, dynamic> fixture) {
  final psbt = Psbt.parse(fixture['returnedPayload'] as String);
  final transaction = psbt.unsignedTransaction!;
  transaction.outputs.first.setAmount(transaction.outputs.first.amount + 1);
  psbt.psbtMap['global']['00'] = transaction.serialize();
  return psbt.serialize();
}

String _rawTransactionWithChangedOutputAmount(Map<String, dynamic> fixture) {
  final transaction = Transaction.parse(fixture['returnedPayload'] as String);
  transaction.outputs.first.setAmount(transaction.outputs.first.amount + 1);
  return transaction.serialize();
}
