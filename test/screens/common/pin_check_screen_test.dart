import 'dart:async';

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/screens/common/pin_check_screen.dart';
import 'package:coconut_wallet/services/security/pin_auth_service.dart';
import 'package:coconut_wallet/widgets/features/auth/pin/pin_input_pad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class TestAuth extends Fake with ChangeNotifier implements AuthProvider {
  PinAuthStatus status = const PinAuthStatus();
  PinVerificationResult result = const PinVerificationResult(
    PinVerificationOutcome.incorrect,
    PinAuthStatus(failures: 1),
  );
  int calls = 0;
  bool storageUnavailable = false;
  Completer<PinVerificationResult>? gate;
  @override
  int get pinLength => 4;
  @override
  List<String> getShuffledNumberPad({bool isSettings = false}) => [
    '1',
    '2',
    '3',
    '4',
    '5',
    '6',
    '7',
    '8',
    '9',
    '',
    '0',
    '<',
  ];
  @override
  Future<PinAuthStatus> getPinAuthStatus() async {
    if (storageUnavailable) throw const PinAuthException(PinAuthError.unavailable);
    return status;
  }

  @override
  Future<PinVerificationResult> verifyPinResult(String inputPin) async {
    calls++;
    return gate == null ? result : await gate!.future;
  }
}

void main() {
  Future<void> open(WidgetTester tester, TestAuth auth) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: MaterialApp(theme: buildCoconutThemeData(), home: const PinCheckScreen(allowBiometrics: false)),
      ),
    );
    await tester.pumpAndSettle();
  }

  void enter(WidgetTester tester) {
    final pad = tester.widget<PinInputPad>(find.byType(PinInputPad));
    for (final digit in ['1', '2', '3', '4']) {
      pad.onKeyTap(digit);
    }
  }

  testWidgets('a restored cooldown blocks input and displays the remaining wait', (tester) async {
    final auth = TestAuth()..status = const PinAuthStatus(failures: 3, remaining: Duration(seconds: 30));
    await open(tester, auth);
    expect(find.text(t.pin_check_screen.retry_after(time: '30${t.pin_check_screen.time_second}')), findsOneWidget);
    enter(tester);
    await tester.pump();
    expect(auth.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('repeated input during verification cannot submit twice', (tester) async {
    final auth = TestAuth()..gate = Completer<PinVerificationResult>();
    await open(tester, auth);
    enter(tester);
    enter(tester);
    await tester.pump();
    expect(auth.calls, 1);
    auth.gate!.complete(auth.result);
    await tester.pumpAndSettle();
    expect(find.text(t.errors.pin_check_error.trial_count(count: 2)), findsOneWidget);
    expect(tester.widget<PinInputPad>(find.byType(PinInputPad)).pin, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('restored failures show the remaining attempts in the current turn', (tester) async {
    for (final failures in [1, 2, 3, 4, 5]) {
      final auth = TestAuth()..status = PinAuthStatus(failures: failures);
      await open(tester, auth);
      expect(find.text(t.errors.pin_check_error.trial_count(count: 3 - failures % 3)), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('cooldowns use Vault-style hour minute and second labels', (tester) async {
    const duration = Duration(hours: 1, minutes: 2, seconds: 3);
    final auth = TestAuth()..status = const PinAuthStatus(failures: 3, remaining: duration);
    await open(tester, auth);
    final formatted =
        '1${t.pin_check_screen.time_hour} 2${t.pin_check_screen.time_minute} 3${t.pin_check_screen.time_second}';
    expect(find.text(t.pin_check_screen.retry_after(time: formatted)), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an unreadable authentication record never enables PIN entry', (tester) async {
    final auth = TestAuth()..storageUnavailable = true;
    await open(tester, auth);
    expect(find.text(t.pin_check_screen.authentication_unavailable), findsOneWidget);
    enter(tester);
    await tester.pump();
    expect(auth.calls, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
