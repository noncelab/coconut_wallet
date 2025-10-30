import 'package:coconut_wallet/core/exceptions/transaction_creation/transaction_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/utxo_selector.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<UtxoState> utxoList;

  setUpAll(() {
    utxoList = [
      UtxoState(
        transactionHash: '1',
        index: 0,
        amount: 100000,
        derivationPath: "m/84'/0'/0'/0/0",
        blockHeight: 0,
        to: 'address1',
        timestamp: DateTime.now(),
        status: UtxoStatus.unspent,
      ),
      UtxoState(
        transactionHash: '2',
        index: 0,
        amount: 50000,
        derivationPath: "m/84'/0'/0'/0/1",
        blockHeight: 0,
        to: 'address2',
        timestamp: DateTime.now(),
        status: UtxoStatus.unspent,
      ),
      UtxoState(
        transactionHash: '3',
        index: 0,
        amount: 25000, // 0.00025 BTC
        derivationPath: "m/84'/0'/0'/0/2",
        blockHeight: 0,
        to: 'address3',
        timestamp: DateTime.now(),
        status: UtxoStatus.unspent,
      ),
    ];
  });

  group('[UtxoSelector SingleSigWallet Test]', () {
    test('should select optimal UTXOs for single signature wallet', () {
      final paymentMap = {'address1': 60000}; // 0.0006 BTC
      final feeRate = 1.0; // 1 sat/vB

      final result = UtxoSelector.selectOptimalUtxos(utxoList, paymentMap, feeRate, WalletType.singleSignature);

      expect(result.selectedUtxos.length, 1);
      expect(result.selectedUtxos.first.amount, 100000);
    });

    test('should select multiple UTXOs when single UTXO is not enough', () {
      final paymentMap = {'address1': 120000}; // 0.0012 BTC
      final feeRate = 1.0;

      final result = UtxoSelector.selectOptimalUtxos(utxoList, paymentMap, feeRate, WalletType.singleSignature);

      expect(result.selectedUtxos.length, 2);
      expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 150000);
    });

    test('should throw exception when not enough funds (1)', () {
      final paymentMap = {'address1': 1000000}; // 0.01 BTC
      const feeRate = 1.0;

      expect(
        () => UtxoSelector.selectOptimalUtxos(utxoList, paymentMap, feeRate, WalletType.singleSignature),
        throwsA(
          isA<InsufficientBalanceException>().having((e) => e.toString(), 'message', 'Not enough balance for sending.'),
        ),
      );
    });

    test('should throw exception when not enough funds (2)', () {
      final paymentMap = {'address1': 175000};
      const feeRate = 1.0;

      expect(
        () => UtxoSelector.selectOptimalUtxos(utxoList, paymentMap, feeRate, WalletType.singleSignature),
        throwsA(
          isA<InsufficientBalanceException>().having((e) => e.toString(), 'message', 'Not enough balance for sending.'),
        ),
      );
    });
  });

  group('[UtxoSelector SingleSigWallet Test] when isFeeSubtractedFromAmount is true', () {
    test('should handle fee subtracted from amount (1)', () {
      final paymentMap = {'address1': 100000}; // 0.00095 BTC
      final feeRate = 1.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.singleSignature,
        isFeeSubtractedFromAmount: true,
      );

      expect(result.selectedUtxos.length, 1);
      expect(result.selectedUtxos.first.amount, 100000);
    });

    test('should handle fee subtracted from amount (2)', () {
      final paymentMap = {'address1': 175000};
      final feeRate = 1.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.singleSignature,
        isFeeSubtractedFromAmount: true,
      );

      expect(result.selectedUtxos.length, 3);
      expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 175000);
    });

    test('should handle fee subtracted from amount (3)', () {
      final paymentMap = {'address1': 175000};
      final feeRate = 2.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.singleSignature,
        isFeeSubtractedFromAmount: true,
      );

      expect(result.selectedUtxos.length, 3);
      expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 175000);
    });

    test('should throw exception when last payment value is too small to cover fee (1)', () {
      final paymentMap = {'address1': 100000, 'address2': 300}; // 0.00095 BTC
      const feeRate = 1.0;

      expect(
        () => UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.singleSignature,
          isFeeSubtractedFromAmount: true,
        ),
        throwsA(isA<SendAmountTooLowException>()),
      );
    });
  });
}
