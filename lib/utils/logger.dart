import 'package:flutter/foundation.dart';

class Logger {
  static const bool _isReleaseMode = kReleaseMode;

  static void log(Object? object) {
    if (!_isReleaseMode) {
      // ignore: avoid_print
      print(object);
    }
  }

  static void error(Object? object) {
    if (!_isReleaseMode) {
      print('\n************error************\n');
      print(object);
      print('\n************error************\n');
    }
  }
}
