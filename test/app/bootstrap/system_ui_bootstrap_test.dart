import 'package:coconut_wallet/app/bootstrap/system_ui_bootstrap.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'bootstrap preserves native orientation for every display shape while configuring system UI',
    (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        calls.add(call);
        return null;
      });
      addTearDown(() {
        tester.view.reset();
        tester.view.display.reset();
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });
      // Ensure bootstrap must send its bar style even if a previous test configured it.
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle());
      await tester.pump();
      calls.clear();

      tester.view.devicePixelRatio = 3;
      tester.view.display.devicePixelRatio = 3;
      const shapes = [
        (name: 'portrait phone', display: Size(1080, 1920), view: Size(1080, 1920)),
        (name: 'rotated phone', display: Size(1920, 1080), view: Size(1920, 1080)),
        (name: 'portrait tablet', display: Size(1800, 2700), view: Size(1800, 2700)),
        (name: 'rotated tablet', display: Size(2700, 1800), view: Size(2700, 1800)),
        (name: 'unfolded', display: Size(2208, 1840), view: Size(2208, 1840)),
        (name: 'rotated unfolded', display: Size(1840, 2208), view: Size(1840, 2208)),
        (name: 'letterboxed view', display: Size(2208, 1840), view: Size(1380, 1840)),
        (name: 'stale outer display', display: Size(1080, 2092), view: Size(2208, 1840)),
        (name: 'transient zero metrics', display: Size.zero, view: Size.zero),
      ];
      for (final shape in shapes) {
        tester.view.display.size = shape.display;
        tester.view.physicalSize = shape.view;
        await configureSystemUi();
        await tester.pump();

        expect(
          calls.where((call) => call.method == 'SystemChrome.setPreferredOrientations'),
          isEmpty,
          reason: '${shape.name} must retain native orientation ownership.',
        );
      }

      final overlayCalls = calls.where((call) => call.method == 'SystemChrome.setEnabledSystemUIOverlays');
      expect(overlayCalls, hasLength(shapes.length));
      for (final call in overlayCalls) {
        expect(call.arguments, ['SystemUiOverlay.top', 'SystemUiOverlay.bottom']);
      }
      expect(calls.where((call) => call.method == 'SystemChrome.setSystemUIOverlayStyle'), isNotEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
  );
}
