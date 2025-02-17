import 'base_stream_state.dart';

class SuccessState<T> extends BaseStreamState<T> {
  @override
  T get data => super.data!;

  const SuccessState({
    required super.timestamp,
    required super.methodName,
    required super.data,
  }) : super(hasError: false);
}

class ErrorState<T> extends BaseStreamState<T> {
  const ErrorState({
    required super.timestamp,
    required super.methodName,
    required super.errorMessage,
    super.stackTrace,
  }) : super(hasError: true);
}
