import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';

void main() {
  group('formatLastUpdateTime', () {
    test('should return only time if the date is today', () {
      DateTime now = DateTime.now();
      int millisecondsSinceEpoch = now.millisecondsSinceEpoch;
      String result = DateTimeUtil.formatLastUpdateTime(millisecondsSinceEpoch);
      String expected = DateFormat('HH:mm').format(now);
      expect(result, expected);
    });

    test('should return date without year if the year is same', () {
      DateTime now = DateTime.now();
      DateTime sameYear = DateTime(now.year, 1, 1, 12, 30);
      int millisecondsSinceEpoch = sameYear.millisecondsSinceEpoch;
      String result = DateTimeUtil.formatLastUpdateTime(millisecondsSinceEpoch);
      String expected = DateFormat('M.d HH:mm').format(sameYear);
      expect(result, expected);
    });

    test('should return full format if the year is different', () {
      DateTime now = DateTime.now();
      DateTime differentYear = DateTime(now.year - 1, 1, 1, 12, 30);
      int millisecondsSinceEpoch = differentYear.millisecondsSinceEpoch;
      String result = DateTimeUtil.formatLastUpdateTime(millisecondsSinceEpoch);
      String expected = DateFormat('yy.M.d HH:mm').format(differentYear);
      expect(result, expected);
    });

    test('should handle edge case of end of year', () {
      DateTime endOfYear = DateTime(2023, 12, 31, 23, 59);
      int millisecondsSinceEpoch = endOfYear.millisecondsSinceEpoch;
      String result = DateTimeUtil.formatLastUpdateTime(millisecondsSinceEpoch);
      String expected = DateFormat('yy.M.d HH:mm').format(endOfYear);
      expect(result, expected);
    });

    test('should handle edge case of start of year', () {
      DateTime startOfYear = DateTime(2023, 1, 1, 0, 0);
      int millisecondsSinceEpoch = startOfYear.millisecondsSinceEpoch;
      String result = DateTimeUtil.formatLastUpdateTime(millisecondsSinceEpoch);
      String expected = DateFormat('yy.M.d HH:mm').format(startOfYear);
      expect(result, expected);
    });

    test('should return true if the date is today ', () {
      var tomorrow = DateTime.now().add(const Duration(days: 1));
      var millisecondsSinceEpoch = tomorrow.millisecondsSinceEpoch;
      var result = DateTimeUtil.isToday(millisecondsSinceEpoch);
      expect(result, isFalse);
    });
  });
}
