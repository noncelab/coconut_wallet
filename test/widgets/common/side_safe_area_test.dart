import 'dart:ui' as ui;

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/widgets/common/side_safe_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

class _Counter extends StatefulWidget {
  const _Counter({super.key});
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

// iPhone Duo 닫힌 세로 화면(466x678pt)에서 보고된 값: 상태바 세로 열이 오른쪽 84pt, 위 0, 아래 34.
const _duoClosed = FakeViewPadding(right: 84, bottom: 34);

void main() {
  late MediaQueryData inner;
  late EdgeInsets sideInsets;
  final counter = GlobalKey<_CounterState>();

  Future<void> pumpApp(WidgetTester tester, FakeViewPadding padding) async {
    tester.view.physicalSize = const Size(466, 678);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = padding;
    tester.view.viewPadding = padding;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.light),
        builder: (context, child) => SideSafeArea(child: child!),
        home: Builder(
          builder: (context) {
            inner = MediaQuery.of(context);
            sideInsets = SideSafeArea.insetsOf(context);
            return _Counter(key: counter);
          },
        ),
      ),
    );
  }

  testWidgets('the app stays clear of a side status column and screens get the usable width', (tester) async {
    await pumpApp(tester, _duoClosed);
    expect(tester.getRect(find.byKey(counter)), const Rect.fromLTRB(0, 0, 466 - 84, 678));
    expect(inner.size, const Size(466 - 84, 678));
    expect(inner.padding, const EdgeInsets.only(bottom: 34));
    expect(inner.viewPadding, const EdgeInsets.only(bottom: 34));
    expect(sideInsets, const EdgeInsets.only(right: 84));
  });

  testWidgets('devices without side insets keep the full screen and the original values', (tester) async {
    await pumpApp(tester, const FakeViewPadding(top: 47, bottom: 34));
    expect(tester.getRect(find.byKey(counter)), const Rect.fromLTRB(0, 0, 466, 678));
    expect(inner.size, const Size(466, 678));
    expect(inner.padding, const EdgeInsets.only(top: 47, bottom: 34));
    expect(inner, same(MediaQuery.of(tester.element(find.byType(SideSafeArea)))));
    expect(sideInsets, EdgeInsets.zero);
  });

  testWidgets('screens keep their state when the side inset appears and disappears (fold, rotate)', (tester) async {
    await pumpApp(tester, const FakeViewPadding(top: 47, bottom: 34));
    final state = counter.currentState!..taps = 3;
    tester.view.physicalSize = const Size(951, 669);
    tester.view.padding = _duoClosed;
    tester.view.viewPadding = _duoClosed;
    await tester.pump();
    expect(counter.currentState, same(state));
    expect(tester.getRect(find.byKey(counter)).right, 951 - 84);
    tester.view.physicalSize = const Size(466, 678);
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    await tester.pump();
    expect(counter.currentState, same(state));
    expect(counter.currentState!.taps, 3);
  });
  testWidgets('only side insets add edge filters, on either or both sides', (tester) async {
    for (final padding in [
      const FakeViewPadding(bottom: 34),
      const FakeViewPadding(right: 84, bottom: 34),
      const FakeViewPadding(left: 84, bottom: 34),
      const FakeViewPadding(left: 20, right: 84, bottom: 34),
      const FakeViewPadding(top: 47, bottom: 34),
    ]) {
      await pumpApp(tester, padding);
      expect(find.byType(BackdropFilter), findsNWidgets((padding.left > 0 ? 1 : 0) + (padding.right > 0 ? 1 : 0)));
      expect(tester.getRect(find.byKey(counter)), Rect.fromLTRB(padding.left, 0, 466 - padding.right, 678));
      expect(inner.size.width, 466 - padding.left - padding.right);
      expect(sideInsets, EdgeInsets.only(left: padding.left, right: padding.right));
    }
  });

  testWidgets('side insets are zero outside SideSafeArea', (tester) async {
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          expect(SideSafeArea.insetsOf(context), EdgeInsets.zero);
          return const SizedBox.shrink();
        },
      ),
    );
  });

  for (final dpr in [1.0, 3.0, 2.625]) {
    for (final sides in [
      const EdgeInsets.only(left: 80),
      const EdgeInsets.only(right: 88),
      const EdgeInsets.only(left: 80, right: 88),
    ]) {
      testWidgets('side columns repeat their own edge pixels at DPR $dpr with $sides', (tester) async {
        const size = Size(400, 32);
        const capture = Key('edge-paint');
        tester.view.devicePixelRatio = dpr;
        tester.view.physicalSize = size * dpr;
        tester.view.padding = FakeViewPadding(left: sides.left * dpr, right: sides.right * dpr);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MediaQuery.fromView(
            view: tester.view,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: RepaintBoundary(
                key: capture,
                child: SideSafeArea(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    // 가장자리 3물리 픽셀 밖은 다른 색이라 DPR 샘플 위치 오류도 드러난다.
                    children: [
                      SizedBox(width: 3 / dpr, child: const ColoredBox(color: Color(0xFF0000FF))),
                      const Expanded(child: ColoredBox(color: Color(0xFFFF0000))),
                      SizedBox(width: 3 / dpr, child: const ColoredBox(color: Color(0xFF00FF00))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        // 실제 DPR로 래스터화해 행렬 부호·이동량·물리 픽셀 변환을 함께 검증한다.
        final image =
            (await tester.runAsync(
              () => tester.renderObject<RenderRepaintBoundary>(find.byKey(capture)).toImage(pixelRatio: dpr),
            ))!;
        final bytes = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
        final width = image.width;
        final height = image.height;
        image.dispose();
        List<int> pixel(int x, int y) {
          final offset = (y * width + x) * 4;
          return bytes.buffer.asUint8List(offset, 4);
        }

        for (var y = 0; y < height; y++) {
          for (var x = 0; x < (sides.left * dpr).round(); x++) {
            expect(pixel(x, y), [0, 0, 255, 255], reason: 'left column ($x, $y)');
          }
          for (var x = width - (sides.right * dpr).round(); x < width; x++) {
            expect(pixel(x, y), [0, 255, 0, 255], reason: 'right column ($x, $y)');
          }
          expect(pixel(width ~/ 2, y), [255, 0, 0, 255], reason: 'interior stays unchanged');
        }
      });
    }
  }
}
