import 'package:coconut_wallet/app/bootstrap/system_ui_bootstrap.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an unfolded physical display unlocks even when the app viewport is letterboxed', (tester) async {
    final orientations = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') orientations.add(call.arguments);
      return null;
    });
    addTearDown(() {
      tester.view.reset();
      tester.view.display.reset();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(1398, 2034);
    tester.view.display.size = const Size(2007, 2853);

    await configureSystemUi();

    expect(orientations, [isEmpty]);
  });

  testWidgets('folding, partial opening and rotation change the orientation policy only at the display boundary', (
    tester,
  ) async {
    final orientations = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') orientations.add(call.arguments);
      return null;
    });
    addTearDown(() {
      tester.view.reset();
      tester.view.display.reset();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    tester.view.devicePixelRatio = 3;
    for (final size in const [
      Size(1398, 2034), // Closed Duo display: 466 x 678 logical.
      Size(1398, 2034), // Hinge movement that keeps the outer display active.
      Size(2007, 2853), // Unfolded: 669 x 951.
      Size(2853, 2007), // Unfolded landscape.
      Size(2007, 2853),
      Size(1398, 2034),
      Size(2007, 2853),
    ]) {
      tester.view.display.size = size;
      tester.view.physicalSize = size;
      await updatePreferredOrientations(tester.view);
    }
    const portrait = ['DeviceOrientation.portraitUp', 'DeviceOrientation.portraitDown'];
    expect(orientations, [portrait, isEmpty, portrait, isEmpty]);
  });

  testWidgets('an unfolded view unlocks when the engine retains the outer display metadata', (tester) async {
    final orientations = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemChrome.setPreferredOrientations') orientations.add(call.arguments);
      return null;
    });
    addTearDown(() {
      tester.view.reset();
      tester.view.display.reset();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });
    tester.view.devicePixelRatio = 3;
    tester.view.display.size = const Size(1398, 2034);
    tester.view.physicalSize = const Size(1398, 2034);
    await configureSystemUi();
    orientations.clear();

    tester.view.physicalSize = const Size(2007, 2853);
    await configureSystemUi();
    expect(orientations, [isEmpty]);

    tester.view.physicalSize = const Size(1398, 2034);
    await configureSystemUi();
    expect(orientations, [
      isEmpty,
      ['DeviceOrientation.portraitUp', 'DeviceOrientation.portraitDown'],
    ]);
  });
}
