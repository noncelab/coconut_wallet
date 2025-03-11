import 'package:intl/intl.dart';

class DateTimeUtil {
  // ex) "2024-04-12 18:19:26.000" => List<String> ["24.04.12", "18:19"]
  static List<String> formatTimeStamp(DateTime dateTime) {
    DateTime localDateTime = dateTime.toLocal();

    String formattedDate =
        "${localDateTime.year % 100}.${localDateTime.month >= 10 ? localDateTime.month : "0${localDateTime.month}"}."
        "${localDateTime.day >= 10 ? localDateTime.day : "0${localDateTime.day}"}";

    String formattedTime =
        "${localDateTime.hour >= 10 ? localDateTime.hour : '0${localDateTime.hour}'}:${localDateTime.minute >= 10 ? localDateTime.minute : "0${localDateTime.minute}"}";

    return [formattedDate, formattedTime];
  }

  static String formatLastUpdateTime(int millisecondsSinceEpoch) {
    DateTime dateTime =
        DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);
    DateTime now = DateTime.now();

    DateFormat timeFormat = DateFormat('HH:mm');
    DateFormat fullFormat = DateFormat('yy.M.d HH:mm');
    DateFormat dateFormat = DateFormat('M.d HH:mm');

    // 오늘 날짜인지 확인
    if (dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day) {
      return timeFormat.format(dateTime);
    }

    // 같은 연도인지 확인
    if (dateTime.year == now.year) {
      return dateFormat.format(dateTime);
    }

    // 기본 포맷
    return fullFormat.format(dateTime);
  }

  static bool isToday(int millisecondsSinceEpoch) {
    var dateTime = DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch);

    var now = DateTime.now();
    var today = DateTime(now.year, now.month, now.day);
    var dateToCheck = DateTime(dateTime.year, dateTime.month, dateTime.day);

    return today == dateToCheck;
  }
}
