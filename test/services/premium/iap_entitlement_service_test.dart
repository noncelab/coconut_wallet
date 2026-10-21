import 'dart:async';
import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/premium/premium_paywall_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/services/premium/iap_entitlement_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// InAppPurchase.instance 대신. restorePurchases는 Android처럼 끝나기 전에 [owned](검증된 소유 거래)를 스트림에 넣는다
class _FakeIap extends Fake implements InAppPurchase {
  final stream = StreamController<List<PurchaseDetails>>.broadcast();
  bool available = true;
  List<PurchaseDetails> owned = [];
  Completer<void>? restoreGate;
  Object? restoreError;
  int restoreCount = 0;
  bool buyResult = true;
  Object? buyError;
  List<ProductDetails> products = [];
  final completed = <PurchaseDetails>[];
  Completer<void>? completeGate;
  void Function(PurchaseDetails)? onComplete;
  final bought = <PurchaseParam>[];

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => stream.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> restorePurchases({String? applicationUserName}) async {
    restoreCount++;
    await restoreGate?.future;
    if (restoreError != null) throw restoreError!;
    stream.add([...owned]);
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
    await completeGate?.future;
    onComplete?.call(purchase);
  }

  @override
  Future<bool> buyNonConsumable({required PurchaseParam purchaseParam}) async {
    bought.add(purchaseParam);
    if (buyError != null) throw buyError!;
    return buyResult;
  }

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) async =>
      ProductDetailsResponse(productDetails: products, notFoundIDs: const []);
}

/// 플랫폼이 등록되지 않은 스토어(InAppPurchase.instance.purchaseStream이 throw)
class _BrokenIap extends Fake implements InAppPurchase {
  @override
  Stream<List<PurchaseDetails>> get purchaseStream => throw StateError('no store platform');

  @override
  Future<bool> isAvailable() => throw StateError('no store platform');
}

class _Analytics extends Fake implements AnalyticsService {
  final events = <(String, Map<String, Object>?)>[];

  @override
  Future<void> logEvent({required String eventName, Map<String, Object>? parameters}) async =>
      events.add((eventName, parameters));
}

DateTime _ms(DateTime d) => DateTime.fromMillisecondsSinceEpoch(d.millisecondsSinceEpoch);
final _nextMonth = _ms(DateTime.now().add(const Duration(days: 30)));

/// StoreKit 2 거래. localVerificationData는 Transaction.jsonRepresentation 모양(ms). purchased만 finish 대상
PurchaseDetails _sk(
  String productId,
  PurchaseStatus status, {
  String id = '1',
  DateTime? expires,
  Map<String, Object> extra = const {},
  String? local,
}) => PurchaseDetails(
  purchaseID: id,
  productID: productId,
  verificationData: PurchaseVerificationData(
    localVerificationData:
        local ?? jsonEncode({'expiresDate': (expires ?? _nextMonth).millisecondsSinceEpoch, ...extra}),
    serverVerificationData: 'jws',
    source: 'app_store',
  ),
  transactionDate: '0',
  status: status,
)..pendingCompletePurchase = status == PurchaseStatus.purchased;

ProductDetails _iosProduct(String id, String price, {double rawPrice = 0, String currencyCode = 'KRW'}) =>
    ProductDetails(
      id: id,
      title: 'Coconut Premium',
      description: '',
      price: price,
      rawPrice: rawPrice,
      currencyCode: currencyCode,
    );

PricingPhaseWrapper _phase(
  String price,
  int micros,
  String period,
  RecurrenceMode mode, {
  String currencyCode = 'KRW',
}) => PricingPhaseWrapper(
  billingCycleCount: mode == RecurrenceMode.infiniteRecurring ? 0 : 1,
  billingPeriod: period,
  formattedPrice: price,
  priceAmountMicros: micros,
  priceCurrencyCode: currencyCode,
  recurrenceMode: mode,
);

SubscriptionOfferDetailsWrapper _offer(String basePlanId, List<PricingPhaseWrapper> phases, {String? offerId}) =>
    SubscriptionOfferDetailsWrapper(
      basePlanId: basePlanId,
      offerId: offerId,
      offerTags: const [],
      offerIdToken: '$basePlanId-${offerId ?? 'base'}-token',
      pricingPhases: phases,
    );

/// Play가 base plan·혜택마다 하나씩 주는 상품 목록
List<GooglePlayProductDetails> _playProducts({
  bool includeYearlyBase = true,
  List<PricingPhaseWrapper>? yearlyBasePhases,
}) => GooglePlayProductDetails.fromProductDetails(
  ProductDetailsWrapper(
    description: '',
    name: 'Coconut Premium',
    productId: 'coconut_premium',
    productType: ProductType.subs,
    title: 'Coconut Premium',
    subscriptionOfferDetails: [
      if (includeYearlyBase)
        _offer('yearly', yearlyBasePhases ?? [_phase('₩39,000', 39000000000, 'P1Y', RecurrenceMode.infiniteRecurring)]),
      _offer('yearly', offerId: 'trial', [
        _phase('무료', 0, 'P1W', RecurrenceMode.finiteRecurring),
        _phase('₩39,000', 39000000000, 'P1Y', RecurrenceMode.infiniteRecurring),
      ]),
      _offer('monthly', [_phase('₩4,900', 4900000000, 'P1M', RecurrenceMode.infiniteRecurring)]),
    ],
  ),
);

/// Play 구매. [status]는 바깥 상태(복원이면 restored로 덮어써진다), [state]는 안쪽 purchaseState
GooglePlayPurchaseDetails _play(
  PurchaseStateWrapper state,
  PurchaseStatus status, {
  bool acknowledged = false,
  String token = 'token',
}) =>
    GooglePlayPurchaseDetails.fromPurchase(
        PurchaseWrapper(
          orderId: 'GPA.1',
          packageName: 'onl.coconut.wallet',
          purchaseTime: 0,
          purchaseToken: token,
          signature: '',
          products: const ['coconut_premium'],
          isAutoRenewing: true,
          originalJson: '{"productId":"coconut_premium"}',
          isAcknowledged: acknowledged,
          purchaseState: state,
        ),
      ).single
      ..status = status;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeIap iap;
  late _Analytics analytics;
  final services = <InAppPurchaseEntitlementService>[];

  Future<void> prefs([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    await SharedPrefsRepository().init();
  }

  InAppPurchaseEntitlementService create({
    bool? debugOverrideAllowed,
    Future<bool> Function(Uri)? launch,
    InAppPurchase? store,
    Duration ackRetryDelay = const Duration(seconds: 10),
  }) {
    final service = InAppPurchaseEntitlementService(
      iap: store ?? iap,
      analytics: analytics,
      debugOverrideAllowed: debugOverrideAllowed,
      restoreSettle: Duration.zero,
      ackRetryDelay: ackRetryDelay,
      launch: launch,
    );
    services.add(service);
    return service;
  }

  /// 시작 복원과 스트림 이벤트, 이어지는 재조회가 끝날 때까지
  Future<void> settle() => pumpEventQueue();

  String cache(PremiumStatus status, {DateTime? expiresAt}) => jsonEncode({
    'status': status.name,
    'productId': 'coconut_premium_yearly',
    'period': 'yearly',
    'expiresAt': expiresAt?.millisecondsSinceEpoch,
  });

  void resume() {
    final binding = TestWidgetsFlutterBinding.instance;
    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  }

  setUp(() async {
    iap = _FakeIap();
    analytics = _Analytics();
    await prefs();
  });

  tearDown(() {
    for (final s in services) {
      s.dispose();
    }
    services.clear();
    debugDefaultTargetPlatformOverride = null;
  });

  group('iOS', () {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      iap.products = [
        _iosProduct('coconut_premium_yearly', 'US\$ 29,99'),
        _iosProduct('coconut_premium_monthly', '\$2.99'),
      ];
    });

    test('스토어 가격 문자열은 그대로, 연간이 먼저', () async {
      final service = create();
      final products = await service.loadProducts();

      expect(products.map((p) => p.config.period), [PremiumPeriod.yearly, PremiumPeriod.monthly]);
      expect(products.map((p) => p.price), ['US\$ 29,99', '\$2.99']);
      expect(products.first.freeTrialDays, isNull);
    });

    testWidgets('연간 카드에 스토어 숫자 가격으로 계산한 할인율을 표시한다', (tester) async {
      try {
        LocaleSettings.setLocaleSync(AppLocale.ko);
        iap.products = [
          _iosProduct('coconut_premium_yearly', '스토어 연간 가격', rawPrice: 24),
          _iosProduct('coconut_premium_monthly', '스토어 월간 가격', rawPrice: 3),
        ];
        await tester.pumpWidget(
          Provider<EntitlementService>.value(
            value: create(),
            child: MaterialApp(
              theme: buildCoconutThemeData(variant: CoconutThemeVariant.light),
              home: const PremiumPaywallScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.descendant(of: find.byKey(const Key('premium-plan-yearly')), matching: find.text('월간보다 33% 저렴')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('G-B1: purchased 이벤트만으로는 열지 않는다. 검증된 소유 조회에 그 거래가 있어야 active·완료·기록', () async {
      final service = create();
      await settle();
      final yearly = (await service.loadProducts()).first;

      // 검증 실패한 직접 구매: StoreKit은 purchased를 보내지만 currentEntitlements에는 없다
      var outcome = service.purchase(yearly);
      await settle();
      iap.stream.add([_sk('coconut_premium_yearly', PurchaseStatus.purchased, id: '9')]);
      expect(await outcome, PurchaseOutcome.failed);
      expect(service.state.value.isActive, isFalse);
      expect(iap.completed, isEmpty);
      expect(analytics.events, isEmpty);

      // 검증된 구매: 소유 조회에 같은 거래가 있다
      outcome = service.purchase(yearly);
      await settle();
      iap.owned = [_sk('coconut_premium_yearly', PurchaseStatus.restored, id: '10')];
      final tx = _sk('coconut_premium_yearly', PurchaseStatus.purchased, id: '10');
      iap.stream.add([tx]);
      expect(await outcome, PurchaseOutcome.purchased);
      await settle();
      expect(service.state.value.isActive, isTrue);
      expect(service.state.value.period, PremiumPeriod.yearly);
      expect(iap.completed, [tx]);
      expect(analytics.events.map((e) => e.$1), [AnalyticsEventNames.premiumPurchaseCompleted]);
      expect(analytics.events.single.$2, {AnalyticsParameterNames.period: 'yearly'});

      // 같은 거래가 다시 오거나 복원돼도 완료·기록은 한 번
      iap.stream.add([tx]);
      await service.restore();
      await settle();
      expect(iap.completed, hasLength(1));
      expect(analytics.events, hasLength(1));
    });

    test('G-M2: iOS 구독은 읽을 수 있는 미래 만료일이 있어야 열린다(없거나 깨지면 확인 중)', () async {
      final payloads = [
        '',
        'not json',
        jsonEncode({'productId': 'x'}),
        jsonEncode({'expiresDate': '2030-01-01'}),
      ];
      for (final local in payloads) {
        iap = _FakeIap()..owned = [_sk('coconut_premium_yearly', PurchaseStatus.restored, local: local)];
        final service = create();
        await settle();
        expect(service.state.value.status, PremiumStatus.verifying, reason: local);
      }
    });

    test('복원: 가진 구독이 오면 active, 갱신일은 거래 JSON의 expiresDate', () async {
      iap.owned = [_sk('coconut_premium_monthly', PurchaseStatus.restored)];
      final service = create();
      await settle();

      expect(
        service.state.value,
        PremiumState(
          PremiumStatus.active,
          expiresAt: _nextMonth,
          productId: 'coconut_premium_monthly',
          period: PremiumPeriod.monthly,
        ),
      );
      expect(iap.completed, isEmpty);
      expect(analytics.events, isEmpty);
    });

    test('복원에 아무것도 없으면: 써 본 적 있으면 expired(지난 만료일), 없으면 none', () async {
      final fresh = create();
      expect(fresh.state.value.status, PremiumStatus.verifying);
      await settle();
      expect(fresh.state.value.status, PremiumStatus.none);

      final endedAt = _ms(DateTime(2026, 9, 1));
      await prefs({SharedPrefKeys.kPremiumEntitlementCache: cache(PremiumStatus.active, expiresAt: endedAt)});
      final service = create();
      await settle();

      expect(service.state.value.status, PremiumStatus.expired);
      expect(service.state.value.expiresAt, endedAt);
      expect(service.state.value.isActive, isFalse);
    });

    test('G-M1: 쓰는 중 환불되면 다시 조회해 만료로, 다른 권한이 남아 있으면 그대로', () async {
      iap.owned = [
        _sk('coconut_premium_yearly', PurchaseStatus.restored, id: 'A'),
        _sk('coconut_premium_monthly', PurchaseStatus.restored, id: 'B'),
      ];
      final service = create();
      await settle();
      expect(service.state.value.isActive, isTrue);

      iap.owned = [_sk('coconut_premium_monthly', PurchaseStatus.restored, id: 'B')];
      iap.stream.add([
        _sk('coconut_premium_yearly', PurchaseStatus.purchased, id: 'A', extra: {'revocationDate': 1}),
      ]);
      await settle();
      expect(service.state.value.isActive, isTrue);
      expect(service.state.value.productId, 'coconut_premium_monthly');

      iap.owned = [];
      iap.stream.add([
        _sk('coconut_premium_monthly', PurchaseStatus.purchased, id: 'B', extra: {'revocationDate': 2}),
      ]);
      await settle();
      expect(service.state.value.status, PremiumStatus.expired);
    });

    test('G-R1: 무효화 이벤트로 닫고, 새 조회가 실패하면 열지 않으며, 예전에 인정된 거래가 다시 와도 확인으로 치지 않는다', () async {
      iap.owned = [_sk('coconut_premium_yearly', PurchaseStatus.restored, id: 'A')];
      final service = create();
      await settle();
      expect(service.state.value.isActive, isTrue);

      iap.restoreError = PlatformException(code: 'storekit2_restore_failed');
      iap.stream.add([
        _sk('coconut_premium_yearly', PurchaseStatus.purchased, id: 'A', extra: {'revocationDate': 1}),
      ]);
      await settle();
      expect(service.state.value.status, PremiumStatus.verifying);

      // 무효가 되기 전 인정됐던 거래가 다시 와도, 새로 확인하지 못했으면 완료하지도 열지도 않는다
      iap.stream.add([_sk('coconut_premium_yearly', PurchaseStatus.purchased, id: 'A')]);
      await settle();
      expect(service.state.value.isActive, isFalse);
      expect(iap.completed, isEmpty);

      // 새 조회가 성공하면 그 결과대로(다른 권한이 있으면 다시 연다)
      iap.restoreError = null;
      iap.owned = [_sk('coconut_premium_monthly', PurchaseStatus.restored, id: 'B')];
      await service.restore();
      expect(service.state.value.isActive, isTrue);
    });

    test('G-M1: 앱이 다시 앞으로 오면 조용히 다시 조회한다(밖에서 해지된 구독)', () async {
      iap.owned = [_sk('coconut_premium_yearly', PurchaseStatus.restored)];
      final service = create();
      await settle();
      expect(service.state.value.isActive, isTrue);
      final before = iap.restoreCount;

      iap.owned = [];
      resume();
      await settle();
      expect(iap.restoreCount, before + 1);
      expect(service.state.value.status, PremiumStatus.expired);
    });

    test('G-M3: 같은 거래의 완료(finish)는 진행 중 중복 이벤트·복원에도 한 번', () async {
      iap.completeGate = Completer<void>();
      iap.owned = [_sk('coconut_premium_yearly', PurchaseStatus.restored, id: '5')];
      final service = create();
      await settle();

      final tx = _sk('coconut_premium_yearly', PurchaseStatus.purchased, id: '5');
      iap.stream.add([tx]);
      await settle();
      iap.stream.add([tx]);
      await service.restore();
      await settle();
      expect(iap.completed, hasLength(1));

      iap.completeGate!.complete();
      iap.stream.add([tx]);
      await settle();
      expect(iap.completed, hasLength(1));
      expect(service.state.value.isActive, isTrue);
    });

    test('우리 상품이 아닌 거래는 손대지 않는다', () async {
      final service = create();
      await settle();
      iap.stream.add([_sk('other_product', PurchaseStatus.purchased)]);
      await settle();

      expect(service.state.value.isActive, isFalse);
      expect(iap.completed, isEmpty);
    });
  });

  group('확인 중에는 캐시로 열지 않는다', () {
    test('캐시가 사용 중이어도 스토어 확인 전에는 verifying, isActive false', () async {
      await prefs({
        SharedPrefKeys.kPremiumEntitlementCache: cache(
          PremiumStatus.active,
          expiresAt: DateTime.now().add(const Duration(days: 300)),
        ),
      });
      iap.restoreGate = Completer<void>();
      final service = create();
      await settle();

      expect(service.state.value.status, PremiumStatus.verifying);
      expect(service.state.value.isActive, isFalse);
    });

    test('스토어 확인 실패: 써 본 적 있으면 verifying 유지, 없으면 none', () async {
      iap.restoreError = Exception('billing unavailable');
      final fresh = create();
      await settle();
      expect(fresh.state.value.status, PremiumStatus.none);

      await prefs({SharedPrefKeys.kPremiumEntitlementCache: cache(PremiumStatus.active)});
      final returning = create();
      await settle();
      expect(returning.state.value.status, PremiumStatus.verifying);
      expect(returning.state.value.isActive, isFalse);
      await expectLater(returning.restore(), throwsException);
    });

    test('m3: 로그에는 오류 종류와 코드만(메시지·details의 영수증은 남기지 않는다)', () async {
      const marker = 'eyJhbGciOiJFUzI1NiJ9.RECEIPT-MARKER';
      final error = PlatformException(
        code: 'storekit2_restore_failed',
        message: 'This purchase could not be restored.',
        details: {'1': marker},
      );
      expect(premiumErrorTag(error), 'PlatformException(storekit2_restore_failed)');
      expect(
        premiumErrorTag(
          InAppPurchaseException(source: 'google_play', code: 'restore_transactions_failed', message: '7'),
        ),
        'InAppPurchaseException(restore_transactions_failed)',
      );

      final logs = <String>[];
      iap.restoreError = error;
      await runZoned(() async {
        create();
        await settle();
      }, zoneSpecification: ZoneSpecification(print: (_, _, _, line) => logs.add(line)));
      expect(logs.join('\n'), contains('storekit2_restore_failed'));
      expect(logs.join('\n'), isNot(contains('RECEIPT-MARKER')));
      expect(logs.join('\n'), isNot(contains('could not be restored')));
    });
  });

  group('구매 결과', () {
    late InAppPurchaseEntitlementService service;
    late PremiumProduct yearly;

    setUp(() async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      iap.products = [
        _iosProduct('coconut_premium_yearly', '₩39,000'),
        _iosProduct('coconut_premium_monthly', '₩4,900'),
      ];
      service = create();
      await settle();
      yearly = (await service.loadProducts()).first;
    });

    test('취소', () async {
      final outcome = service.purchase(yearly);
      await settle();
      iap.stream.add([_sk('coconut_premium_yearly', PurchaseStatus.canceled)]);
      expect(await outcome, PurchaseOutcome.cancelled);
      expect(service.state.value.isActive, isFalse);
    });

    test('오류 이벤트·시작 실패·예외는 failed', () async {
      final outcome = service.purchase(yearly);
      await settle();
      iap.stream.add([_sk('', PurchaseStatus.error)]);
      expect(await outcome, PurchaseOutcome.failed);

      iap.buyResult = false;
      expect(await service.purchase(yearly), PurchaseOutcome.failed);

      iap.buyError = Exception('storekit2_failed_to_fetch_product');
      expect(await service.purchase(yearly), PurchaseOutcome.failed);
      expect(analytics.events, isEmpty);
    });

    test('G-M4: 스트림 오류·종료·dispose는 진행 중 구매를 끝낸다', () async {
      var outcome = service.purchase(yearly);
      await settle();
      iap.stream.addError(PlatformException(code: 'channel-error'));
      expect(await outcome, PurchaseOutcome.failed);

      outcome = service.purchase(yearly);
      await settle();
      service.dispose();
      services.remove(service);
      expect(await outcome, PurchaseOutcome.failed);

      final closing = _FakeIap()..products = iap.products;
      final other = create(store: closing);
      await settle();
      final product = (await other.loadProducts()).first;
      outcome = other.purchase(product);
      await settle();
      await closing.stream.close();
      expect(await outcome, PurchaseOutcome.failed);
    });

    test('m1: 승인 대기는 빈 소유 조회나 취소 이벤트로 지워진다', () async {
      var outcome = service.purchase(yearly);
      await settle();
      iap.stream.add([_sk('coconut_premium_yearly', PurchaseStatus.pending, id: '0')]);
      expect(await outcome, PurchaseOutcome.pending);
      expect(service.state.value.status, PremiumStatus.pending);
      await service.restore();
      expect(service.state.value.status, PremiumStatus.none);

      outcome = service.purchase(yearly);
      await settle();
      iap.stream.add([_sk('coconut_premium_yearly', PurchaseStatus.pending, id: '0')]);
      await outcome;
      expect(service.state.value.status, PremiumStatus.pending);
      iap.stream.add([_sk('coconut_premium_yearly', PurchaseStatus.canceled, id: '0')]);
      await settle();
      expect(service.state.value.status, PremiumStatus.none);
    });

    test('m2: 진행 중 구매와 다른 상품·갱신 이벤트는 그 구매를 끝내지도 기록하지도 않는다', () async {
      var settled = false;
      final outcome = service.purchase(yearly);
      unawaited(outcome.then((_) => settled = true));
      await settle();
      iap.owned = [_sk('coconut_premium_monthly', PurchaseStatus.restored, id: 'R')];
      iap.stream.add([
        _sk('coconut_premium_monthly', PurchaseStatus.purchased, id: 'R', extra: {'transactionReason': 'RENEWAL'}),
      ]);
      await settle();
      expect(settled, isFalse);
      expect(analytics.events, isEmpty);

      iap.owned = [...iap.owned, _sk('coconut_premium_yearly', PurchaseStatus.restored, id: 'Y')];
      iap.stream.add([_sk('coconut_premium_yearly', PurchaseStatus.purchased, id: 'Y')]);
      expect(await outcome, PurchaseOutcome.purchased);
      await settle();
      expect(analytics.events.single.$2, {AnalyticsParameterNames.period: 'yearly'});
    });

    test('m2: 승인 대기 구매가 앱을 다시 켠 뒤 승인돼도 완료 이벤트는 한 번', () async {
      final outcome = service.purchase(yearly);
      await settle();
      iap.stream.add([_sk('coconut_premium_yearly', PurchaseStatus.pending, id: '0')]);
      expect(await outcome, PurchaseOutcome.pending);
      service.dispose();
      services.remove(service);

      // 앱을 다시 켬: 같은 저장소, 새 스트림
      iap = _FakeIap()..owned = [_sk('coconut_premium_yearly', PurchaseStatus.restored, id: '7')];
      final relaunched = create();
      await settle();
      final approved = _sk('coconut_premium_yearly', PurchaseStatus.purchased, id: '7');
      iap.stream.add([approved]);
      await settle();
      iap.stream.add([approved]);
      await settle();
      expect(relaunched.state.value.isActive, isTrue);
      expect(analytics.events.single.$2, {AnalyticsParameterNames.period: 'yearly'});

      // 기록을 지웠으므로 또 다시 켜도 다시 남기지 않는다
      iap = _FakeIap()..owned = [_sk('coconut_premium_yearly', PurchaseStatus.restored, id: '7')];
      create();
      await settle();
      iap.stream.add([approved]);
      await settle();
      expect(analytics.events, hasLength(1));
    });

    test('스토어를 쓸 수 없으면 상품 없음, 구매는 unavailable', () async {
      iap.available = false;
      expect(await service.loadProducts(), isEmpty);
      expect(service.isAvailable, isFalse);
      expect(await service.purchase(yearly), PurchaseOutcome.unavailable);
      expect(iap.bought, isEmpty);
    });
  });

  group('Android', () {
    setUp(() => iap.products = _playProducts());

    test('체험 혜택은 유지하고 기본 요금제로 할인율을 비교', () async {
      final service = create();
      final products = await service.loadProducts();
      expect(products.first.freeTrialDays, 7);
      expect(annualDiscountPercent(products), 33);
      iap.buyResult = false;
      expect(await service.purchase(products.first), PurchaseOutcome.failed);
      expect((iap.bought.single.productDetails as GooglePlayProductDetails).offerToken, 'yearly-trial-token');
    });

    test('비교용 기본 요금제가 없으면 할인율만 숨김', () async {
      iap.products = _playProducts(includeYearlyBase: false);
      final products = await create().loadProducts();
      expect(products, hasLength(2));
      expect(products.first.freeTrialDays, 7);
      expect(annualDiscountPercent(products), isNull);
    });

    for (final (name, phases) in <(String, List<PricingPhaseWrapper>)>[
      (
        '여러 가격 단계',
        [
          _phase('intro', 0, 'P1W', RecurrenceMode.finiteRecurring),
          _phase('regular', 39000000000, 'P1Y', RecurrenceMode.infiniteRecurring),
        ],
      ),
      ('정기 결제가 아님', [_phase('finite', 39000000000, 'P1Y', RecurrenceMode.finiteRecurring)]),
      ('선택 혜택과 정기 가격이 다름', [_phase('different', 38000000000, 'P1Y', RecurrenceMode.infiniteRecurring)]),
      (
        '선택 혜택과 통화가 다름',
        [_phase('different', 39000000000, 'P1Y', RecurrenceMode.infiniteRecurring, currencyCode: 'USD')],
      ),
      ('선택 혜택과 기간이 다름', [_phase('different', 39000000000, 'P1M', RecurrenceMode.infiniteRecurring)]),
    ]) {
      test('기본 요금제 $name: 불확실한 할인율은 숨김', () async {
        iap.products = _playProducts(yearlyBasePhases: phases);
        final products = await create().loadProducts();
        expect(products, hasLength(2));
        expect(products.first.freeTrialDays, 7);
        expect(annualDiscountPercent(products), isNull);
      });
    }

    test('base plan별 상품: 체험 혜택을 고르고, 가격은 정기 결제 단계 문자열 그대로', () async {
      final service = create();
      final products = await service.loadProducts();

      expect(products.map((p) => p.config.basePlanId), ['yearly', 'monthly']);
      expect(products.map((p) => p.price), ['₩39,000', '₩4,900']);
      expect(products.map((p) => p.freeTrialDays), [7, null]);

      unawaited(service.purchase(products.first));
      await settle();
      expect((iap.bought.single.productDetails as GooglePlayProductDetails).offerToken, 'yearly-trial-token');
    });

    test('구매엔 base plan이 없어 고른 상품의 기간으로 남기고, 확인(acknowledge)은 한 번', () async {
      final service = create();
      await settle();
      final monthly = (await service.loadProducts()).last;
      final outcome = service.purchase(monthly);
      await settle();
      iap.owned = [_play(PurchaseStateWrapper.purchased, PurchaseStatus.restored)];
      iap.stream.add([_play(PurchaseStateWrapper.purchased, PurchaseStatus.purchased)]);

      expect(await outcome, PurchaseOutcome.purchased);
      await settle();
      expect(service.state.value.period, PremiumPeriod.monthly);
      expect(iap.completed, hasLength(1));
      expect(analytics.events.single.$2, {AnalyticsParameterNames.period: 'monthly'});
    });

    test('G-M2: 복원이 restored로 덮어쓴 미지정 상태 구매는 열지도 확인하지도 않는다', () async {
      iap.owned = [_play(PurchaseStateWrapper.unspecified_state, PurchaseStatus.restored)];
      final service = create();
      await settle();

      expect(service.state.value.status, PremiumStatus.none);
      expect(iap.completed, isEmpty);
    });

    test('복원에 온 승인 대기 구매는 pending, 열지도 확인하지도 않는다', () async {
      iap.owned = [_play(PurchaseStateWrapper.pending, PurchaseStatus.restored)];
      final service = create();
      await settle();

      expect(service.state.value.status, PremiumStatus.pending);
      expect(iap.completed, isEmpty);
    });

    test('G-R1: 앞으로 왔을 때 조회가 실패하면 쓰던 권한도 확인 중으로 닫는다(밖에서의 환불·만료를 놓치지 않게)', () async {
      iap.owned = [_play(PurchaseStateWrapper.purchased, PurchaseStatus.restored, acknowledged: true)];
      final service = create();
      await settle();
      expect(service.state.value.isActive, isTrue);

      iap.restoreError = InAppPurchaseException(
        source: 'google_play',
        code: 'restore_transactions_failed',
        message: '6',
      );
      resume();
      await settle();
      expect(service.state.value.status, PremiumStatus.verifying);

      iap.restoreError = null;
      resume();
      await settle();
      expect(service.state.value.isActive, isTrue);
    });

    test('G-M3: 확인 실패는 새 조회로 알아채고 바로 반복하지 않다가, 앱이 다시 앞으로 오면 바로 다시 확인한다', () async {
      iap.owned = [_play(PurchaseStateWrapper.purchased, PurchaseStatus.restored)];
      final service = create(ackRetryDelay: const Duration(hours: 1));
      await settle();
      expect(service.state.value.isActive, isTrue);
      expect(iap.completed, hasLength(1));
      expect(iap.restoreCount, 2); // 확인 뒤 새 소유 조회. 아직 안 됐어도 다시 확인하지 않는다

      resume();
      await settle();
      expect(iap.completed, hasLength(2));

      // 이번에는 확인된다: 다음 조회부터 isAcknowledged라 더 확인하지 않는다
      iap.onComplete =
          (_) => iap.owned = [_play(PurchaseStateWrapper.purchased, PurchaseStatus.restored, acknowledged: true)];
      resume();
      await settle();
      resume();
      await settle();
      expect(iap.completed, hasLength(3));
    });

    test('복원된 구독은 지난번 기록의 기간을 쓴다', () async {
      await prefs({
        SharedPrefKeys.kPremiumEntitlementCache: jsonEncode({
          'status': 'active',
          'productId': 'coconut_premium',
          'period': 'monthly',
        }),
      });
      iap.owned = [_play(PurchaseStateWrapper.purchased, PurchaseStatus.restored, acknowledged: true)];
      final service = create();
      await settle();

      expect(service.state.value.isActive, isTrue);
      expect(service.state.value.period, PremiumPeriod.monthly);
      expect(iap.completed, isEmpty);
    });
  });

  /// 가짜 시간(testWidgets)에서 조회·스트림·0초 타이머가 이어지는 만큼 비운다(pump()만으로는 시간이 흐르지 않아 0초 타이머가 안 돈다)
  Future<void> drain(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(Duration.zero);
    }
  }

  group('만료 시각(가짜 시간)', () {
    final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
    DateTime inFiveMinutes() => _ms(DateTime.now().add(const Duration(minutes: 5)));

    testWidgets('G-M1: 만료 시각이 지나면 다시 조회해 만료로 바꾼다', variant: ios, (tester) async {
      iap.owned = [_sk('coconut_premium_yearly', PurchaseStatus.restored, expires: inFiveMinutes())];
      final service = create();
      await drain(tester);
      expect(service.state.value.isActive, isTrue);

      iap.owned = [];
      await tester.pump(const Duration(minutes: 5, seconds: 2));
      await drain(tester);
      expect(service.state.value.status, PremiumStatus.expired);
      service.dispose();
      services.remove(service);
    });

    testWidgets('G-R1: 만료 시각이 지나면 조회 전에 닫고, 조회가 실패해도 열지 않는다', variant: ios, (tester) async {
      iap.owned = [_sk('coconut_premium_yearly', PurchaseStatus.restored, expires: inFiveMinutes())];
      final service = create();
      await drain(tester);
      expect(service.state.value.isActive, isTrue);

      iap.restoreError = PlatformException(code: 'storekit2_restore_failed');
      await tester.pump(const Duration(minutes: 5, seconds: 2));
      await drain(tester);
      expect(service.state.value.status, PremiumStatus.verifying);
      expect(service.state.value.isActive, isFalse);
      service.dispose();
      services.remove(service);
    });
  });

  group('Android 확인 재시도(가짜 시간)', () {
    testWidgets('G-R2: 확인이 안 되면 앞에 있는 동안에도 점점 길게 기다려 다시 시도하고, 확인되면 멈춘다', (tester) async {
      iap.owned = [_play(PurchaseStateWrapper.purchased, PurchaseStatus.restored)];
      final service = create(ackRetryDelay: const Duration(seconds: 10));
      await drain(tester);
      expect(iap.completed, hasLength(1));
      final queries = iap.restoreCount;

      await tester.pump(const Duration(seconds: 9));
      await drain(tester);
      expect(iap.completed, hasLength(1)); // 바로 되풀이하지 않는다
      await tester.pump(const Duration(seconds: 1));
      await drain(tester);
      expect(iap.completed, hasLength(2)); // 10초 뒤
      await tester.pump(const Duration(seconds: 19));
      await drain(tester);
      expect(iap.completed, hasLength(2));
      await tester.pump(const Duration(seconds: 1));
      await drain(tester);
      expect(iap.completed, hasLength(3)); // 그다음은 20초 뒤

      iap.onComplete =
          (_) => iap.owned = [_play(PurchaseStateWrapper.purchased, PurchaseStatus.restored, acknowledged: true)];
      await tester.pump(const Duration(seconds: 40));
      await drain(tester);
      expect(iap.completed, hasLength(4)); // 40초 뒤에 확인됨
      await tester.pump(const Duration(hours: 1));
      await drain(tester);
      expect(iap.completed, hasLength(4)); // 확인되면 멈춘다
      expect(iap.restoreCount - queries, 6); // 재시도마다 조회 두 번(다시 시도, 확인됐는지)
      service.dispose();
      services.remove(service);
    });

    testWidgets('R2-M2: 재시도 조회가 한 번 실패해도 다음 단계로 이어지고, 회복되면 확인된 뒤 멈춘다', (tester) async {
      iap.owned = [_play(PurchaseStateWrapper.purchased, PurchaseStatus.restored)];
      final service = create(ackRetryDelay: const Duration(seconds: 10));
      await drain(tester);
      expect(iap.completed, hasLength(1)); // 첫 확인은 안 됐다(조회가 계속 미확인으로 보여 준다)
      final queries = iap.restoreCount;

      // 10초 뒤 재시도의 조회가 일시적으로 실패한다
      iap.restoreError = InAppPurchaseException(
        source: 'google_play',
        code: 'restore_transactions_failed',
        message: '2',
      );
      await tester.pump(const Duration(seconds: 10));
      await drain(tester);
      expect(iap.restoreCount, queries + 1);
      expect(iap.completed, hasLength(1));
      expect(service.state.value.status, PremiumStatus.verifying); // 실패는 닫힌 쪽으로

      // 회복: 다음 단계(20초 뒤)에 다시 조회해 확인한다
      iap.restoreError = null;
      iap.onComplete =
          (_) => iap.owned = [_play(PurchaseStateWrapper.purchased, PurchaseStatus.restored, acknowledged: true)];
      await tester.pump(const Duration(seconds: 19));
      await drain(tester);
      expect(iap.completed, hasLength(1));
      expect(iap.restoreCount, queries + 1);
      await tester.pump(const Duration(seconds: 1));
      await drain(tester);
      expect(iap.completed, hasLength(2));
      expect(service.state.value.isActive, isTrue);
      expect(iap.restoreCount, queries + 3); // 실패 1 + 재시도 1 + 확인됐는지 1

      // 확인됐으니 더 묻지도 다시 확인하지도 않는다
      await tester.pump(const Duration(minutes: 20));
      await drain(tester);
      expect(iap.completed, hasLength(2));
      expect(iap.restoreCount, queries + 3);
      service.dispose();
      services.remove(service);
    });

    testWidgets('G-R2: 복원을 누르면 기다리지 않고 바로 다시 확인한다', (tester) async {
      iap.owned = [_play(PurchaseStateWrapper.purchased, PurchaseStatus.restored)];
      final service = create(ackRetryDelay: const Duration(minutes: 10));
      await drain(tester);
      expect(iap.completed, hasLength(1));

      unawaited(service.restore());
      await drain(tester);
      expect(iap.completed, hasLength(2));
      service.dispose();
      services.remove(service);
    });
  });

  group('G-R3·G-R5: 소유 조회로 구매를 끝내고, 이 구매의 거래만 기록', () {
    test('G-R3: 구매 이벤트를 놓쳐도 다음 소유 조회가 진행 중 구매를 끝내고 한 번 기록한다', () async {
      iap.products = _playProducts();
      final service = create();
      await settle();
      final monthly = (await service.loadProducts()).last;
      final outcome = service.purchase(monthly);
      await settle();

      // Play 결제는 끝났지만 purchased 이벤트가 오지 않았다. 앱이 다시 앞으로 와서 조회한다
      iap.owned = [_play(PurchaseStateWrapper.purchased, PurchaseStatus.restored, token: 'new')];
      resume();
      expect(await outcome, PurchaseOutcome.purchased);
      await settle();
      expect(service.state.value.isActive, isTrue);
      expect(analytics.events.single.$2, {AnalyticsParameterNames.period: 'monthly'});
    });

    test('G-R3: 앱이 닫혀 있는 동안 승인된 대기 구매도 시작 조회만으로 한 번 기록한다', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      iap.products = [_iosProduct('coconut_premium_yearly', '₩39,000')];
      final first = create();
      await settle();
      final yearly = (await first.loadProducts()).single;
      final outcome = first.purchase(yearly);
      await settle();
      iap.stream.add([_sk('coconut_premium_yearly', PurchaseStatus.pending, id: '0')]);
      expect(await outcome, PurchaseOutcome.pending);
      first.dispose();
      services.remove(first);

      // 다시 켬: purchased 이벤트 없이 소유 조회에만 승인된 구매가 있다
      iap = _FakeIap()..owned = [_sk('coconut_premium_yearly', PurchaseStatus.restored, id: '7')];
      final relaunched = create();
      await settle();
      expect(relaunched.state.value.isActive, isTrue);
      expect(analytics.events.single.$2, {AnalyticsParameterNames.period: 'yearly'});

      iap = _FakeIap()..owned = [_sk('coconut_premium_yearly', PurchaseStatus.restored, id: '7')];
      create();
      await settle();
      expect(analytics.events, hasLength(1));
    });

    test('G-R5: 시작 조회 전에 구매해도, 그때 이미 가진 같은 상품 거래는 이 구매로 치지 않는다', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      iap.products = [_iosProduct('coconut_premium_yearly', '₩39,000')];
      iap.owned = [_sk('coconut_premium_yearly', PurchaseStatus.restored, id: 'OLD')];
      iap.restoreGate = Completer<void>();
      final service = create();
      await settle();
      final yearly = (await service.loadProducts()).single;
      var settled = false;
      final outcome = service.purchase(yearly);
      unawaited(outcome.then((_) => settled = true));
      await settle();
      expect(iap.bought, isEmpty); // 이미 가진 거래를 알기 전에는 결제 창을 띄우지 않는다
      iap.restoreGate!.complete();
      await settle();
      expect(iap.bought, hasLength(1));

      // 예전 구매가 다시 온다: 이 구매를 끝내지도 기록하지도 않는다
      iap.stream.add([_sk('coconut_premium_yearly', PurchaseStatus.purchased, id: 'OLD')]);
      await settle();
      expect(settled, isFalse);
      expect(analytics.events, isEmpty);

      iap.owned = [...iap.owned, _sk('coconut_premium_yearly', PurchaseStatus.restored, id: 'NEW')];
      iap.stream.add([_sk('coconut_premium_yearly', PurchaseStatus.purchased, id: 'NEW')]);
      expect(await outcome, PurchaseOutcome.purchased);
      await settle();
      expect(analytics.events, hasLength(1));
    });

    test('G-R5: 다시 켠 뒤에도 승인 대기를 시작할 때 이미 가진 구매(같은 상품 id)는 그 구매로 치지 않는다', () async {
      iap.products = _playProducts();
      PurchaseDetails old() =>
          _play(PurchaseStateWrapper.purchased, PurchaseStatus.restored, acknowledged: true, token: 'old');
      iap.owned = [old()];
      final first = create();
      await settle();
      final yearly = (await first.loadProducts()).first;
      final outcome = first.purchase(yearly);
      await settle();
      iap.stream.add([_play(PurchaseStateWrapper.pending, PurchaseStatus.pending, token: 'new')]);
      expect(await outcome, PurchaseOutcome.pending);
      first.dispose();
      services.remove(first);

      // 다시 켬: 아직 승인 전이라 예전 구매만 있다
      iap = _FakeIap()..owned = [old()];
      create();
      await settle();
      expect(analytics.events, isEmpty);

      // 승인됨: 새 토큰이 생겼다
      iap.owned = [old(), _play(PurchaseStateWrapper.purchased, PurchaseStatus.restored, token: 'new')];
      resume();
      await settle();
      expect(analytics.events.single.$2, {AnalyticsParameterNames.period: 'yearly'});
    });

    test('G-R5: 7일이 넘은 승인 대기는 이 앱의 구매로 치지 않고 지운다', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await prefs({
        SharedPrefKeys.kPremiumEntitlementCache: jsonEncode({
          'pending': {
            'productId': 'coconut_premium_yearly',
            'period': 'yearly',
            'prior': <String>[],
            'at': DateTime.now().subtract(const Duration(days: 8)).millisecondsSinceEpoch,
          },
        }),
      });
      iap.owned = [_sk('coconut_premium_yearly', PurchaseStatus.restored, id: 'X')];
      final service = create();
      await settle();

      expect(service.state.value.isActive, isTrue);
      expect(analytics.events, isEmpty);
      expect(
        SharedPrefsRepository().getStringOrNull(SharedPrefKeys.kPremiumEntitlementCache),
        isNot(contains('pending')),
      );
    });
  });

  group('생성은 throw하지 않는다', () {
    test('B: 다른 형식의 저장값·시작하지 못하는 스토어에도 throw 없이 사용 불가·비활성으로 둔다', () async {
      await prefs({SharedPrefKeys.kPremiumEntitlementCache: 42, SharedPrefKeys.kPremiumDebugOverride: 'yes'});
      late InAppPurchaseEntitlementService service;
      expect(() => service = create(store: _BrokenIap(), debugOverrideAllowed: true), returnsNormally);
      await settle();

      expect(service.state.value.status, PremiumStatus.none);
      expect(service.state.value.isActive, isFalse);
      expect(service.debugOverride, isFalse);
      expect(service.isAvailable, isFalse);
      expect(await service.loadProducts(), isEmpty);
      await expectLater(service.restore(), throwsStateError);

      // 저장값만 깨졌으면 스토어 확인은 그대로 한다
      final healthy = create();
      await settle();
      expect(healthy.state.value.status, PremiumStatus.none);
      expect(iap.restoreCount, 1);
    });
  });

  group('구독 관리 열기', () {
    test('m6: 열지 못하면(false·예외) throw, 열리면 App Store 구독 화면', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await expectLater(create(launch: (_) async => false).openManageSubscriptions(), throwsStateError);
      await expectLater(
        create(launch: (_) async => throw PlatformException(code: 'ACTIVITY_NOT_FOUND')).openManageSubscriptions(),
        throwsA(isA<PlatformException>()),
      );
      Uri? opened;
      await create(
        launch: (url) async {
          opened = url;
          return true;
        },
      ).openManageSubscriptions();
      expect(opened, Uri.parse('https://apps.apple.com/account/subscriptions'));
    });
  });

  group('Premium 강제 켜기(디버그·regtest 전용)', () {
    test('허용 조건: 디버그 빌드 또는 regtest. 메인넷 릴리즈는 안 됨', () {
      expect(premiumDebugOverrideAllowed(debugMode: false, network: NetworkType.mainnet), isFalse);
      expect(premiumDebugOverrideAllowed(debugMode: false, network: NetworkType.testnet), isFalse);
      expect(premiumDebugOverrideAllowed(debugMode: false, network: NetworkType.regtest), isTrue);
      expect(premiumDebugOverrideAllowed(debugMode: true, network: NetworkType.mainnet), isTrue);
    });

    test('메인넷 릴리즈 설정: 저장된 켜기도, 새로 켜기도 무시', () async {
      await prefs({SharedPrefKeys.kPremiumDebugOverride: true});
      final service = create(debugOverrideAllowed: false);
      await settle();
      expect(service.state.value.isActive, isFalse);

      await service.setDebugOverride(true);
      expect(service.debugOverride, isFalse);
      expect(service.state.value.isActive, isFalse);
    });

    test('허용되면 active로 바꾸고, 끄면 스토어 상태로 돌아온다', () async {
      final service = create(debugOverrideAllowed: true);
      await settle();

      await service.setDebugOverride(true);
      expect(service.state.value.isActive, isTrue);
      expect(SharedPrefsRepository().getBool(SharedPrefKeys.kPremiumDebugOverride), isTrue);

      await service.setDebugOverride(false);
      expect(service.state.value.status, PremiumStatus.none);
    });
  });
}
