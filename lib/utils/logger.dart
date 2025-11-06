import 'package:flutter/foundation.dart';
import 'dart:io';

class Logger {
  static const bool _isReleaseMode = kReleaseMode;

  static void info(Object? message) => _log('INFO', message);
  static void warning(Object? message) => _log('WARN', message);
  static void error(Object? message) => _log('ERROR', message);
  static void success(Object? message) => _log('SUCCESS', message);
  static void performance(Object? message) => _log('PERF', message);
  static void network(Object? message) => _log('NETWORK', message);
  static void database(Object? message) => _log('DATABASE', message);
  static void log(Object? message) => _log('LOG', message);

  static void _log(String level, Object? message) {
    if (_isReleaseMode) return;

    final timestamp = _getTimestamp();
    final caller = _getCallerTag(); // [파일명:라인]
    final logMsg = '[$timestamp] [$level] [$caller] $message';

    // 터미널 색상 적용 (원하면 ANSI 코드 유지 가능)
    if (_isRunningInTerminal()) {
      final color = _getColorForLevel(level);
      // ignore: avoid_print
      print('$color$logMsg\x1B[0m');
    } else {
      // ignore: avoid_print
      print(logMsg);
    }
  }

  static String _getTimestamp() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final h = now.hour.toString().padLeft(2, '0');
    final min = now.minute.toString().padLeft(2, '0');
    final s = now.second.toString().padLeft(2, '0');
    final ms = now.millisecond.toString().padLeft(3, '0');
    return '$y-$m-$d $h:$min:$s.$ms';
  }

  static String _getCallerTag() {
    try {
      final stackTrace = StackTrace.current.toString().split('\n');
      for (final frame in stackTrace) {
        if (frame.contains('Logger.') || frame.contains('_log')) continue;
        final match = RegExp(r'([^/\\]+)\.dart:(\d+)').firstMatch(frame);
        if (match != null) {
          final fileName = match.group(1) ?? 'unknown';
          return '$fileName:${match.group(2)}';
        }
      }
    } catch (_) {}
    return 'unknown';
  }

  static String _getColorForLevel(String level) {
    switch (level) {
      case 'ERROR':
        return '\x1B[31m';
      case 'WARN':
        return '\x1B[33m';
      case 'SUCCESS':
        return '\x1B[32m';
      case 'PERF':
      case 'NETWORK':
        return '\x1B[36m';
      default:
        return '\x1B[37m';
    }
  }

  static bool _isRunningInTerminal() {
    try {
      return stdout.hasTerminal;
    } catch (e) {
      return false;
    }
  }

  static void logLongString(String str, {String level = 'LOG'}) {
    if (!_isReleaseMode) {
      const chunkSize = 800;
      final timestamp = _getTimestamp();
      final caller = _getCallerTag();

      for (int i = 0; i < str.length; i += chunkSize) {
        final endIndex = i + chunkSize > str.length ? str.length : i + chunkSize;
        String chunk = str.substring(i, endIndex);

        if (endIndex < str.length) {
          final lastNewlineIndex = chunk.lastIndexOf('\n');
          if (lastNewlineIndex != -1 && lastNewlineIndex > chunk.length - 50) {
            chunk = chunk.substring(0, lastNewlineIndex + 1);
            i = i + lastNewlineIndex + 1 - chunkSize;
          }
        }
        final logMsg = '[$timestamp] [$level] [$caller] $chunk';
        if (kDebugMode && !_isRunningInTerminal()) {
          // ignore: avoid_print
          print(logMsg);
        } else {
          final color = _getColorForLevel(level);
          // ignore: avoid_print
          print('$color$logMsg\x1B[0m');
        }
      }
    }
  }

  static void logMapRecursive(Map<dynamic, dynamic> map, {int indent = 0}) {
    if (_isReleaseMode) return;

    final spaces = ' ' * indent;
    map.forEach((key, value) {
      if (value is Map) {
        print('$spaces$key:');
        logMapRecursive(value, indent: indent + 2);
      } else {
        print('$spaces$key: $value');
      }
    });
  }
}
