import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:flutter_test/flutter_test.dart';

PremiumProduct _product(
  PremiumPeriod period,
  double? rawPrice, {
  String? currencyCode = 'USD',
  PremiumProductKind kind = PremiumProductKind.subscription,
}) => PremiumProduct(
  config: PremiumProductConfig(storeId: period.name, kind: kind, period: period),
  price: 'store-formatted price',
  rawPrice: rawPrice,
  currencyCode: currencyCode,
);

void main() {
  group('연간 할인율', () {
    for (final (name, monthly, yearly, expected) in <(String, double?, double?, int?)>[
      ('소수 할인율은 내림', 3, 24, 33),
      ('십진 가격의 정확한 정수 할인율', 1.25, 12, 20),
      ('정수 경계 바로 아래는 다음 정수로 올리지 않음', 1.25, 12.000001, 19),
      ('1퍼센트 경계는 표시', 1, 11.88, 1),
      ('1퍼센트 미만은 숨김', 1, 11.89, null),
      ('같은 연간 비용은 숨김', 1, 12, null),
      ('연간 비용이 더 크면 숨김', 1, 13, null),
      ('월간 가격 누락', null, 12, null),
      ('연간 가격 누락', 1, null, null),
      ('월간 가격이 영', 0, 12, null),
      ('연간 가격이 영', 1, 0, null),
      ('월간 가격이 음수', -1, 12, null),
      ('연간 가격이 음수', 1, -12, null),
      ('월간 가격이 NaN', double.nan, 12, null),
      ('연간 가격이 NaN', 1, double.nan, null),
      ('월간 가격이 무한대', double.infinity, 12, null),
      ('연간 가격이 무한대', 1, double.infinity, null),
      ('유한 입력의 연간 환산은 오버플로 없이 계산', double.maxFinite, 1, 99),
    ]) {
      test(name, () {
        expect(
          annualDiscountPercent([_product(PremiumPeriod.yearly, yearly), _product(PremiumPeriod.monthly, monthly)]),
          expected,
        );
      });
    }

    for (final (name, monthlyCurrency, yearlyCurrency) in <(String, String?, String?)>[
      ('다른 통화', 'USD', 'KRW'),
      ('월간 통화 누락', null, 'USD'),
      ('연간 통화 누락', 'USD', null),
      ('빈 통화', '', ''),
      ('공백 통화', ' ', ' '),
    ]) {
      test(name, () {
        expect(
          annualDiscountPercent([
            _product(PremiumPeriod.yearly, 24, currencyCode: yearlyCurrency),
            _product(PremiumPeriod.monthly, 3, currencyCode: monthlyCurrency),
          ]),
          isNull,
        );
      });
    }

    final yearly = _product(PremiumPeriod.yearly, 24);
    final monthly = _product(PremiumPeriod.monthly, 3);

    test('상품 순서와 무관하게 같은 기간을 비교', () {
      expect(annualDiscountPercent([monthly, yearly]), 33);
    });

    for (final (name, products) in <(String, List<PremiumProduct>)>[
      ('상품 없음', []),
      ('연간만 있음', [yearly]),
      ('월간만 있음', [monthly]),
      ('연간이 중복됨', [yearly, yearly, monthly]),
      ('월간이 중복됨', [yearly, monthly, monthly]),
      ('일회 구매는 구독 비교에서 제외', [yearly, _product(PremiumPeriod.monthly, 3, kind: PremiumProductKind.oneTimePurchase)]),
    ]) {
      test(name, () => expect(annualDiscountPercent(products), isNull));
    }
  });
}
