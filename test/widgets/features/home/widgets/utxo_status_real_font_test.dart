import 'dart:io';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/activity_widget_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _load(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    loader.addFont(Future.value(ByteData.view(Uint8List.fromList(File('assets/fonts/$file').readAsBytesSync()).buffer)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await _load('Pretendard', ['Pretendard-Regular.ttf', 'Pretendard-Bold.ttf']);
    await _load('SpaceGrotesk', ['SpaceGrotesk-Regular.ttf', 'SpaceGrotesk-Bold.ttf']);
  });

  testWidgets('real fonts: no count is clipped', (tester) async {
    for (final side in [140.0, 156.0, 172.0, 190.0]) {
      for (final counts in const [
        [9, 9, 1, 2],
        [1234, 5678, 9012, 3456],
        [1, 0, 0, 0],
        [12, 345, 6, 78],
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCoconutThemeData(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: side,
                  height: side,
                  child: UtxoStatusView(
                    buckets: HomeUtxoBuckets(counts),
                    bucketColors: const [Color(0xFFF9DA94), Color(0xFF98A8D0), Color(0xFFDAF8E7), Color(0xFFD2E6FB)],
                  ),
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        for (final element in find.textContaining('%').evaluate()) {
          final paragraph = element.renderObject! as RenderParagraph;
          final text = (element.widget as Text).data;
          expect(
            paragraph.size.width,
            greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity) - 0.01),
            reason: 'side $side "$text" width ${paragraph.size.width} needs ${paragraph.getMaxIntrinsicWidth(double.infinity)}',
          );
        }
      }
    }
  });
}
