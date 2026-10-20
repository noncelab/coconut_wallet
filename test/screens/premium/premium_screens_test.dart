import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutSwitch;
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/premium/premium_paywall_screen.dart';
import 'package:coconut_wallet/screens/premium/premium_subscription_screen.dart';
import 'package:coconut_wallet/screens/settings/app_settings/app_settings_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/premium/entitlement_service.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart' show InlineActionButton;
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/loading/loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

class _Preferences extends ChangeNotifier implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
  @override
  FiatCode get selectedFiat => FiatCode.USD;
  @override
  String get language => 'ko';
  @override
  NumberFormatPreset get numberFormatPreset => NumberFormatPreset.dotDecimal;
  @override
  bool get isManualUtxoSelectionMode => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Auth extends ChangeNotifier implements AuthProvider {
  @override
  bool get isSetPin => false;
  @override
  bool get canCheckBiometrics => false;
  @override
  bool get isSetBiometrics => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PremiumProduct _product(PremiumPeriod period, String price, {int? trialDays}) => PremiumProduct(
  config: kAppStorePremiumProducts.firstWhere((c) => c.period == period),
  price: price,
  freeTrialDays: trialDays,
);

final _products = [_product(PremiumPeriod.yearly, '₩39,000'), _product(PremiumPeriod.monthly, 'US\$ 4,99')];

/// 상품 불러오기·복원이 [gate]가 열릴 때까지 기다리는 스토어
class _SlowPremium extends FakeEntitlementService {
  _SlowPremium({super.products, super.initial});

  final gate = Completer<void>();

  @override
  Future<List<PremiumProduct>> loadProducts() async {
    await gate.future;
    return super.loadProducts();
  }

  @override
  Future<void> restore() async {
    await gate.future;
    return super.restore();
  }
}

/// 스토어 구독 관리를 열지 못하는 서비스
class _ManageFails extends FakeEntitlementService {
  _ManageFails() : super(initial: const PremiumState(PremiumStatus.active));

  @override
  Future<void> openManageSubscriptions() async => throw StateError('subscription management did not open');
}

/// 구매가 뜻밖에 예외로 끝나는 서비스
class _ThrowingPremium extends FakeEntitlementService {
  _ThrowingPremium({super.products});

  int purchases = 0;

  @override
  Future<PurchaseOutcome> purchase(PremiumProduct product) async {
    purchases++;
    throw StateError('store');
  }
}

void main() {
  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    NetworkType.setNetworkType(NetworkType.regtest);
  });

  Widget app(EntitlementService? premium, Widget home, {bool reduceMotion = false, double textScale = 1}) =>
      MultiProvider(
        providers: [
          Provider<AnalyticsService>(create: (_) => AnalyticsService(null, true)),
          ChangeNotifierProvider<PreferenceProvider>.value(value: _Preferences()),
          ChangeNotifierProvider<AuthProvider>.value(value: _Auth()),
          if (premium != null) Provider<EntitlementService>.value(value: premium),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.light),
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(disableAnimations: reduceMotion, textScaler: TextScaler.linear(textScale)),
                child: child!,
              ),
          home: home,
        ),
      );

  /// 런처 버튼으로 [open]을 불러 돌려준 값을 받는다
  Future<ValueNotifier<bool?>> pumpPaywall(
    WidgetTester tester,
    FakeEntitlementService premium, {
    bool reduceMotion = false,
    double textScale = 1,
  }) async {
    final result = ValueNotifier<bool?>(null);
    await tester.pumpWidget(
      app(
        premium,
        reduceMotion: reduceMotion,
        textScale: textScale,
        Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed: () async => result.value = await PremiumPaywallScreen.open(context),
                  child: const Text('open'),
                ),
              ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    if (premium is _SlowPremium) {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600)); // 화면 전환
    } else {
      await tester.pumpAndSettle();
    }
    return result;
  }

  /// 토스트는 3초 뒤 사라진다
  Future<void> waitToast(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  }

  Border? planBorder(WidgetTester tester, PremiumPeriod period) =>
      tester.widget<ShrinkAnimationButton>(find.byKey(Key('premium-plan-${period.name}'))).border;

  group('페이월', () {
    testWidgets('스토어 가격 그대로·연간 기본 선택·자동 갱신 고지·약관·개인정보·복원', variant: TargetPlatformVariant.only(TargetPlatform.iOS), (
      tester,
    ) async {
      final premium = FakeEntitlementService(products: _products);
      await pumpPaywall(tester, premium);

      expect(find.text('₩39,000'), findsOneWidget);
      expect(find.text('US\$ 4,99'), findsOneWidget);
      expect(find.text(t.premium.paywall.period_year), findsOneWidget);
      expect(find.text(t.premium.paywall.compare_note), findsOneWidget);
      expect(planBorder(tester, PremiumPeriod.yearly)!.top.color, isNot(Colors.transparent));
      expect(planBorder(tester, PremiumPeriod.monthly)!.top.color, Colors.transparent);
      expect(find.text('${t.premium.store_notice.apple} ${t.premium.paywall.platform_note}'), findsOneWidget);
      expect(find.text(t.app_info_screen.terms_of_service), findsOneWidget);
      expect(find.text(t.app_info_screen.privacy_policy), findsOneWidget);
      expect(find.text(t.premium.paywall.subscribe), findsOneWidget);
      expect(find.text(t.premium.paywall.trial(n: 7)), findsNothing);
      // 스토어가 체험을 주지 않으면 체험 문구는 어디에도 없다(고지 포함)
      expect(find.textContaining(t.premium.store_notice.apple_trial), findsNothing);
      expect(find.textContaining(t.premium.paywall.start_trial), findsNothing);

      await tester.tap(find.byKey(const Key('premium-paywall-restore')));
      await tester.pump();
      expect(premium.restoreCount, 1);
      expect(find.text(t.premium.toast.nothing_to_restore), findsOneWidget);
      await waitToast(tester);
    });

    testWidgets('정책: 320dp에서 구독 버튼이 켜져 있으면 고른 플랜의 가격·기간과 약관·개인정보 링크가 버튼 바로 위 화면 안에 있다', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpPaywall(tester, FakeEntitlementService(products: _products));

      final buttonFinder = find.byKey(const Key('premium-paywall-subscribe'));
      expect(tester.widget<InlineActionButton>(buttonFinder).isActive, isTrue);
      final button = tester.getRect(buttonFinder);
      const screen = Rect.fromLTWH(0, 0, 320, 640);
      void expectAboveButton(Finder finder) {
        final rect = tester.getRect(finder);
        expect(screen.contains(rect.topLeft) && screen.contains(rect.bottomRight.translate(-0.5, -0.5)), isTrue);
        expect(rect.bottom, lessThanOrEqualTo(button.top));
      }

      String plan(String period, String price) => '${t.premium.name} · $period · $price';
      expectAboveButton(find.text(plan(t.premium.paywall.period_year, '₩39,000')));
      expectAboveButton(find.text(t.premium.paywall.renew_line(store: 'Google Play')));
      expectAboveButton(find.text(t.app_info_screen.terms_of_service));
      expectAboveButton(find.text(t.app_info_screen.privacy_policy));
      expectAboveButton(find.text(t.premium.paywall.restore));
      expect(button.bottom, lessThanOrEqualTo(640));

      // 플랜을 바꾸면 버튼 위 줄도 그 플랜의 가격·기간으로 바뀐다
      await tester.ensureVisible(find.byKey(const Key('premium-plan-monthly')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('premium-plan-monthly')));
      await tester.pumpAndSettle();
      expectAboveButton(find.text(plan(t.premium.paywall.period_month, 'US\$ 4,99')));
    });

    testWidgets('가이드·도움말 줄은 도움 받기 시트를 연다', (tester) async {
      await pumpPaywall(tester, FakeEntitlementService(products: _products));
      await tester.ensureVisible(find.byKey(const Key('premium-paywall-help')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('premium-paywall-help')));
      await tester.pumpAndSettle();

      expect(find.text(t.safety_guide.help_center.open), findsOneWidget);
    });

    testWidgets('Android는 Google Play 고지', variant: TargetPlatformVariant.only(TargetPlatform.android), (tester) async {
      await pumpPaywall(tester, FakeEntitlementService(products: _products));

      expect(find.text('${t.premium.store_notice.google} ${t.premium.paywall.platform_note}'), findsOneWidget);
    });

    testWidgets('무료 체험은 스토어 상품에 있을 때만', (tester) async {
      await pumpPaywall(
        tester,
        FakeEntitlementService(products: [_product(PremiumPeriod.yearly, '₩39,000', trialDays: 7), _products.last]),
      );
      expect(find.text(t.premium.paywall.trial(n: 7)), findsOneWidget);
      expect(find.text(t.premium.paywall.start_trial), findsOneWidget);
      expect(find.textContaining(t.premium.store_notice.google_trial), findsOneWidget);
      expect(
        find.text('${t.premium.name} · ${t.premium.paywall.period_year} · ₩39,000 · ${t.premium.paywall.trial(n: 7)}'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byKey(const Key('premium-plan-monthly')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('premium-plan-monthly')));
      await tester.pumpAndSettle();
      expect(planBorder(tester, PremiumPeriod.monthly)!.top.color, isNot(Colors.transparent));
      expect(find.text(t.premium.paywall.subscribe), findsOneWidget);
      expect(find.textContaining(t.premium.store_notice.google_trial), findsNothing);
    });

    testWidgets('구독 → 결과 화면 → 확인 → open이 true', (tester) async {
      final premium = FakeEntitlementService(products: _products);
      final result = await pumpPaywall(tester, premium);

      await tester.tap(find.text(t.premium.paywall.subscribe));
      await tester.pumpAndSettle();
      expect(find.text(t.premium.purchased.title), findsOneWidget);
      expect(premium.state.value.period, PremiumPeriod.yearly);

      await tester.tap(find.text(t.confirm));
      await tester.pumpAndSettle();
      expect(result.value, isTrue);
      expect(find.byKey(const Key('premium-paywall')), findsNothing);
    });

    testWidgets('취소면 아무 안내 없이 그대로, 실패면 경고 토스트', (tester) async {
      final premium = FakeEntitlementService(products: _products, purchaseOutcome: PurchaseOutcome.cancelled);
      await pumpPaywall(tester, premium);

      await tester.tap(find.text(t.premium.paywall.subscribe));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('premium-paywall')), findsOneWidget);
      expect(find.text(t.premium.toast.failed), findsNothing);

      premium.purchaseOutcome = PurchaseOutcome.failed;
      await tester.tap(find.text(t.premium.paywall.subscribe));
      await tester.pump();
      expect(find.text(t.premium.toast.failed), findsOneWidget);
      expect(premium.state.value.isActive, isFalse);
      await waitToast(tester);
    });

    testWidgets('m7: 승인 대기면 결과 화면(정보 아이콘)으로 알리고, 확인하면 open은 false', (tester) async {
      final premium = FakeEntitlementService(products: _products, purchaseOutcome: PurchaseOutcome.pending);
      final result = await pumpPaywall(tester, premium);

      await tester.tap(find.text(t.premium.paywall.subscribe));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('premium-result-pending')), findsOneWidget);
      expect(find.text(t.premium.purchased.pending_title), findsOneWidget);
      expect(find.text(t.premium.purchased.pending_body), findsOneWidget);
      expect(result.value, isNull); // 확인 전에는 닫히지 않는다

      await tester.tap(find.text(t.confirm));
      await tester.pumpAndSettle();
      expect(result.value, isFalse);
      expect(find.byKey(const Key('premium-paywall')), findsNothing);
    });

    testWidgets('G-M4: 구매가 예외로 끝나도 로딩을 걷고 실패 안내, 다시 누를 수 있다', (tester) async {
      final premium = _ThrowingPremium(products: _products);
      await pumpPaywall(tester, premium);

      await tester.tap(find.text(t.premium.paywall.subscribe));
      await tester.pump();
      expect(find.text(t.premium.toast.failed), findsOneWidget);
      expect(find.byType(FullscreenLoadingIndicator), findsNothing);
      await waitToast(tester);

      await tester.tap(find.text(t.premium.paywall.subscribe));
      await tester.pump();
      expect(premium.purchases, 2);
      await waitToast(tester);
    });

    testWidgets('m5: 동작 줄이기면 상품 불러오는 동안 스켈레톤이 움직이지 않는다', (tester) async {
      final premium = _SlowPremium(products: _products);
      await pumpPaywall(tester, premium, reduceMotion: true);

      expect(tester.widget<Shimmer>(find.byType(Shimmer)).enabled, isFalse);
      premium.gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(Shimmer), findsNothing);
    });

    testWidgets('스토어에 연결할 수 없으면 안내와 다시 시도, 구독 버튼은 동작하지 않음', (tester) async {
      final premium = FakeEntitlementService(isAvailable: false, products: _products);
      await pumpPaywall(tester, premium);

      expect(find.byKey(const Key('premium-paywall-unavailable')), findsOneWidget);
      expect(find.text(t.premium.paywall.store_unavailable), findsOneWidget);
      expect(find.text(t.retry), findsOneWidget);
      await tester.tap(find.text(t.premium.paywall.subscribe));
      await tester.pumpAndSettle();
      expect(premium.state.value.status, PremiumStatus.none);
      expect(find.text(t.premium.purchased.title), findsNothing);
    });
  });

  group('구독 관리', () {
    Future<void> pumpManage(WidgetTester tester, FakeEntitlementService premium, {bool reduceMotion = false}) async {
      await tester.pumpWidget(
        app(
          premium,
          reduceMotion: reduceMotion,
          Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(onPressed: () => PremiumSubscriptionScreen.open(context), child: const Text('open')),
                ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('m4: 복원을 기다리는 동안 화면이 닫혀도 다른 화면의 로딩·토스트를 건드리지 않는다', (tester) async {
      final premium = _SlowPremium(initial: const PremiumState(PremiumStatus.active));
      await pumpManage(tester, premium);

      await tester.tap(find.byKey(const Key('premium-subscription-restore')));
      await tester.pump();
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('premium-subscription')), findsNothing);

      premium.gate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      expect(find.text(t.premium.toast.restored), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('m6: 스토어 구독 관리를 열지 못하면 경고 토스트', (tester) async {
      await pumpManage(tester, _ManageFails());

      await tester.tap(find.byKey(const Key('premium-subscription-manage')));
      await tester.pump();
      expect(find.text(t.premium.toast.manage_failed), findsOneWidget);
      await waitToast(tester);
    });

    testWidgets('m5: 동작 줄이기면 확인 중 스켈레톤이 움직이지 않는다', (tester) async {
      final premium = FakeEntitlementService(initial: const PremiumState(PremiumStatus.verifying));
      await pumpManage(tester, premium, reduceMotion: true);

      expect(tester.widget<Shimmer>(find.byType(Shimmer)).enabled, isFalse);
    });

    testWidgets('상태별 카드: 사용 중·만료(날짜)·없음 → 페이월', (tester) async {
      final premium = FakeEntitlementService(
        products: _products,
        initial: const PremiumState(PremiumStatus.active, period: PremiumPeriod.yearly),
      );
      await pumpManage(tester, premium);
      expect(find.text(t.premium.subscription.active_title), findsOneWidget);
      expect(find.text(t.premium.subscription.yearly_plan), findsOneWidget);
      expect(find.byKey(const Key('premium-subscription-see-plans')), findsNothing);

      premium.emit(PremiumState(PremiumStatus.expired, expiresAt: DateTime(2026, 9, 1)));
      await tester.pump();
      expect(find.text(t.premium.subscription.expired_on(date: '2026.09.01')), findsOneWidget);
      expect(find.text(t.premium.subscription.resubscribe), findsOneWidget);
      expect(find.text(t.premium.subscription.expired_note), findsOneWidget);

      premium.emit(const PremiumState(PremiumStatus.none));
      await tester.pump();
      expect(find.text(t.premium.subscription.none_title), findsOneWidget);
      await tester.tap(find.text(t.premium.card.explore));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('premium-paywall')), findsOneWidget);
    });

    testWidgets('구매 복원과 스토어 구독 관리', (tester) async {
      final premium = FakeEntitlementService(initial: const PremiumState(PremiumStatus.active));
      await pumpManage(tester, premium);

      await tester.tap(find.byKey(const Key('premium-subscription-restore')));
      await tester.pump();
      expect(premium.restoreCount, 1);
      expect(find.text(t.premium.toast.restored), findsOneWidget);
      await waitToast(tester);

      await tester.tap(find.byKey(const Key('premium-subscription-manage')));
      await tester.pumpAndSettle();
      expect(premium.manageCount, 1);
    });
  });

  group('앱 설정', () {
    testWidgets('Premium 줄과 강제 켜기는 EntitlementService가 있을 때만', (tester) async {
      await tester.pumpWidget(app(null, const AppSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('app-settings-premium')), findsNothing);
      expect(find.byKey(const Key('app-settings-premium-debug')), findsNothing);

      final premium = FakeEntitlementService(initial: const PremiumState(PremiumStatus.active));
      await tester.pumpWidget(app(premium, const AppSettingsScreen()));
      await tester.pumpAndSettle();
      final row = find.byKey(const Key('app-settings-premium'));
      expect(find.descendant(of: row, matching: find.text(t.premium.name)), findsOneWidget);
      expect(find.descendant(of: row, matching: find.text(t.premium.subscription.active)), findsOneWidget);

      // 테스트는 디버그 빌드라 강제 켜기가 보인다(메인넷 릴리즈 조건은 서비스 테스트에서 고정)
      final toggle = find.descendant(
        of: find.byKey(const Key('app-settings-premium-debug')),
        matching: find.byType(CoconutSwitch),
      );
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(premium.debugOverride, isTrue);

      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('premium-subscription')), findsOneWidget);
    });
  });

  // 실제 글꼴로 재야 한다(테스트 기본 글꼴은 글자마다 1em이라 라틴 문자가 실제보다 훨씬 넓다). 다른 테스트에 영향이 없게 맨 끝에서 불러온다
  group('정책: 버튼 위 갱신 줄(320dp, 실제 글꼴)', () {
    setUpAll(() async {
      final font =
          FontLoader('Pretendard')
            ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.ttf'));
      await font.load();
    });

    /// 그려진 RichText와 같은 글·글꼴·배율·너비로 줄 수를 센다
    int lineCount(WidgetTester tester, Finder finder) {
      final rich = tester.widget<RichText>(find.descendant(of: finder, matching: find.byType(RichText)));
      final painter = TextPainter(
        text: rich.text,
        textAlign: rich.textAlign,
        textDirection: TextDirection.ltr,
        textScaler: rich.textScaler,
      )..layout(maxWidth: tester.getSize(finder).width);
      return painter.computeLineMetrics().length;
    }

    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      for (final locale in AppLocale.values) {
        testWidgets(
          '${locale.name}: 1배는 한 줄, 1.3배도 두 줄 이내로 버튼 위에 다 보인다',
          variant: TargetPlatformVariant.only(platform),
          (tester) async {
            tester.view.physicalSize = const Size(320, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            LocaleSettings.setLocaleSync(locale);
            final store = platform == TargetPlatform.android ? 'Google Play' : 'App Store';

            for (final (scale, maxLines) in [(1.0, 1), (1.3, 2)]) {
              await pumpPaywall(tester, FakeEntitlementService(products: _products), textScale: scale);
              final line = find.byKey(const Key('premium-paywall-renew-line'));
              expect(tester.widget<Text>(line).data, t.premium.paywall.renew_line(store: store));
              expect(lineCount(tester, line), lessThanOrEqualTo(maxLines), reason: '$scale');
              final rect = tester.getRect(line);
              expect(rect.top, greaterThanOrEqualTo(0));
              expect(
                rect.bottom,
                lessThanOrEqualTo(tester.getRect(find.byKey(const Key('premium-paywall-subscribe'))).top),
              );
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox()); // 다음 배율은 새 화면 스택에서
            }
          },
        );
      }
    }
  });
}
