import 'package:coconut_wallet/core/transaction/utxo_selector.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/wallet/multisig_config.dart';
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

      final selectedUtxos = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.singleSignature,
      );

      expect(selectedUtxos.length, 1);
      expect(selectedUtxos.first.amount, 100000);
    });

    test('should select multiple UTXOs when single UTXO is not enough', () {
      final paymentMap = {'address1': 120000}; // 0.0012 BTC
      final feeRate = 1.0;

      final selectedUtxos = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.singleSignature,
      );

      expect(selectedUtxos.length, 2);
      expect(selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 150000);
    });

    test('should throw exception when not enough funds (1)', () {
      final paymentMap = {'address1': 1000000}; // 0.01 BTC
      final feeRate = 1.0;

      expect(
        () => UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.singleSignature,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            'Exception: Not enough amount for sending.',
          ),
        ),
      );
    });

    test('should throw exception when not enough funds (2)', () {
      final paymentMap = {'address1': 175000};
      final feeRate = 1.0;

      expect(
        () => UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.singleSignature,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            'Exception: Not enough amount for sending.',
          ),
        ),
      );
    });
  });

  group('[UtxoSelector SingleSigWallet Test] when isFeeSubtractedFromAmount is true', () {
    test('should handle fee subtracted from amount (1)', () {
      final paymentMap = {'address1': 100000}; // 0.00095 BTC
      final feeRate = 1.0;

      final selectedUtxos = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.singleSignature,
        isFeeSubtractedFromAmount: true,
      );

      expect(selectedUtxos.length, 1);
      expect(selectedUtxos.first.amount, 100000);
    });

    test('should handle fee subtracted from amount (2)', () {
      final paymentMap = {'address1': 175000};
      final feeRate = 1.0;

      final selectedUtxos = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.singleSignature,
        isFeeSubtractedFromAmount: true,
      );

      expect(selectedUtxos.length, 3);
      expect(selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 175000);
    });

    test('should handle fee subtracted from amount (3)', () {
      final paymentMap = {'address1': 175000};
      final feeRate = 2.0;

      final selectedUtxos = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.singleSignature,
        isFeeSubtractedFromAmount: true,
      );

      expect(selectedUtxos.length, 3);
      expect(selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 175000);
    });

    test('should throw exception when last payment value is too small to cover fee (1)', () {
      final paymentMap = {'address1': 100000, 'address2': 500}; // 0.00095 BTC
      final feeRate = 1.0;

      // exception message check
      expect(
        () => UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.singleSignature,
          isFeeSubtractedFromAmount: true,
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            'Exception: Last output amount is too small to cover fee.',
          ),
        ),
      );
    });
  });
}
