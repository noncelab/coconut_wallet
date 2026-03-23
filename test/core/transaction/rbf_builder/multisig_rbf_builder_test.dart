import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_builder.dart';
import 'package:coconut_wallet/extensions/transaction_extension.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/packages/bc-ur-dart/lib/utils.dart';
import 'package:coconut_wallet/utils/fee_rate_util.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../mock/wallet_mock.dart';
import 'setup_util.dart';

void main() {
  MultisigWalletListItem multiWallet = WalletMock.createMultiSigWalletItem();
  final creator = RbfBuilderCreator(multiWallet);
  group('멀티시그지갑 - getBaselineTransaction', () {
    test('External 1 / change enough', () async {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(false, 1000)],
        changeAmount: 98811,
        fee: 189,
        vSize: 189,
        additionalSpendable: [50000],
      );

      final RbfBuildResult result = rbfBuilder.getBaselineTransaction();

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.isOnlyChangeOutputUsed, isTrue);
      expect(result.isSelfOutputsUsed, isFalse);
      expect(result.addedInputs, isNull);
      expect(result.deficitAmount, isNull);
      expect(result.minimumFeeRate, equals(2.0));

      final tx = result.transaction!;
      final int totalInput = tx.totalInputAmount;
      final int totalOutput = tx.outputs.fold(0, (sum, out) => sum + out.amount);
      final int actualFee = totalInput - totalOutput;
      final double vByte = tx.estimateVirtualByteForWallet(multiWallet);
      final double calculatedFeeRate = FeeRateUtils.roundToTwoDecimals(actualFee / vByte);
      final int changeAmount = totalInput - 1000 - actualFee;

      expect(calculatedFeeRate, equals(2.0));
      expect(changeAmount, equals(98622)); // 98811 - 189
    });

    test('External 1 / change NotEnough / no additional UTXO', () async {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(false, 99890)],
        changeAmount: 0,
        fee: 110,
        vSize: 110,
      );

      final RbfBuildResult result = rbfBuilder.getBaselineTransaction();

      expect(result.isSuccess, isFalse);
      expect(result.transaction, isNull);
      expect(result.isOnlyChangeOutputUsed, isFalse);
      expect(result.isSelfOutputsUsed, isFalse);
      expect(result.addedInputs, isNull);
      expect(result.deficitAmount, isNotNull);
    });

    test('External 1 / change NotEnough / not enough additional UTXO', () async {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(false, 99890)],
        changeAmount: 0,
        fee: 110,
        vSize: 110,
        additionalSpendable: [100],
      );

      final RbfBuildResult result = rbfBuilder.getBaselineTransaction();

      expect(result.isSuccess, isFalse);
      expect(result.transaction, isNull);
      expect(result.isOnlyChangeOutputUsed, isFalse);
      expect(result.isSelfOutputsUsed, isFalse);
      expect(result.addedInputs!.length, equals(1));
      expect(result.deficitAmount, isNotNull);
    });

    test('External 1 / change NotEnough / enough additional UTXO', () async {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(false, 99890)],
        changeAmount: 0,
        fee: 110,
        vSize: 110,
        additionalSpendable: [1000, 1000, 1000],
      );

      final RbfBuildResult result = rbfBuilder.getBaselineTransaction();

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.isOnlyChangeOutputUsed, isFalse);
      expect(result.isSelfOutputsUsed, isFalse);
      expect(result.addedInputs!.length, equals(1));
      expect(result.deficitAmount, isNull);
      expect(result.minimumFeeRate, equals(1.43));
    });
  });

  group('멀티시그지갑 - changeAdditionalSpendable', () {
    test('External 1 / change NotEnough / not enough additional UTXO', () async {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(false, 99890)],
        changeAmount: 0,
        fee: 110,
        vSize: 110,
        additionalSpendable: [100],
      );

      final firstRbfResult = rbfBuilder.getBaselineTransaction();
      final newUtxo = UtxoState(
        transactionHash: creator.transactionHashes[0],
        index: 100,
        amount: 1000,
        blockHeight: 21000,
        to: creator.receiveAddressList[0],
        derivationPath: "${creator.derivationPathPrefix}/0",
        timestamp: DateTime.now(),
      );

      final RbfBuildResult changeResult = rbfBuilder.changeAdditionalSpendable([newUtxo]);
      expect(firstRbfResult.isFailure, isTrue);
      expect(changeResult.isSuccess, isTrue);
    });
  });

  group('멀티시그지갑 - build', () {
    test('External 1 / put low feeRate', () async {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(true, 5000)],
        changeAmount: 94859,
        fee: 141,
        vSize: 141,
      );
      final baselineResult = rbfBuilder.getBaselineTransaction();
      final buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate - 0.5);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));
      expect(buildResult.isSuccess, isTrue);
      // 적은 수수료율을 입력해서 트랜잭션 생성을 성공했지만 RBF 최소 조건을 충족하지 못해 보정된 결과가 반환됨
    });

    test('External 1 / change enough', () async {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(true, 5000)],
        changeAmount: 94859,
        fee: 141,
        vSize: 141,
      );
      final baselineResult = rbfBuilder.getBaselineTransaction();
      final buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(baselineResult.transaction, isNotNull);
      expect(buildResult.transaction, isNotNull);
      final baselineTxFee =
          baselineResult.transaction!.totalInputAmount -
          baselineResult.transaction!.outputs.fold(0, (s, o) => s + o.amount);
      final int pendingTxFee = pendingTx.fee;
      final double baselineVSize = baselineResult.transaction!.estimateVirtualByte(AddressType.p2wpkh);

      expect(
        FeeRateUtils.roundToTwoDecimals(baselineTxFee / baselineVSize),
        greaterThanOrEqualTo(FeeRateUtils.roundToTwoDecimals((pendingTxFee + baselineVSize) / baselineVSize)),
      );
    });

    test('External 1 / change NotEnough / enough additional UTXO', () async {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(false, 99890)],
        changeAmount: 0,
        fee: 110,
        vSize: 110,
        additionalSpendable: [1000],
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();
      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);
      expect(baselineResult.transaction, isNotNull);
      expect(buildResult.transaction, isNotNull);
      final baselineTxFee =
          baselineResult.transaction!.totalInputAmount -
          baselineResult.transaction!.outputs.fold(0, (s, o) => s + o.amount);
      final int pendingTxFee = pendingTx.fee;
      final double baselineVSize = baselineResult.transaction!.estimateVirtualByte(AddressType.p2wpkh);

      expect(
        FeeRateUtils.roundToTwoDecimals(baselineTxFee / baselineVSize), // 1.54
        greaterThanOrEqualTo(FeeRateUtils.roundToTwoDecimals((pendingTxFee + baselineVSize) / baselineVSize)), // 1.53
      );
    });
  });

  // group('멀티시그지갑 - InputSum enough', () {
  //   test('External 1 / InputSum enough', () async {
  //     final rbfBuilder = createRbfBuilder(
  //       inputAmounts: [100000],
  //       recipients: [Tuple(false, 1000)],
  //       changeAmount: 98811,
  //       fee: 189,
  //       vSize: 189,
  //       isMultiSig: true,
  //     );

  //     final RbfBuildResult result = await rbfBuilder.buildRbfTransaction(newFeeRate: 2.0, additionalSpendable: []);

  //     expect(result.isSuccess, isTrue);
  //     expect(result.transaction, isNotNull);
  //     expect(result.isOnlyChangeOutputUsed, isTrue);
  //     expect(result.isSelfOutputsUsed, isFalse);

  //     final tx = result.transaction!;
  //     final int totalInput = tx.totalInputAmount;
  //     final int totalOutput = tx.outputs.fold(0, (sum, out) => sum + out.amount);
  //     final int actualFee = totalInput - totalOutput;
  //     final double vByte =
  //         tx.estimateVirtualByte(AddressType.p2wsh, requiredSignature: 2, totalSigner: 3).ceil().toDouble();
  //     final double calculatedFeeRate = actualFee / vByte;
  //     final int expectedChange = totalInput - 1000 - actualFee;

  //     expect(rbfBuilder.nonChangeOutputs.length, 1);
  //     expect(rbfBuilder.nonChangeOutputsSum, 1000);
  //     expect(calculatedFeeRate, 2.0);
  //     expect(expectedChange, equals(98622));
  //   });
  //   test('External 3 / InputSum enough', () async {
  //     final rbfBuilder = createRbfBuilder(
  //       inputAmounts: [200000],
  //       recipients: [Tuple(false, 10000), Tuple(false, 20000), Tuple(false, 30000)],
  //       changeAmount: 139749,
  //       fee: 251,
  //       vSize: 251,
  //       isMultiSig: true,
  //     );

  //     final RbfBuildResult result = await rbfBuilder.buildRbfTransaction(newFeeRate: 3.0, additionalSpendable: []);

  //     expect(result.isSuccess, isTrue);
  //     expect(result.transaction, isNotNull);
  //     expect(result.isOnlyChangeOutputUsed, isTrue);

  //     final tx = result.transaction!;
  //     final int totalInput = tx.totalInputAmount;
  //     final int totalOutput = tx.outputs.fold(0, (sum, out) => sum + out.amount);
  //     final int actualFee = tx.totalInputAmount - totalOutput;
  //     final double vByte =
  //         tx.estimateVirtualByte(AddressType.p2wsh, requiredSignature: 2, totalSigner: 3).ceil().toDouble();
  //     final double calculatedFeeRate = actualFee / vByte;
  //     final int expectedChange = totalInput - 60000 - actualFee;

  //     expect(totalInput, 200000);
  //     expect(rbfBuilder.nonChangeOutputs.length, 3);
  //     expect(rbfBuilder.nonChangeOutputsSum, 60000);
  //     expect(calculatedFeeRate, 3.0);
  //     expect(expectedChange, equals(139247));
  //   });
  // });

  // group('멀티시그지갑 - InputSum not enough / selfOutput 사용', () {
  //   test('selfOutput 1 / no change / selfOutput 1개의 amount를 차감하여 성공🟢', () async {
  //     final rbfBuilder = createRbfBuilder(
  //       inputAmounts: [100000],
  //       recipients: [Tuple(true, 99000)],
  //       changeAmount: 0,
  //       fee: 1000,
  //       vSize: 1000,
  //       isMultiSig: true,
  //     );

  //     final RbfBuildResult result = await rbfBuilder.buildRbfTransaction(newFeeRate: 10.0, additionalSpendable: []);

  //     expect(result.isSuccess, isTrue);
  //     expect(result.transaction, isNotNull);
  //     expect(result.isSelfOutputsUsed, isTrue);
  //     expect(result.isOnlyChangeOutputUsed, isFalse);
  //     expect(result.addedUtxos, isNull);
  //     expect(result.deficitAmount, isNull);

  //     final tx = result.transaction!;
  //     final int totalInput = tx.totalInputAmount; // 100,000
  //     final int totalOutput = tx.outputs.fold(0, (sum, out) => sum + out.amount);
  //     final int actualFee = totalInput - totalOutput;
  //     final double vByte =
  //         tx.estimateVirtualByte(AddressType.p2wsh, requiredSignature: 2, totalSigner: 3).ceil().toDouble();
  //     final double calculatedFeeRate = actualFee / vByte;

  //     expect(tx.outputs.length, 1);
  //     expect(actualFee, 1580);
  //     expect(calculatedFeeRate, 10.0);
  //   });
  // });
}
