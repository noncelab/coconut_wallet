import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/common/overlays/custom_loading_overlay.dart';
import 'package:coconut_wallet/widgets/features/auth/pin/key_button.dart';
import 'package:coconut_wallet/widgets/features/auth/pin/pin_input_pad.dart';
import 'package:coconut_wallet/widgets/features/auth/pin/pin_length_toggle_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Shuffled like AuthProvider.getShuffledNumberPad(isSettings: true): 10 digits, '' before the last digit, then '<'.
const _keys = ['7', '3', '9', '0', '5', '1', '8', '4', '2', '', '6', '<'];

/// The PIN sheets as AppSettings/WalletInfo open them: CommonBottomSheets.showCustomHeightBottomSheet(heightRatio: 0.9)
/// with CustomLoadingOverlay > (PinSettingScreen/PinCheckScreen) > PinInputPad; [sheet] false is the app-entrance
/// PinCheckScreen, full screen under CustomLoadingOverlay (lib/app.dart).
Future<List<String>> _openSheet(
  WidgetTester tester,
  Size logical,
  PinInputPad Function(List<String> taps) pad, {
  EdgeInsets insets = EdgeInsets.zero,
  bool sheet = true,
}) async {
  tester.view.physicalSize = logical * 3;
  tester.view.devicePixelRatio = 3;
  final physical = insets * 3;
  final padding = FakeViewPadding(
    left: physical.left,
    top: physical.top,
    right: physical.right,
    bottom: physical.bottom,
  );
  tester.view.padding = padding;
  tester.view.viewPadding = padding;
  addTearDown(tester.view.reset);
  final taps = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home:
          sheet
              ? Builder(
                builder:
                    (context) => Scaffold(
                      body: Center(
                        child: TextButton(
                          onPressed:
                              () => CommonBottomSheets.showCustomHeightBottomSheet(
                                context: context,
                                screenName: AnalyticsScreenNames.appSettingsPinSetSheet,
                                heightRatio: 0.9,
                                child: CustomLoadingOverlay(child: Scaffold(body: pad(taps))),
                              ),
                          child: const Text('open'),
                        ),
                      ),
                    ),
              )
              : CustomLoadingOverlay(child: pad(taps)),
    ),
  );
  if (sheet) await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return taps;
}

PinInputPad _setting(List<String> taps, {int step = 0, int pinLength = 4, String error = ''}) => PinInputPad(
  title: step == 0 ? t.pin_setting_screen.new_password : t.pin_setting_screen.enter_again,
  pin: '',
  errorMessage: error,
  onKeyTap: taps.add,
  pinShuffleNumbers: _keys,
  onClosePressed: () {},
  onBackPressed: () {},
  step: step,
  pinLength: pinLength,
  centerWidget: step == 0 ? PinLengthToggleButton(currentPinLength: pinLength, onToggle: () {}) : null,
);

PinInputPad _check(List<String> taps) => PinInputPad(
  title: t.pin_check_screen.text,
  pin: '',
  errorMessage: '',
  onKeyTap: taps.add,
  pinShuffleNumbers: _keys,
  onClosePressed: () {},
  step: 0,
);

PinInputPad _entrance(List<String> taps) => PinInputPad(
  appBarVisible: false,
  title: '',
  initOptionVisible: true,
  pin: '',
  errorMessage: '',
  onKeyTap: taps.add,
  pinShuffleNumbers: _keys,
  onClosePressed: () {},
  onReset: () => taps.add('reset'),
  step: 0,
);

/// No framework error, every key fully inside the sheet (or app-entrance screen) and the screen, hit-testable at its centre, and a usable
/// height; one tap reaches its own callback.
Future<List<Rect>> _expectReachableKeypad(WidgetTester tester, List<String> taps) async {
  expect(tester.takeException(), isNull);
  final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
  final sheet = find.byType(BottomSheet).evaluate().isEmpty ? screen : tester.getRect(find.byType(BottomSheet));
  final keys = find.byType(KeyButton);
  expect(keys, findsNWidgets(12));
  expect(keys.hitTestable(), findsNWidgets(12));
  final rects = [for (final e in keys.evaluate()) tester.getRect(find.byWidget(e.widget))];
  for (final r in rects) {
    expect(
      sheet.contains(r.topLeft) && sheet.contains(r.bottomRight - const Offset(.01, .01)),
      isTrue,
      reason: '$r in $sheet',
    );
    expect(screen.contains(r.bottomRight - const Offset(.01, .01)), isTrue, reason: '$r on $screen');
    expect(r.height, greaterThanOrEqualTo(48));
  }
  await tester.tap(find.widgetWithText(KeyButton, '0'));
  await tester.pump();
  expect(taps, ['0']);
  expect(tester.takeException(), isNull);
  return rects;
}

void main() {
  // iPhone Duo inner panel, UIKit natural locked canvas measured on the iOS 27.1 simulator (951x669 pt @3).
  // The native Flutter safe-area padding there was not recorded, so every Duo state runs for a range of bottom
  // insets (0 = none, 21 = iPhone landscape home indicator, 34 = portrait home indicator, 48 = larger margin).
  const duo = Size(951, 669);
  const bottoms = [0.0, 21.0, 34.0, 48.0];

  for (final bottom in bottoms) {
    final insets = EdgeInsets.only(bottom: bottom);
    group('Duo full natural canvas, bottom inset $bottom', () {
      testWidgets('PIN set sheet, 4 digits (the native 8.2 px overflow state)', (tester) async {
        final taps = await _openSheet(tester, duo, (taps) => _setting(taps), insets: insets);
        await _expectReachableKeypad(tester, taps);
      });
      testWidgets('PIN set sheet, 6 digits', (tester) async {
        final taps = await _openSheet(tester, duo, (taps) => _setting(taps, pinLength: 6), insets: insets);
        await _expectReachableKeypad(tester, taps);
      });
      testWidgets('PIN confirm step with an error message', (tester) async {
        final taps = await _openSheet(
          tester,
          duo,
          (taps) => _setting(taps, step: 1, error: t.errors.pin_setting_error.process_failed),
          insets: insets,
        );
        await _expectReachableKeypad(tester, taps);
      });
      testWidgets('PIN check sheet', (tester) async {
        final taps = await _openSheet(tester, duo, _check, insets: insets);
        await _expectReachableKeypad(tester, taps);
      });
      testWidgets('app-entrance PIN check with forgot PIN', (tester) async {
        final taps = await _openSheet(tester, duo, _entrance, insets: insets, sheet: false);
        await _expectReachableKeypad(tester, taps);
        await tester.tap(find.text(t.forgot_password).hitTestable());
        expect(taps, ['0', 'reset']);
      });
    });
  }

  // Too short for 4 rows of usable keys (sheet 450 pt, 34 pt bottom inset): keys keep >= 48 pt and the keypad scrolls,
  // so the last row (incl. backspace) is still reachable; no clipping, no framework error.
  testWidgets('compact 951x500 sheet keeps usable keys and scrolls to the last row', (tester) async {
    final taps = await _openSheet(
      tester,
      const Size(951, 500),
      (taps) => _setting(taps),
      insets: const EdgeInsets.only(bottom: 34),
    );
    expect(tester.takeException(), isNull);
    final keys = find.byType(KeyButton);
    expect(keys, findsNWidgets(12));
    for (final e in keys.evaluate()) {
      expect(tester.getSize(find.byWidget(e.widget)).height, greaterThanOrEqualTo(kMinInteractiveDimension));
    }
    final grid = find.byType(GridView);
    final sheet = tester.getRect(find.byType(BottomSheet));
    for (final value in ['6', '<']) {
      final key = find.byWidgetPredicate((w) => w is KeyButton && w.keyValue == value).hitTestable();
      await tester.scrollUntilVisible(
        key,
        40,
        scrollable: find.descendant(of: grid, matching: find.byType(Scrollable)),
      );
      final rect = tester.getRect(key);
      final viewport = tester.getRect(grid);
      expect(
        viewport.top <= rect.top && rect.bottom <= viewport.bottom && rect.bottom <= sheet.bottom,
        isTrue,
        reason: '$rect in $viewport / $sheet',
      );
      await tester.tap(key);
      await tester.pump();
    }
    expect(taps, ['6', '<']);
    expect(tester.takeException(), isNull);
  });

  // Unbounded height (keypad-only use inside a scroll view): the nominal keypad, no NaN/invalid aspect, no scrolling.
  testWidgets('keypad-only, unbounded height keeps the nominal keypad', (tester) async {
    tester.view.physicalSize = const Size(390, 844) * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PinInputPad(
              title: '',
              pin: '',
              errorMessage: '',
              onKeyTap: (_) {},
              pinShuffleNumbers: _keys,
              onClosePressed: () {},
              step: 0,
              showOnlyKeypad: true,
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    for (final e in find.byType(KeyButton).evaluate()) {
      expect(tester.getSize(find.byWidget(e.widget)).height, moreOrLessEquals(390 / 3 / 2, epsilon: 1e-6));
    }
  });

  // Ordinary portrait phones (with their usual safe areas) keep the existing keypad exactly: cell height ==
  // (sheet width / 3) / 2, and the grid still adds the bottom safe inset below the last row.
  const phones = [
    (Size(375, 667), EdgeInsets.only(top: 20)),
    (Size(390, 844), EdgeInsets.only(top: 47, bottom: 34)),
    (Size(402, 874), EdgeInsets.only(top: 62, bottom: 34)),
    (Size(430, 932), EdgeInsets.only(top: 59, bottom: 34)),
  ];
  for (final (phone, insets) in phones) {
    testWidgets('ordinary phone $phone keeps the normal keypad dimensions', (tester) async {
      final taps = await _openSheet(tester, phone, (taps) => _setting(taps), insets: insets);
      final rects = await _expectReachableKeypad(tester, taps);
      final grid = tester.getRect(find.byType(GridView));
      expect(grid.width, phone.width);
      for (final r in rects) {
        expect(r.height, moreOrLessEquals(phone.width / 3 / 2, epsilon: 1e-6));
        expect(r.width, moreOrLessEquals(phone.width / 3 - 32, epsilon: 1e-6));
      }
      expect(grid.height, moreOrLessEquals(4 * phone.width / 3 / 2 + insets.bottom, epsilon: 1e-6));
    });
  }
}
