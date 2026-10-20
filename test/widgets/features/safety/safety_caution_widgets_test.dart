import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart' show kHomeTileMaxTextScale;
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_caution_widgets.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/wallet_mock.dart';
import '../../../screens/safety/safety_test_harness.dart';

Widget _walletDetailLike() => origin(
  child: const Column(children: [SafetyCautionBanner(walletId: kWalletId), SafetyCautionBadge(walletId: kWalletId)]),
);

void main() {
  final strings = t.safety_guide.caution;

  for (final variant in CoconutThemeVariant.values) {
    testWidgets('${variant.name} removing "use with caution" asks first, then folds the banner and badge', (
      tester,
    ) async {
      final safety = fixedSafety(caution: {kWalletId});
      await tester.pumpWidget(safetyTestApp(_walletDetailLike(), safety: safety, variant: variant));
      expect(find.byKey(const Key('safety-caution-banner')), findsOneWidget);
      expect(findText(strings.badge), findsNWidgets(2)); // 배너 제목 + 배지

      await tester.tap(findText(strings.remove_link));
      await tester.pumpAndSettle();
      expect(findText(strings.remove_title), findsOneWidget);
      await tester.tap(findText(strings.remove_confirm));
      await tester.pumpAndSettle();

      expect(safety.isCaution(kWalletId), isFalse);
      expect(find.byKey(const Key('safety-caution-banner')), findsNothing);
      expect(findText(strings.badge), findsNothing);
      expect(findText(strings.removed_toast), findsOneWidget);
      await settleToasts(tester);
    });
  }

  testWidgets('cancel keeps the caution', (tester) async {
    final safety = fixedSafety(caution: {kWalletId});
    await tester.pumpWidget(safetyTestApp(_walletDetailLike(), safety: safety));
    await tester.tap(findText(strings.remove_link));
    await tester.pumpAndSettle();
    await tester.tap(findText(t.cancel));
    await tester.pumpAndSettle();
    expect(safety.isCaution(kWalletId), isTrue);
    expect(find.byKey(const Key('safety-caution-banner')), findsOneWidget);
  });

  testWidgets('nothing is drawn for a normal wallet or without SafetyProvider', (tester) async {
    Widget? marked, normal, noProvider;
    await tester.pumpWidget(
      safetyTestApp(
        origin(
          child: Builder(
            builder: (context) {
              marked = safetyCautionBadgeFor(context, kWalletId);
              normal = safetyCautionBadgeFor(context, 2);
              return const SafetyCautionBanner(walletId: 2);
            },
          ),
        ),
        safety: fixedSafety(caution: {kWalletId}),
      ),
    );
    expect(marked, isA<SafetyCautionBadge>());
    expect(normal, isNull);
    expect(find.byKey(const Key('safety-caution-banner')), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Builder(
          builder: (context) {
            noProvider = safetyCautionBadgeFor(context, kWalletId);
            return const Column(
              children: [SafetyCautionBanner(walletId: kWalletId), SafetyCautionBadge(walletId: kWalletId)],
            );
          },
        ),
      ),
    );
    expect(noProvider, isNull);
    expect(findText(strings.badge), findsNothing);
  });

  // D1: 지갑 목록 카드의 배지는 이름 줄을 밀지 않고 신원 열 끝 자기 줄에 있다(큰 글자면 설명 줄이 아래로 내려간다)
  for (final (below, scale) in [(false, 1.0), (false, 1.3), (true, 2.0)]) {
    testWidgets('wallet list card puts the caution badge on its own line (320dp, ${scale}x, German)', (tester) async {
      useSmallPhone(tester, scale);
      useLocale(AppLocale.de);
      final wallet = WalletMock.createSingleSigWalletItem(id: kWalletId);
      Widget card(Set<int> caution) => safetyTestApp(
        Scaffold(
          body: WalletItemCard(
            walletItem: wallet,
            animatedBalanceData: AnimatedBalanceData(100000, 100000),
            currentUnit: BitcoinUnit.btc,
            isLastItem: true,
            placeTrailingBelow: below,
            rightWidget: const SizedBox(),
            onPressed: () {},
          ),
        ),
        safety: fixedSafety(caution: caution),
      );

      await tester.pumpWidget(card({kWalletId}));
      expect(tester.takeException(), isNull);
      final badge = findText(t.safety_guide.caution.badge);
      expect(badge, findsOneWidget);
      expect(tester.getRect(badge).top, greaterThanOrEqualTo(tester.getRect(findText(wallet.name)).bottom));
      expect(tester.getRect(find.byType(SafetyCautionBadge)).right, lessThanOrEqualTo(320));

      // 사용 주의가 아니면 배지도 그 위 간격도 없다(기존 카드 높이 그대로)
      await tester.pumpWidget(card(const {}));
      expect(badge, findsNothing);
      expect(tester.getSize(find.byType(SafetyCautionBadge)), Size.zero);
    });
  }

  // D2: 2×2 홈 카드용 아이콘 원(글자 없이 20, 뜻은 의미 라벨로)
  testWidgets('the compact badge is a 20dp icon circle carrying the caution label', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      safetyTestApp(
        const Center(child: SafetyCautionBadge(walletId: kWalletId, compact: true)),
        safety: fixedSafety(caution: {kWalletId}),
      ),
    );
    expect(findText(t.safety_guide.caution.badge), findsNothing);
    expect(tester.getSize(find.byType(SafetyCautionBadge)), const Size(20, 20));
    expect(find.bySemanticsLabel(t.safety_guide.caution.badge_a11y), findsOneWidget);
    semantics.dispose();
  });

  // M2/D9: WalletCard 머리 줄은 배지 폭을 묶지 않는다(Expanded 이름 열 + 배지). 배지가 스스로 줄여 맞춘다
  for (final scale in [1.3, 2.0]) {
    testWidgets('the WalletCard slot badge stays within its width at ${scale}x in German', (tester) async {
      useSmallPhone(tester, scale);
      useLocale(AppLocale.de);
      await tester.pumpWidget(
        safetyTestApp(
          Scaffold(
            body: Builder(
              builder:
                  (context) =>
                      Row(children: [const Expanded(child: Text('name')), safetyCautionBadgeFor(context, kWalletId)!]),
            ),
          ),
          safety: fixedSafety(caution: {kWalletId}),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byType(SafetyCautionBadge)).width, lessThanOrEqualTo(kSafetyCautionSlotMaxWidth));
      expect(findText(t.safety_guide.caution.badge), findsOneWidget); // 글자는 줄이지만 자르지 않는다
    });
  }

  testWidgets('a wide WalletCard with the slot badge fits 320dp at the home 1.2x cap in German', (tester) async {
    useSmallPhone(tester, 2.0);
    useLocale(AppLocale.de);
    final wallet = WalletMock.createSingleSigWalletItem(id: kWalletId);
    await tester.pumpWidget(
      safetyTestApp(
        Scaffold(
          body: Center(
            child: Builder(
              builder:
                  (context) => MediaQuery.withClampedTextScaling(
                    maxScaleFactor: kHomeTileMaxTextScale,
                    child: SizedBox(
                      width: 280,
                      height: 148,
                      child: WalletCard(
                        wallet: wallet,
                        appearance: WalletAppearance.of(wallet),
                        size: WalletCardSize.wide,
                        statusBadge: safetyCautionBadgeFor(context, kWalletId),
                      ),
                    ),
                  ),
            ),
          ),
        ),
        safety: fixedSafety(caution: {kWalletId}),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(findText(t.safety_guide.caution.badge), findsOneWidget);
  });
}
