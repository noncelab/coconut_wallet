import 'generated/bark.dart';

/// A [BarkLogger] that forwards records to [print].
///
/// Useful as a default during development. For production, implement
/// [BarkLogger] yourself to forward to `package:logging`, Sentry, etc.
class BarkPrintLogger extends BarkLogger {
  @override
  void log(LogLevel level, String target, String message) {
    print('[bark][${level.name}][$target] $message');
  }
}

/// Install a default [BarkPrintLogger].
///
/// The underlying logger bridge can only be installed once per process;
/// calling this more than once throws the [BarkException] returned by
/// [setLogger].
BarkLogger barkAttachPrintLogger({LogLevel maxLevel = LogLevel.info}) {
  final logger = BarkPrintLogger();
  setLogger(logger: logger, maxLevel: maxLevel);
  return logger;
}
