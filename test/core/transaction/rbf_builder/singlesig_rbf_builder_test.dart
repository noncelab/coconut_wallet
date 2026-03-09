import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/exceptions/rbf_creation/rbf_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_builder.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/packages/bc-ur-dart/lib/utils.dart';
import 'package:coconut_wallet/utils/fee_rate_util.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(result.addedInputs, isNull);
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
      expect(result.addedInputs, isNull);
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
      expect(result.addedInputs!.length, equals(1));
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
      expect(result.addedInputs!.length, equals(1));
      expect(result.deficitAmount, isNull);
      expect(result.minimumFeeRate, equals(1.54));
    });

    test('External 1 / changeAmount == additionalFee (정확히 일치) / 경계 조건', () async {
      // additionalFee = ceil(141 * 1.0) = 141
      // changeAmount = 141 → changeOutput.amount(141) >= deficitAmount(141) 이므로 "enough" 분기 진입
      // rebuild 시 change = 100000 - 99718 - 282 = 0 → coconut_lib이 change output을 드롭하고 tx 생성 성공
      // 결과 tx: 1-input, 1-output (change 없음) → vSize ≈ 109.75 vbytes
      // 저장되는 minimumFeeRate = getFeeRate() = minimumFee(282) / 109.75 ≈ 2.57
      // (빌드는 feeRate 2.0으로 요청했지만, change output이 없어 tx가 작아져 실제 feeRate이 더 높게 측정됨)
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(false, 99718)], // 100000 - 141(fee) - 141(change) = 99718
        changeAmount: 141, // == additionalFee
        fee: 141,
        vSize: 141,
        // additionalSpendable 없음
      );

      final RbfBuildResult result = rbfBuilder.getBaselineTransaction();

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.addedInputs, isNull);
      expect(result.deficitAmount, isNull);
      expect(result.minimumFeeRate, equals(2.57)); // FreeRateUtils.ceilFeeRate(141*2 / 109.75)
    });

    test('External 1 / changeAmount == additionalFee - 1 (1 sat 부족) / 경계 조건', () async {
      // changeAmount = 140 → changeOutput.amount(140) < deficitAmount(141) 이므로 "not enough" 분기 직접 진입
      // deficitAmount = 141 - 140 = 1, 추가 UTXO 없음 → deficitAmount = 1 + 68 = 69
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(false, 99719)], // 100000 - 141(fee) - 140(change) = 99719
        changeAmount: 140, // == additionalFee - 1
        fee: 141,
        vSize: 141,
        // additionalSpendable 없음
      );

      final RbfBuildResult result = rbfBuilder.getBaselineTransaction();

      // "not enough" 분기 직접 진입: deficitAmount = 141 - 140 = 1 → + 68 = 69
      expect(result.isSuccess, isFalse);
      expect(result.transaction, isNull);
      expect(result.addedInputs, isNull);
      expect(result.deficitAmount, equals(1 + 68)); // = 69
      expect(result.minimumFeeRate, equals(1.68));
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
      expect(baselineResult.minimumFeeRate, equals(buildResult.minimumFeeRate));
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

    test('External 1 / no change / manual UTXO add / add enough UTXO later', () async {
      // Step 1: additionalSpendable 없이 rbfBuilder 생성 (change 없음, 수수료 부족)
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(false, 99890)],
        changeAmount: 0,
        fee: 110,
        vSize: 110,
        // additionalSpendable: [] (기본값)
      );

      // Step 2: 초기 baseline 확인 — 실패
      final RbfBuildResult firstResult = rbfBuilder.getBaselineTransaction();
      expect(firstResult.isFailure, isTrue);
      expect(firstResult.transaction, isNull);
      expect(firstResult.addedInputs, isNull); // 아무 UTXO도 시도하지 않음
      expect(firstResult.deficitAmount, equals(141 + 68)); // = 209
      expect(firstResult.minimumFeeRate, equals(1.53));

      // Step 3: changeAdditionalSpendable로 충분한 UTXO 추가 → 새 Baseline 생성
      final newUtxo = UtxoState(
        transactionHash: creator.transactionHashes[1],
        index: 0,
        amount: 1000,
        blockHeight: 21000,
        to: creator.receiveAddressList[1],
        derivationPath: "m/84'/1'/0'/0/1",
        timestamp: DateTime.now(),
      );
      final RbfBuildResult changeResult = rbfBuilder.changeAdditionalSpendable([newUtxo]);

      expect(changeResult.isSuccess, isTrue);
      expect(changeResult.transaction, isNotNull);
      expect(changeResult.isOnlyChangeOutputUsed, isFalse);
      expect(changeResult.isSelfOutputsUsed, isFalse);
      expect(changeResult.addedInputs, isNotNull);
      expect(changeResult.addedInputs!.length, equals(1));
      expect(changeResult.deficitAmount, isNull);
      // ⚠️ minimumFeeRate는 firstResult(1.53)보다 0.01 높은 1.54
      //    (getBaselineTransaction 계산값 1.53으로 빌드 후 getFeeRate()가 1.54 반환 — 정수 반올림)
      expect(changeResult.minimumFeeRate, equals(1.54));
      expect(changeResult.minimumFeeRate, greaterThanOrEqualTo(firstResult.minimumFeeRate));

      // Step 4: build() 호출 → isSuccess 확인
      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: changeResult.minimumFeeRate);
      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.addedInputs, isNotNull);
      expect(buildResult.addedInputs!.length, equals(1));
      expect(buildResult.deficitAmount, isNull);
      expect(buildResult.minimumFeeRate, equals(changeResult.minimumFeeRate));
    });

    test('External 1 / change enough / build(minimumFeeRate)은 baseline과 동일한 트랜잭션 구조를 가져야 함', () async {
      // baseline이 성공하고, 그 minimumFeeRate로 build를 호출하면 동일한 결과가 나와야 한다.
      // 단, getFeeRate()의 반올림으로 인해 수수료는 최대 1-2 sat 차이가 날 수 있다.
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(false, 1000)],
        changeAmount: 98859,
        fee: 141,
        vSize: 141,
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();
      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isOnlyChangeOutputUsed, isTrue);
      expect(baselineResult.addedInputs, isNull);

      // 최소 수수료율로 build 호출
      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      // build도 성공해야 함
      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);

      // 동일한 전략(change only, 추가 input 없음)으로 빌드되어야 함
      expect(buildResult.isOnlyChangeOutputUsed, isTrue);
      expect(buildResult.addedInputs, isNull);
      expect(buildResult.deficitAmount, isNull);

      // minimumFeeRate는 동일 (_cachedBaseline에서 가져옴)
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      final baselineTx = baselineResult.transaction!;
      final buildTx = buildResult.transaction!;

      // output 개수 동일
      expect(buildTx.outputs.length, equals(baselineTx.outputs.length));

      // 외부 recipient 금액은 변하지 않음
      expect(
        buildTx.outputs.where((o) => o.getAddress() == creator.externalWalletAddressList[0]).first.amount,
        equals(baselineTx.outputs.where((o) => o.getAddress() == creator.externalWalletAddressList[0]).first.amount),
      );

      // build(minimumFeeRate) 수수료 >= baseline 수수료 (같거나 약간 높음)
      expect(buildResult.estimatedFee, greaterThanOrEqualTo(baselineResult.estimatedFee!));

      // 수수료 차이는 반올림 오차 수준이어야 함 (최대 2 sat)
      expect(buildResult.estimatedFee! - baselineResult.estimatedFee!, lessThanOrEqualTo(2));

      // RBF 최소 수수료 규칙을 만족해야 함: newFee > pendingTxFee
      expect(buildResult.estimatedFee, greaterThan(pendingTx.fee));
    });

    test(
      'External 1 / change NotEnough / additional UTXO / build(minimumFeeRate)은 baseline과 동일한 트랜잭션 구조를 가져야 함',
      () async {
        final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
          inputAmounts: [100000],
          recipients: [Tuple(false, 99890)],
          changeAmount: 0,
          fee: 110,
          vSize: 110,
          additionalSpendable: [1000],
        );

        final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();
        expect(baselineResult.isSuccess, isTrue);
        expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
        expect(baselineResult.addedInputs, isNotNull);
        expect(baselineResult.addedInputs!.length, equals(1));

        // 최소 수수료율로 build 호출
        final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

        // build도 성공해야 함
        expect(buildResult.isSuccess, isTrue);
        expect(buildResult.transaction, isNotNull);

        // 동일한 전략(추가 input 1개)으로 빌드되어야 함
        expect(buildResult.addedInputs, isNotNull);
        expect(buildResult.addedInputs!.length, equals(1));
        expect(buildResult.deficitAmount, isNull);

        // minimumFeeRate는 동일 (_cachedBaseline에서 가져옴)
        expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

        // output 개수 동일
        final baselineTx = baselineResult.transaction!;
        final buildTx = buildResult.transaction!;
        expect(buildTx.outputs.length, equals(baselineTx.outputs.length));

        // 외부 recipient 금액은 변하지 않음
        expect(
          buildTx.outputs
              .where((TransactionOutput o) => o.getAddress() == creator.externalWalletAddressList[0])
              .first
              .amount,
          equals(baselineTx.outputs.where((o) => o.getAddress() == creator.externalWalletAddressList[0]).first.amount),
        );

        // build(minimumFeeRate) 수수료 >= baseline 수수료
        expect(buildResult.estimatedFee, greaterThanOrEqualTo(baselineResult.estimatedFee!));

        // RBF 최소 수수료 규칙을 만족해야 함
        expect(buildResult.estimatedFee, greaterThan(pendingTx.fee));
      },
    );

    test('External 1 / change short with new feeRate / manual UTXO add / add enough UTXO later', () async {
      // Step 1: additionalSpendable 없이 rbfBuilder 생성 (change=547 있음, 최소 수수료는 충분)
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(false, 100000 - 141 - 547)],
        changeAmount: 547,
        fee: 141,
        vSize: 141,
        // additionalSpendable: [] (기본값)
      );

      // Step 2: 초기 baseline 확인 — 성공 (change 547 >= additionalFee 141)
      final RbfBuildResult firstResult = rbfBuilder.getBaselineTransaction();
      expect(firstResult.isSuccess, isTrue);
      expect(firstResult.isOnlyChangeOutputUsed, isTrue);
      expect(firstResult.addedInputs, isNull);
      expect(firstResult.minimumFeeRate, equals(2.01));

      // Step 3: feeRate을 5.0으로 높여 build 호출 → change 547로 부족하여 실패
      // requiredFee = ceil(140.75 * 5.0) = 704, additionalFee = 704 - 141 = 563
      // change 547이 563에서 16을 못 냄 → deficit = 16
      // additionalSpendable 없음 → bottom: deficit = 16 + ceil(68 * 5.0) = 356
      final RbfBuildResult buildResult1 = rbfBuilder.build(newFeeRate: 5.0);
      expect(buildResult1.isFailure, isTrue);
      expect(buildResult1.transaction, isNull);
      expect(buildResult1.deficitAmount, equals(16 + 340)); // = 356
      expect(buildResult1.minimumFeeRate, equals(firstResult.minimumFeeRate)); // 2.01

      // Step 4: amount가 다른 2개의 UTXO를 추가
      final smallUtxo = UtxoState(
        transactionHash: creator.transactionHashes[2],
        index: 0,
        amount: 300,
        blockHeight: 21000,
        to: creator.receiveAddressList[2],
        derivationPath: "m/84'/1'/0'/0/2",
        timestamp: DateTime.now(),
      );
      final largeUtxo = UtxoState(
        transactionHash: creator.transactionHashes[1],
        index: 0,
        amount: 1000,
        blockHeight: 21000,
        to: creator.receiveAddressList[1],
        derivationPath: "m/84'/1'/0'/0/1",
        timestamp: DateTime.now(),
      );

      final RbfBuildResult changeResult = rbfBuilder.changeAdditionalSpendable([smallUtxo, largeUtxo]);

      // baseline 재계산: change(547) >= additionalFee(141)이므로 여전히 change만으로 baseline 성공
      // → 추가 UTXO들은 baseline에서 사용되지 않고, minimumFeeRate도 이전과 동일
      expect(changeResult.isSuccess, isTrue);
      expect(changeResult.isOnlyChangeOutputUsed, isTrue);
      expect(changeResult.addedInputs, isNull);
      expect(changeResult.minimumFeeRate, equals(firstResult.minimumFeeRate)); // 2.01 동일!

      // Step 5: 동일한 feeRate 5.0으로 다시 build → 성공
      // change 547이 564 중 547 커버, deficit = 17
      // UTXO[0](1000): deficit = 17 + 340 = 357, 1000 >= 357 → deficit = 0 (성공!)
      // UTXO[1](300)은 사용되지 않음
      final RbfBuildResult buildResult2 = rbfBuilder.build(newFeeRate: 5.0);
      expect(buildResult2.isSuccess, isTrue);
      expect(buildResult2.transaction, isNotNull);
      expect(buildResult2.exception, isNull);
      expect(buildResult2.addedInputs, isNotNull);
      expect(buildResult2.addedInputs!.length, equals(1)); // 2개 중 1개만 사용
      expect(buildResult2.addedInputs![0].amount, equals(1000)); // 더 큰 UTXO만 사용
      expect(buildResult2.deficitAmount, isNull);
      expect(buildResult2.minimumFeeRate, equals(changeResult.minimumFeeRate));
    });

    test('External 1 / changeAmount == additionalFee / 추가 UTXO로 build 성공', () async {
      // getBaselineTransaction 경계 조건 케이스 1과 동일한 셋업
      // baseline: change=0 → change output 드롭 → minimumFeeRate=2.57, estimatedVSize=109.75
      // build(2.57): requiredFee=ceil(109.75*2.57)=283, additionalFee=283-141=142 > change(141) → 1 sat 부족
      // 추가 UTXO(10000)이 deficit(1) + overhead(ceil(68*2.57)=175) = 176을 커버 → 성공
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(false, 99718)],
        changeAmount: 141,
        fee: 141,
        vSize: 141,
        additionalSpendable: [10000],
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();
      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.minimumFeeRate, equals(2.57));
      expect(baselineResult.addedInputs, isNull); // 추가 UTXO는 baseline에서 사용되지 않음

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.addedInputs, isNotNull);
      expect(buildResult.addedInputs!.length, equals(1)); // 1 sat 부족분을 추가 UTXO로 커버
      expect(buildResult.deficitAmount, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));
    });

    test('External 1 / changeAmount == additionalFee - 1 / changeAdditionalSpendable 후 build 성공', () async {
      // getBaselineTransaction 경계 조건 케이스 2와 동일한 셋업
      // baseline: deficitAmount=69, minimumFeeRate=1.68 → 실패
      // changeAdditionalSpendable로 UTXO 추가 → 새 baseline 성공
      // build(newMinimumFeeRate) → 성공
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(false, 99719)],
        changeAmount: 140,
        fee: 141,
        vSize: 141,
      );

      final RbfBuildResult firstBaseline = rbfBuilder.getBaselineTransaction();
      expect(firstBaseline.isFailure, isTrue);
      expect(firstBaseline.deficitAmount, equals(69));
      expect(firstBaseline.minimumFeeRate, equals(1.68));

      final newUtxo = UtxoState(
        transactionHash: creator.transactionHashes[1],
        index: 0,
        amount: 10000,
        blockHeight: 21000,
        to: creator.receiveAddressList[1],
        derivationPath: "m/84'/1'/0'/0/1",
        timestamp: DateTime.now(),
      );
      final RbfBuildResult newBaseline = rbfBuilder.changeAdditionalSpendable([newUtxo]);

      // 새 baseline: change(140)으로 deficit 1 sat 커버, 나머지 deficitAmount(1) + 68 = 69를 UTXO(10000)으로 커버
      expect(newBaseline.isSuccess, isTrue);
      expect(newBaseline.addedInputs, isNotNull);
      expect(newBaseline.addedInputs!.length, equals(1));
      expect(newBaseline.deficitAmount, isNull);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: newBaseline.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.addedInputs, isNotNull);
      expect(buildResult.addedInputs!.length, equals(1));
      expect(buildResult.deficitAmount, isNull);
      expect(buildResult.minimumFeeRate, equals(newBaseline.minimumFeeRate));
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
