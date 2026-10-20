import 'dart:async';

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutSwitch;
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
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
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:coconut_wallet/widgets/common/loading/loading_indicator.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
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

  final colors = resolveCoconutThemeExtension(variant: CoconutThemeVariant.light).colors;

  /// 고른 플랜 카드만 로고 그라데이션 링, 안 고른 카드는 같은 두께의 투명 링
  Gradient? planRing(WidgetTester tester, PremiumPeriod period) =>
      tester.widget<ShrinkAnimationButton>(find.byKey(Key('premium-plan-${period.name}'))).borderGradient;

  /// 줄바꿈을 막는 보이지 않는 문자(단어 이음·줄바꿈 없는 공백)를 걷어 낸 글
  String plain(String text) => text.replaceAll('\u2060', '').replaceAll('\u00A0', ' ');

  /// 버튼 위 플랜 줄 + 갱신 줄(Text.rich 하나)
  String planText(WidgetTester tester) =>
      plain(tester.widget<Text>(find.byKey(const Key('premium-paywall-selected-plan'))).textSpan!.toPlainText());

  bool isAsset(Widget w, String asset) =>
      w is SvgPicture && w.bytesLoader is SvgAssetLoader && (w.bytesLoader as SvgAssetLoader).assetName == asset;

  ColorFilter tint(Color color) => ColorFilter.mode(color, BlendMode.srcIn);

  /// R1(safetyKoText)로 한국어 글자 사이에 이음 문자가 들어가도 원문으로 찾는다
  Finder findText(String value) =>
      find.byWidgetPredicate((w) => w is Text && plain(w.data ?? w.textSpan?.toPlainText() ?? '') == value);

  /// [findText]의 포함 버전(여러 문장을 한 Text로 잇는 스토어 고지)
  Finder findTextContaining(String value) =>
      find.byWidgetPredicate((w) => w is Text && plain(w.data ?? w.textSpan?.toPlainText() ?? '').contains(value));

  group('페이월', () {
    testWidgets('스토어 가격 그대로·연간 기본 선택·자동 갱신 고지·약관·개인정보·복원', variant: TargetPlatformVariant.only(TargetPlatform.iOS), (
      tester,
    ) async {
      final premium = FakeEntitlementService(products: _products);
      await pumpPaywall(tester, premium);

      expect(findText('₩39,000'), findsOneWidget);
      expect(findText('US\$ 4,99'), findsOneWidget);
      expect(findText(t.premium.paywall.period_year), findsOneWidget);
      expect(findText(t.premium.paywall.compare_note), findsOneWidget);
      expect(planRing(tester, PremiumPeriod.yearly), colors.mainnetLogoGradient);
      expect((planRing(tester, PremiumPeriod.monthly)! as LinearGradient).colors, everyElement(Colors.transparent));
      expect(findText('${t.premium.store_notice.apple} ${t.premium.paywall.platform_note}'), findsOneWidget);
      // X9: 고지도 R1(safetyKoText)이라 큰 글자에서 단어 중간에서 끊기지 않는다
      expect(tester.widget<Text>(find.byKey(const Key('premium-paywall-notice'))).data, contains('\u2060'));
      expect(findText(t.app_info_screen.terms_of_service), findsOneWidget);
      expect(findText(t.app_info_screen.privacy_policy), findsOneWidget);
      expect(findText(t.premium.paywall.subscribe), findsOneWidget);
      expect(findText(t.premium.paywall.trial(n: 7)), findsNothing);
      // 스토어가 체험을 주지 않으면 체험 문구는 어디에도 없다(고지 포함)
      expect(findTextContaining(t.premium.store_notice.apple_trial), findsNothing);
      expect(find.textContaining(t.premium.paywall.start_trial), findsNothing);

      await tester.tap(find.byKey(const Key('premium-paywall-restore')));
      await tester.pump();
      expect(premium.restoreCount, 1);
      expect(findText(t.premium.toast.nothing_to_restore), findsOneWidget);
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

      String plan(String period, String price) =>
          '${t.premium.name} · $period · $price\n${t.premium.paywall.renew_line(store: 'Google Play')}';
      final planLine = find.byKey(const Key('premium-paywall-selected-plan'));
      expect(planText(tester), plan(t.premium.paywall.period_year, '₩39,000'));
      expectAboveButton(planLine);
      expectAboveButton(findText(t.app_info_screen.terms_of_service));
      expectAboveButton(findText(t.app_info_screen.privacy_policy));
      expectAboveButton(findText(t.premium.paywall.restore));
      expect(button.bottom, lessThanOrEqualTo(640));
      // 구매 복원은 법적 링크 사이가 아니라 버튼 바로 위 따로 한 줄(UI_SPEC §10.3)
      expect(
        tester.getRect(find.byKey(const Key('premium-paywall-restore'))).top,
        greaterThanOrEqualTo(tester.getRect(find.byKey(const Key('premium-paywall-terms'))).bottom),
      );

      // 플랜을 바꾸면 버튼 위 줄도 그 플랜의 가격·기간으로 바뀐다
      await tester.ensureVisible(find.byKey(const Key('premium-plan-monthly')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('premium-plan-monthly')));
      await tester.pumpAndSettle();
      expect(planText(tester), plan(t.premium.paywall.period_month, 'US\$ 4,99'));
      expectAboveButton(planLine);
    });

    testWidgets('POLISH G15: 비교표 아래 도움 링크가 도움 받기 시트를 연다', (tester) async {
      await pumpPaywall(tester, FakeEntitlementService(products: _products));
      await tester.ensureVisible(find.byKey(const Key('premium-paywall-help')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('premium-paywall-help')));
      await tester.pumpAndSettle();

      // 가치 행은 정적이고 비교표 아래 링크가 도움 받기 시트를 연다(링크 글과 시트 버튼 글이 같아 채널 키로 본다)
      expect(find.byKey(const Key('help-channel-discord')), findsOneWidget);
    });

    testWidgets('Android는 Google Play 고지', variant: TargetPlatformVariant.only(TargetPlatform.android), (tester) async {
      await pumpPaywall(tester, FakeEntitlementService(products: _products));

      expect(findText('${t.premium.store_notice.google} ${t.premium.paywall.platform_note}'), findsOneWidget);
    });

    testWidgets('무료 체험은 스토어 상품에 있을 때만', (tester) async {
      await pumpPaywall(
        tester,
        FakeEntitlementService(products: [_product(PremiumPeriod.yearly, '₩39,000', trialDays: 7), _products.last]),
      );
      expect(findText(t.premium.paywall.trial(n: 7)), findsOneWidget);
      // 체험은 Premium 상품의 속성: premiumText(초록 아님)
      expect(tester.widget<Text>(findText(t.premium.paywall.trial(n: 7))).style!.color, colors.premiumText);
      expect(findText(t.premium.paywall.start_trial), findsOneWidget);
      expect(findTextContaining(t.premium.store_notice.google_trial), findsOneWidget);
      expect(
        planText(tester).split('\n').first,
        '${t.premium.name} · ${t.premium.paywall.period_year} · ₩39,000 · ${t.premium.paywall.trial(n: 7)}',
      );

      await tester.ensureVisible(find.byKey(const Key('premium-plan-monthly')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('premium-plan-monthly')));
      await tester.pumpAndSettle();
      expect(planRing(tester, PremiumPeriod.monthly), colors.mainnetLogoGradient);
      expect(findText(t.premium.paywall.subscribe), findsOneWidget);
      expect(findTextContaining(t.premium.store_notice.google_trial), findsNothing);
    });

    testWidgets('구독 → 결과 화면 → 확인 → open이 true', (tester) async {
      final premium = FakeEntitlementService(products: _products);
      final result = await pumpPaywall(tester, premium);

      await tester.tap(findText(t.premium.paywall.subscribe));
      await tester.pumpAndSettle();
      expect(findText(t.premium.purchased.title), findsOneWidget);
      expect(premium.state.value.period, PremiumPeriod.yearly);
      // POLISH G10: 제목 위 Premium 칩
      expect(
        tester.getRect(find.byType(PremiumChip)).bottom,
        lessThanOrEqualTo(tester.getRect(findText(t.premium.purchased.title)).top),
      );
      // §4 D9: 본문 아래 비상 이동 목적지 안내 한 줄
      expect(
        tester.getRect(findText(t.premium.purchased.rescue_hint)).top,
        greaterThanOrEqualTo(tester.getRect(findText(t.premium.purchased.body)).bottom),
      );

      await tester.tap(findText(t.confirm));
      await tester.pumpAndSettle();
      expect(result.value, isTrue);
      expect(find.byKey(const Key('premium-paywall')), findsNothing);
    });

    testWidgets('취소면 아무 안내 없이 그대로, 실패면 경고 토스트', (tester) async {
      final premium = FakeEntitlementService(products: _products, purchaseOutcome: PurchaseOutcome.cancelled);
      await pumpPaywall(tester, premium);

      await tester.tap(findText(t.premium.paywall.subscribe));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('premium-paywall')), findsOneWidget);
      expect(findText(t.premium.toast.failed), findsNothing);

      premium.purchaseOutcome = PurchaseOutcome.failed;
      await tester.tap(findText(t.premium.paywall.subscribe));
      await tester.pump();
      expect(findText(t.premium.toast.failed), findsOneWidget);
      expect(premium.state.value.isActive, isFalse);
      await waitToast(tester);
    });

    testWidgets('m7: 승인 대기면 결과 화면(정보 아이콘)으로 알리고, 확인하면 open은 false', (tester) async {
      final premium = FakeEntitlementService(products: _products, purchaseOutcome: PurchaseOutcome.pending);
      final result = await pumpPaywall(tester, premium);

      await tester.tap(findText(t.premium.paywall.subscribe));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('premium-result-pending')), findsOneWidget);
      expect(find.byType(PremiumChip), findsNothing); // 승인 전에는 Premium이 아니다
      expect(find.byKey(const Key('premium-result-rescue-hint')), findsNothing);
      expect(findText(t.premium.purchased.pending_title), findsOneWidget);
      expect(findText(t.premium.purchased.pending_body), findsOneWidget);
      expect(result.value, isNull); // 확인 전에는 닫히지 않는다

      await tester.tap(findText(t.confirm));
      await tester.pumpAndSettle();
      expect(result.value, isFalse);
      expect(find.byKey(const Key('premium-paywall')), findsNothing);
    });

    testWidgets('G-M4: 구매가 예외로 끝나도 로딩을 걷고 실패 안내, 다시 누를 수 있다', (tester) async {
      final premium = _ThrowingPremium(products: _products);
      await pumpPaywall(tester, premium);

      await tester.tap(findText(t.premium.paywall.subscribe));
      await tester.pump();
      expect(findText(t.premium.toast.failed), findsOneWidget);
      expect(find.byType(FullscreenLoadingIndicator), findsNothing);
      await waitToast(tester);

      await tester.tap(findText(t.premium.paywall.subscribe));
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
      expect(findText(t.premium.paywall.store_unavailable), findsOneWidget);
      expect(findText(t.retry), findsOneWidget);
      await tester.tap(findText(t.premium.paywall.subscribe));
      await tester.pumpAndSettle();
      expect(premium.state.value.status, PremiumStatus.none);
      expect(findText(t.premium.purchased.title), findsNothing);
    });

    testWidgets('POLISH G3·G5·G6·G7·G8: 히어로, 비교표 머리, 판매표 체크 색, 가치 행 아이콘, 플랜 고름 표시', (tester) async {
      await pumpPaywall(tester, FakeEntitlementService(products: _products));

      expect(find.byType(PremiumHero), findsOneWidget);
      // G15: 가치 행 셋은 모두 정적(화살표·누름 없음)
      expect(find.byIcon(Icons.keyboard_arrow_right_rounded), findsNothing);
      // 고정 칸의 열 제목은 줄여서 한 줄, Premium 열 제목 앞에 젬 12
      final premiumHeader = find.ancestor(of: findText(t.premium.badge), matching: find.byType(FittedBox));
      expect(premiumHeader, findsOneWidget);
      expect(
        tester.widget<PremiumMark>(find.descendant(of: premiumHeader, matching: find.byType(PremiumMark))).size,
        12,
      );
      expect(find.ancestor(of: findText(t.premium.paywall.free), matching: find.byType(FittedBox)), findsOneWidget);
      // 판매표에는 초록이 없다: 무료 열 iconPrimary, Premium 열 premiumText, "–"는 iconSecondary
      final checks = tester.widgetList<SvgPicture>(
        find.byWidgetPredicate((w) => isAsset(w, CommonActionIconPath.check)),
      );
      expect(checks.map((c) => c.colorFilter).toSet(), {tint(colors.iconPrimary), tint(colors.premiumText)});
      expect(tester.widgetList<Text>(findText('–')).map((d) => d.style!.color).toSet(), {colors.iconSecondary});
      // 가치 행 아이콘은 premiumText
      for (final icon in [
        FeatureShortcutIconPath.transactionDraft,
        CommonActionIconPath.arrowReload,
        FeatureShortcutIconPath.tutorial,
      ]) {
        expect(
          tester.widget<SvgPicture>(find.byWidgetPredicate((w) => isAsset(w, icon))).colorFilter,
          tint(colors.premiumText),
        );
      }
      // 고름 표시는 UtxoSelectionCard와 같은 circleCheck(고름 borderStrong, 안 고름 iconSecondary)
      ColorFilter? marker(PremiumPeriod period) =>
          tester
              .widget<SvgPicture>(
                find.descendant(
                  of: find.byKey(Key('premium-plan-${period.name}')),
                  matching: find.byWidgetPredicate((w) => isAsset(w, CommonFormIconPath.circleCheck)),
                ),
              )
              .colorFilter;
      expect(marker(PremiumPeriod.yearly), tint(colors.borderStrong));
      expect(marker(PremiumPeriod.monthly), tint(colors.iconSecondary));
      expect(tester.widget<ShrinkAnimationButton>(find.byKey(const Key('premium-plan-yearly'))).borderWidth, 1.5);
      expect(tester.widget<ShrinkAnimationButton>(find.byKey(const Key('premium-plan-monthly'))).borderWidth, 1.5);
    });

    testWidgets('POLISH G4: 점 없는 법적 링크, 복원은 버튼 바로 위, 본문 끝 페이드, 기간·가격은 줄 사이로 갈리지 않는다', (tester) async {
      await pumpPaywall(tester, FakeEntitlementService(products: _products));

      expect(findText(' · '), findsNothing);
      final legal = find.ancestor(of: find.byKey(const Key('premium-paywall-terms')), matching: find.byType(Wrap));
      expect(find.descendant(of: legal, matching: find.byKey(const Key('premium-paywall-privacy'))), findsOneWidget);
      expect(find.descendant(of: legal, matching: find.byKey(const Key('premium-paywall-restore'))), findsNothing);
      final restore = tester.getRect(find.byKey(const Key('premium-paywall-restore')));
      final button = tester.getRect(find.byKey(const Key('premium-paywall-subscribe')));
      expect(restore.bottom, lessThanOrEqualTo(button.top));
      expect(restore.top, greaterThanOrEqualTo(tester.getRect(legal).bottom));
      // 작은 링크도 누름 높이 24 이상(WCAG 2.5.8), 법적 링크 사이 12
      for (final key in [
        'premium-paywall-terms',
        'premium-paywall-privacy',
        'premium-paywall-restore',
        'premium-paywall-help',
      ]) {
        expect(tester.getSize(find.byKey(Key(key))).height, greaterThanOrEqualTo(24), reason: key);
      }
      expect(tester.widget<Wrap>(legal).spacing, 12);
      // 본문 아래 24 페이드(누름은 통과)
      final fade = find.byWidgetPredicate(
        (w) =>
            w is DecoratedBox &&
            w.decoration is BoxDecoration &&
            (w.decoration as BoxDecoration).gradient ==
                LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colors.background.withValues(alpha: 0), colors.background],
                ),
      );
      expect(fade, findsOneWidget);
      expect(tester.getSize(fade).height, 24);
      expect(find.ancestor(of: fade, matching: find.byType(IgnorePointer)), findsWidgets);
      // "1년"·가격 안에서는 줄이 바뀌지 않는다(글자 사이 이음 문자, 가격의 공백은 줄바꿈 없는 공백)
      // 플랜 줄(첫 줄)만: 갱신 줄의 " · "는 보통 문장이다
      final raw =
          tester
              .widget<Text>(find.byKey(const Key('premium-paywall-selected-plan')))
              .textSpan!
              .toPlainText()
              .split('\n')
              .first;
      final year = t.premium.paywall.period_year;
      expect(raw, contains(year.runes.map(String.fromCharCode).join('\u2060').replaceAll(' ', '\u00A0')));
      expect(raw, isNot(contains(' ·')));
    });

    testWidgets('POLISH G4: 아래 고정 묶음은 글자를 1.3배에서 멈추고 본문은 그대로 커진다', (tester) async {
      await pumpPaywall(tester, FakeEntitlementService(products: _products), textScale: 2);
      double scaleOf(Finder richText) => tester.widget<RichText>(richText).textScaler.scale(10);
      final plan = find.descendant(
        of: find.byKey(const Key('premium-paywall-selected-plan')),
        matching: find.byType(RichText),
      );
      expect(scaleOf(plan), moreOrLessEquals(13));
      final headline = find.byWidgetPredicate(
        (w) => w is RichText && plain(w.text.toPlainText()) == t.premium.paywall.headline,
      );
      expect(scaleOf(headline), moreOrLessEquals(20));
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
      await tester.tap(findText('open'));
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
      expect(findText(t.premium.toast.restored), findsNothing);
      expect(findText('open'), findsOneWidget);
    });

    testWidgets('m6: 스토어 구독 관리를 열지 못하면 경고 토스트', (tester) async {
      await pumpManage(tester, _ManageFails());

      await tester.tap(find.byKey(const Key('premium-subscription-manage')));
      await tester.pump();
      expect(findText(t.premium.toast.manage_failed), findsOneWidget);
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
      expect(findText(t.premium.subscription.active_title), findsOneWidget);
      expect(findText(t.premium.subscription.yearly_plan), findsOneWidget);
      expect(find.byKey(const Key('premium-subscription-see-plans')), findsNothing);
      // POLISH G9: 사용 중은 Premium 바탕(r24, 링 1) + 젬 20, 제목 premiumText, 플랜 줄 secondaryTextStrong
      final active = tester.widget<PremiumSurface>(find.byKey(const Key('premium-status-active')));
      expect((active.radius, active.ringWidth), (24.0, 1.0));
      final activeMark = tester.widget<PremiumMark>(find.byType(PremiumMark));
      expect((activeMark.size, activeMark.muted), (20.0, false));
      expect(tester.widget<Text>(findText(t.premium.subscription.active_title)).style!.color, colors.premiumText);
      expect(
        tester.widget<Text>(findText(t.premium.subscription.yearly_plan)).style!.color,
        colors.secondaryTextStrong,
      );

      premium.emit(PremiumState(PremiumStatus.expired, expiresAt: DateTime(2026, 9, 1)));
      await tester.pump();
      expect(findText(t.premium.subscription.expired_on(date: '2026.09.01')), findsOneWidget);
      expect(findText(t.premium.subscription.resubscribe), findsOneWidget);
      expect(findText(t.premium.subscription.expired_note), findsOneWidget);

      premium.emit(const PremiumState(PremiumStatus.none));
      await tester.pump();
      expect(findText(t.premium.subscription.none_title), findsOneWidget);
      // 없음·만료는 surface r24 + 빛 꺼진 젬
      final none = tester.widget<Container>(find.byKey(const Key('premium-status-none')));
      expect((none.decoration! as BoxDecoration).borderRadius, BorderRadius.circular(24));
      expect((none.decoration! as BoxDecoration).color, colors.surface);
      expect(tester.widget<PremiumMark>(find.byType(PremiumMark)).muted, isTrue);
      await tester.tap(findText(t.premium.card.explore));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('premium-paywall')), findsOneWidget);
    });

    testWidgets('구매 복원과 스토어 구독 관리', (tester) async {
      final premium = FakeEntitlementService(initial: const PremiumState(PremiumStatus.active));
      await pumpManage(tester, premium);

      await tester.tap(find.byKey(const Key('premium-subscription-restore')));
      await tester.pump();
      expect(premium.restoreCount, 1);
      expect(findText(t.premium.toast.restored), findsOneWidget);
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
      expect(find.descendant(of: row, matching: findText(t.premium.name)), findsOneWidget);
      expect(find.descendant(of: row, matching: findText(t.premium.subscription.active)), findsOneWidget);
      // POLISH G11: 사용 중일 때만 부제 premiumText, 아니면 다른 행과 같은 기본 부제
      SingleButton rowButton() =>
          tester.widget<SingleButton>(find.descendant(of: row, matching: find.byType(SingleButton)));
      expect(rowButton().subtitleStyle!.color, colors.premiumText);
      premium.emit(const PremiumState(PremiumStatus.none));
      await tester.pump();
      expect(rowButton().subtitle, t.premium.subscription.not_subscribed);
      expect(rowButton().subtitleStyle, isNull);

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
          '${locale.name}: 플랜·갱신 줄은 1배 두 줄, 1.3배 네 줄 이내로 버튼 위에 보이고, 2배도 1.3배와 같은 높이(상한)',
          variant: TargetPlatformVariant.only(platform),
          (tester) async {
            tester.view.physicalSize = const Size(320, 640);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            LocaleSettings.setLocaleSync(locale);
            final store = platform == TargetPlatform.android ? 'Google Play' : 'App Store';
            final blockHeights = <double, double>{};

            for (final (scale, maxLines) in [(1.0, 2), (1.3, 4), (2.0, 4)]) {
              await pumpPaywall(tester, FakeEntitlementService(products: _products), textScale: scale);
              final line = find.byKey(const Key('premium-paywall-selected-plan'));
              expect(planText(tester).split('\n').last, t.premium.paywall.renew_line(store: store));
              expect(lineCount(tester, line), lessThanOrEqualTo(maxLines), reason: '$scale');
              final rect = tester.getRect(line);
              expect(rect.top, greaterThanOrEqualTo(0));
              expect(
                rect.bottom,
                lessThanOrEqualTo(tester.getRect(find.byKey(const Key('premium-paywall-subscribe'))).top),
              );
              blockHeights[scale] = tester.getSize(find.byKey(const Key('premium-paywall-bottom'))).height;
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox()); // 다음 배율은 새 화면 스택에서
            }
            // 2.0배·320dp에서도 고정 묶음은 1.3배 그대로라 본문 창이 남는다(전에는 화면의 54%)
            expect(blockHeights[2.0], moreOrLessEquals(blockHeights[1.3]!));
            // 가장 긴 de·es에서 46%(상한 전 54%)
            expect(blockHeights[2.0]! / 640, lessThan(0.5), reason: '${blockHeights[2.0]}');
          },
        );
      }
    }
  });
}
