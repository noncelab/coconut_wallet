// ignore_for_file: constant_identifier_names

import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

import '../utils/balance_format_util.dart';

enum FiatCode {
  KRW('KRW', 'South Korean Won', '₩'),
  USD('USD', 'US Dollar', '\$'),
  JPY('JPY', 'Japanese Yen', '¥');

  final String code; // ISO 4217 코드
  final String fullName; // 통화 이름
  final String symbol;

  const FiatCode(this.code, this.fullName, this.symbol);

  // 메서드 추가 가능
  String description() {
    return '$code: $fullName $symbol';
  }
}

enum BitcoinUnit {
  btc,
  sats,
  bip177;

  BitcoinUnit get next => BitcoinUnit.values[(index + 1) % BitcoinUnit.values.length];

  bool get isBtcUnit => this == BitcoinUnit.btc;
  bool get isSatsUnit => this == BitcoinUnit.sats;
  bool get isBip177Unit => this == BitcoinUnit.bip177;

  /// satoshi 단위의 금액이 내부 표현 기준 (sats, bip177)
  bool get isBasedOnSatoshi => this == BitcoinUnit.sats || this == BitcoinUnit.bip177;

  /// BIP-177은 심볼이 숫자 앞에 위치
  bool get isPrefixSymbol => this == BitcoinUnit.bip177;

  String get symbol {
    switch (this) {
      case BitcoinUnit.btc:
        return t.btc;
      case BitcoinUnit.sats:
        return t.sats;
      case BitcoinUnit.bip177:
        return '₿';
    }
  }

  String get fullName {
    switch (this) {
      case BitcoinUnit.btc:
        return t.bitcoin_name;
      case BitcoinUnit.sats:
        return t.satoshi;
      case BitcoinUnit.bip177:
        return 'bitcoins';
    }
  }

  /// 사용자 입력 금액(double)을 satoshi로 변환
  int toSatoshi(double amount) {
    switch (this) {
      case BitcoinUnit.btc:
        return UnitUtil.convertBitcoinToSatoshi(amount);
      case BitcoinUnit.sats:
      case BitcoinUnit.bip177:
        return amount.toInt();
    }
  }

  /// satoshi를 현재 단위의 double 값으로 변환
  double fromSatoshi(int satoshi) {
    switch (this) {
      case BitcoinUnit.btc:
        return UnitUtil.convertSatoshiToBitcoin(satoshi);
      case BitcoinUnit.sats:
      case BitcoinUnit.bip177:
        return satoshi.toDouble();
    }
  }

  String displayBitcoinAmount(
    int? amount, {
    String defaultWhenNull = '',
    String defaultWhenZero = '',
    bool shouldCheckZero = false,
    bool withUnit = false,
    bool forceEightDecimals = false,
  }) {
    if (amount == null) return defaultWhenNull;
    if (shouldCheckZero && amount == 0) return defaultWhenZero;

    String amountText;
    switch (this) {
      case BitcoinUnit.btc:
        amountText = BalanceFormatUtil.formatSatoshiToReadableBitcoin(amount, forceEightDecimals: forceEightDecimals);
        break;
      case BitcoinUnit.sats:
      case BitcoinUnit.bip177:
        amountText = amount.toThousandsSeparatedString();
        break;
    }

    if (!withUnit) return amountText;
    return isPrefixSymbol ? "$symbol $amountText" : "$amountText $symbol";
  }

  /// 금액에 +/- 접두사와 단위 심볼을 포함한 텍스트 반환합
  /// e.g. BTC: "+0.001 BTC", sats: "+100,000 sats", BIP-177: "+₿0.001"
  String formatAmountWithSign(int? amount, {bool isPositive = true}) {
    if (amount == null) return '';
    final absAmountText = displayBitcoinAmount(amount.abs());
    final sign = isPositive ? '+' : '-';
    if (isPrefixSymbol) return "$sign$symbol$absAmountText";
    return "$sign$absAmountText $symbol";
  }

  static BitcoinUnit? getFromSymbol(String symbol) {
    if (symbol == t.btc) return BitcoinUnit.btc;
    if (symbol == t.sats) return BitcoinUnit.sats;
    if (symbol == '₿') return BitcoinUnit.bip177;
    return null;
  }

  /// SharedPreferences 저장용 키
  String get storageKey => name;

  /// SharedPreferences에서 복원
  static BitcoinUnit fromStorageKey(String key) {
    return BitcoinUnit.values.firstWhere((e) => e.name == key, orElse: () => BitcoinUnit.btc);
  }

  /// 기존 bool 값으로부터 마이그레이션
  static BitcoinUnit fromLegacyBool(bool isBtcUnit) {
    return isBtcUnit ? BitcoinUnit.btc : BitcoinUnit.sats;
  }
}
