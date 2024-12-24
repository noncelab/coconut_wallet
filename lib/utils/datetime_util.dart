import 'package:intl/intl.dart';

class DateTimeUtil {
  // ex) "2024-04-12 18:19:26.000" => List<String> ["24.04.12", "18:19"]
  static List<String> formatTimeStamp(DateTime dateTime) {
    String formattedDate =
        "${dateTime.year % 100}.${dateTime.month >= 10 ? dateTime.month : "0${dateTime.month}"}."
        "${dateTime.day >= 10 ? dateTime.day : "0${dateTime.day}"}";
    String formattedTime =
        "${dateTime.hour >= 10 ? dateTime.hour : '0${dateTime.hour}'}:${dateTime.minute >= 10 ? dateTime.minute : "0${dateTime.minute}"}";

    return [formattedDate, formattedTime];
  }

  static String formatDatetime(String timestamp) {
    var dateTime =
        DateTime.fromMillisecondsSinceEpoch(int.parse(timestamp) * 1000);
    //var kstDateTime = dateTime.add(const Duration(hours: 9)); // UTC+9 for KST
    var formattedDate = DateFormat('yy.MM.dd | HH:mm').format(dateTime);
    return formattedDate;
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
