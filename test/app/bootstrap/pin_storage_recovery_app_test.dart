import 'dart:async';

import 'package:coconut_wallet/app/bootstrap/pin_storage_recovery_app.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('startup recovery offers retry and prevents concurrent attempts', (tester) async {
    final gate = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(
      PinStorageRecoveryApp(
        onRetry: () async {
          attempts++;
          await gate.future;
        },
      ),
    );
    expect(find.text(t.pin_check_screen.startup_authentication_unavailable), findsOneWidget);
    await tester.tap(find.text(t.retry));
    await tester.pump();
    expect(attempts, 1);
    expect(tester.widget<ShrinkAnimationButton>(find.byType(ShrinkAnimationButton)).isActive, isFalse);
    await tester.tap(find.byType(ShrinkAnimationButton));
    await tester.pump();
    expect(attempts, 1);
    gate.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<ShrinkAnimationButton>(find.byType(ShrinkAnimationButton)).isActive, isTrue);
    await tester.tap(find.text(t.retry));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed startup can replace the recovery screen during a pending retry', (tester) async {
    final gate = Completer<void>();
    await tester.pumpWidget(PinStorageRecoveryApp(onRetry: () => gate.future));
    await tester.tap(find.text(t.retry));
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: Text('started')));
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('started'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
