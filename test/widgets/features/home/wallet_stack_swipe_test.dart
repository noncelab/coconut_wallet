import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/widgets/features/home/home_cube_pager.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/wallet_mock.dart';

/// 홈 위 2×2 지갑 스택에서 왼쪽으로 270을 민다(화면 폭 390의 절반 넘게). 이벤트 시각을 넣어야 속도가 계산된다.
/// 홈 페이지가 바뀐 기록을 돌려준다(1 = All Features)
Future<List<int>> _swipeLeftOnStack(WidgetTester tester, {required int wallets, bool addPage = false}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 300);
  addTearDown(tester.view.reset);
  final pages = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home: HomeCubePager(
        onPageChanged: pages.add,
        home: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox.square(
              dimension: 173,
              child: WalletStackView(
                keyPrefix: 'swipe',
                wallets: [for (var id = 1; id <= wallets; id++) WalletMock.createSingleSigWalletItem(id: id)],
                size: WalletCardSize.small,
                emptyText: 'empty',
                onAddPressed: addPage ? () {} : null,
              ),
            ),
          ),
        ),
        allFeaturesBuilder: (_) => const Center(child: Text('All Features')),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final gesture = await tester.startGesture(tester.getCenter(find.byType(WalletStackView)));
  for (var i = 1; i <= 6; i++) {
    await gesture.moveBy(const Offset(-45, 0), timeStamp: Duration(milliseconds: 16 * i));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await gesture.up(timeStamp: const Duration(milliseconds: 16 * 7));
  await tester.pumpAndSettle();
  return pages;
}

/// 스택이 보여 주는 카드 페이지(0 = 첫 카드)
double? _cardPage(WidgetTester tester) =>
    tester.widget<PageView>(find.byKey(const Key('swipe-pager'))).controller!.page;

double _indicatorOpacity(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(find.byKey(const Key('shrink-indicator'))).opacity;

void main() {
  // M31: 넘길 카드가 없는 한 장 스택은 홈의 가로 스와이프를 가로채지 않는다
  testWidgets('a one-card stack lets the home swipe through to All Features', (tester) async {
    expect(await _swipeLeftOnStack(tester, wallets: 1), [1]);
    expect(find.text('All Features').hitTestable(), findsOneWidget);
  });

  testWidgets('a stack with two cards still pages its own cards instead of the home', (tester) async {
    expect(await _swipeLeftOnStack(tester, wallets: 2), isEmpty);
    expect(_cardPage(tester), closeTo(1, 1e-6));
  });

  // 모든 지갑 스택은 지갑 하나라도 추가 카드가 있어 두 페이지다
  testWidgets('one wallet plus the add card is two pages and keeps the swipe', (tester) async {
    expect(await _swipeLeftOnStack(tester, wallets: 1, addPage: true), isEmpty);
    expect(_cardPage(tester), closeTo(1, 1e-6));
  });

  // 끌던 중에 한 장이 되면 끌기 인식이 사라져 끝 알림이 오지 않는다. 다시 두 장이 돼도 표시가 켜진 채 남으면 안 된다
  for (final target in ['card-slider', 'indicator-scrubber']) {
    testWidgets('the indicator turns off after the stack drops to one card mid-drag on the $target', (tester) async {
      final count = ValueNotifier(2);
      addTearDown(count.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(),
          home: Center(
            child: SizedBox.square(
              dimension: 173,
              child: ValueListenableBuilder<int>(
                valueListenable: count,
                builder:
                    (_, wallets, _) => WalletStackView(
                      keyPrefix: 'shrink',
                      wallets: [for (var id = 1; id <= wallets; id++) WalletMock.createSingleSigWalletItem(id: id)],
                      size: WalletCardSize.small,
                      emptyText: 'empty',
                    ),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(Key('shrink-$target'))));
      await gesture.moveBy(const Offset(-30, 0));
      await tester.pump();
      expect(_indicatorOpacity(tester), 1);
      count.value = 1;
      await tester.pump();
      count.value = 2;
      await tester.pump();
      await gesture.up();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(_indicatorOpacity(tester), 0);
    });
  }
}
