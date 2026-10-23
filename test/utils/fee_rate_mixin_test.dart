import 'dart:async';

import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/utils/fee_rate_mixin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class TestFeeModel extends ChangeNotifier with FeeRateMixin {
  final response = Completer<RecommendedFee?>();

  @override
  Future<RecommendedFee?> loadRecommendedFees() => response.future;
}

void main() {
  for (final succeeds in [true, false]) {
    test('dispose 후 수수료 ${succeeds ? '성공' : '실패'} 응답은 무시한다', () async {
      final model = TestFeeModel();
      var notifications = 0;
      var updates = 0;
      model.addListener(() => notifications++);
      final pending = model.fetchRecommendedFees(currentFeeRateText: '', onDefaultFeeRateSet: (_) => updates++);
      expect(notifications, 1);
      model.dispose();
      model.response.complete(succeeds ? RecommendedFee(3, 2, 1, 1, 1) : null);
      expect(await pending, isFalse);
      expect(notifications, 1);
      expect(updates, 0);
      expect(model.minimumFeeRate, isNull);
      expect(model.feeInfos.every((fee) => fee.satsPerVb == null), isTrue);
    });
  }

  test('살아 있는 화면에는 수수료와 기본 입력값을 반영한다', () async {
    final model = TestFeeModel();
    addTearDown(model.dispose);
    String? defaultFee;
    final pending = model.fetchRecommendedFees(
      currentFeeRateText: '',
      onDefaultFeeRateSet: (value) => defaultFee = value,
    );
    model.response.complete(RecommendedFee(3, 2, 1, 1, 1));
    expect(await pending, isTrue);
    expect(defaultFee, '2.0');
    expect(model.minimumFeeRate, 1);
    expect(model.recommendedFeeFetchStatus, RecommendedFeeFetchStatus.succeed);
  });
}
