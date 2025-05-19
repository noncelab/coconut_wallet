import 'package:flutter/services.dart';

void setSystemBarColor(Color barColor) {
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: barColor, //상단바 색상
      statusBarIconBrightness: Brightness.light, //상단바 아이콘 색상
      systemNavigationBarDividerColor: barColor, //하단바 디바이더 색상
      systemNavigationBarColor: barColor, //하단바 색상
      systemNavigationBarIconBrightness: Brightness.light, //하단바 아이콘 색상
    ),
  );
}
