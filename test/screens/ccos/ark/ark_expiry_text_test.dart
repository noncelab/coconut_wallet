import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_expiry_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  test('blocks left read as days, hours, under an hour or expired at ten minutes a block', () {
    expect(arkExpiryText(null), '-');
    expect(arkExpiryText(0), '만료됨');
    expect(arkExpiryText(5), '1시간 안에');
    expect(arkExpiryText(60), '약 10시간 뒤');
    expect(arkExpiryText(4320), '약 30일 뒤');
  });

  test('a span of blocks reads as rough days or hours', () {
    expect(arkDurationText(4320), '약 30일');
    expect(arkDurationText(60), '약 10시간');
    expect(arkDurationText(3), '1시간 미만');
  });

  test('a single day reads as a day, not one day, both as a span and as time left', () {
    expect(arkDurationText(144), '약 하루');
    expect(arkDurationText(287), '약 하루');
    expect(arkExpiryText(144), '약 하루 뒤');
    LocaleSettings.setLocaleSync(AppLocale.en);
    expect(arkDurationText(144), 'about a day');
    expect(arkExpiryText(200), 'in about a day');
  });

  test('a block count is written with the time it takes, minutes under an hour', () {
    expect(arkBlocksText(3), '3블록(약 30분)');
    expect(arkBlocksText(144), '144블록(약 하루)');
    expect(arkBlocksText(60), '60블록(약 10시간)');
    expect(arkBlocksLaterText(144), '144블록(약 하루) 뒤');
    LocaleSettings.setLocaleSync(AppLocale.en);
    expect(arkBlocksText(144), '144 blocks (about a day)');
  });
}
