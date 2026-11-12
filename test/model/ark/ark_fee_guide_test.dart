import 'package:coconut_wallet/model/ark/ark_fee_guide.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('수수료율은 퍼센트로, 구간이 다르면 최솟값~최댓값으로 표시한다', () {
    expect(const ArkFeeRate(minPpm: 0, maxPpm: 0).percentText, '0');
    expect(const ArkFeeRate(minPpm: 2000, maxPpm: 5000).percentText, '0.2~0.5');
    expect(const ArkFeeRate(minPpm: 4000, maxPpm: 4000).percentText, '0.4');
    expect(const ArkFeeRate(minPpm: 125, maxPpm: 125).percentText, '0.01');
    expect(const ArkFeeRate(minPpm: 15000, maxPpm: 15000).percentText, '1.5');
  });
}
