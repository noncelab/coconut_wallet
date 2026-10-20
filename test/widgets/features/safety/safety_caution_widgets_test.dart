import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/widgets/features/safety/safety_caution_widgets.dart';
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
      expect(find.text(strings.badge), findsNWidgets(2)); // 배너 제목 + 배지

      await tester.tap(find.text(strings.remove_link));
      await tester.pumpAndSettle();
      expect(find.text(strings.remove_title), findsOneWidget);
      await tester.tap(find.text(strings.remove_confirm));
      await tester.pumpAndSettle();

      expect(safety.isCaution(kWalletId), isFalse);
      expect(find.byKey(const Key('safety-caution-banner')), findsNothing);
      expect(find.text(strings.badge), findsNothing);
      expect(find.text(strings.removed_toast), findsOneWidget);
      await settleToasts(tester);
    });
  }

  testWidgets('cancel keeps the caution', (tester) async {
    final safety = fixedSafety(caution: {kWalletId});
    await tester.pumpWidget(safetyTestApp(_walletDetailLike(), safety: safety));
    await tester.tap(find.text(strings.remove_link));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.cancel));
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
    expect(find.text(strings.badge), findsNothing);
  });

  // 큰 글자에서는 지갑 목록 카드가 설명 줄을 아래로 내린다(placeTrailingBelow). 그때도 배지가 보여야 한다
  for (final (layout, below, scale) in [('one-line', false, 1.0), ('large-text', true, 2.0)]) {
    testWidgets('wallet list card shows the caution badge in the $layout layout (text scale $scale)', (tester) async {
      Widget card(Set<int> caution) => safetyTestApp(
        Builder(
          builder:
              (context) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: WalletItemCard(
                    walletItem: WalletMock.createSingleSigWalletItem(id: kWalletId),
                    animatedBalanceData: AnimatedBalanceData(100000, 100000),
                    currentUnit: BitcoinUnit.btc,
                    isLastItem: true,
                    placeTrailingBelow: below,
                    rightWidget: const SizedBox(),
                    onPressed: () {},
                  ),
                ),
              ),
        ),
        safety: fixedSafety(caution: caution),
      );

      await tester.pumpWidget(card({kWalletId}));
      expect(find.text(strings.badge), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(card(const {}));
      expect(find.text(strings.badge), findsNothing);
    });
  }
}
