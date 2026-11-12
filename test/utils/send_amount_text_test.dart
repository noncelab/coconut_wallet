import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/utils/send_amount_text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String type(String keys, {bool isSats = false}) => SendAmountText.applyAll('', keys, isSats: isSats);

  test('digits, a decimal point and backspace', () {
    expect(type('12'), '12');
    expect(type('.5'), '0.5');
    expect(type('1,5'), '1.5');
    expect(type('1..5'), '1.5');
    expect(SendAmountText.apply('1.5', '<', isSats: false), '1.');
    expect(SendAmountText.apply('', '<', isSats: false), '');
  });

  test('a leading zero is replaced, unless a decimal follows', () {
    expect(type('05'), '5');
    expect(type('00'), '0');
    expect(type('0.05'), '0.05');
  });

  test('BTC keeps 8 decimals and 8 integer digits; sats has no decimals and 16 digits', () {
    expect(type('0.123456789'), '0.12345678');
    expect(type('123456789'), '12345678');
    expect(type('12.5', isSats: true), '125');
    expect(type('12345678901234567', isSats: true), '1234567890123456');
  });

  test('conversions follow the unit', () {
    expect(SendAmountText.toSats('0.0002', BitcoinUnit.btc), 20000);
    expect(SendAmountText.toSats('20000', BitcoinUnit.sats), 20000);
    expect(SendAmountText.toSats('', BitcoinUnit.btc), isNull);
    expect(SendAmountText.toSats('0', BitcoinUnit.btc), isNull);
    expect(SendAmountText.fromSats(20000, BitcoinUnit.btc), '0.0002');
    expect(SendAmountText.fromSats(100000000, BitcoinUnit.btc), '1');
    expect(SendAmountText.fromSats(20000, BitcoinUnit.sats), '20000');
  });
}
