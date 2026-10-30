// ignore_for_file: constant_identifier_names

import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

import '../utils/balance_format_util.dart';

enum FiatCode {
  // 거래소 웹소켓으로 실시간 시세를 제공하는 통화 (ExchangeType/웹소켓 매핑 대상)
  KRW('KRW', 'South Korean Won', '₩', 0),
  USD('USD', 'US Dollar', '\$', 2),
  JPY('JPY', 'Japanese Yen', '¥', 0),
  EUR('EUR', 'Euro', '€', 2),

  // CoinGecko 폴링으로 시세를 제공하는 통화
  AED('AED', 'UAE Dirham', 'د.إ', 2),
  ARS('ARS', 'Argentine Peso', r'$', 2),
  AUD('AUD', 'Australian Dollar', r'A$', 2),
  BDT('BDT', 'Bangladeshi Taka', '৳', 2),
  BHD('BHD', 'Bahraini Dinar', 'BD', 3),
  BMD('BMD', 'Bermudian Dollar', r'$', 2),
  BRL('BRL', 'Brazilian Real', r'R$', 2),
  CAD('CAD', 'Canadian Dollar', r'C$', 2),
  CHF('CHF', 'Swiss Franc', 'CHF', 2),
  CLP('CLP', 'Chilean Peso', r'$', 0),
  CZK('CZK', 'Czech Koruna', 'Kč', 2),
  DKK('DKK', 'Danish Krone', 'kr', 2),
  GBP('GBP', 'British Pound', '£', 2),
  GEL('GEL', 'Georgian Lari', '₾', 2),
  HKD('HKD', 'Hong Kong Dollar', r'HK$', 2),
  HUF('HUF', 'Hungarian Forint', 'Ft', 2),
  IDR('IDR', 'Indonesian Rupiah', 'Rp', 2),
  ILS('ILS', 'Israeli New Shekel', '₪', 2),
  INR('INR', 'Indian Rupee', '₹', 2),
  KWD('KWD', 'Kuwaiti Dinar', 'KD', 3),
  LKR('LKR', 'Sri Lankan Rupee', 'Rs', 2),
  MMK('MMK', 'Burmese Kyat', 'K', 2),
  MXN('MXN', 'Mexican Peso', r'MX$', 2),
  MYR('MYR', 'Malaysian Ringgit', 'RM', 2),
  NGN('NGN', 'Nigerian Naira', '₦', 2),
  NOK('NOK', 'Norwegian Krone', 'kr', 2),
  NZD('NZD', 'New Zealand Dollar', r'NZ$', 2),
  PHP('PHP', 'Philippine Peso', '₱', 2),
  PKR('PKR', 'Pakistani Rupee', '₨', 2),
  PLN('PLN', 'Polish Zloty', 'zł', 2),
  RUB('RUB', 'Russian Ruble', '₽', 2),
  SAR('SAR', 'Saudi Riyal', '﷼', 2),
  SEK('SEK', 'Swedish Krona', 'kr', 2),
  SGD('SGD', 'Singapore Dollar', r'S$', 2),
  THB('THB', 'Thai Baht', '฿', 2),
  TRY('TRY', 'Turkish Lira', '₺', 2),
  TWD('TWD', 'New Taiwan Dollar', r'NT$', 2),
  UAH('UAH', 'Ukrainian Hryvnia', '₴', 2),
  VND('VND', 'Vietnamese Dong', '₫', 0),
  ZAR('ZAR', 'South African Rand', 'R', 2);

  final String code; // ISO 4217 코드
  final String fullName; // 통화 이름
  final String symbol;
  final int decimalDigits; // ISO 4217 기준 소수 자리수 (예: KRW/JPY=0, USD/EUR=2, BHD/KWD=3)

  const FiatCode(this.code, this.fullName, this.symbol, this.decimalDigits);

  /// 거래소 웹소켓으로 실시간 시세를 받는 통화. 나머지는 CoinGecko 폴링 사용.
  bool get hasExchangeSource =>
      this == FiatCode.KRW || this == FiatCode.USD || this == FiatCode.JPY || this == FiatCode.EUR;

  /// CoinGecko vs_currency 파라미터 값
  String get vsCurrency => code.toLowerCase();

  /// 가격 출처 표기
  String get priceSource => switch (this) {
    FiatCode.KRW => 'Upbit (KRW-BTC)',
    FiatCode.USD => 'Binance (BTCUSDT)',
    FiatCode.JPY => 'bitFlyer (BTC_JPY)',
    FiatCode.EUR => 'Binance (BTCEUR)',
    _ => 'CoinGecko',
  };

  /// 1 whole unit를 최소단위(minor unit, 예: cent) 정수로 위해 필요한 배수 (10^decimalDigits)
  /// 예: $1 = 100 cent -> decimalDigits = 2 (10^2 = 100)
  int get minorUnitsPerWhole {
    var result = 1;
    for (var i = 0; i < decimalDigits; i++) {
      result *= 10;
    }
    return result;
  }

  // 메서드 추가 가능
  String description() {
    return '$code: $fullName $symbol';
  }
}

/// 통화별 Quick Add 금액. 10/50/100/500 USD 상당의 금액대를
/// 1, 0, 5 세 숫자로만 표현 가능한 값으로 지정한다.
/// 두 번째 값은 fiat 입력 필드의 placeholder로도 사용된다.
const Map<FiatCode, List<int>> kFiatQuickAddAmounts = {
  // 강한 통화: 5/10/50/100
  FiatCode.BHD: [5, 10, 50, 100],
  FiatCode.KWD: [5, 10, 50, 100],

  // 10/50/100/500
  FiatCode.USD: [10, 50, 100, 500],
  FiatCode.EUR: [10, 50, 100, 500],
  FiatCode.GBP: [10, 50, 100, 500],
  FiatCode.AUD: [10, 50, 100, 500],
  FiatCode.CAD: [10, 50, 100, 500],
  FiatCode.CHF: [10, 50, 100, 500],
  FiatCode.NZD: [10, 50, 100, 500],
  FiatCode.SGD: [10, 50, 100, 500],
  FiatCode.BMD: [10, 50, 100, 500],

  // 50/100/500/1,000
  FiatCode.AED: [50, 100, 500, 1000],
  FiatCode.ILS: [50, 100, 500, 1000],
  FiatCode.SAR: [50, 100, 500, 1000],
  FiatCode.MYR: [50, 100, 500, 1000],
  FiatCode.PLN: [50, 100, 500, 1000],
  FiatCode.BRL: [50, 100, 500, 1000],
  FiatCode.DKK: [50, 100, 500, 1000],
  FiatCode.GEL: [10, 100, 500, 1000],

  // 100/500/1,000/5,000
  FiatCode.HKD: [100, 500, 1000, 5000],
  FiatCode.NOK: [100, 500, 1000, 5000],
  FiatCode.SEK: [100, 500, 1000, 5000],
  FiatCode.MXN: [100, 500, 1000, 5000],
  FiatCode.ZAR: [100, 500, 1000, 5000],
  FiatCode.CZK: [100, 500, 1000, 10000],

  // 500/1,000/5,000/10,000
  FiatCode.PHP: [500, 1000, 5000, 10000],
  FiatCode.THB: [500, 1000, 5000, 10000],
  FiatCode.TRY: [500, 1000, 5000, 10000],
  FiatCode.TWD: [500, 1000, 5000, 10000],
  FiatCode.UAH: [500, 1000, 5000, 10000],

  // 1,000/5,000/10,000/50,000
  FiatCode.JPY: [1000, 5000, 10000, 50000],
  FiatCode.BDT: [1000, 5000, 10000, 50000],
  FiatCode.INR: [1000, 5000, 10000, 50000],
  FiatCode.RUB: [1000, 5000, 10000, 50000],
  FiatCode.PKR: [1000, 10000, 50000, 100000],

  // 5,000/10,000/50,000/100,000
  FiatCode.HUF: [5000, 10000, 50000, 100000],
  FiatCode.LKR: [5000, 10000, 50000, 100000],

  // 10,000/50,000/100,000/500,000
  FiatCode.KRW: [10000, 50000, 100000, 500000],
  FiatCode.ARS: [10000, 50000, 100000, 500000],
  FiatCode.CLP: [10000, 50000, 100000, 500000],
  FiatCode.MMK: [10000, 50000, 100000, 500000],
  FiatCode.NGN: [10000, 50000, 100000, 500000],

  // 100,000/500,000/1,000,000/5,000,000
  FiatCode.IDR: [100000, 500000, 1000000, 5000000],
  FiatCode.VND: [100000, 500000, 1000000, 5000000],
};

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
