import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/screens/wallet_detail/card_detail/wallet_detail_card_carousel.dart';
import 'package:coconut_wallet/widgets/common/side_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../mock/wallet_mock.dart';

void main() {
  testWidgets('side columns sample background while carousel geometry and no-inset paint stay unchanged', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(466, 678);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final wallets = [for (var id = 1; id <= 3; id++) WalletMock.createSingleSigWalletItem(id: id)];
    const capture = Key('carousel-paint');
    const carousel = Key('wallet-detail-carousel');

    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.light),
        builder: (context, child) => SideSafeArea(child: child!),
        home: Builder(
          builder:
              (context) => Align(
                alignment: Alignment.topLeft,
                child: RepaintBoundary(
                  key: capture,
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(size: const Size(382, 678), padding: EdgeInsets.zero, viewPadding: EdgeInsets.zero),
                    child: SizedBox(
                      width: 382,
                      child: ColoredBox(
                        color: Colors.green,
                        child: WalletDetailCardCarousel(
                          wallets: wallets,
                          initialIndex: 1,
                          onFocusChanged: (_) {},
                          cardBuilder: (_, _, _, surfaceBuilder) => surfaceBuilder(const ColoredBox(color: Colors.red)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        ),
      ),
    );

    Future<Uint8List> paint(FakeViewPadding padding) async {
      tester.view.padding = padding;
      tester.view.viewPadding = padding;
      // 트리를 다시 만들지 않고 창 메트릭만 바꾼다. 같은 폭에서 좌우가 바뀌어도 클립이 갱신되어야 한다.
      await tester.pumpAndSettle();
      return (await tester.runAsync(() async {
        final image = await tester.renderObject<RenderRepaintBoundary>(find.byKey(capture)).toImage();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        return data!.buffer.asUint8List();
      }))!;
    }

    List<int> pixel(Uint8List data, int x) => data.sublist((100 * 382 + x) * 4, (100 * 382 + x) * 4 + 4);
    final original = await paint(const FakeViewPadding());
    final rect = tester.getRect(find.byKey(carousel));
    final controller = tester.widget<PageView>(find.byKey(carousel)).controller;
    final mountedCarousel = tester.element(find.byType(WalletDetailCardCarousel));
    expect(pixel(original, 381), isNot(equals([76, 175, 80, 255])));
    final right = await paint(const FakeViewPadding(right: 84));
    expect(pixel(right, 381), [76, 175, 80, 255]);
    expect(pixel(right, 190), pixel(original, 190));
    expect(pixel(right, 350), pixel(original, 350));
    expect(tester.getRect(find.byKey(carousel)), rect);
    expect(tester.widget<PageView>(find.byKey(carousel)).controller, same(controller));
    final left = await paint(const FakeViewPadding(left: 84));
    expect(pixel(left, 0), [76, 175, 80, 255]);
    expect(pixel(left, 381), pixel(original, 381));
    expect(tester.getRect(find.byKey(carousel)), rect.shift(const Offset(84, 0)));
    expect(tester.element(find.byType(WalletDetailCardCarousel)), same(mountedCarousel));
    expect(tester.widget<PageView>(find.byKey(carousel)).controller, same(controller));
    expect(await paint(const FakeViewPadding()), original);
    expect(tester.widget<PageView>(find.byKey(carousel)).controller!.page, 1);
  });
}
