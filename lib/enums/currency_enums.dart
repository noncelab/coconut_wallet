// ignore_for_file: constant_identifier_names

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
