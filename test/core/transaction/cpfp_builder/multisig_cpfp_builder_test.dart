import 'package:coconut_wallet/core/exceptions/cpfp_creation/cpfp_creation_exception.dart';
import 'package:coconut_wallet/core/transaction/fee_bumping/cpfp_builder.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_list_item.dart';
import 'package:coconut_wallet/utils/fee_rate_util.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/wallet_mock.dart';
import 'setup_util.dart';

void main() {
  MultisigWalletListItem multisigWallet = WalletMock.createMultiSigWalletItem();

  final creator = CpfpBuilderCreator(multisigWallet);

  group('멀티시그지갑 - getBaselineTransaction', () {
    test('1 output / parent overpaid / minimumFeeRate ≈ 1.0', () {
      // 멀티시그(2-of-3) input vSize ≈ 105 vB
      // estimatedChildVSize ≈ 147 vB (1 input, 1 output, P2WSH)
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [50000],
        parentFee: 1000,
        parentVSize: 200.0,
        minimumNetworkFeeRate: 1.0,
      );

      final CpfpBuildResult result = cpfpBuilder.getBaselineTransaction();

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.exception, isNull);
      expect(result.minimumFeeRate, equals(1.0));
      expect(result.packageFeeRate, greaterThanOrEqualTo(1.0));
      // parentFee(1000) >= parentVSize(200) * minimumFeeRate(1.0) → CPFP 불필요
      expect(result.isCpfpNeeded, isFalse);

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
      // 멀티시그는 input vSize가 커서 child가 더 많은 수수료를 부담해야 함
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [50000],
        parentFee: 50,
        parentVSize: 200.0,
        minimumNetworkFeeRate: 2.0,
      );

      final CpfpBuildResult result = cpfpBuilder.getBaselineTransaction();

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.exception, isNull);
      expect(result.minimumFeeRate, greaterThan(2.0));
      expect(result.packageFeeRate, greaterThanOrEqualTo(2.0));
      // parentFee(50) < parentVSize(200) * minimumFeeRate(2.0) → CPFP 필요
      expect(result.isCpfpNeeded, isTrue);

      final int childFee = result.estimatedFee!;
      final double childVSize = result.estimatedVSize;
      expect(
        result.packageFeeRate,
        equals(FeeRateUtils.roundToTwoDecimals((pendingTx.fee + childFee) / (pendingTx.vSize + childVSize))),
      );
    });

    test('2 outputs / first UTXO enough for baseline / success', () {
      // 수신 UTXO 2개 → baseline에서 1개만 사용하여 성공
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [50000, 40000],
        parentFee: 50,
        parentVSize: 250.0,
        minimumNetworkFeeRate: 2.0,
      );

      final CpfpBuildResult result = cpfpBuilder.getBaselineTransaction();

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.transaction!.inputs.length, equals(1));
      expect(result.transaction!.outputs.length, equals(1));
      expect(result.packageFeeRate, greaterThanOrEqualTo(2.0));
      expect(result.isCpfpNeeded, isTrue);

      final int childFee = result.estimatedFee!;
      final double childVSize = result.estimatedVSize;
      expect(
        result.packageFeeRate,
        equals(FeeRateUtils.roundToTwoDecimals((pendingTx.fee + childFee) / (pendingTx.vSize + childVSize))),
      );
    });

    test('1 output / insufficient funds / failure', () {
      // 멀티시그 input vSize가 크므로 수수료가 높아져서 소액으로는 실패
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [547],
        parentFee: 50,
        parentVSize: 200.0,
        minimumNetworkFeeRate: 2.0,
      );

      final CpfpBuildResult result = cpfpBuilder.getBaselineTransaction();

      expect(result.isFailure, isTrue);
      expect(result.transaction, isNull);
      expect(result.exception, isNotNull);
      expect(result.exception, isA<CpfpInsufficientFundsException>());
      expect(result.packageFeeRate, equals(2.0));
      expect(result.deficitAmount, isNotNull);
      expect(result.isCpfpNeeded, isTrue);
    });
  });

  group('멀티시그지갑 - build', () {
    test('baseline.minimumFeeRate보다 작은 수수료율 입력', () {
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [50000],
        parentFee: 1000,
        parentVSize: 200.0,
        minimumNetworkFeeRate: 2.0,
      );

      final CpfpBuildResult baselineResult = cpfpBuilder.getBaselineTransaction();
      expect(baselineResult.isSuccess, isTrue);
      expect(baselineResult.isCpfpNeeded, isFalse);

      final CpfpBuildResult buildResult = cpfpBuilder.build(newFeeRate: baselineResult.minimumFeeRate - 0.01);
      expect(buildResult.isSuccess, isTrue); // 네트워크 상 최소 추천 수수료율을 기준으로 minimumFeeRate을 계산했기 때문에 더 작은 값을 입력해도 상관없음
    });

    test('minimumFeeRate / success / packageFeeRate is correct', () {
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [50000],
        parentFee: 50,
        parentVSize: 200.0,
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
      expect(buildResult.isCpfpNeeded, isTrue);

      final int childFee = buildResult.estimatedFee!;
      final double childVSize = buildResult.estimatedVSize;
      expect(
        buildResult.packageFeeRate,
        equals(FeeRateUtils.roundToTwoDecimals((pendingTx.fee + childFee) / (pendingTx.vSize + childVSize))),
      );
    });

    test('higher feeRate / success / packageFeeRate increases', () {
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [50000],
        parentFee: 50,
        parentVSize: 200.0,
        minimumNetworkFeeRate: 2.0,
      );

      final CpfpBuildResult baselineResult = cpfpBuilder.getBaselineTransaction();
      expect(baselineResult.isSuccess, isTrue);

      final CpfpBuildResult highFeeResult = cpfpBuilder.build(newFeeRate: 5.0);

      expect(highFeeResult.isSuccess, isTrue);
      expect(highFeeResult.minimumFeeRate, equals(baselineResult.minimumFeeRate));
      expect(highFeeResult.packageFeeRate, greaterThan(baselineResult.packageFeeRate));
      expect(highFeeResult.isCpfpNeeded, isTrue);
    });

    test('insufficient funds at high feeRate / isFailure', () {
      // 멀티시그는 input vSize가 크므로 높은 수수료율에서 더 빨리 실패
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [1000],
        parentFee: 50,
        parentVSize: 200.0,
        minimumNetworkFeeRate: 1.0,
      );

      final CpfpBuildResult baselineResult = cpfpBuilder.getBaselineTransaction();
      expect(baselineResult.isSuccess, isTrue);

      final CpfpBuildResult buildResult = cpfpBuilder.build(newFeeRate: 10.0);

      expect(buildResult.isFailure, isTrue);
      expect(buildResult.transaction, isNull);
      expect(buildResult.exception, isA<CpfpInsufficientFundsException>());
      expect(buildResult.deficitAmount, greaterThan(0));
      expect(buildResult.isCpfpNeeded, isTrue);
    });

    test('2 outputs / baseline use 1, build use 2 as inputs at high feeRate / success', () {
      // 멀티시그는 input vSize가 크므로 금액을 적게 설정해야 2번째 input이 필요해짐
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [5000, 4000],
        parentFee: 50,
        parentVSize: 250.0,
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

      // 높은 feeRate로 빌드 → 1개 input의 금액(5000)으로 부족하여 2번째 input 추가
      final CpfpBuildResult buildResult = cpfpBuilder.build(newFeeRate: result.minimumFeeRate + 25);
      expect(buildResult.isSuccess, isTrue);
      expect(buildResult.transaction, isNotNull);
      expect(buildResult.transaction!.inputs.length, equals(2));
      expect(buildResult.transaction!.outputs.length, equals(1));
      expect(buildResult.packageFeeRate, greaterThanOrEqualTo(2.0));
      expect(buildResult.isCpfpNeeded, isTrue);
    });
  });

  group('멀티시그지갑 - additionalSpendable', () {
    test('changeAdditionalSpendable로 나중에 추가하여 성공', () {
      // 수신 금액만으로는 부족 → baseline 실패
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [547],
        parentFee: 50,
        parentVSize: 200.0,
        minimumNetworkFeeRate: 2.0,
      );

      final CpfpBuildResult baselineResult = cpfpBuilder.getBaselineTransaction();
      expect(baselineResult.isFailure, isTrue);
      expect(baselineResult.exception, isA<CpfpInsufficientFundsException>());

      // additionalSpendable 추가 후 재시도 → 성공
      final additionalUtxos = creator.createAdditionalUtxos(amounts: [50000]);
      final CpfpBuildResult result = cpfpBuilder.changeAdditionalSpendable(additionalUtxos);

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.addedInputs, isNotNull);
      expect(result.addedInputs!.length, equals(1));
      expect(result.packageFeeRate, greaterThanOrEqualTo(2.0));
      expect(result.isCpfpNeeded, isTrue);
    });

    test('처음부터 additionalSpendable을 넘겨서 성공 / addedInputs notNull / 큰 UTXO부터 사용됨', () {
      // 수신 금액만으로는 부족하지만 additionalSpendable 포함하여 성공
      final (pendingTx, cpfpBuilder) = creator.createCpfpBuilder(
        receivedAmounts: [547],
        parentFee: 50,
        parentVSize: 200.0,
        minimumNetworkFeeRate: 2.0,
        additionalSpendables: [50000, 100000],
      );

      final CpfpBuildResult result = cpfpBuilder.getBaselineTransaction();

      expect(result.isSuccess, isTrue);
      expect(result.transaction, isNotNull);
      expect(result.addedInputs, isNotNull);
      expect(result.addedInputs!.length, equals(1));
      expect(result.addedInputs![0].amount, equals(100000));
      expect(result.packageFeeRate, greaterThanOrEqualTo(2.0));
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
