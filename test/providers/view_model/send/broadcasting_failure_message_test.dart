import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/providers/view_model/send/broadcasting_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Electrum 서버가 sendrawtransaction 거부 사유를 담아 돌려주는 형태
AppError _rejected(String reason) => ErrorCodes.broadcastErrorWithMessage(
  {'code': 1, 'message': 'the transaction was rejected by network rules.\n\n$reason\n[0200...]'}.toString(),
);

void main() {
  setUpAll(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  test('미성숙 coinbase 전송 거부는 남은 블록 수와 함께 안내한다', () {
    final message = BroadcastingViewModel.broadcastFailureMessage(
      _rejected('bad-txns-premature-spend-of-coinbase, tried to spend coinbase at depth 12'),
    );

    expect(message, t.alert.error_send.immature_coinbase_remaining(count: 88));
  });

  test('깊이를 알 수 없는 미성숙 coinbase 거부는 남은 블록 수 없이 안내한다', () {
    final message = BroadcastingViewModel.broadcastFailureMessage(_rejected('bad-txns-premature-spend-of-coinbase'));

    expect(message, t.alert.error_send.immature_coinbase);
  });

  test('최소 중계 수수료 미달은 기존 수수료 안내를 유지한다', () {
    final message = BroadcastingViewModel.broadcastFailureMessage(_rejected('min relay fee not met, 100 < 141'));

    expect(message, t.alert.error_send.insufficient_fee);
  });

  test('알 수 없는 거부 사유는 원문을 그대로 보여 준다', () {
    final error = _rejected('bad-txns-inputs-missingorspent');

    expect(BroadcastingViewModel.broadcastFailureMessage(error), error.toString());
  });
}
