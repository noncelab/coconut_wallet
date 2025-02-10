import 'stream_state.dart';

abstract class BaseStreamState<T> {
  final DateTime timestamp;
  final String methodName;
  final T? data;
  final bool hasError;
  final String? errorMessage;
  final StackTrace? stackTrace;

  const BaseStreamState({
    required this.timestamp,
    required this.methodName,
    this.data,
    this.hasError = false,
    this.errorMessage,
    this.stackTrace,
  });

  factory BaseStreamState.success(String methodName, T data) {
    return SuccessState(
      timestamp: DateTime.now(),
      methodName: methodName,
      data: data,
    );
  }

  factory BaseStreamState.error(
    String methodName,
    String errorMessage, [
    StackTrace? stackTrace,
  ]) {
    return ErrorState(
      timestamp: DateTime.now(),
      methodName: methodName,
      errorMessage: errorMessage,
      stackTrace: stackTrace,
    );
  }
}
