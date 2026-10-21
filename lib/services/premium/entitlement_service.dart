import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/premium/iap_entitlement_service.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';

/// 상품 유형. 구독 심사가 거절되면 비소모성 일회 구매로 바꿀 수 있게 나눠 둔다(SPEC v2)
enum PremiumProductKind { subscription, oneTimePurchase }

enum PremiumPeriod { monthly, yearly }

/// 스토어 콘솔에 등록한 상품 하나
class PremiumProductConfig {
  /// iOS 상품 id / Android 상품 id
  final String storeId;
  final PremiumProductKind kind;

  /// 일회 구매면 null
  final PremiumPeriod? period;

  /// Android 구독의 base plan id(구독 하나에 기간별 base plan이 붙는다)
  final String? basePlanId;

  const PremiumProductConfig({required this.storeId, required this.kind, this.period, this.basePlanId});
}

/// iOS 구독 그룹 "Coconut Premium"
const kAppStorePremiumProducts = [
  PremiumProductConfig(
    storeId: 'coconut_premium_yearly',
    kind: PremiumProductKind.subscription,
    period: PremiumPeriod.yearly,
  ),
  PremiumProductConfig(
    storeId: 'coconut_premium_monthly',
    kind: PremiumProductKind.subscription,
    period: PremiumPeriod.monthly,
  ),
];

/// Android 구독 coconut_premium + base plan yearly·monthly
const kPlayStorePremiumProducts = [
  PremiumProductConfig(
    storeId: 'coconut_premium',
    basePlanId: 'yearly',
    kind: PremiumProductKind.subscription,
    period: PremiumPeriod.yearly,
  ),
  PremiumProductConfig(
    storeId: 'coconut_premium',
    basePlanId: 'monthly',
    kind: PremiumProductKind.subscription,
    period: PremiumPeriod.monthly,
  ),
];

/// 지금 플랫폼의 상품. 페이월은 이 순서(연간 먼저)로 보여 준다
List<PremiumProductConfig> get kPremiumProducts =>
    defaultTargetPlatform == TargetPlatform.android ? kPlayStorePremiumProducts : kAppStorePremiumProducts;

enum PremiumStatus { none, verifying, active, expired, pending }

class PremiumState {
  final PremiumStatus status;

  /// 갱신·만료 시각. null = 평생(일회 구매)이거나 스토어가 알려 주지 않음(Android)
  final DateTime? expiresAt;
  final String? productId;

  /// 모르면 null(Android 복원은 base plan을 알려 주지 않는다)
  final PremiumPeriod? period;

  const PremiumState(this.status, {this.expiresAt, this.productId, this.period});

  /// Premium 자동화를 **새로 시작**해도 되는지. 이 값으로 막는 것은 셋뿐이다:
  /// Rescue-ready 자동 재계산, 지갑 자동 생성, 대체 거래 자동 준비.
  /// 이미 만든 지갑·비상 목적지·마지막 초안(지금 이동)·보내기·서명·사건·무료 가이드는 만료돼도 막지 않는다(SPEC v2).
  /// 확인 중(verifying)이면 캐시가 사용 중이라고 해도 false. 알려진 만료 시각이 지나면 다시 확인되기 전까지 false.
  bool get isActive {
    final ends = expiresAt;
    return status == PremiumStatus.active && (ends == null || ends.isAfter(DateTime.now()));
  }

  @override
  bool operator ==(Object other) =>
      other is PremiumState &&
      other.status == status &&
      other.expiresAt == expiresAt &&
      other.productId == productId &&
      other.period == period;

  @override
  int get hashCode => Object.hash(status, expiresAt, productId, period);
}

/// 페이월에 보여 줄 스토어 상품
class PremiumProduct {
  final PremiumProductConfig config;

  /// 스토어 현지 가격 문자열 그대로(재포맷·월 환산 금지)
  final String price;

  /// 비교 가능한 정기 요금의 스토어 숫자 가격·통화. 불확실하면 null
  final double? rawPrice;
  final String? currencyCode;

  /// 무료 체험 일수. 스토어 상품에 있고 이 사용자가 받을 수 있을 때만
  final int? freeTrialDays;

  const PremiumProduct({
    required this.config,
    required this.price,
    this.rawPrice,
    this.currencyCode,
    this.freeTrialDays,
  });
}

/// 같은 통화의 월간 정기 요금 대비 연간 할인율. 표시 문자열과 체험 가격은 계산에 쓰지 않는다
int? annualDiscountPercent(Iterable<PremiumProduct> products) {
  final subscriptions = products.where((p) => p.config.kind == PremiumProductKind.subscription);
  final monthly = subscriptions.where((p) => p.config.period == PremiumPeriod.monthly).singleOrNull;
  final yearly = subscriptions.where((p) => p.config.period == PremiumPeriod.yearly).singleOrNull;
  final monthlyPrice = monthly?.rawPrice;
  final yearlyPrice = yearly?.rawPrice;
  final currency = monthly?.currencyCode;
  if (currency == null ||
      currency.trim().isEmpty ||
      currency != yearly?.currencyCode ||
      monthlyPrice == null ||
      !monthlyPrice.isFinite ||
      monthlyPrice <= 0 ||
      yearlyPrice == null ||
      !yearlyPrice.isFinite ||
      yearlyPrice <= 0) {
    return null;
  }
  // 십진 가격의 정수 할인 경계가 부동소수점 오차로 한 단계 낮아지지 않게 한다.
  final annualized = Decimal.parse(monthlyPrice.toString()) * Decimal.fromInt(12);
  final discount = ((annualized - Decimal.parse(yearlyPrice.toString())) * Decimal.fromInt(100) / annualized).floor();
  return discount > BigInt.zero ? discount.toInt() : null;
}

enum PurchaseOutcome { purchased, pending, cancelled, failed, unavailable }

abstract interface class EntitlementService {
  ValueListenable<PremiumState> get state;

  /// 스토어 결제 가능 여부(마지막 [loadProducts] 기준)
  bool get isAvailable;

  /// 디버그·regtest 전용 Premium 강제 켜기가 켜져 있는지
  bool get debugOverride;

  /// 스토어에 없거나 연결할 수 없으면 빈 목록
  Future<List<PremiumProduct>> loadProducts();
  Future<PurchaseOutcome> purchase(PremiumProduct product);

  /// 스토어에서 지금 가진 권한을 다시 받는다. 끝나면 [state]가 결과. 실패하면 throw
  Future<void> restore();

  /// 스토어 구독 관리 화면을 연다. 열지 못하면 throw
  Future<void> openManageSubscriptions();

  /// [premiumDebugOverrideAllowed]가 false면 무시
  Future<void> setDebugOverride(bool enabled);
  void dispose();
}

/// Premium 강제 켜기는 디버그 빌드나 regtest에서만 동작·노출한다(메인넷 릴리즈 금지)
bool premiumDebugOverrideAllowed({bool debugMode = kDebugMode, NetworkType? network}) =>
    debugMode || (network ?? NetworkType.currentNetworkType) == NetworkType.regtest;

/// iOS·Android 공통(in_app_purchase umbrella). 앱 시작 때 한 번 만들어 Provider로 내린다(lazy: false — 구매 스트림을 바로 들어야 함)
EntitlementService createEntitlementService({AnalyticsService? analytics}) =>
    InAppPurchaseEntitlementService(analytics: analytics);

/// 테스트·위젯 하네스용. [emit]으로 상태를 바꾸고, 구매 결과는 [purchaseOutcome]으로 정한다
class FakeEntitlementService implements EntitlementService {
  FakeEntitlementService({
    bool isAvailable = true,
    PremiumState? initial,
    this.products = const [],
    this.purchaseOutcome = PurchaseOutcome.purchased,
  }) : _isAvailable = isAvailable,
       _state = ValueNotifier(initial ?? const PremiumState(PremiumStatus.none));

  final bool _isAvailable;
  final ValueNotifier<PremiumState> _state;
  List<PremiumProduct> products;
  PurchaseOutcome purchaseOutcome;
  int restoreCount = 0;
  int manageCount = 0;
  bool _debugOverride = false;

  void emit(PremiumState state) => _state.value = state;

  @override
  ValueListenable<PremiumState> get state => _state;

  @override
  bool get isAvailable => _isAvailable;

  @override
  bool get debugOverride => _debugOverride;

  @override
  Future<List<PremiumProduct>> loadProducts() async => _isAvailable ? products : const [];

  @override
  Future<PurchaseOutcome> purchase(PremiumProduct product) async {
    switch (purchaseOutcome) {
      case PurchaseOutcome.purchased:
        emit(PremiumState(PremiumStatus.active, productId: product.config.storeId, period: product.config.period));
      case PurchaseOutcome.pending:
        emit(const PremiumState(PremiumStatus.pending));
      default:
    }
    return purchaseOutcome;
  }

  @override
  Future<void> restore() async => restoreCount++;

  @override
  Future<void> openManageSubscriptions() async => manageCount++;

  @override
  Future<void> setDebugOverride(bool enabled) async {
    _debugOverride = enabled;
    emit(PremiumState(enabled ? PremiumStatus.active : PremiumStatus.none));
  }

  @override
  void dispose() => _state.dispose();
}
