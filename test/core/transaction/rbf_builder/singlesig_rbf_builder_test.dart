import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/exceptions/rbf_creation/rbf_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_builder.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_preparer.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/packages/bc-ur-dart/lib/utils.dart';
import 'package:coconut_wallet/utils/fee_rate_util.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../mock/transaction_record_mock.dart';
import '../../../mock/wallet_mock.dart';
import 'setup_util.dart';

void main() {
  SinglesigWalletListItem singleWallet = WalletMock.createSingleSigWalletItem();

  final creator = RbfBuilderCreator(singleWallet);
  group('변수 생성 테스트', () {
    test('External 1 / 모든 getter들 정합성 확인', () {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(false, 1000)],
        changeAmount: 98859,
        fee: 141,
        vSize: 141,
      );

      expect(rbfBuilder.nonChangeOutputs.length, 1);
      expect(rbfBuilder.nonChangeOutputsSum, 1000);
      expect(rbfBuilder.recipientMap.length, 1);
      expect(rbfBuilder.recipientMap[creator.externalWalletAddressList[0]], 1000);
      expect(rbfBuilder.externalOutputs, isNotNull);
      expect(rbfBuilder.externalOutputs!.length, 1);
      expect(rbfBuilder.externalOutputs![0].address, creator.externalWalletAddressList[0]);
      expect(rbfBuilder.externalOutputs![0].amount, 1000);
      expect(rbfBuilder.selfOutputs, isNull);
      expect(rbfBuilder.changeOutput, isNotNull);
      expect(rbfBuilder.changeOutput!.address, creator.changeAddressList[0]);
      expect(rbfBuilder.changeOutput!.amount, 98859);
      expect(rbfBuilder.changeOutputDerivationPath, isNotNull);
      expect(rbfBuilder.changeOutputDerivationPath, "m/84'/1'/0'/1/0");
      expect(rbfBuilder.inputSum, 100000);
    });

    test('selfOutputs 1 / 모든 getter들 정합성 확인', () {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(true, 5000)],
        changeAmount: 94859,
        fee: 141,
        vSize: 141,
      );

      expect(rbfBuilder.nonChangeOutputs.length, 1);
      expect(rbfBuilder.nonChangeOutputsSum, 5000);
      expect(rbfBuilder.recipientMap.length, 1);
      expect(rbfBuilder.recipientMap[creator.receiveAddressList[1]], 5000);
      expect(rbfBuilder.externalOutputs, isNull);
      expect(rbfBuilder.selfOutputs, isNotNull);
      expect(rbfBuilder.selfOutputs!.length, 1);
      expect(rbfBuilder.selfOutputs![0].address, creator.receiveAddressList[1]);
      expect(rbfBuilder.selfOutputs![0].amount, 5000);
      expect(rbfBuilder.changeOutput, isNotNull);
      expect(rbfBuilder.changeOutput!.address, creator.changeAddressList[0]);
      expect(rbfBuilder.changeOutput!.amount, 94859);
      expect(rbfBuilder.inputSum, 100000);
    });

    test('External 1 / selfOutputs 2 / 모든 getter들 정합성 확인', () {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [200000],
        recipients: [Tuple(false, 1000), Tuple(true, 2000), Tuple(true, 3000)],
        changeAmount: 193859,
        fee: 141,
        vSize: 141,
      );

      expect(rbfBuilder.nonChangeOutputs.length, 3);
      expect(rbfBuilder.nonChangeOutputsSum, 6000);
      expect(rbfBuilder.recipientMap.length, 3);
      expect(rbfBuilder.recipientMap[creator.externalWalletAddressList[0]], 1000);
      expect(rbfBuilder.recipientMap[creator.receiveAddressList[1]], 2000);
      expect(rbfBuilder.recipientMap[creator.receiveAddressList[2]], 3000);
      expect(rbfBuilder.externalOutputs, isNotNull);
      expect(rbfBuilder.externalOutputs!.length, 1);
      expect(rbfBuilder.externalOutputs![0].address, creator.externalWalletAddressList[0]);
      expect(rbfBuilder.externalOutputs![0].amount, 1000);
      expect(rbfBuilder.selfOutputs, isNotNull);
      expect(rbfBuilder.selfOutputs!.length, 2);
      expect(rbfBuilder.selfOutputs!.any((e) => e.address == creator.receiveAddressList[1]), isTrue);
      expect(rbfBuilder.selfOutputs!.any((e) => e.address == creator.receiveAddressList[2]), isTrue);
      expect(rbfBuilder.selfOutputs![0].amount + rbfBuilder.selfOutputs![1].amount, 5000);
      expect(rbfBuilder.changeOutput, isNotNull);
      expect(rbfBuilder.changeOutput!.address, creator.changeAddressList[0]);
      expect(rbfBuilder.changeOutput!.amount, 193859);
      expect(rbfBuilder.inputSum, 200000);
    });
    // test('Invalid getDerivationPath 함수 전달 시 InvalidChangeOutputException 발생', () {
    //   final List<TransactionAddress> inputAddressList = [TransactionAddress(creator.receiveAddressList[0], 100000)];
    //   final List<TransactionAddress> outputAddressList = [
    //     TransactionAddress(creator.externalWalletAddressList[0], 1000),
    //     TransactionAddress(creator.changeAddressList[0], 98859),
    //   ];
    //   final TransactionRecord pendingTx = TransactionRecordMock.createMockTransactionRecord(
    //     inputAddressList: inputAddressList,
    //     outputAddressList: outputAddressList,
    //     amount: 1000,
    //   );

    //   expect(
    //     () {
    //       return RbfPreparer.fromPendingTx(
    //         pendingTx: pendingTx,
    //         rawTx: '', // Mock raw transaction
    //         getUtxos: (utxoId) => null, // Mock getUtxos that returns null
    //         isMyAddress: creator.isMyAddress,
    //         getDerivationPath: (address) => '', // Invalid empty derivation path
    //       );
    //     },
    //     throwsA(isA<InvalidChangeOutputException>()),
    //   );
    // });
  });

  group('싱글시그지갑 - getBaselineTransaction', () {
    test('External 1 / change enough', () async {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(false, 1000)],
        changeAmount: 98859,
        fee: 141,
        vSize: 141,
        additionalSpendable: [50000],
      );

      final RbfBuildResult result = rbfBuilder.getBaselineTransaction();

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.isOnlyChangeOutputUsed, isTrue);
      expect(result.isSelfOutputsUsed, isFalse);
      expect(result.addedUtxos, isNull);
      expect(result.deficitAmount, isNull);
      expect(result.minimumFeeRate, equals(2.01));

      final tx = result.transaction!;
      final int totalInput = tx.totalInputAmount;
      final int totalOutput = tx.outputs.fold(0, (sum, out) => sum + out.amount);
      final int actualFee = totalInput - totalOutput;
      final double vByte = tx.estimateVirtualByte(AddressType.p2wpkh).ceil().toDouble();
      final double calculatedFeeRate = actualFee / vByte;
      final int changeAmount = totalInput - 1000 - actualFee;

      expect(calculatedFeeRate, equals(2.0));
      expect(changeAmount, equals(98718)); // 98859 - 141
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
      expect(result.addedUtxos, isNull);
      expect(result.deficitAmount, 141 + 68);
      expect(result.minimumFeeRate, equals(1.53)); // (110 + 141 + 68) / 209 = 319 / 209
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
      expect(result.addedUtxos!.length, equals(1));
      expect(result.deficitAmount, 141 + 68 + 68 - 100);
      expect(result.minimumFeeRate, equals(1.4));
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
      expect(result.addedUtxos!.length, equals(1));
      expect(result.deficitAmount, isNull);
      expect(result.minimumFeeRate, equals(1.54));
    });
  });

  group('싱글시그지갑 - changeAdditionalSpendable', () {
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
        derivationPath: "m/84'/1'/0'/0/0",
        timestamp: DateTime.now(),
      );

      final RbfBuildResult changeResult = rbfBuilder.changeAdditionalSpendable([newUtxo]);
      expect(firstRbfResult.isFailure, isTrue);
      expect(changeResult.isSuccess, isTrue);
    });
  });

  group('싱글시그지갑 - build', () {
    test('External 1 / feeRate too low', () async {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(true, 5000)],
        changeAmount: 94859,
        fee: 141,
        vSize: 141,
      );
      final baselineResult = rbfBuilder.getBaselineTransaction();
      final buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate - 0.01);

      expect(buildResult.exception, isNotNull);
      expect(buildResult.exception, isA<FeeRateTooLowException>());
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
        FeeRateUtils.ceilFeeRate(baselineTxFee / baselineVSize),
        equals(FeeRateUtils.ceilFeeRate((pendingTxFee + baselineVSize) / baselineVSize)),
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
        FeeRateUtils.ceilFeeRate(baselineTxFee / baselineVSize), // 1.54
        greaterThanOrEqualTo(FeeRateUtils.ceilFeeRate((pendingTxFee + baselineVSize) / baselineVSize)), // 1.53
      );
    });
  });
  // group('싱글시그지갑 - InputSum enough', () {
  //   test('External 1 / change / InputSum enough', () async {
  //     final rbfBuilder = createRbfBuilder(
  //       inputAmounts: [100000],
  //       recipients: [Tuple(false, 1000)],
  //       changeAmount: 98859,
  //       fee: 141,
  //       vSize: 141,
  //       isMultiSig: false,
  //     );

  //     final RbfBuildResult result = await rbfBuilder.buildRbfTransaction(newFeeRate: 2.0, additionalSpendable: []);

  //     expect(result.isSuccess, isTrue);
  //     expect(result.transaction, isNotNull);
  //     expect(result.isOnlyChangeOutputUsed, isTrue);
  //     expect(result.isSelfOutputsUsed, isFalse);
  //     expect(result.addedUtxos, isNull);
  //     expect(result.deficitAmount, isNull);

  //     final tx = result.transaction!;
  //     final int totalInput = tx.totalInputAmount;
  //     final int totalOutput = tx.outputs.fold(0, (sum, out) => sum + out.amount);
  //     final int actualFee = totalInput - totalOutput;
  //     final double vByte = tx.estimateVirtualByte(AddressType.p2wpkh).ceil().toDouble();
  //     final double calculatedFeeRate = actualFee / vByte;
  //     final int changeAmount = totalInput - 1000 - actualFee;

  //     expect(calculatedFeeRate, 2.0);
  //     expect(changeAmount, equals(98718)); // 98859 - 141
  //   });

  //   test('External 3 / InputSum enough', () async {
  //     final rbfBuilder = createRbfBuilder(
  //       inputAmounts: [200000],
  //       recipients: [Tuple(false, 10000), Tuple(false, 20000), Tuple(false, 30000)],
  //       changeAmount: 139859,
  //       fee: 141,
  //       vSize: 141,
  //       isMultiSig: false,
  //     );

  //     final RbfBuildResult result = await rbfBuilder.buildRbfTransaction(newFeeRate: 3.0, additionalSpendable: []);

  //     expect(result.isSuccess, isTrue);
  //     expect(result.transaction, isNotNull);
  //     expect(result.isOnlyChangeOutputUsed, isTrue);
  //     expect(result.isSelfOutputsUsed, isFalse);
  //     expect(result.addedUtxos, isNull);
  //     expect(result.deficitAmount, isNull);
  //     expect(rbfBuilder.nonChangeOutputs.length, 3);
  //     expect(rbfBuilder.nonChangeOutputsSum, 60000);

  //     final tx = result.transaction!;
  //     final int totalInput = tx.totalInputAmount;
  //     final int totalOutput = tx.outputs.fold(0, (sum, out) => sum + out.amount);
  //     final int actualFee = totalInput - totalOutput;
  //     final double vByte = tx.estimateVirtualByte(AddressType.p2wpkh).ceil().toDouble();
  //     final double calculatedFeeRate = actualFee / vByte;
  //     final int changeAmount = totalInput - 60000 - actualFee;

  //     expect(calculatedFeeRate, 3.0);
  //     expect(changeAmount, equals(139391));
  //   });

  //   // TODO: sweep tx 테스트 코드
  //   // TODO: batch sweep 테스트 코드
  // });

  // group('예외 상황', () {
  //   test('newFeeRate가 pendingTx.feeRate보다 작으면 FeeRateTooLowException 발생', () async {
  //     final rbfBuilder = createRbfBuilder(
  //       inputAmounts: [100000],
  //       recipients: [Tuple(false, 50000)],
  //       changeAmount: 49000,
  //       fee: 1000,
  //       vSize: 100,
  //       isMultiSig: false,
  //     );

  //     expect(
  //       () => rbfBuilder.buildRbfTransaction(newFeeRate: 5.0, additionalSpendable: []),
  //       throwsA(isA<FeeRateTooLowException>()),
  //     );
  //   });
  // });

  // group('싱글시그지갑 - InputSum not enough / selfOutput 사용', () {
  //   test('selfOutput 1 / no change / selfOutput 1개의 amount를 차감하여 성공🟢', () async {
  //     final rbfBuilder = createRbfBuilder(
  //       inputAmounts: [50000],
  //       recipients: [Tuple(true, 50000 - 110)],
  //       changeAmount: 0,
  //       fee: 110,
  //       vSize: 110,
  //       isMultiSig: false,
  //     );
  //     final result = await rbfBuilder.buildRbfTransaction(newFeeRate: 5.0, additionalSpendable: []);

  //     expect(result.isSuccess, isTrue);
  //     expect(result.transaction, isNotNull);
  //     expect(result.isOnlyChangeOutputUsed, isFalse);
  //     expect(result.isSelfOutputsUsed, isTrue);
  //     expect(result.addedUtxos, isNull);
  //     expect(result.deficitAmount, isNull);

  //     final tx = result.transaction!;
  //     final int totalInput = tx.totalInputAmount;
  //     final int totalOutput = tx.outputs.fold(0, (sum, out) => sum + out.amount);
  //     final int actualFee = totalInput - totalOutput;

  //     expect(totalInput, 50000);
  //     expect(totalOutput, greaterThanOrEqualTo(49450));
  //     expect(actualFee, lessThanOrEqualTo(550));
  //   });

  //   // test('selfOutput 1 / no change / selfOutput 1개의 amount를 차감하여 시도했지만 Input 부족🔴', () async {
  //   //   final rbfBuilder = createRbfBuilder(
  //   //     inputAmounts: [1000],
  //   //     recipients: [Tuple(true, 1000 - 110)],
  //   //     changeAmount: 0,
  //   //     fee: 110,
  //   //     vSize: 110,
  //   //   );
  //   //   final result = await rbfBuilder.buildRbfTransaction(newFeeRate: 5.0, additionalSpendable: []);

  //   //   expect(result.isSuccess, isFalse);
  //   //   expect(result.transaction, isNull);
  //   //   expect(result.isOnlyChangeOutputUsed, isFalse);
  //   //   expect(result.isSelfOutputsUsed, isFalse);
  //   //   expect(result.addedUtxos, isNull);
  //   //   expect(result.deficitAmount, isNotNull);
  //   //   print(result.deficitAmount);
  //   // });

  //   test('selfOutput 1개의 amount를 차감하여 성공 / leftOutput > dustLimit', () async {
  //     final rbfBuilder = createRbfBuilder(
  //       inputAmounts: [50000],
  //       recipients: [Tuple(true, 50000 - 110)],
  //       changeAmount: 0,
  //       fee: 110,
  //       vSize: 110,
  //       isMultiSig: false,
  //     );
  //     final result = await rbfBuilder.buildRbfTransaction(newFeeRate: 5.0, additionalSpendable: []);

  //     expect(result.isSuccess, isTrue);
  //     expect(result.transaction, isNotNull);
  //     expect(result.isOnlyChangeOutputUsed, isFalse);
  //     expect(result.isSelfOutputsUsed, isTrue);
  //     expect(result.addedUtxos, isNull);
  //     expect(result.deficitAmount, isNull);
  //     expect(result.transaction!.estimateFee(5, AddressType.p2wpkh), greaterThan(110));
  //   });

  //   test('selfOutput 1개를 제거하여 성공 / 0 < leftOutput <= dustLimit', () async {
  //     final rbfBuilder = createRbfBuilder(
  //       inputAmounts: [50000],
  //       recipients: [Tuple(true, 50000 - 110)],
  //       changeAmount: 0,
  //       fee: 110,
  //       vSize: 110,
  //       isMultiSig: false,
  //     );
  //     final result = await rbfBuilder.buildRbfTransaction(newFeeRate: 5.0, additionalSpendable: []);

  //     expect(result.isSuccess, isTrue);
  //     expect(result.transaction, isNotNull);
  //     expect(result.isOnlyChangeOutputUsed, isFalse);
  //     expect(result.isSelfOutputsUsed, isTrue);
  //     expect(result.addedUtxos, isNull);
  //     expect(result.deficitAmount, isNull);
  //     expect(result.transaction!.estimateFee(5, AddressType.p2wpkh), greaterThan(110));
  //   });

  //   test('selfOutput 1개를 제거하여 성공 / leftOutput == 0', () async {});

  //   test('selfOutput 1 제거 + selfOutput 2에서 amount 차감하여 성공 / leftOutput > dustLimit', () async {});

  //   test('selfOutput 2 제거하여 성공 / 0 < leftOutput <= dustLimit', () async {});

  //   test('selfOutput 2 제거하여 성공 / leftOutput == 0', () async {});

  //   test('selfOutput 1개를 제거하여 성공 / 기존 수수료보다 새로운 수수료가 적어짐 / 수수료 조정하여 성공', () async {});
  // });
}
