import 'package:coconut_wallet/utils/fee_rate_mixin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _FeeRateNotifier extends ChangeNotifier with FeeRateMixin {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('추천 수수료를 받아오는 도중 dispose되면 이후 알림·콜백 없이 false를 반환한다', () async {
    final notifier = _FeeRateNotifier();
    var defaultFeeRateSetCount = 0;

    final fetch = notifier.fetchRecommendedFees(
      currentFeeRateText: '',
      onDefaultFeeRateSet: (_) => defaultFeeRateSetCount++,
    );
    notifier.dispose();

    expect(await fetch, isFalse);
    expect(defaultFeeRateSetCount, 0);
  });
}
