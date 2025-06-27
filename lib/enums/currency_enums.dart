// ignore_for_file: constant_identifier_names

import 'package:coconut_wallet/localization/strings.g.dart';

enum CurrencyCode {
  KRW('KRW', 'South Korean Won', '₩'),
  ;

  final String code; // ISO 4217 코드
  final String fullName; // 통화 이름
  final String symbol;

  const CurrencyCode(this.code, this.fullName, this.symbol);

  // 메서드 추가 가능
  String description() {
    return '$code: $fullName $symbol';
  }
}

enum BitcoinUnit {
  btc,
  sats;

  String symbol() {
    return this == BitcoinUnit.btc ? t.btc : t.sats;
  }
}
