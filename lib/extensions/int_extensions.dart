import 'package:intl/intl.dart';

extension IntFormatting on int {
  String toThousandsSeparatedString() {
    final formatter = NumberFormat('#,###');
    return formatter.format(this);
  }
}
