import 'dart:ui';

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/utility/p2p_calculator_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePreferenceProvider extends Fake implements PreferenceProvider {
  @override
  final FiatCode selectedFiat;
  @override
  final bool isBtcUnit;

  FakePreferenceProvider({this.selectedFiat = FiatCode.KRW, this.isBtcUnit = false});

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class FakeConnectivityProvider extends Fake implements ConnectivityProvider {
  @override
  bool isInternetOn;

  FakeConnectivityProvider({this.isInternetOn = true});

  @override
  bool get isInternetOff => !isInternetOn;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

class FakePriceProvider extends Fake implements PriceProvider {
  final Map<FiatCode, int?> _prices;

  FakePriceProvider({int? defaultPrice})
    : _prices = {FiatCode.KRW: defaultPrice, FiatCode.USD: defaultPrice, FiatCode.JPY: defaultPrice};

  FakePriceProvider.withPrices(this._prices);

  @override
  int? getBitcoinPriceForFiat(FiatCode fiatCode) => _prices[fiatCode];

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}

void main() {
  const int defaultBtcPriceKrw = 140000000;

  P2PCalculatorViewModel createViewModel({
    FiatCode fiatCode = FiatCode.KRW,
    bool isBtcUnit = false,
    int? btcPrice = defaultBtcPriceKrw,
    bool isNetworkOn = true,
  }) {
    final prefProvider = FakePreferenceProvider(selectedFiat: fiatCode, isBtcUnit: isBtcUnit);
    final connectivityProvider = FakeConnectivityProvider(isInternetOn: isNetworkOn);
    final priceProvider = FakePriceProvider(defaultPrice: btcPrice);

    return P2PCalculatorViewModel(prefProvider, connectivityProvider, priceProvider);
  }

  group('calculateSatsFromFiat - Fiat → Sats 변환', () {
    test('[Fiat -> Sats] 기본 변환: 1,000,000원을 수수료 1%로 Sats 변환', () {
      final viewModel = createViewModel();
      // (1,000,000 × 0.99) / 140,000,000 × 100,000,000 = 707,142.857... → 707,143
      expect(viewModel.calculateSatsFromFiat(1000000), 707143);
    });

    test('[Fiat -> Sats] 수수료 0%: 수수료 없이 변환', () {
      final viewModel = createViewModel();
      viewModel.setFeeRate(0.0);
      // 1,000,000 / 140,000,000 × 100,000,000 = 714,285.714... → 714,286
      expect(viewModel.calculateSatsFromFiat(1000000), 714286);
    });

    test('[Fiat -> Sats] 수수료 5%: 높은 수수료로 변환', () {
      final viewModel = createViewModel();
      viewModel.setFeeRate(5.0);
      // (1,000,000 × 0.95) / 140,000,000 × 100,000,000 = 678,571.428... → 678,571
      expect(viewModel.calculateSatsFromFiat(1000000), 678571);
    });

    test('[Fiat -> Sats] 수수료 10%: 매우 높은 수수료로 변환', () {
      final viewModel = createViewModel();
      viewModel.setFeeRate(10.0);
      // (1,000,000 × 0.90) / 140,000,000 × 100,000,000 = 642,857.142... → 642,857
      expect(viewModel.calculateSatsFromFiat(1000000), 642857);
    });

    test('[Fiat -> Sats] 소액 입력: 1,000원 변환', () {
      final viewModel = createViewModel();
      // (1,000 × 0.99) / 140,000,000 × 100,000,000 = 707.142... → 707
      expect(viewModel.calculateSatsFromFiat(1000), 707);
    });

    test('[Fiat -> Sats] 고액 입력: 1억원 변환', () {
      final viewModel = createViewModel();
      // (100,000,000 × 0.99) / 140,000,000 × 100,000,000 = 70,714,285.714... → 70,714,286
      expect(viewModel.calculateSatsFromFiat(100000000), 70714286);
    });

    test('[Fiat -> Sats] 0원 입력 시 0 sats 반환', () {
      final viewModel = createViewModel();
      expect(viewModel.calculateSatsFromFiat(0), 0);
    });

    test('[Fiat -> Sats] 최소 금액: 1원 입력 시 0보다 큰 결과 반환', () {
      final viewModel = createViewModel();
      // (1 × 0.99) / 140,000,000 × 100,000,000 = 0.7071... → 1
      expect(viewModel.calculateSatsFromFiat(1), 1);
    });

    test('[Fiat -> Sats] 오프라인 시 KRW 기본 가격(20,000,000) 사용', () {
      final viewModel = createViewModel(isNetworkOn: false);
      // (1,000,000 × 0.99) / 20,000,000 × 100,000,000 = 4,950,000
      expect(viewModel.calculateSatsFromFiat(1000000), 4950000);
    });

    test('[Fiat -> Sats] 수수료율 변경 후 동일 금액 재계산 시 결과 변경 확인', () {
      final viewModel = createViewModel();

      final satsWithFee1 = viewModel.calculateSatsFromFiat(1000000);
      expect(satsWithFee1, 707143);

      viewModel.setFeeRate(3.0);
      final satsWithFee3 = viewModel.calculateSatsFromFiat(1000000);
      // (1,000,000 × 0.97) / 140,000,000 × 100,000,000 = 692,857.142... → 692,857
      expect(satsWithFee3, 692857);

      expect(satsWithFee1, greaterThan(satsWithFee3));
    });

    test('[Fiat -> Sats] 수수료가 높을수록 받는 Sats가 줄어드는지 확인', () {
      final viewModel = createViewModel();
      const fiatAmount = 1000000;

      viewModel.setFeeRate(0.0);
      final satsNoFee = viewModel.calculateSatsFromFiat(fiatAmount);

      viewModel.setFeeRate(1.0);
      final satsFee1 = viewModel.calculateSatsFromFiat(fiatAmount);

      viewModel.setFeeRate(5.0);
      final satsFee5 = viewModel.calculateSatsFromFiat(fiatAmount);

      viewModel.setFeeRate(10.0);
      final satsFee10 = viewModel.calculateSatsFromFiat(fiatAmount);

      expect(satsNoFee, greaterThan(satsFee1));
      expect(satsFee1, greaterThan(satsFee5));
      expect(satsFee5, greaterThan(satsFee10));
    });

    test('[Fiat -> Sats] 소수점 수수료율(0.5%) 적용', () {
      final viewModel = createViewModel();
      viewModel.setFeeRate(0.5);
      // discountMultiplier = 0.995
      // (1,000,000 × 0.995) / 140,000,000 × 100,000,000 = 710,714.285... → 710,714
      expect(viewModel.calculateSatsFromFiat(1000000), 710714);
    });
  });

  group('calculateFiatFromSats - Sats → Fiat 변환', () {
    test('[Sats -> Fiat] 기본 변환: 1,000,000Sats를 수수료 1%로 Fiat 변환', () {
      final viewModel = createViewModel();
      // (1,000,000 /100,000,000) * 140,000,000 × 1.01 = 1,414,000
      expect(viewModel.calculateFiatFromSats(1000000), 1414000);
    });

    test('[Sats -> Fiat] 수수료 0%: 수수료 없이 변환', () {
      final viewModel = createViewModel();
      viewModel.setFeeRate(0);
      // (1,000,000 / 100,000,000) * 140,000,000 = 1,400,000
      expect(viewModel.calculateFiatFromSats(1000000), 1400000);
    });

    test('[Sats -> Fiat] 수수료 5%: 높은 수수료로 변환', () {
      final viewModel = createViewModel();
      viewModel.setFeeRate(5);
      // (1,000,000 / 100,000,000) * 140,000,000 * 1.05 = 1,470,000
      expect(viewModel.calculateFiatFromSats(1000000), 1470000);
    });

    test('[Sats -> Fiat] 수수료 10%: 매우 높은 수수료로 변환', () {
      final viewModel = createViewModel();
      viewModel.setFeeRate(10);
      // (1,000,000 / 100,000,000) * 140,000,000 * 1.1 = 1,540,000
      expect(viewModel.calculateFiatFromSats(1000000), 1540000);
    });

    test('[Sats -> Fiat] 소액 입력: 1,000 sats 변환', () {
      final viewModel = createViewModel();
      // (1,000 / 100,000,000) * 140,000,000 * 1.01= 1,414
      expect(viewModel.calculateFiatFromSats(1000), 1414);
    });

    test('[Sats -> Fiat] 고액 입력: 1억 Sats 변환', () {
      final viewModel = createViewModel();
      // (100,000,000 / 100,000,000) * 140,000,000 * 1.01 = 141,400,000
      expect(viewModel.calculateFiatFromSats(100000000), 141400000);
    });

    test('[Sats -> Fiat] 0 Sats 입력 시 0원 반환', () {
      final viewModel = createViewModel();
      expect(viewModel.calculateFiatFromSats(0), 0);
    });

    test('[Sats -> Fiat] 최소 금액: 1 Sats 입력 시 결과 반환', () {
      final viewModel = createViewModel();
      // (1 / 100,000,000) × 140,000,000 × 1.01 = 1.414 → round → 1
      expect(viewModel.calculateFiatFromSats(1), 1);
    });

    test('[Sats -> Fiat] 오프라인 시 KRW 기본 가격(20,000,000) 사용', () {
      final viewModel = createViewModel(isNetworkOn: false);
      // (1,000,000 / 100,000,000) * 20,000,000 * 1.01 = 202,000
      expect(viewModel.calculateFiatFromSats(1000000), 202000);
    });

    test('[Sats -> Fiat] 수수료율 변경 후 동일 금액 재계산 시 결과 변경 확인', () {
      final viewModel = createViewModel();

      final fiatWithFee1 = viewModel.calculateFiatFromSats(1000000);
      expect(fiatWithFee1, 1414000);

      viewModel.setFeeRate(3.0);
      final fiatWithFee3 = viewModel.calculateFiatFromSats(1000000);
      // (1,000,000 / 100,000,000) * 140,000,000 * 1.03 = 1,442,000
      expect(fiatWithFee3, 1442000);

      expect(fiatWithFee3, greaterThan(fiatWithFee1));
    });

    test('[Sats -> Fiat] 수수료가 높을수록 받는 Fiat가 줄어드는지 확인', () {
      final viewModel = createViewModel();
      const satsAmount = 1000000;

      viewModel.setFeeRate(0.0);
      final fiatNoFee = viewModel.calculateFiatFromSats(satsAmount);

      viewModel.setFeeRate(1.0);
      final fiatFee1 = viewModel.calculateFiatFromSats(satsAmount);

      viewModel.setFeeRate(5.0);
      final fiatFee5 = viewModel.calculateFiatFromSats(satsAmount);

      viewModel.setFeeRate(10.0);
      final fiatFee10 = viewModel.calculateFiatFromSats(satsAmount);

      expect(fiatFee10, greaterThan(fiatFee5));
      expect(fiatFee5, greaterThan(fiatFee1));
      expect(fiatFee1, greaterThan(fiatNoFee));
    });
  });

  group('수수료 계산 정확성', () {
    group('Fiat 입력 모드: 수수료 금액 검증', () {
      test('수수료 금액(원화) = 입력금액 × 수수료율', () {
        const fiatAmount = 1000000;
        const feeRate = 1.0;

        final expectedFeeInFiat = (fiatAmount * feeRate / 100).round();
        expect(expectedFeeInFiat, 10000);
      });

      test('수수료 1%: 수수료로 차감된 Sats 차이 검증', () {
        final viewModel = createViewModel();
        const fiatAmount = 1000000;

        viewModel.setFeeRate(0.0);
        final satsNoFee = viewModel.calculateSatsFromFiat(fiatAmount);

        viewModel.setFeeRate(1.0);
        final satsWithFee = viewModel.calculateSatsFromFiat(fiatAmount);

        final feeSats = satsNoFee - satsWithFee;
        // 수수료 10,000원의 Sats 환산: 10,000 / 140,000,000 × 100,000,000 = 7,142.857... → 7,143
        expect(feeSats, 7143);
      });

      test('수수료 5%: 수수료로 차감된 Sats 차이 검증', () {
        final viewModel = createViewModel();
        const fiatAmount = 1000000;

        viewModel.setFeeRate(0.0);
        final satsNoFee = viewModel.calculateSatsFromFiat(fiatAmount);

        viewModel.setFeeRate(5.0);
        final satsWithFee = viewModel.calculateSatsFromFiat(fiatAmount);

        final feeSats = satsNoFee - satsWithFee;
        // 수수료 50,000원의 Sats 환산: 50,000 / 140,000,000 × 100,000,000 = 35,714.285... → 35,715
        expect(feeSats, 35715);
      });

      test('수수료 0.5%: 소수점 수수료의 Sats 차이 검증', () {
        final viewModel = createViewModel();
        const fiatAmount = 1000000;

        viewModel.setFeeRate(0.0);
        final satsNoFee = viewModel.calculateSatsFromFiat(fiatAmount);

        viewModel.setFeeRate(0.5);
        final satsWithFee = viewModel.calculateSatsFromFiat(fiatAmount);

        final feeSats = satsNoFee - satsWithFee;
        // 수수료 5,000원의 Sats 환산: 5,000 / 140,000,000 × 100,000,000 = 3,571.428... → 3,572
        expect(feeSats, 3572);
      });
    });

    group('BTC 입력 모드: 수수료 금액 검증', () {
      test('수수료 1%: 프리미엄으로 추가된 Fiat 차이 검증', () {
        final viewModel = createViewModel();
        const satsAmount = 1000000;

        viewModel.setFeeRate(0.0);
        final fiatNoFee = viewModel.calculateFiatFromSats(satsAmount);

        viewModel.setFeeRate(1.0);
        final fiatWithFee = viewModel.calculateFiatFromSats(satsAmount);

        final feeInFiat = fiatWithFee - fiatNoFee;
        // 기본 Fiat = 1,400,000원, 수수료 = 1,400,000 × 1% = 14,000원
        expect(fiatNoFee, 1400000);
        expect(feeInFiat, 14000);
      });

      test('수수료 5%: 프리미엄으로 추가된 Fiat 차이 검증', () {
        final viewModel = createViewModel();
        const satsAmount = 1000000;

        viewModel.setFeeRate(0.0);
        final fiatNoFee = viewModel.calculateFiatFromSats(satsAmount);

        viewModel.setFeeRate(5.0);
        final fiatWithFee = viewModel.calculateFiatFromSats(satsAmount);

        final feeInFiat = fiatWithFee - fiatNoFee;
        // 수수료 = 1,400,000 × 5% = 70,000원
        expect(feeInFiat, 70000);
      });

      test('수수료 0.5%: 소수점 수수료의 Fiat 차이 검증', () {
        final viewModel = createViewModel();
        const satsAmount = 1000000;

        viewModel.setFeeRate(0.0);
        final fiatNoFee = viewModel.calculateFiatFromSats(satsAmount);

        viewModel.setFeeRate(0.5);
        final fiatWithFee = viewModel.calculateFiatFromSats(satsAmount);

        final feeInFiat = fiatWithFee - fiatNoFee;
        // 수수료 = 1,400,000 × 0.5% = 7,000원
        expect(feeInFiat, 7000);
      });

      test('수수료의 Sats 환산 검증', () {
        final viewModel = createViewModel();
        const satsAmount = 1000000;

        viewModel.setFeeRate(0.0);
        final fiatNoFee = viewModel.calculateFiatFromSats(satsAmount);

        viewModel.setFeeRate(1.0);
        final fiatWithFee = viewModel.calculateFiatFromSats(satsAmount);

        final feeInFiat = fiatWithFee - fiatNoFee;
        // feeInFiat(14,000)을 다시 Sats로 환산
        viewModel.setFeeRate(0.0);
        final feeSats = viewModel.calculateSatsFromFiat(feeInFiat);
        // 14,000 / 140,000,000 × 100,000,000 = 10,000
        expect(feeSats, 10000);
      });
    });

    group('수수료 방향성 검증', () {
      test('Fiat→BTC는 차감(discount), BTC→Fiat는 추가(premium)', () {
        final viewModel = createViewModel();

        viewModel.setFeeRate(0.0);
        final satsNoFee = viewModel.calculateSatsFromFiat(1000000);
        final fiatNoFee = viewModel.calculateFiatFromSats(1000000);

        viewModel.setFeeRate(5.0);
        final satsWithFee = viewModel.calculateSatsFromFiat(1000000);
        final fiatWithFee = viewModel.calculateFiatFromSats(1000000);

        // Fiat→BTC: 수수료가 있으면 받는 Sats가 줄어듦 (차감)
        expect(satsWithFee, lessThan(satsNoFee));
        // BTC→Fiat: 수수료가 있으면 지불할 Fiat이 늘어남 (추가)
        expect(fiatWithFee, greaterThan(fiatNoFee));
      });

      test('동일 금액 왕복 변환 시 수수료만큼 손실 발생', () {
        final viewModel = createViewModel();
        viewModel.setFeeRate(1.0);

        // 1,000,000원 → Sats 변환
        final sats = viewModel.calculateSatsFromFiat(1000000);
        // 변환된 Sats → 원화 재변환
        final fiatBack = viewModel.calculateFiatFromSats(sats);

        // 왕복 시 양쪽 수수료로 인해 원금보다 적어야 함
        expect(fiatBack, lessThan(1000000));
      });

      test('수수료율이 같아도 방향에 따라 수수료 금액(원화)이 다름', () {
        final viewModel = createViewModel();
        const feeRate = 5.0;
        viewModel.setFeeRate(feeRate);

        // Fiat→Sats: 수수료 = 입력 fiat × rate = 1,000,000 × 5% = 50,000원
        viewModel.setFeeRate(0.0);
        final satsNoFee = viewModel.calculateSatsFromFiat(1000000);
        viewModel.setFeeRate(feeRate);
        final satsWithFee = viewModel.calculateSatsFromFiat(1000000);
        final fiatToSatsFeeSats = satsNoFee - satsWithFee;

        // Sats→Fiat: 수수료 = 기본 fiat × rate = 1,400,000 × 5% = 70,000원
        viewModel.setFeeRate(0.0);
        final fiatNoFee = viewModel.calculateFiatFromSats(1000000);
        viewModel.setFeeRate(feeRate);
        final fiatWithFee = viewModel.calculateFiatFromSats(1000000);
        final satsToFiatFeeFiat = fiatWithFee - fiatNoFee;

        // 입력 금액이 달라서 수수료 금액도 다름
        // Fiat→Sats 수수료: 50,000원 → 35,715 sats
        // Sats→Fiat 수수료: 70,000원
        expect(fiatToSatsFeeSats, 35715);
        expect(satsToFiatFeeFiat, 70000);
      });
    });

    group('다양한 입력 금액에서 수수료 비례 검증', () {
      test('입력 금액이 2배이면 수수료 Sats도 2배', () {
        final viewModel = createViewModel();
        viewModel.setFeeRate(0.0);
        final satsNoFee1M = viewModel.calculateSatsFromFiat(1000000);
        final satsNoFee2M = viewModel.calculateSatsFromFiat(2000000);

        viewModel.setFeeRate(1.0);
        final satsWithFee1M = viewModel.calculateSatsFromFiat(1000000);
        final satsWithFee2M = viewModel.calculateSatsFromFiat(2000000);

        final feeSats1M = satsNoFee1M - satsWithFee1M;
        final feeSats2M = satsNoFee2M - satsWithFee2M;

        // 반올림 오차 허용 범위 내에서 2배 관계 검증
        expect((feeSats2M - feeSats1M * 2).abs(), lessThanOrEqualTo(1));
      });

      test('입력 금액이 10배이면 수수료 Fiat도 10배', () {
        final viewModel = createViewModel();

        viewModel.setFeeRate(0.0);
        final fiatNoFee100K = viewModel.calculateFiatFromSats(100000);
        final fiatNoFee1M = viewModel.calculateFiatFromSats(1000000);

        viewModel.setFeeRate(1.0);
        final fiatWithFee100K = viewModel.calculateFiatFromSats(100000);
        final fiatWithFee1M = viewModel.calculateFiatFromSats(1000000);

        final feeFiat100K = fiatWithFee100K - fiatNoFee100K;
        final feeFiat1M = fiatWithFee1M - fiatNoFee1M;

        // 10배 입력 → 10배 수수료
        expect(feeFiat1M, feeFiat100K * 10);
      });
    });

    group('다양한 엣지케이스 테스트', () {
      test('수수료 99.9%: 거의 전부 수수료, 극소량 Sats만 반환', () {
        final viewModel = createViewModel();
        viewModel.setFeeRate(99.9);
        // (100 × 0.001) / 140,000,000 × 100,000,000 = 0.07142857... → 0
        expect(viewModel.calculateSatsFromFiat(100), 0);
        // (1,000 × 0.001) / 140,000,000 × 100,000,000 = 0.7142857... → 1
        expect(viewModel.calculateSatsFromFiat(1000), 1);
        // (10,000 × 0.001) / 140,000,000 × 100,000,000 = 7.142857... → 7
        expect(viewModel.calculateSatsFromFiat(10000), 7);
      });

      test('수수료 0.01%: 매우 작은 수수료', () {
        final viewModel = createViewModel();
        viewModel.setFeeRate(0.01);
        // (100 × 0.9999) / 140,000,000 × 100,000,000 = 71.42142857... → 71
        expect(viewModel.calculateSatsFromFiat(100), 71);
        // (1,000 × 0.9999) / 140,000,000 × 100,000,000 = 714.2142857... → 714
        expect(viewModel.calculateSatsFromFiat(1000), 714);
        // (10,000 × 0.9999) / 140,000,000 × 100,000,000 = 7142.142857... → 7,142
        expect(viewModel.calculateSatsFromFiat(10000), 7142);
      });
    });
  });

  group('BTC 가격 극단값 테스트', () {
    group('가격 = 1 (극단적 저가, 1원/BTC)', () {
      test('[Fiat→Sats] 1원 입력 시 거의 1 BTC에 해당하는 Sats 반환(수수료율: 1%)', () {
        final viewModel = createViewModel(btcPrice: 1);
        viewModel.setFeeRate(1.0);
        // (1 × 0.99) / 1 × 100,000,000 = 99,000,000 sats (≈ 0.99 BTC)
        expect(viewModel.calculateSatsFromFiat(1), 99000000);
      });

      test('[Fiat→Sats] 100만원 입력 시 천문학적 Sats 반환(수수료율: 1%)', () {
        final viewModel = createViewModel(btcPrice: 1);
        viewModel.setFeeRate(1.0);
        // (1,000,000 × 0.99) / 1 × 100,000,000 = 99,000,000,000,000,000
        final sats = viewModel.calculateSatsFromFiat(1000000);
        expect(sats, 99000000000000);
      });

      test('[Sats→Fiat] 1,000,000 sats 입력 시 0원 반환 (소수점 이하 반올림)(수수료율: 1%)', () {
        final viewModel = createViewModel(btcPrice: 1);
        viewModel.setFeeRate(1.0);
        // (1,000,000 / 100,000,000) × 1 × 1.01 = 0.0101 → round → 0
        expect(viewModel.calculateFiatFromSats(1000000), 0);
      });

      test('[Sats→Fiat] 1 BTC(100,000,000 sats) 입력 시 1원 반환(수수료율: 1%)', () {
        final viewModel = createViewModel(btcPrice: 1);
        viewModel.setFeeRate(1.0);
        // (100,000,000 / 100,000,000) × 1 × 1.01 = 1.01 → round → 1
        expect(viewModel.calculateFiatFromSats(100000000), 1);
      });

      test('[Sats→Fiat] Fiat 결과가 0이 아니려면 최소 약 0.5 BTC 필요(수수료율: 0%)', () {
        final viewModel = createViewModel(btcPrice: 1);
        viewModel.setFeeRate(0.0);
        // (49,999,999 / 1e8) × 1 = 0.49999999 → round → 0
        expect(viewModel.calculateFiatFromSats(49999999), 0);
        // (50,000,000 / 1e8) × 1 = 0.5 → round → 1
        expect(viewModel.calculateFiatFromSats(50000000), 1);
      });

      test('[Fiat→Sats] 수수료 0%에서 정확히 입력금액 × 1억 sats(수수료율: 0%)', () {
        final viewModel = createViewModel(btcPrice: 1);
        viewModel.setFeeRate(0.0);
        // 1 / 1 × 100,000,000 = 100,000,000 (정확히 1 BTC)
        expect(viewModel.calculateSatsFromFiat(1), 100000000);
      });
    });
  });
}
