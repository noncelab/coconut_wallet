import 'dart:async';

import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/common/pin_check_view_model.dart';
import 'package:coconut_wallet/services/security/pin_auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../screens/common/pin_check_screen_test.dart' show TestAuth;

void main() {
  testWidgets('cooldown expiration reloads authentication status and disposal stops its timer', (tester) async {
    var now = DateTime.utc(2026, 10, 30);
    final auth = TestAuth()..status = const PinAuthStatus(failures: 3, remaining: Duration(seconds: 2));
    final model = PinCheckViewModel(auth, now: () => now);
    model.initialize();
    await tester.pump();
    expect(model.canEnterPin, isFalse);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(model.errorMessage, t.pin_check_screen.retry_after(time: '1${t.pin_check_screen.time_second}'));
    auth.status = const PinAuthStatus(failures: 3);
    now = now.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(model.canEnterPin, isTrue);
    expect(model.errorMessage, t.errors.pin_check_error.trial_count(count: 3));
    model.dispose();
    await tester.pump(const Duration(seconds: 2));
  });

  test('verification prevents duplicate requests and ignores completion after disposal', () async {
    final auth = TestAuth()..gate = Completer<PinVerificationResult>();
    final model = PinCheckViewModel(auth);
    await model.refreshStatus();
    for (final digit in ['1', '2', '3', '4']) {
      model.enterKey(digit);
    }
    final pending = model.verifyPin();
    expect(model.isLoading, isTrue);
    expect(await model.verifyPin(), isNull);
    expect(auth.calls, 1);
    model.dispose();
    auth.gate!.complete(const PinVerificationResult(PinVerificationOutcome.success));
    expect(await pending, isNull);
    expect(model.pin, isEmpty);
  });

  test('unavailable verification disables input until a successful status refresh', () async {
    final auth = TestAuth()..result = const PinVerificationResult(PinVerificationOutcome.unavailable);
    final model = PinCheckViewModel(auth);
    addTearDown(model.dispose);
    await model.refreshStatus();
    for (final digit in ['1', '2', '3', '4']) {
      model.enterKey(digit);
    }
    expect(await model.verifyPin(), isFalse);
    expect(model.canEnterPin, isFalse);
    expect(model.errorMessage, t.pin_check_screen.authentication_unavailable);
    await model.refreshStatus();
    expect(model.canEnterPin, isTrue);
  });
}
