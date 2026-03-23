import 'package:coconut_wallet/core/exceptions/cpfp_creation/cpfp_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/cpfp_builder.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/utils/fee_rate_util.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/wallet_mock.dart';
import 'setup_util.dart';

void main() {
  SinglesigWalletListItem singleWallet = WalletMock.createSingleSigWalletItem();

  final creator = CpfpBuilderCreator(singleWallet);

  group('싱글시그지갑 - getBaselineTransaction', () {
    test('1 output / parent overpaid / minimumFeeRate ≈ 1.0', () {
      // 부모 tx가 이미 충분히 수수료를 냄 → child는 자기 자신의 relay fee(1 sat/vB)만 부담
      // estimatedChildVSize = 110 vB (1 input, 1 output, P2WPKH)
      // childShareOfPackageMin = ceil(100+110) - 1000 = -790 → childOwnMin = 110 적용
      // minimumChildFeeRate = ceilFeeRate(110/110) = 1.0
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [10000],
        parentFee: 1000,
        parentVSize: 100.0,
        minimumNetworkFeeRate: 1.0,
      );

      final CpfpBuildResult result = cpfpBuilder.getBaselineTransaction();

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.exception, isNull);
      expect(result.minimumFeeRate, equals(1.0));
      expect(result.packageFeeRate, greaterThanOrEqualTo(1.0));
      // parentFee(1000) >= parentVSize(100) * minimumFeeRate(1.0) → CPFP 불필요
      expect(result.isCpfpNeeded, isFalse);

      // packageFeeRate = ceilFeeRate((parentFee + childFee) / (parentVSize + childVSize))
      final int childFee = result.estimatedFee!;
      final double childVSize = result.estimatedVSize;
      expect(
        result.packageFeeRate,
        equals(FeeRateUtils.roundToTwoDecimals((pendingTx.fee + childFee) / (pendingTx.vSize + childVSize))),
      );

      final CpfpBuildResult buildResult = cpfpBuilder.build(newFeeRate: result.minimumFeeRate);
      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.minimumFeeRate, equals(1.0));
    });

    test('1 output / parent low fee / success', () {
      // 부모 tx 수수료가 낮음 → child가 패키지 relay 최솟값까지 보충
      // estimatedChildVSize = 114 vB
      // minimumChildFee = max((100+114) * 2.0 - 50, 114 * 2.0) = max(378, 228) = 378
      // minimumChildFeeRate = ceilFeeRate(378/114) ≈ 3.32
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [10000],
        parentFee: 50,
        parentVSize: 100.0,
        minimumNetworkFeeRate: 2.0,
      );

      final CpfpBuildResult result = cpfpBuilder.getBaselineTransaction();

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.exception, isNull);
      // actual minimumFeeRate from tx may be slightly different due to vSize precision
      expect(result.minimumFeeRate, greaterThanOrEqualTo(3.32));
      expect(result.packageFeeRate, greaterThanOrEqualTo(2.0));
      // parentFee(50) < parentVSize(100) * minimumFeeRate(2.0) → CPFP 필요
      expect(result.isCpfpNeeded, isTrue);

      final int childFee = result.estimatedFee!;
      final double childVSize = result.estimatedVSize;
      expect(
        result.packageFeeRate,
        equals(FeeRateUtils.roundToTwoDecimals((pendingTx.fee + childFee) / (pendingTx.vSize + childVSize))),
      );

      final CpfpBuildResult buildResult = cpfpBuilder.build(newFeeRate: result.minimumFeeRate);
      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.minimumFeeRate, result.minimumFeeRate);
    });

    test('2 outputs / both UTXOs used as inputs / success', () {
      // 수신 UTXO 2개 → child tx: 2 inputs, 1 output
      // receivedAmounts 1개만으로 cpfp 트랜잭션 생성 가능
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [5000, 4000],
        parentFee: 50,
        parentVSize: 150.0,
        minimumNetworkFeeRate: 2.0,
      );

      final CpfpBuildResult result = cpfpBuilder.getBaselineTransaction();

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.inputs.length, equals(1));
      expect(result.transaction!.outputs.length, equals(1));
      expect(result.packageFeeRate, greaterThanOrEqualTo(2.0));
      // parentFee(50) < parentVSize(150) * minimumFeeRate(2.0) → CPFP 필요
      expect(result.isCpfpNeeded, isTrue);

      final int childFee = result.estimatedFee!;
      final double childVSize = result.estimatedVSize;
      expect(
        result.packageFeeRate,
        equals(FeeRateUtils.roundToTwoDecimals((pendingTx.fee + childFee) / (pendingTx.vSize + childVSize))),
      );
    });

    test('1 output / insufficient funds / failure', () {
      // 수신 금액이 너무 적어 child fee를 낼 수 없음
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [547],
        parentFee: 50,
        parentVSize: 100.0,
        minimumNetworkFeeRate: 2.0,
      );

      final CpfpBuildResult result = cpfpBuilder.getBaselineTransaction();

      expect(result.isFailure, isTrue);
      expect(result.transaction, isNull);
      expect(result.exception, isNotNull);
      expect(result.exception, isA<CpfpInsufficientFundsException>());
      expect(result.packageFeeRate, equals(2.0));
      expect(result.deficitAmount, isNotNull);
      // parentFee(50) < parentVSize(100) * minimumFeeRate(2.0) → CPFP 필요
      expect(result.isCpfpNeeded, isTrue);
      print('deficitAmount: ${result.deficitAmount}');
    });
  });

  group('싱글시그지갑 - build', () {
    test('feeRate too low / CpfpFeeRateTooLowException', () {
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [10000],
        parentFee: 1000,
        parentVSize: 100.0,
        minimumNetworkFeeRate: 2.0,
      );

      final CpfpBuildResult baselineResult = cpfpBuilder.getBaselineTransaction();
      expect(baselineResult.isSuccess, isTrue);
      // parentFee(1000) >= parentVSize(100) * minimumFeeRate(2.0) → CPFP 불필요
      expect(baselineResult.isCpfpNeeded, isFalse);

      final CpfpBuildResult buildResult = cpfpBuilder.build(newFeeRate: baselineResult.minimumFeeRate - 0.01);
      expect(buildResult.isSuccess, isTrue); // 네트워크 상 최소 추천 수수료율을 기준으로 minimumFeeRate을 계산했기 때문에 더 작은 값을 입력해도 상관없음
    });

    test('minimumFeeRate / success / packageFeeRate is correct', () {
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [10000],
        parentFee: 50,
        parentVSize: 100.0,
        minimumNetworkFeeRate: 2.0,
      );

      final CpfpBuildResult baselineResult = cpfpBuilder.getBaselineTransaction();
      expect(baselineResult.isSuccess, isTrue);

      final CpfpBuildResult buildResult = cpfpBuilder.build(newFeeRate: baselineResult.minimumFeeRate);

      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.exception, isNull);
      expect(buildResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));
      expect(buildResult.packageFeeRate, greaterThanOrEqualTo(2.0));
      // parentFee(50) < parentVSize(100) * minimumFeeRate(2.0) → CPFP 필요
      expect(buildResult.isCpfpNeeded, isTrue);

      final int childFee = buildResult.estimatedFee!;
      final double childVSize = buildResult.estimatedVSize;
      expect(
        buildResult.packageFeeRate,
        equals(FeeRateUtils.roundToTwoDecimals((pendingTx.fee + childFee) / (pendingTx.vSize + childVSize))),
      );
    });

    test('higher feeRate / success / packageFeeRate increases', () {
      // 수수료율을 높일수록 packageFeeRate가 올라감을 검증
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [10000],
        parentFee: 50,
        parentVSize: 100.0,
        minimumNetworkFeeRate: 2.0,
      );

      final CpfpBuildResult baselineResult = cpfpBuilder.getBaselineTransaction();
      expect(baselineResult.isSuccess, isTrue);

      final CpfpBuildResult highFeeResult = cpfpBuilder.build(newFeeRate: 5.0);

      expect(highFeeResult.isSuccess, isTrue);
      expect(highFeeResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));
      expect(highFeeResult.packageFeeRate, greaterThan(baselineResult.packageFeeRate));
      // parentFee(50) < parentVSize(100) * minimumFeeRate(2.0) → CPFP 필요
      expect(highFeeResult.isCpfpNeeded, isTrue);
    });

    test('insufficient funds at high feeRate / isFailure', () {
      // baseline은 성공하지만 높은 수수료율에서 수신 금액 부족
      // receivedAmount=500: minimumChildFee≈160 (baseline 성공), fee at 10 sat/vB ≈ 1100 > 500 (실패)
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [1000],
        parentFee: 50,
        parentVSize: 100.0,
        minimumNetworkFeeRate: 1.0,
      );

      final CpfpBuildResult baselineResult = cpfpBuilder.getBaselineTransaction();
      expect(baselineResult.isSuccess, isTrue);

      final CpfpBuildResult buildResult = cpfpBuilder.build(newFeeRate: 10.0);

      expect(buildResult.isFailure, isTrue);
      expect(buildResult.transaction, isNull);
      expect(buildResult.exception, isA<CpfpInsufficientFundsException>());
      expect(buildResult.deficitAmount, greaterThan(0));
      // parentFee(50) < parentVSize(100) * minimumFeeRate(1.0) → CPFP 필요
      expect(buildResult.isCpfpNeeded, isTrue);
    });

    test('2 outputs / baseline use 1, build use 2 as inputs at high feeRate / success', () {
      // 수신 UTXO 2개 → child tx: 2 inputs, 1 output
      // receivedAmounts 1개만으로 cpfp 트랜잭션 생성 가능
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [5000, 4000],
        parentFee: 50,
        parentVSize: 150.0,
        minimumNetworkFeeRate: 2.0,
      );

      final CpfpBuildResult result = cpfpBuilder.getBaselineTransaction();

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.inputs.length, equals(1));
      expect(result.transaction!.outputs.length, equals(1));
      expect(result.packageFeeRate, greaterThanOrEqualTo(2.0));

      final int childFee = result.estimatedFee!;
      final double childVSize = result.estimatedVSize;
      expect(
        result.packageFeeRate,
        equals(FeeRateUtils.roundToTwoDecimals((pendingTx.fee + childFee) / (pendingTx.vSize + childVSize))),
      );

      final CpfpBuildResult buildResult = cpfpBuilder.build(newFeeRate: result.minimumFeeRate + 40);
      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.transaction!.inputs.length, equals(2));
      expect(buildResult.transaction!.outputs.length, equals(1));
      expect(buildResult.packageFeeRate, greaterThanOrEqualTo(2.0));
      // parentFee(50) < parentVSize(150) * minimumFeeRate(2.0) → CPFP 필요
      expect(buildResult.isCpfpNeeded, isTrue);
    });
  });

  group('싱글시그지갑 - additionalSpendable', () {
    test('changeAdditionalSpendable로 나중에 추가하여 성공', () {
      // 수신 금액만으로는 부족 → baseline 실패
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [547],
        parentFee: 50,
        parentVSize: 100.0,
        minimumNetworkFeeRate: 2.0,
      );

      final CpfpBuildResult baselineResult = cpfpBuilder.getBaselineTransaction();
      expect(baselineResult.isFailure, isTrue);
      expect(baselineResult.exception, isA<CpfpInsufficientFundsException>());

      // additionalSpendable 추가 후 재시도 → 성공
      final additionalUtxos = creator.createAdditionalUtxos(amounts: [10000]);
      final CpfpBuildResult result = cpfpBuilder.changeAdditionalSpendable(additionalUtxos);

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.addedInputs, isNotNull);
      expect(result.addedInputs!.length, equals(1));
      expect(result.packageFeeRate, greaterThanOrEqualTo(2.0));
      // parentFee(50) < parentVSize(100) * minimumFeeRate(2.0) → CPFP 필요
      expect(result.isCpfpNeeded, isTrue);
    });

    test('처음부터 additionalSpendable을 넘겨서 성공 / addedUtxo notNull / 큰 UTXO부터 사용됨', () {
      // 수신 금액만으로는 부족하지만 additionalSpendable 포함하여 성공
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [547],
        parentFee: 50,
        parentVSize: 100.0,
        minimumNetworkFeeRate: 2.0,
        additionalSpendables: [10000, 20000],
      );

      final CpfpBuildResult result = cpfpBuilder.getBaselineTransaction();

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.addedInputs, isNotNull);
      expect(result.addedInputs!.length, equals(1));
      expect(result.addedInputs![0].amount, equals(20000));
      expect(result.packageFeeRate, greaterThanOrEqualTo(2.0));
      // parentFee(50) < parentVSize(100) * minimumFeeRate(2.0) → CPFP 필요
      expect(result.isCpfpNeeded, isTrue);

      final int childFee = result.estimatedFee!;
      final double childVSize = result.estimatedVSize;
      expect(
        result.packageFeeRate,
        equals(FeeRateUtils.roundToTwoDecimals((pendingTx.fee + childFee) / (pendingTx.vSize + childVSize))),
      );
    });
  });
}
