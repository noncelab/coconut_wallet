import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:intl/intl.dart';

extension StringFormatting on String {
  String toThousandsSeparatedString() {
    // String을 숫자로 변환할 수 없는 경우 원래 문자열 반환
    final number = num.tryParse(this);
    if (number == null) return this;

    try {
      // 소수점이 있는지 확인
      if (contains('.')) {
        List<String> parts = split('.');
        String integerPart = parts[0];
        String decimalPart = parts.length > 1 ? parts[1] : '';

        // 소수점 4자리가 넘어가는 경우 4자리씩 띄워서 처리
        if (decimalPart.length > 4) {
          decimalPart = "${decimalPart.substring(0, 4)} ${decimalPart.substring(4)}";
        }

        final formatter = NumberFormat('#,###');
        String formattedInt = formatter.format(int.parse(integerPart));
        return '$formattedInt.$decimalPart';
      } else {
        return int.parse(this).toThousandsSeparatedString();
      }
    } catch (e) {
      return this;
    }
  }
}
