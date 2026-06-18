import 'package:coconut_wallet/core/exceptions/transaction_creation/transaction_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/utxo_selector.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/taproot_script_path_config.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<UtxoState> utxoList;

  // keypath 1개 + InheritancePolicy 1개 구조 지갑 기준
  const taprootConfig = TaprootScriptPathConfig(requiredSignature: 1, leafCount: 1, tapScriptSize: 41);

  setUpAll(() {
    utxoList = [
      UtxoState(
        transactionHash: '1',
        index: 0,
        amount: 100000,
        derivationPath: "m/86'/0'/0'/0/0",
        blockHeight: 0,
        to: 'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e',
        timestamp: DateTime.now(),
        status: UtxoStatus.unspent,
      ),
      UtxoState(
        transactionHash: '2',
        index: 0,
        amount: 50000,
        derivationPath: "m/86'/0'/0'/0/1",
        blockHeight: 0,
        to: 'bcrt1qwpkzfxqnenazz5vd5afnhsxhjqpa6zf4vp7kz3',
        timestamp: DateTime.now(),
        status: UtxoStatus.unspent,
      ),
      UtxoState(
        transactionHash: '3',
        index: 0,
        amount: 25000,
        derivationPath: "m/86'/0'/0'/0/2",
        blockHeight: 0,
        to: 'address3',
        timestamp: DateTime.now(),
        status: UtxoStatus.unspent,
      ),
    ];
  });

  // ─────────────────────────────────────────────────────────────
  // Group 1: only keyPathSeedInfos isNotEmpty → key path spending
  // ─────────────────────────────────────────────────────────────
  group('[UtxoSelector TaprootWallet - only keyPathSeedInfos]', () {
    test('should select optimal UTXOs for key path spending', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 60000};
      const feeRate = 1.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootSpendType: TaprootSpendType.keyPath,
      );

      expect(result.selectedUtxos.length, 1);
      expect(result.selectedUtxos.first.amount, 100000);
      print(result.estimatedFee);
    });

    test('should select multiple UTXOs when single UTXO is not enough', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 120000};
      const feeRate = 1.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootSpendType: TaprootSpendType.keyPath,
      );

      expect(result.selectedUtxos.length, 2);
      expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 150000);
      print(result.estimatedFee);
    });

    test('should throw exception when not enough funds (1)', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 1000000};
      const feeRate = 1.0;

      expect(
        () => UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootSpendType: TaprootSpendType.keyPath,
        ),
        throwsA(
          isA<InsufficientBalanceException>().having((e) => e.toString(), 'message', 'Not enough balance for sending.'),
        ),
      );
    });

    test('should throw exception when not enough funds (2)', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 175000};
      const feeRate = 1.0;

      expect(
        () => UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootSpendType: TaprootSpendType.keyPath,
        ),
        throwsA(
          isA<InsufficientBalanceException>().having((e) => e.toString(), 'message', 'Not enough balance for sending.'),
        ),
      );
    });
  });

  group('[UtxoSelector TaprootWallet - only keyPathSeedInfos] when isFeeSubtractedFromAmount is true', () {
    test('should handle fee subtracted from amount (1)', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 100000};
      const feeRate = 1.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootSpendType: TaprootSpendType.keyPath,
        isFeeSubtractedFromAmount: true,
      );

      expect(result.selectedUtxos.length, 1);
      expect(result.selectedUtxos.first.amount, 100000);
      print(result.estimatedFee);
    });

    test('should handle fee subtracted from amount (2)', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 175000};
      const feeRate = 1.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootSpendType: TaprootSpendType.keyPath,
        isFeeSubtractedFromAmount: true,
      );

      expect(result.selectedUtxos.length, 3);
      expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 175000);
      print(result.estimatedFee);
    });

    test('should handle fee subtracted from amount (3)', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 175000};
      const feeRate = 2.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootSpendType: TaprootSpendType.keyPath,
        isFeeSubtractedFromAmount: true,
      );

      expect(result.selectedUtxos.length, 3);
      expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 175000);
      print(result.estimatedFee);
    });

    test('should throw exception when last payment value is too small to cover fee (1)', () {
      final paymentMap = {
        'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 100000,
        'bcrt1qwpkzfxqnenazz5vd5afnhsxhjqpa6zf4vp7kz3': 300,
      };
      const feeRate = 1.0;

      expect(
        () => UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootSpendType: TaprootSpendType.keyPath,
          isFeeSubtractedFromAmount: true,
        ),
        throwsA(isA<SendAmountTooLowException>()),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Group 2: only scriptPathSeedInfos isNotEmpty → script path spending
  // ─────────────────────────────────────────────────────────────
  group('[UtxoSelector TaprootWallet - only scriptPathSeedInfos]', () {
    test('should select optimal UTXOs for script path spending', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 60000};
      const feeRate = 1.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootConfig: taprootConfig,
        taprootSpendType: TaprootSpendType.scriptPath,
      );

      expect(result.selectedUtxos.length, 1);
      expect(result.selectedUtxos.first.amount, 100000);
      print(result.estimatedFee);
    });

    test('should select multiple UTXOs when single UTXO is not enough', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 120000};
      const feeRate = 1.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootConfig: taprootConfig,
        taprootSpendType: TaprootSpendType.scriptPath,
      );

      expect(result.selectedUtxos.length, 2);
      expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 150000);
      print(result.estimatedFee);
    });

    test('should throw exception when not enough funds (1)', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 1000000};
      const feeRate = 1.0;

      expect(
        () => UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootConfig: taprootConfig,
          taprootSpendType: TaprootSpendType.scriptPath,
        ),
        throwsA(
          isA<InsufficientBalanceException>().having((e) => e.toString(), 'message', 'Not enough balance for sending.'),
        ),
      );
    });

    test('should throw exception when not enough funds (2)', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 175000};
      const feeRate = 1.0;

      expect(
        () => UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootConfig: taprootConfig,
          taprootSpendType: TaprootSpendType.scriptPath,
        ),
        throwsA(
          isA<InsufficientBalanceException>().having((e) => e.toString(), 'message', 'Not enough balance for sending.'),
        ),
      );
    });
  });

  group('[UtxoSelector TaprootWallet - only scriptPathSeedInfos] when isFeeSubtractedFromAmount is true', () {
    test('should handle fee subtracted from amount (1)', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 100000};
      const feeRate = 1.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootConfig: taprootConfig,
        taprootSpendType: TaprootSpendType.scriptPath,
        isFeeSubtractedFromAmount: true,
      );

      expect(result.selectedUtxos.length, 1);
      expect(result.selectedUtxos.first.amount, 100000);
      print(result.estimatedFee);
    });

    test('should handle fee subtracted from amount (2)', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 175000};
      const feeRate = 1.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootConfig: taprootConfig,
        taprootSpendType: TaprootSpendType.scriptPath,
        isFeeSubtractedFromAmount: true,
      );

      expect(result.selectedUtxos.length, 3);
      expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 175000);
      print(result.estimatedFee);
    });

    test('should handle fee subtracted from amount (3)', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 175000};
      const feeRate = 2.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootConfig: taprootConfig,
        taprootSpendType: TaprootSpendType.scriptPath,
        isFeeSubtractedFromAmount: true,
      );

      expect(result.selectedUtxos.length, 3);
      expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 175000);
      print(result.estimatedFee);
    });

    test('should throw exception when last payment value is too small to cover fee (1)', () {
      final paymentMap = {
        'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 100000,
        'bcrt1qwpkzfxqnenazz5vd5afnhsxhjqpa6zf4vp7kz3': 300,
      };
      const feeRate = 1.0;

      expect(
        () => UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootConfig: taprootConfig,
          taprootSpendType: TaprootSpendType.scriptPath,
          isFeeSubtractedFromAmount: true,
        ),
        throwsA(isA<SendAmountTooLowException>()),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────
  // Group 3: both keyPathSeedInfos and scriptPathSeedInfos isNotEmpty
  // ─────────────────────────────────────────────────────────────
  group('[UtxoSelector TaprootWallet - both keyPath and scriptPath seeds] key path spending', () {
    test('should select optimal UTXOs for key path spending', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 60000};
      const feeRate = 1.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootSpendType: TaprootSpendType.keyPath,
      );

      expect(result.selectedUtxos.length, 1);
      expect(result.selectedUtxos.first.amount, 100000);
      print(result.estimatedFee);
    });

    test('should select multiple UTXOs when single UTXO is not enough', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 120000};
      const feeRate = 1.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootSpendType: TaprootSpendType.keyPath,
      );

      expect(result.selectedUtxos.length, 2);
      expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 150000);
      print(result.estimatedFee);
    });

    test('should throw exception when not enough funds', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 175000};
      const feeRate = 1.0;

      expect(
        () => UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootSpendType: TaprootSpendType.keyPath,
        ),
        throwsA(isA<InsufficientBalanceException>()),
      );
    });
  });

  // ─────────────────────────────────────────────────────────────
  // keypath 2개, scriptpath 1개 지갑
  // Key path spending: MuSig으로 집계되어 최종 서명은 1개이므로
  // 코사이너 수가 달라도 fee는 keypath 1개 지갑과 동일.
  // ─────────────────────────────────────────────────────────────
  group('[UtxoSelector TaprootWallet(2-keyPath, 1-scriptPath) - only keyPathSeedInfos]', () {
    test('should select optimal UTXOs for key path spending', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 60000};
      const feeRate = 1.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootSpendType: TaprootSpendType.keyPath,
      );

      expect(result.selectedUtxos.length, 1);
      expect(result.selectedUtxos.first.amount, 100000);
    });

    test('should select multiple UTXOs when single UTXO is not enough', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 120000};
      const feeRate = 1.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootSpendType: TaprootSpendType.keyPath,
      );

      expect(result.selectedUtxos.length, 2);
      expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 150000);
    });

    test('should throw exception when not enough funds (1)', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 1000000};
      const feeRate = 1.0;

      expect(
        () => UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootSpendType: TaprootSpendType.keyPath,
        ),
        throwsA(
          isA<InsufficientBalanceException>().having((e) => e.toString(), 'message', 'Not enough balance for sending.'),
        ),
      );
    });

    test('should throw exception when not enough funds (2)', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 175000};
      const feeRate = 1.0;

      expect(
        () => UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootSpendType: TaprootSpendType.keyPath,
        ),
        throwsA(
          isA<InsufficientBalanceException>().having((e) => e.toString(), 'message', 'Not enough balance for sending.'),
        ),
      );
    });
  });

  group(
    '[UtxoSelector TaprootWallet(2-keyPath, 1-scriptPath) - only keyPathSeedInfos] when isFeeSubtractedFromAmount is true',
    () {
      test('should handle fee subtracted from amount (1)', () {
        final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 100000};
        const feeRate = 1.0;

        final result = UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootSpendType: TaprootSpendType.keyPath,
          isFeeSubtractedFromAmount: true,
        );

        expect(result.selectedUtxos.length, 1);
        expect(result.selectedUtxos.first.amount, 100000);
      });

      test('should handle fee subtracted from amount (2)', () {
        final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 175000};
        const feeRate = 1.0;

        final result = UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootSpendType: TaprootSpendType.keyPath,
          isFeeSubtractedFromAmount: true,
        );

        expect(result.selectedUtxos.length, 3);
        expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 175000);
      });

      test('should handle fee subtracted from amount (3)', () {
        final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 175000};
        const feeRate = 2.0;

        final result = UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootSpendType: TaprootSpendType.keyPath,
          isFeeSubtractedFromAmount: true,
        );

        expect(result.selectedUtxos.length, 3);
        expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 175000);
      });

      test('should throw exception when last payment value is too small to cover fee (1)', () {
        final paymentMap = {
          'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 100000,
          'bcrt1qwpkzfxqnenazz5vd5afnhsxhjqpa6zf4vp7kz3': 300,
        };
        const feeRate = 1.0;

        expect(
          () => UtxoSelector.selectOptimalUtxos(
            utxoList,
            paymentMap,
            feeRate,
            WalletType.taproot,
            taprootSpendType: TaprootSpendType.keyPath,
            isFeeSubtractedFromAmount: true,
          ),
          throwsA(isA<SendAmountTooLowException>()),
        );
      });
    },
  );

  group('[UtxoSelector TaprootWallet(2-keyPath, 1-scriptPath) - only scriptPathSeedInfos]', () {
    test('should select optimal UTXOs for script path spending', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 60000};
      const feeRate = 1.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootConfig: taprootConfig,
        taprootSpendType: TaprootSpendType.scriptPath,
      );

      expect(result.selectedUtxos.length, 1);
      expect(result.selectedUtxos.first.amount, 100000);
    });

    test('should select multiple UTXOs when single UTXO is not enough', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 120000};
      const feeRate = 1.0;

      final result = UtxoSelector.selectOptimalUtxos(
        utxoList,
        paymentMap,
        feeRate,
        WalletType.taproot,
        taprootConfig: taprootConfig,
        taprootSpendType: TaprootSpendType.scriptPath,
      );

      expect(result.selectedUtxos.length, 2);
      expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 150000);
    });

    test('should throw exception when not enough funds (1)', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 1000000};
      const feeRate = 1.0;

      expect(
        () => UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootConfig: taprootConfig,
          taprootSpendType: TaprootSpendType.scriptPath,
        ),
        throwsA(
          isA<InsufficientBalanceException>().having((e) => e.toString(), 'message', 'Not enough balance for sending.'),
        ),
      );
    });

    test('should throw exception when not enough funds (2)', () {
      final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 175000};
      const feeRate = 1.0;

      expect(
        () => UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootConfig: taprootConfig,
          taprootSpendType: TaprootSpendType.scriptPath,
        ),
        throwsA(
          isA<InsufficientBalanceException>().having((e) => e.toString(), 'message', 'Not enough balance for sending.'),
        ),
      );
    });
  });

  group(
    '[UtxoSelector TaprootWallet(2-keyPath, 1-scriptPath) - only scriptPathSeedInfos] when isFeeSubtractedFromAmount is true',
    () {
      test('should handle fee subtracted from amount (1)', () {
        final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 100000};
        const feeRate = 1.0;

        final result = UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootConfig: taprootConfig,
          taprootSpendType: TaprootSpendType.scriptPath,
          isFeeSubtractedFromAmount: true,
        );

        expect(result.selectedUtxos.length, 1);
        expect(result.selectedUtxos.first.amount, 100000);
      });

      test('should handle fee subtracted from amount (2)', () {
        final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 175000};
        const feeRate = 1.0;

        final result = UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootConfig: taprootConfig,
          taprootSpendType: TaprootSpendType.scriptPath,
          isFeeSubtractedFromAmount: true,
        );

        expect(result.selectedUtxos.length, 3);
        expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 175000);
      });

      test('should handle fee subtracted from amount (3)', () {
        final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 175000};
        const feeRate = 2.0;

        final result = UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootConfig: taprootConfig,
          taprootSpendType: TaprootSpendType.scriptPath,
          isFeeSubtractedFromAmount: true,
        );

        expect(result.selectedUtxos.length, 3);
        expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 175000);
      });

      test('should throw exception when last payment value is too small to cover fee (1)', () {
        final paymentMap = {
          'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 100000,
          'bcrt1qwpkzfxqnenazz5vd5afnhsxhjqpa6zf4vp7kz3': 300,
        };
        const feeRate = 1.0;

        expect(
          () => UtxoSelector.selectOptimalUtxos(
            utxoList,
            paymentMap,
            feeRate,
            WalletType.taproot,
            taprootConfig: taprootConfig,
            taprootSpendType: TaprootSpendType.scriptPath,
            isFeeSubtractedFromAmount: true,
          ),
          throwsA(isA<SendAmountTooLowException>()),
        );
      });
    },
  );

  group(
    '[UtxoSelector TaprootWallet(2-keyPath, 1-scriptPath) - both keyPath and scriptPath seeds] key path spending',
    () {
      test('should select optimal UTXOs for key path spending', () {
        final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 60000};
        const feeRate = 1.0;

        final result = UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootSpendType: TaprootSpendType.keyPath,
        );

        expect(result.selectedUtxos.length, 1);
        expect(result.selectedUtxos.first.amount, 100000);
      });

      test('should select multiple UTXOs when single UTXO is not enough', () {
        final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 120000};
        const feeRate = 1.0;

        final result = UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootSpendType: TaprootSpendType.keyPath,
        );

        expect(result.selectedUtxos.length, 2);
        expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 150000);
      });

      test('should throw exception when not enough funds', () {
        final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 175000};
        const feeRate = 1.0;

        expect(
          () => UtxoSelector.selectOptimalUtxos(
            utxoList,
            paymentMap,
            feeRate,
            WalletType.taproot,
            taprootSpendType: TaprootSpendType.keyPath,
          ),
          throwsA(isA<InsufficientBalanceException>()),
        );
      });
    },
  );

  group(
    '[UtxoSelector TaprootWallet(2-keyPath, 1-scriptPath) - both keyPath and scriptPath seeds] script path spending',
    () {
      test('should select optimal UTXOs for script path spending', () {
        final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 60000};
        const feeRate = 1.0;

        final result = UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootConfig: taprootConfig,
          taprootSpendType: TaprootSpendType.scriptPath,
        );

        expect(result.selectedUtxos.length, 1);
        expect(result.selectedUtxos.first.amount, 100000);
        print(result.estimatedFee);
      });

      test('should select multiple UTXOs when single UTXO is not enough', () {
        final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 120000};
        const feeRate = 1.0;

        final result = UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootConfig: taprootConfig,
          taprootSpendType: TaprootSpendType.scriptPath,
        );

        expect(result.selectedUtxos.length, 2);
        expect(result.selectedUtxos.map((u) => u.amount).reduce((a, b) => a + b), 150000);
        print(result.estimatedFee);
      });

      test('should throw exception when not enough funds', () {
        final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 175000};
        const feeRate = 1.0;

        expect(
          () => UtxoSelector.selectOptimalUtxos(
            utxoList,
            paymentMap,
            feeRate,
            WalletType.taproot,
            taprootConfig: taprootConfig,
            taprootSpendType: TaprootSpendType.scriptPath,
          ),
          throwsA(isA<InsufficientBalanceException>()),
        );
      });

      test('script path fee should be higher than key path fee for the same transaction', () {
        final paymentMap = {'bcrt1q6c8cqxwld4zazqntqnw88p0krqp48hk7ngzl9e': 60000};
        const feeRate = 1.0;

        final keyPathResult = UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootSpendType: TaprootSpendType.keyPath,
        );

        final scriptPathResult = UtxoSelector.selectOptimalUtxos(
          utxoList,
          paymentMap,
          feeRate,
          WalletType.taproot,
          taprootConfig: taprootConfig,
          taprootSpendType: TaprootSpendType.scriptPath,
        );

        print("${keyPathResult.estimatedFee} vs ${scriptPathResult.estimatedFee}");

        expect(scriptPathResult.estimatedFee, greaterThan(keyPathResult.estimatedFee));
      });
    },
  );
}
