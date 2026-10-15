import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/widgets/features/qr/camera_permission_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  String get language => 'ko';
}

void main() {
  for (final dismissWithCancel in [true, false]) {
    testWidgets('camera permission dialog completes after ${dismissWithCancel ? 'cancel' : 'barrier tap'}', (
      tester,
    ) async {
      var completed = false;
      await tester.pumpWidget(
        ChangeNotifierProvider<PreferenceProvider>.value(
          value: _Preferences(),
          child: MaterialApp(
            theme: buildCoconutThemeData(),
            home: Builder(
              builder:
                  (context) => Scaffold(
                    body: TextButton(
                      onPressed: () async {
                        await showCameraPermissionDialog(context);
                        completed = true;
                      },
                      child: const Text('Open scanner'),
                    ),
                  ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open scanner'));
      await tester.pumpAndSettle();
      expect(find.text(t.coconut_qr_scanner.camera_error.title), findsOneWidget);
      expect(find.text(t.coconut_qr_scanner.camera_error.need_camera_permission), findsOneWidget);
      expect(find.text(t.go_to_settings), findsOneWidget);
      expect(completed, isFalse);

      if (dismissWithCancel) {
        await tester.tap(find.text(t.cancel));
      } else {
        await tester.tapAt(const Offset(5, 5));
      }
      await tester.pumpAndSettle();

      expect(completed, isTrue);
      expect(find.text(t.coconut_qr_scanner.camera_error.title), findsNothing);
      expect(find.text('Open scanner'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
