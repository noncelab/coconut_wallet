import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class FileLogger {
  static File? _logFile;
  static const String _fileName = 'debug_log.txt';
  static final Queue<String> _logQueue = Queue<String>();
  static bool _isWriting = false;
  static Timer? _flushTimer;

  static Future<void> initialize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logFile = File('${directory.path}/$_fileName');

      // 새 로그 파일 생성
      await _logFile!.writeAsString('=== Debug Log Started: ${_getSimpleTimestamp()} ===\n');

      // 주기적으로 큐를 플러시하는 타이머 시작
      _flushTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        _flushQueue();
      });
    } catch (e) {
      // ignore: avoid_print
      print('FileLogger initialization failed: $e');
    }
  }

  static String _getSimpleTimestamp() {
    final now = DateTime.now();
    final year = now.year.toString().substring(2); // 2025 -> 25
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    final millisecond = (now.millisecond ~/ 10).toString().padLeft(2, '0'); // 3자리 -> 2자리

    return '$year-$month-${day}T$hour:$minute:$second.$millisecond';
  }

  static Future<void> log(String className, String methodName, [String? message]) async {
    final timestamp = _getSimpleTimestamp();
    final logEntry =
        message != null ? '[$timestamp] $className.$methodName: $message' : '[$timestamp] $className.$methodName';

    _logQueue.add(logEntry);
    _flushQueue();
  }

  static Future<void> error(String className, String methodName, String error, [StackTrace? stackTrace]) async {
    final timestamp = _getSimpleTimestamp();
    final logEntry = '[$timestamp] ERROR $className.$methodName: $error';

    _logQueue.add(logEntry);

    if (stackTrace != null) {
      final stackEntry = '[$timestamp] STACK $className.$methodName: $stackTrace';
      _logQueue.add(stackEntry);
    }

    _flushQueue();
  }

  static Future<void> _flushQueue() async {
    if (_isWriting || _logQueue.isEmpty || _logFile == null) {
      return;
    }

    _isWriting = true;
    final entries = <String>[];

    try {
      while (_logQueue.isNotEmpty) {
        entries.add(_logQueue.removeFirst());
      }

      if (entries.isNotEmpty) {
        final logContent = entries.join('\n') + '\n';
        await _logFile!.writeAsString(logContent, mode: FileMode.append);
      }
    } catch (e) {
      // ignore: avoid_print
      print('FileLogger._flushQueue failed: $e');
      // 실패한 로그들을 다시 큐에 추가
      for (final entry in entries) {
        _logQueue.addFirst(entry);
      }
    } finally {
      _isWriting = false;
    }
  }

  static Future<String?> getLogContent() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        // 플러시 타이머를 일시 중지하고 큐를 비움
        await _flushQueue();
        final content = await _logFile!.readAsString();
        Logger.log('FileLogger.getLogContent: content length = ${content.length}');
        return content;
      }
    } catch (e) {
      Logger.error('FileLogger.getLogContent failed: $e');
    }
    return null;
  }

  static Future<void> shareLog() async {
    try {
      if (_logFile != null && await _logFile!.exists()) {
        final logContent = await _logFile!.readAsString();

        await Share.share(logContent, subject: 'Coconut Wallet Debug Log - ${_getSimpleTimestamp()}');
      }
    } catch (e) {
      Logger.error('Log sharing failed: $e');
    }
  }

  static Future<void> clearLog() async {
    try {
      // 큐를 비우고 플러시
      _logQueue.clear();
      await _flushQueue();

      if (_logFile != null) {
        await _logFile!.writeAsString('=== Debug Log Cleared: ${_getSimpleTimestamp()} ===\n');
      }
    } catch (e) {
      Logger.error('FileLogger.clearLog failed: $e');
    }
  }

  static Future<void> dispose() async {
    try {
      _flushTimer?.cancel();
      await _flushQueue();
    } catch (e) {
      Logger.error('FileLogger.dispose failed: $e');
    }
  }
}
