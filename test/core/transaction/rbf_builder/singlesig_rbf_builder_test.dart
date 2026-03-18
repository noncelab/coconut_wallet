import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/core/exceptions/rbf_creation/rbf_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/rbf_builder.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/packages/bc-ur-dart/lib/utils.dart';
import 'package:coconut_wallet/utils/fee_rate_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../../mock/wallet_mock.dart';
import 'setup_util.dart';

void expectRbfMinimumCondition(RbfBuildResult result, TransactionRecord pendingTx) {
  if (result.isSuccess) {
    Logger.log('--> estimated Fee & VSize: ${result.estimatedFee} / ${result.estimatedVSize}');
    expect(result.estimatedFee, greaterThanOrEqualTo(pendingTx.fee + result.estimatedVSize));
  }
}

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

  group('싱글시그지갑 - getBaselineTransaction - no selfOutput', () {
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
      expect(result.minimumFeeRate, closeTo(2.01, 0.02));

      final tx = result.transaction!;
      final int totalInput = tx.totalInputAmount;
      final int totalOutput = tx.outputs.fold(0, (sum, out) => sum + out.amount);
      final int actualFee = totalInput - totalOutput;
      final double vByte = tx.estimateVirtualByte(AddressType.p2wpkh).ceil().toDouble();
      final double calculatedFeeRate = actualFee / vByte;
      final int changeAmount = totalInput - 1000 - actualFee;

      expect(calculatedFeeRate, closeTo(2.01, 0.02));
      expect(changeAmount, equals(98718)); // 98859 - 141

      expectRbfMinimumCondition(result, pendingTx);
    });

    test('External 1 / no change / no additional UTXO', () async {
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
      expect(result.deficitAmount, isNotNull);
      // _calculateMinimumFeeRate(141 + 68 + 68) = (110 + 277) / 277 = 1.4
      expect(result.minimumFeeRate, greaterThanOrEqualTo(1.4));
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
      expect(result.minimumFeeRate, equals(1.53));

      expectRbfMinimumCondition(result, pendingTx);
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
      expectRbfMinimumCondition(result, pendingTx);
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
      expect(result.minimumFeeRate, equals(1.67));
    });

    test('selfOutput 1 / change insufficient / selfOutput partial reduction → getBaselineTransaction 성공', () async {
      // 원본 tx: 1-in/2-out (selfOutput + change), vSize=141
      // additionalFee = 141, changeOutput(100) < 141 → deficitAmount = 41
      // selfOutput(99759) - 41 = 99718 > dustLimit(546) → partial reduction
      // sweep tx 생성 후 실제 vSize=109.75로 작아짐
      // RBF 최소 조건: fee >= 141 + 109.75 = 250.75
      // requiredFeeRate = ceil(251/109.75) = 2.29으로 재빌드
      // 결과 tx: 1-in/1-out, fee=251, vSize=109.75
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(true, 99759)],
        changeAmount: 100,
        fee: 141,
        vSize: 141,
      );

      final RbfBuildResult result = rbfBuilder.getBaselineTransaction();

      expect(result.isSuccess, isTrue);
      expect(result.isSelfOutputsUsed, isTrue);
      expect(result.isOnlyChangeOutputUsed, isFalse);
      expect(result.addedInputs, isNull);
      expect(result.deficitAmount, isNull);
      expect(result.minimumFeeRate, equals(2.29));

      final tx = result.transaction!;
      // selfOutput amount = 100000 - 251 = 99749
      expect(tx.outputs.any((o) => o.getAddress() == creator.receiveAddressList[1] && o.amount == 99749), isTrue);
      // change output은 0 sat → 드롭됨
      expect(tx.outputs.any((o) => o.getAddress() == creator.changeAddressList[0]), isFalse);
      expectRbfMinimumCondition(result, pendingTx);
    });

    test(
      'External 1 + selfOutput 1 / change insufficient / selfOutput full removal → getBaselineTransaction 성공',
      () async {
        // 원본 tx: 1-in/3-out (external + selfOutput + change), vSize=172
        // additionalFee = 172, changeOutput(100) < 172 → deficitAmount = 72
        // selfOutput(500) - 72 = 428 ≤ dustLimit(546) → full removal
        // leftDeficit = 72 - (500 + ceil(31*1.0)=31) = -459 → 0
        // vSizeReduced = 31, newTxVSize = 172 - 31 = 141
        // newRecipients = {external: 1000} (selfOutput 제거됨)
        // build at _calculateMinimumFeeRate(141) = 2.0:
        //   tx: external(1000) + change(1741-1000-282=459), fee=282, 실제 vSize=140.75
        //   getFeeRate = ceilFeeRate(282/140.75) = 2.01
        final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
          inputAmounts: [1772],
          recipients: [Tuple(false, 1000), Tuple(true, 500)],
          changeAmount: 100,
          fee: 172,
          vSize: 172,
        );

        final RbfBuildResult result = rbfBuilder.getBaselineTransaction();

        expect(result.isSuccess, isTrue);
        expect(result.isSelfOutputsUsed, isTrue);
        expect(result.isOnlyChangeOutputUsed, isFalse);
        expect(result.addedInputs, isNull);
        expect(result.deficitAmount, isNull);
        expect(result.minimumFeeRate, equals(2.22));

        final tx = result.transaction!;
        // selfOutput은 제거되어 tx에 없어야 함
        expect(tx.outputs.any((o) => o.getAddress() == creator.receiveAddressList[1]), isFalse);
        // external output은 그대로 존재해야 함
        expect(
          tx.outputs.any((o) => o.getAddress() == creator.externalWalletAddressList[0] && o.amount == 1000),
          isTrue,
        );

        expectRbfMinimumCondition(result, pendingTx);
      },
    );
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
      final newUtxo1 = UtxoState(
        transactionHash: creator.transactionHashes[0],
        index: 100,
        amount: 100,
        blockHeight: 21000,
        to: creator.receiveAddressList[0],
        derivationPath: "m/84'/1'/0'/0/0",
        timestamp: DateTime.now(),
      );
      final newUtxo2 = UtxoState(
        transactionHash: creator.transactionHashes[1],
        index: 100,
        amount: 1000,
        blockHeight: 21000,
        to: creator.receiveAddressList[0],
        derivationPath: "m/84'/1'/0'/0/0",
        timestamp: DateTime.now(),
      );

      final RbfBuildResult changeResult = rbfBuilder.changeAdditionalSpendable([newUtxo1, newUtxo2]);
      expect(firstRbfResult.isFailure, isTrue);
      expect(changeResult.isSuccess, isTrue);
      expect(
        changeResult.minimumFeeRate,
        greaterThanOrEqualTo(firstRbfResult.minimumFeeRate),
      ); // 처음에 utxo 2개 추가 사용한다고 가정하지만, 실제로는 1개만 추가 사용
    });

    test('External 1 / change NotEnough / not enough additional UTXO', () async {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(false, 99890)],
        changeAmount: 0,
        fee: 110,
        vSize: 110,
        additionalSpendable: [],
      );
      final firstRbfResult = rbfBuilder.getBaselineTransaction();
      final newUtxo1 = UtxoState(
        transactionHash: creator.transactionHashes[0],
        index: 100,
        amount: 100,
        blockHeight: 21000,
        to: creator.receiveAddressList[0],
        derivationPath: "m/84'/1'/0'/0/0",
        timestamp: DateTime.now(),
      );
      final newUtxo2 = UtxoState(
        transactionHash: creator.transactionHashes[1],
        index: 100,
        amount: 1000,
        blockHeight: 21000,
        to: creator.receiveAddressList[0],
        derivationPath: "m/84'/1'/0'/0/0",
        timestamp: DateTime.now(),
      );

      final RbfBuildResult changeResult = rbfBuilder.changeAdditionalSpendable([newUtxo1, newUtxo2]);
      expect(firstRbfResult.isFailure, isTrue);
      expect(changeResult.isSuccess, isTrue);
      expect(changeResult.minimumFeeRate, closeTo(firstRbfResult.minimumFeeRate, 0.02));
      final RbfBuildResult rebuildResult = rbfBuilder.build(newFeeRate: firstRbfResult.minimumFeeRate);
      expect(rebuildResult.isSuccess, isTrue);
    });
  });

  group('싱글시그지갑 - build - external only', () {
    test('External 1 / feeRate too low', () async {
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
        closeTo(FeeRateUtils.roundToTwoDecimals((pendingTxFee + baselineVSize) / baselineVSize), 0.02),
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
        FeeRateUtils.roundToTwoDecimals(baselineTxFee / baselineVSize), // 1.54
        greaterThanOrEqualTo(FeeRateUtils.roundToTwoDecimals((pendingTxFee + baselineVSize) / baselineVSize)), // 1.53
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
      expect(changeResult.minimumFeeRate, equals(1.53));
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
      expect(firstResult.minimumFeeRate, closeTo(2.01, 0.02));

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
      expect(firstBaseline.minimumFeeRate, equals(1.67));

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

  group('싱글시그지갑 - build - external + selfOutput', () {
    test('Ex 1, Self 1 / no change / use enough selfOutput', () async {
      // 원본 tx: 1-in/2-out (external + selfOutput), changeAmount=0, vSize=141
      // changeOutput 없으므로 보수적 vSize 추정: newTxVSize = 141 + 31*1.0 = 172
      // additionalFee = ceil(172 * 1.0) = 172, deficitAmount = 172
      // selfOutput(98859) - 172 = 98687 > dustLimit(546) → partial reduction
      // newRecipients = {ext: 1000, self: 98687}, deficit = 0
      // build at _calculateMinimumFeeRate(172) = ceilFeeRate(313/172) = 1.82:
      //   tx: ext(1000) + self(98687), change=0 → 드롭
      //   결과 tx: 1-in/2-out, fee=313, vSize≈140.75
      //   getFeeRate = ceilFeeRate(313/140.75) ≈ 2.23
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [100000],
        recipients: [Tuple(true, 98859), Tuple(false, 1000)],
        changeAmount: 0,
        fee: 141,
        vSize: 141,
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isTrue);
      expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
      expect(baselineResult.addedInputs, isNull);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.addedInputs, isNull);
      expect(buildResult.deficitAmount, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      // External output 금액 불변
      final tx = buildResult.transaction!;
      expect(tx.outputs.any((o) => o.getAddress() == creator.externalWalletAddressList[1] && o.amount == 1000), isTrue);

      // SelfOutput 감소 확인
      final selfOutputInTx = tx.outputs.where((o) => o.getAddress() == creator.receiveAddressList[1]).toList();
      expect(selfOutputInTx.length, 1);
      expect(selfOutputInTx.first.amount, lessThan(98859));

      // RBF 최소 수수료 규칙
      expectRbfMinimumCondition(buildResult, pendingTx);
    });

    test('Ex 1, Self 2 / no change / use 2 enough selfOutputs', () async {
      // 원본 tx: 1-in/3-out (external + selfOutput1 + selfOutput2), changeAmount=0, vSize=172
      // changeOutput 없으므로 보수적 vSize 추정: newTxVSize = 172 + 31*1.0 = 203
      // additionalFee = ceil(203 * 1.0) = 203, deficitAmount = 203
      // selfOutput2(5000) - 203 = 4797 > dustLimit(546) → partial reduction
      // newRecipients = {ext: 1000, self1: 10000, self2: 4797}, deficit = 0
      // sweep tx 생성 후 실제 vSize 확인하여 RBF 최소 조건 만족하도록 재빌드
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [16000],
        recipients: [Tuple(false, 13000), Tuple(true, 2000), Tuple(true, 1000)],
        changeAmount: 0,
        fee: 172,
        vSize: 172,
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isTrue);
      expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
      expect(baselineResult.addedInputs, isNull);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.isOnlyChangeOutputUsed, isFalse);
      expect(buildResult.addedInputs, isNull);
      expect(buildResult.deficitAmount, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      // External output 금액 불변
      final tx = buildResult.transaction!;
      expect(
        tx.outputs.any((o) => o.getAddress() == creator.externalWalletAddressList[0] && o.amount == 13000),
        isTrue,
      );
      // SelfOutput1은 그대로 유지
      expect(tx.outputs.any((o) => o.getAddress() == creator.receiveAddressList[1] && o.amount == 2000), isTrue);
      expect(tx.outputs.where((o) => o.getAddress() == creator.receiveAddressList[2]).first.amount, lessThan(1000));
      // SelfOutput2는 감소
      final selfOutput2InTx = tx.outputs.where((o) => o.getAddress() == creator.receiveAddressList[2]).toList();
      expect(selfOutput2InTx.first.amount, lessThan(1000));

      // RBF 최소 수수료 규칙
      expectRbfMinimumCondition(buildResult, pendingTx);

      // 수수료율 높이기
      final RbfBuildResult buildResult2 = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate + 13);

      expect(buildResult2.isSuccess, isTrue);
      expect(buildResult2.transaction, isNotNull);
      expect(buildResult2.exception, isNull);
      expect(buildResult2.isSelfOutputsUsed, isTrue);
      expect(buildResult2.isOnlyChangeOutputUsed, isFalse);
      expect(buildResult2.addedInputs, isNull);
      expect(buildResult2.deficitAmount, isNull);
      expect(buildResult2.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      // External output 금액 불변
      final tx2 = buildResult2.transaction!;
      expect(
        tx2.outputs.any((o) => o.getAddress() == creator.externalWalletAddressList[0] && o.amount == 13000),
        isTrue,
      );
      // Last SelfOutput은 사라짐
      expect(tx2.outputs.length, equals(2));
      // RBF 최소 수수료 규칙
      expectRbfMinimumCondition(buildResult2, pendingTx);

      final RbfBuildResult failedResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate + 100);

      expect(failedResult.isSuccess, isFalse);
      expect(failedResult.transaction, isNull);
      expect(failedResult.exception, isNotNull);
      expect(failedResult.isSelfOutputsUsed, isTrue);
      expect(failedResult.isOnlyChangeOutputUsed, isFalse);
      expect(failedResult.addedInputs, isNull);
      expect(failedResult.deficitAmount, isNotNull);
    });

    test('Ex 1, Self 2 / change NotEnough / use 1 enough selfOutput', () async {
      // 원본 tx: 1-in/4-out (external + selfOutput1 + selfOutput2 + change), vSize=203
      // changeAmount=100 < additionalFee=203 → deficitAmount = 103
      // selfOutput2(900) - 103 = 797 > dustLimit(546) → partial reduction
      // newRecipients = {ext: 13000, self1: 2000, self2: 797}, deficit = 0
      // sweep tx 생성 후 실제 vSize 확인하여 RBF 최소 조건 만족하도록 재빌드
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [16000],
        recipients: [Tuple(false, 13000), Tuple(true, 2000), Tuple(true, 900)],
        changeAmount: 100,
        fee: 172,
        vSize: 203,
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isTrue);
      expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
      expect(baselineResult.addedInputs, isNull);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.isOnlyChangeOutputUsed, isFalse);
      expect(buildResult.addedInputs, isNull);
      expect(buildResult.deficitAmount, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      final tx = buildResult.transaction!;
      // External output 금액 불변
      expect(
        tx.outputs.any((o) => o.getAddress() == creator.externalWalletAddressList[0] && o.amount == 13000),
        isTrue,
      );
      // SelfOutput1은 그대로 유지
      expect(tx.outputs.any((o) => o.getAddress() == creator.receiveAddressList[1] && o.amount == 2000), isTrue);
      // SelfOutput2는 감소
      final selfOutput2InTx = tx.outputs.where((o) => o.getAddress() == creator.receiveAddressList[2]).toList();
      expect(selfOutput2InTx.length, 1);
      expect(selfOutput2InTx.first.amount, lessThan(1000));
      // Change output은 드롭됨
      expect(tx.outputs.any((o) => o.getAddress() == creator.changeAddressList[0]), isFalse);

      expectRbfMinimumCondition(buildResult, pendingTx);
    });

    test('Ex 1, Self 2 / change NotEnough / use 2 enough selfOutputs', () async {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [16000],
        recipients: [Tuple(false, 13000), Tuple(true, 2000), Tuple(true, 900)],
        changeAmount: 100,
        fee: 172,
        vSize: 203,
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isTrue);
      expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
      expect(baselineResult.addedInputs, isNull);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate + 15);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.isOnlyChangeOutputUsed, isFalse);
      expect(buildResult.addedInputs, isNull);
      expect(buildResult.deficitAmount, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      final tx = buildResult.transaction!;
      // External output 금액 불변
      expect(
        tx.outputs.any((o) => o.getAddress() == creator.externalWalletAddressList[0] && o.amount == 13000),
        isTrue,
      );
      // SelfOutput1은 그대로 유지
      expect(tx.outputs.where((o) => o.getAddress() == creator.receiveAddressList[1]).first.amount, lessThan(2000));
      // SelfOutput2는 제거됨 (dust limit 미만)
      expect(tx.outputs.any((o) => o.getAddress() == creator.receiveAddressList[2]), isFalse);
      // Change output 없음
      final changeOutputs = tx.outputs.where((o) => o.getAddress() == creator.changeAddressList[0]).toList();
      expect(changeOutputs.length, 0);
      expectRbfMinimumCondition(buildResult, pendingTx);
    });
  });

  group('싱글시그지갑 - build - external + selfOutput + additionalUtxos', () {
    test('Ex1, Self2 / no change / use all selfOutputs + additionalUtxos', () async {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [14200],
        recipients: [Tuple(false, 13000), Tuple(true, 500), Tuple(true, 500)],
        changeAmount: 0,
        fee: 203,
        vSize: 203,
        additionalSpendable: [1000, 2000],
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isTrue);
      expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
      //expect(baselineResult.addedInputs, isNull);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate + 10);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.addedInputs, isNotNull);
      expect(buildResult.deficitAmount, isNull);

      final tx = buildResult.transaction!;
      // External output 금액 불변
      expect(
        tx.outputs.any((o) => o.getAddress() == creator.externalWalletAddressList[0] && o.amount == 13000),
        isTrue,
      );
      // 추가 input이 사용됨
      expect(tx.inputs.length, equals(2));

      expectRbfMinimumCondition(buildResult, pendingTx);
    });

    test('Ex1, Self2 / change NotEnough / use all selfOutputs + additionalUtxos', () async {
      // 원본 tx: 1-in/2-out (external + change), vSize=141
      // selfOutput이 없고 입력 금액이 부족하여 additionalUtxos 필수
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [13000],
        recipients: [Tuple(false, 13000)],
        changeAmount: 50,
        fee: 110,
        vSize: 141,
        additionalSpendable: [3000],
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isFalse);
      expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
      expect(baselineResult.addedInputs, isNotNull);
      expect(baselineResult.addedInputs!.length, greaterThan(0));
      expectRbfMinimumCondition(baselineResult, pendingTx);

      // baseline에서 이미 additionalUtxos 사용됨
      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.isSelfOutputsUsed, isFalse);
      expect(buildResult.addedInputs, isNotNull);
      expect(buildResult.deficitAmount, isNull);

      final tx = buildResult.transaction!;
      // External output 금액 불변
      expect(
        tx.outputs.any((o) => o.getAddress() == creator.externalWalletAddressList[0] && o.amount == 13000),
        isTrue,
      );
      // 추가 input이 사용됨
      expect(tx.inputs.length, greaterThan(1));

      expectRbfMinimumCondition(buildResult, pendingTx);
    });

    test('Ex1, Self2 / change NotEnough / use all selfOutputs + additionalUtxos but failed', () async {
      // 원본 tx: 1-in/2-out (external + change), vSize=141
      // selfOutput이 없고 입력 금액 부족
      // additionalUtxos가 있지만 매우 높은 feeRate에서는 부족
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [13000],
        recipients: [Tuple(false, 13000)],
        changeAmount: 50,
        fee: 110,
        vSize: 141,
        additionalSpendable: [500],
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isFalse);
      expect(baselineResult.addedInputs, isNotNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      // 매우 높은 feeRate로 build 시도 - additionalUtxos로도 부족하여 실패
      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate + 100.0);

      expect(buildResult.isSuccess, isFalse);
      expect(buildResult.transaction, isNull);
      expect(buildResult.exception, isNotNull);
      expect(buildResult.isSelfOutputsUsed, isFalse);
      expect(buildResult.deficitAmount, isNotNull);
      expect(buildResult.deficitAmount, greaterThan(0));
    });
  });

  group('싱글시그지갑 - build - only selfOutputs', () {
    test('Self1 / no change / use 1 enough selfOutput', () async {
      // 1-in/1-out (selfOutput only), no change, vSize=141
      // newTxVSize = 141 + 31*1.0 = 172 (conservative for no change)
      // deficitAmount = 172, selfOutput(9859) - 172 = 9687 > dustLimit → partial reduction (sweep)
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [10000],
        recipients: [Tuple(true, 9859)],
        changeAmount: 0,
        fee: 141,
        vSize: 141,
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isTrue);
      expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
      expect(baselineResult.addedInputs, isNull);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.addedInputs, isNull);
      expect(buildResult.deficitAmount, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      // selfOutput 금액이 줄어들었는지 확인
      final tx = buildResult.transaction!;
      final selfOutputInTx = tx.outputs.where((o) => o.getAddress() == creator.receiveAddressList[1]).toList();
      expect(selfOutputInTx.length, 1);
      expect(selfOutputInTx.first.amount, lessThan(9859));

      expectRbfMinimumCondition(buildResult, pendingTx);
    });
    test('Self2 / no change / use 1 enough selfOutput', () async {
      // 1-in/2-out (selfOutput1 + selfOutput2), no change, vSize=172
      // newTxVSize = 172 + 31*1.0 = 203 (conservative for no change)
      // deficitAmount = 203
      // selfOutput2(1800) - 203 = 1597 > dustLimit(546) → selfOutput2만 partial reduction (sweep)
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [12000],
        recipients: [Tuple(true, 10000), Tuple(true, 1800)],
        changeAmount: 0,
        fee: 200,
        vSize: 200,
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isTrue);
      expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
      expect(baselineResult.addedInputs, isNull);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.addedInputs, isNull);
      expect(buildResult.deficitAmount, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      final tx = buildResult.transaction!;
      // selfOutput1(10000)은 변경 없음
      expect(tx.outputs.any((o) => o.getAddress() == creator.receiveAddressList[1] && o.amount == 10000), isTrue);
      // selfOutput2는 감소
      final selfOutput2InTx = tx.outputs.where((o) => o.getAddress() == creator.receiveAddressList[2]).toList();
      expect(selfOutput2InTx.length, 1);
      expect(selfOutput2InTx.first.amount, lessThan(1800));

      expectRbfMinimumCondition(buildResult, pendingTx);
    });
    test('Self2 / no change / use 2 enough selfOutput', () async {
      // 1-in/2-out (selfOutput1=5500 + selfOutput2=59), no change, vSize=141
      // newTxVSize = 141 + 31 = 172
      // deficitAmount = 172, feeSavedByOneRemoval = ceil(31 * minimumFeeRate) ≈ 57
      // selfOutput2(59) - 172 < dustLimit → 전체 제거, leftDeficit = 172 - (59+57) = 56
      // selfOutput1(5500) - 56 = 5444 > dustLimit → partial reduction (sweep), 1개 제거 + 1개 차감
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [5700],
        recipients: [Tuple(true, 5500), Tuple(true, 59)],
        changeAmount: 0,
        fee: 178,
        vSize: 178,
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isTrue);
      expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
      expect(baselineResult.addedInputs, isNull);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.addedInputs, isNull);
      expect(buildResult.deficitAmount, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      final tx = buildResult.transaction!;
      // selfOutput2는 제거됨
      expect(tx.outputs.any((o) => o.getAddress() == creator.receiveAddressList[2]), isFalse);
      // selfOutput1은 감소
      final selfOutput1InTx = tx.outputs.where((o) => o.getAddress() == creator.receiveAddressList[1]).toList();
      expect(selfOutput1InTx.length, 1);
      print(selfOutput1InTx.first.amount);
      expect(selfOutput1InTx.first.amount, lessThan(5500));

      expectRbfMinimumCondition(buildResult, pendingTx);
    });
    test('Self2 / no change / use 2 not enough selfOutput - failed', () async {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [5700],
        recipients: [Tuple(true, 5500), Tuple(true, 59)],
        changeAmount: 0,
        fee: 178,
        vSize: 178,
      );

      // 매우 높은 feeRate으로 build 시도 - selfOutput 모두 사용해도 부족
      final RbfBuildResult buildResult = rbfBuilder.build(
        newFeeRate: rbfBuilder.getBaselineTransaction().minimumFeeRate + 100,
      );

      expect(buildResult.isSuccess, isFalse);
      expect(buildResult.transaction, isNull);
      expect(buildResult.exception, isNotNull);
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.deficitAmount, isNotNull);
      expect(buildResult.deficitAmount, greaterThan(0));
      expect(buildResult.exception, isA<InsufficientBalanceException>());
    });

    test('Self2 / change enough', () async {
      // 1-in/3-out (self1=5000, self2=3000, change=11750), fee=250, vSize=250
      // newTxVSize = 250 (changeOutput exists)
      // additionalFee = 250, change(11750) >= 250 → isOnlyChangeOutputUsed=true
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [20000],
        recipients: [Tuple(true, 5000), Tuple(true, 3000)],
        changeAmount: 11750,
        fee: 250,
        vSize: 209,
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isFalse);
      expect(baselineResult.isOnlyChangeOutputUsed, isTrue);
      expect(baselineResult.addedInputs, isNull);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.isSelfOutputsUsed, isFalse);
      expect(buildResult.isOnlyChangeOutputUsed, isTrue);
      expect(buildResult.addedInputs, isNull);
      expect(buildResult.deficitAmount, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      // selfOutputs는 변경 없음
      final tx = buildResult.transaction!;
      expect(tx.outputs.any((o) => o.getAddress() == creator.receiveAddressList[1] && o.amount == 5000), isTrue);
      expect(tx.outputs.any((o) => o.getAddress() == creator.receiveAddressList[2] && o.amount == 3000), isTrue);

      expectRbfMinimumCondition(buildResult, pendingTx);
    });

    test('Self1 / change not Enough / use 1 enough selfOutput', () async {
      // 1-in/2-out (self1=9750, change=109), fee=141, vSize=141
      // newTxVSize = 141 (changeOutput exists)
      // additionalFee = 141, change(109) < 141 → deficit = 32
      // self1(9750) - 32 = 9718 >= dustLimit → sweep (self1 감소, change 드롭)
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [10000],
        recipients: [Tuple(true, 9750)],
        changeAmount: 109,
        fee: 141,
        vSize: 141,
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isTrue);
      expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
      expect(baselineResult.addedInputs, isNull);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.isOnlyChangeOutputUsed, isFalse);
      expect(buildResult.addedInputs, isNull);
      expect(buildResult.deficitAmount, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      final tx = buildResult.transaction!;
      // self1은 sweep으로 감소
      final selfOutput1InTx = tx.outputs.where((o) => o.getAddress() == creator.receiveAddressList[1]).toList();
      expect(selfOutput1InTx.length, 1);
      expect(selfOutput1InTx.first.amount, lessThan(9750));
      // change output은 sweep으로 드롭됨
      expect(tx.outputs.any((o) => o.getAddress() == creator.changeAddressList[0]), isFalse);

      expectRbfMinimumCondition(buildResult, pendingTx);
    });
    test('Self2 / change not Enough / use 2 enough selfOutputs', () async {
      // 1-in/3-out (self1=5500, self2=159, change=100), fee=241, vSize=172
      // newTxVSize = 172 (changeOutput exists)
      // additionalFee = 172, change(100) < 172 → deficit = 72
      // minimumFeeRate ≈ 2.41, feeSavedByOneRemoval = ceil(31*2.41) = 75
      // self2(159) 제거: leftDeficit = 72-(159+75) = 0 → self1(5500) sweep
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [6000],
        recipients: [Tuple(true, 5500), Tuple(true, 159)],
        changeAmount: 100,
        fee: 241,
        vSize: 209,
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isTrue);
      expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
      expect(baselineResult.addedInputs, isNull);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.addedInputs, isNull);
      expect(buildResult.deficitAmount, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      final tx = buildResult.transaction!;
      // self2는 제거됨
      expect(tx.outputs.any((o) => o.getAddress() == creator.receiveAddressList[2]), isFalse);
      final selfOutput1InTx = tx.outputs.where((o) => o.getAddress() == creator.receiveAddressList[1]).toList();
      expect(selfOutput1InTx.length, 1);
      // self1은 sweep으로 오히려 5600 이상으로 늘어남
      expect(selfOutput1InTx.first.amount, greaterThan(5500));
      // change output은 sweep으로 드롭됨
      expect(tx.outputs.any((o) => o.getAddress() == creator.changeAddressList[0]), isFalse);

      expectRbfMinimumCondition(buildResult, pendingTx);
    });
  });

  group('싱글시그지갑 - build - only selfOutputs + additionalUtxos - Sweep', () {
    test('Self1 / no change / use 1 enough additionalUtxo', () async {
      // 1-in/1-out (self1=700), no change, fee=141, vSize=141
      // newTxVSize = 172 (conservative), deficitAmount = 172
      // self1(700): 700-172=528 < dustLimit → dustLimit 브랜치, set to 547, leftDeficit=19
      // additionalUtxo(1000)로 sweep: self1 = inputSum(841) + 1000 - fee
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [841],
        recipients: [Tuple(true, 700)],
        changeAmount: 0,
        fee: 141,
        vSize: 141,
        additionalSpendable: [1000],
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isTrue);
      expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
      expect(baselineResult.addedInputs, isNotNull);
      expect(baselineResult.addedInputs!.length, 1);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.addedInputs, isNotNull);
      expect(buildResult.addedInputs!.length, 1);
      expect(buildResult.deficitAmount, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      // self1은 sweep되어 있음 (amount = totalInput - fee)
      final tx = buildResult.transaction!;
      final selfOutput1InTx = tx.outputs.where((o) => o.getAddress() == creator.receiveAddressList[1]).toList();
      expect(selfOutput1InTx.length, 1);
      expect(selfOutput1InTx.first.amount, greaterThan(546));

      expectRbfMinimumCondition(buildResult, pendingTx);
    });
    test('Self2 / no change / use 2 selfOutputs, 3 enough additionalUtxo but only used biggest one', () async {
      // 1-in/2-out (self1=50, self2=100), no change, fee=172, vSize=172
      // newTxVSize = 172+31=203 (conservative), deficitAmount=203
      // minimumFeeRate≈2.19, feeSavedByOneRemoval=ceil(31*2.19)=68
      // self2(100) 제거: leftDeficit = 203-(100+68) = 35 > 0
      // self1(50) ≤ 547 → break, leftDeficit=35
      // additionalUtxo(1000)로 sweep: self1 = inputSum(322) + 1000 - fee
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [322],
        recipients: [Tuple(true, 50), Tuple(true, 100)],
        changeAmount: 0,
        fee: 172,
        vSize: 172,
        additionalSpendable: [1000, 2000, 3000],
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isTrue);
      expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
      expect(baselineResult.addedInputs, isNotNull);
      expect(baselineResult.addedInputs!.length, 1);
      expect(baselineResult.addedInputs![0].amount, 3000);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.addedInputs, isNotNull);
      expect(buildResult.addedInputs!.length, 1);
      expect(baselineResult.addedInputs![0].amount, 3000);
      expect(buildResult.deficitAmount, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      final tx = buildResult.transaction!;
      // self2는 제거됨
      expect(tx.outputs.any((o) => o.getAddress() == creator.receiveAddressList[2]), isFalse);
      // self1은 sweep되어 있음
      final selfOutput1InTx = tx.outputs.where((o) => o.getAddress() == creator.receiveAddressList[1]).toList();
      expect(selfOutput1InTx.length, 1);
      expect(selfOutput1InTx.first.amount, greaterThan(546));

      expectRbfMinimumCondition(buildResult, pendingTx);
    });
    test('Self2 / change enough', () async {
      // additionalSpendable 있지만 change가 충분하여 사용 안 함
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [20000],
        recipients: [Tuple(true, 5000), Tuple(true, 3000)],
        changeAmount: 11750,
        fee: 250,
        vSize: 250,
        additionalSpendable: [1000],
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isFalse);
      expect(baselineResult.isOnlyChangeOutputUsed, isTrue);
      expect(baselineResult.addedInputs, isNull);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.isSelfOutputsUsed, isFalse);
      expect(buildResult.isOnlyChangeOutputUsed, isTrue);
      expect(buildResult.addedInputs, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      final tx = buildResult.transaction!;
      expect(tx.outputs.any((o) => o.getAddress() == creator.receiveAddressList[1] && o.amount == 5000), isTrue);
      expect(tx.outputs.any((o) => o.getAddress() == creator.receiveAddressList[2] && o.amount == 3000), isTrue);

      expectRbfMinimumCondition(buildResult, pendingTx);
    });
    test('Self1 / change not Enough / use 1 enough selfOutput', () async {
      // additionalSpendable 있지만 selfOutput sweep으로 충분
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [10000],
        recipients: [Tuple(true, 9750)],
        changeAmount: 109,
        fee: 141,
        vSize: 141,
        additionalSpendable: [1000],
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isTrue);
      expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
      expect(baselineResult.addedInputs, isNull);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.addedInputs, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      final tx = buildResult.transaction!;
      final selfOutput1InTx = tx.outputs.where((o) => o.getAddress() == creator.receiveAddressList[1]).toList();
      expect(selfOutput1InTx.length, 1);
      expect(selfOutput1InTx.first.amount, lessThan(9750));
      expect(tx.outputs.any((o) => o.getAddress() == creator.changeAddressList[0]), isFalse);

      expectRbfMinimumCondition(buildResult, pendingTx);
    });
    test('Self2 / change not Enough / use 2 enough selfOutputs', () async {
      // additionalSpendable 있지만 selfOutput 2개로 충분
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [6000],
        recipients: [Tuple(true, 5500), Tuple(true, 159)],
        changeAmount: 100,
        fee: 241,
        vSize: 172,
        additionalSpendable: [1000],
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isTrue);
      expect(baselineResult.addedInputs, isNull);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.addedInputs, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      final tx = buildResult.transaction!;
      expect(tx.outputs.any((o) => o.getAddress() == creator.receiveAddressList[2]), isFalse);
      final selfOutput1InTx = tx.outputs.where((o) => o.getAddress() == creator.receiveAddressList[1]).toList();
      expect(selfOutput1InTx.length, 1);
      // Sweep으로 오히려 금액이 늘어남: 5647
      expect(selfOutput1InTx.first.amount, greaterThan(5500));

      expectRbfMinimumCondition(buildResult, pendingTx);
    });

    test('Self1 / change not Enough / use 1 selfOutput, 1 enough additionalUtxo', () async {
      // 1-in/2-out (self1=575, change=84), fee=341, vSize=141
      // newTxVSize = 141 (changeOutput exists)
      // additionalFee=141, change(84) < 141 → deficit=57
      // self1(575): 575-57=518 < dustLimit → set to 547, leftDeficit=57-(575-547)=29
      // additionalUtxo(1000)로 sweep: self1 = inputSum(1000) + 1000 - fee
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [1000],
        recipients: [Tuple(true, 575)],
        changeAmount: 84,
        fee: 341,
        vSize: 141,
        additionalSpendable: [1000, 547],
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isTrue);
      expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
      expect(baselineResult.addedInputs, isNotNull);
      expect(baselineResult.addedInputs!.length, 1);
      expect(baselineResult.addedInputs![0].amount, 1000);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.addedInputs, isNotNull);
      expect(buildResult.addedInputs!.length, 1);
      expect(baselineResult.addedInputs![0].amount, 1000);
      expect(buildResult.deficitAmount, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      final tx = buildResult.transaction!;
      // self1은 sweep, change는 드롭
      final selfOutput1InTx = tx.outputs.where((o) => o.getAddress() == creator.receiveAddressList[1]).toList();
      expect(selfOutput1InTx.length, 1);
      expect(selfOutput1InTx.first.amount, greaterThan(546));
      expect(tx.outputs.any((o) => o.getAddress() == creator.changeAddressList[0]), isFalse);

      expectRbfMinimumCondition(buildResult, pendingTx);
    });
    test('Self2 / change not Enough / use 2 selfOutputs, 1 enough additionalUtxos', () async {
      // 1-in/3-out (self1=50, self2=30, change=50), fee=200, vSize=200
      // newTxVSize = 200 (changeOutput exists)
      // additionalFee=200, change(50) < 200 → deficit=150
      // minimumFeeRate=2.0, feeSavedByOneRemoval=ceil(31*2.0)=62
      // self2(30) 제거: leftDeficit=150-(30+62)=58 > 0
      // self1(50) ≤ 547 → break, leftDeficit=58
      // additionalUtxo(1000)로 sweep: self1 = inputSum(330) + 1000 - fee
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [330],
        recipients: [Tuple(true, 50), Tuple(true, 30)],
        changeAmount: 50,
        fee: 200,
        vSize: 200,
        additionalSpendable: [1000],
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isTrue);
      expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
      expect(baselineResult.addedInputs, isNotNull);
      expect(baselineResult.addedInputs!.length, 1);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.addedInputs, isNotNull);
      expect(buildResult.addedInputs!.length, 1);
      expect(buildResult.deficitAmount, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));

      final tx = buildResult.transaction!;
      // self2는 제거됨
      expect(tx.outputs.any((o) => o.getAddress() == creator.receiveAddressList[2]), isFalse);
      // self1은 sweep되어 있음
      final selfOutput1InTx = tx.outputs.where((o) => o.getAddress() == creator.receiveAddressList[1]).toList();
      expect(selfOutput1InTx.length, 1);
      expect(selfOutput1InTx.first.amount, greaterThan(546));

      expectRbfMinimumCondition(buildResult, pendingTx);
    });

    test('Self2 / change not Enough / use 2 selfOutputs, 1  additionalUtxos but failed', () async {
      final (pendingTx, rbfBuilder) = creator.createRbfBuilder(
        inputAmounts: [330],
        recipients: [Tuple(true, 50), Tuple(true, 30)],
        changeAmount: 50,
        fee: 200,
        vSize: 200,
        additionalSpendable: [1000],
      );

      final RbfBuildResult baselineResult = rbfBuilder.getBaselineTransaction();

      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isSelfOutputsUsed, isTrue);
      expect(baselineResult.isOnlyChangeOutputUsed, isFalse);
      expect(baselineResult.addedInputs, isNotNull);
      expect(baselineResult.addedInputs!.length, 1);
      expect(baselineResult.deficitAmount, isNull);
      expectRbfMinimumCondition(baselineResult, pendingTx);

      final RbfBuildResult buildResult = rbfBuilder.build(newFeeRate: baselineResult.minimumFeeRate + 10000);

      expect(buildResult.isSuccess, isFalse);
      expect(buildResult.transaction, isNull);
      expect(buildResult.exception, isNotNull);
      expect(buildResult.exception, isA<InsufficientBalanceException>());
      expect(buildResult.isSelfOutputsUsed, isTrue);
      expect(buildResult.addedInputs, isNotNull);
      expect(buildResult.addedInputs!.length, 1);
      expect(buildResult.deficitAmount, isNotNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));
    });
  });
}
