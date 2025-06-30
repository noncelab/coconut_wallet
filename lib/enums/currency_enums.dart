// ignore_for_file: constant_identifier_names

import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

import '../utils/balance_format_util.dart';

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

  String get symbol => this == BitcoinUnit.btc ? t.btc : t.sats;

  String displayBitcoinAmount(int? amount,
      {String defaultWhenNull = '',
      String defaultWhenZero = '',
      bool shouldCheckZero = false,
      bool withUnit = false,
      bool forceEightDecimals = false}) {
    if (amount == null) return defaultWhenNull;
    if (shouldCheckZero && amount == 0) return defaultWhenZero;

    String amountText = this == BitcoinUnit.btc
        ? BalanceFormatUtil.formatSatoshiToReadableBitcoin(amount,
            forceEightDecimals: forceEightDecimals)
        : amount.toThousandsSeparatedString();

    return withUnit ? "$amountText $symbol" : amountText;
  }
}
