class Result<T, E> {
  final T? _value;
  final E? _error;

  Result._({T? value, E? error})
      : _value = value,
        _error = error;

  factory Result.success(T value) {
    return Result._(value: value);
  }

  factory Result.failure(E error) {
    return Result._(error: error);
  }

  bool get isSuccess => _value != null;
  bool get isFailure => _error != null;

  T get value {
    if (_value == null) {
      throw StateError('Cannot get value from failure result');
    }
    return _value;
  }

  E get error {
    if (_error == null) {
      throw StateError('Cannot get error from success result');
    }
    return _error;
  }

  R fold<R>(R Function(T value) onSuccess, R Function(E error) onFailure) {
    return isSuccess ? onSuccess(value) : onFailure(error);
  }

  Result<R, E> map<R>(R Function(T value) transform) {
    return isSuccess ? Result.success(transform(value)) : Result.failure(error);
  }
}
