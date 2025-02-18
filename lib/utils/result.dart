import 'package:coconut_wallet/model/error/app_error.dart';

class Result<T> {
  final T? _value;
  final AppError? _error;

  Result._({T? value, AppError? error})
      : _value = value,
        _error = error;

  factory Result.success(T value) {
    return Result._(value: value);
  }

  factory Result.failure(AppError error) {
    return Result<T>._(error: error);
  }

  bool get isSuccess => _value != null;
  bool get isFailure => _error != null;

  T get value {
    if (_value == null) {
      throw StateError('Cannot get value from failure result');
    }
    return _value;
  }

  AppError get error {
    if (_error == null) {
      throw StateError('Cannot get error from success result');
    }
    return _error;
  }

  R fold<R>(
      R Function(T value) onSuccess, R Function(AppError error) onFailure) {
    return isSuccess ? onSuccess(value) : onFailure(error);
  }

  Result<R> map<R>(R Function(T value) transform) {
    return isSuccess ? Result.success(transform(value)) : Result.failure(error);
  }
}
