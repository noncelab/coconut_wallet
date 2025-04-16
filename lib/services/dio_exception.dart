import 'package:dio/dio.dart';

class DioException implements Exception {
  late String errorMessage;

  DioException.fromDioError(DioExceptionType dioError) {
    switch (dioError) {
      case DioExceptionType.cancel:
        errorMessage = '(요청취소)Request to the server was cancelled.';
        break;
      case DioExceptionType.connectionTimeout:
        errorMessage = '(연결시간초과)Connection timed out.';
        break;
      case DioExceptionType.receiveTimeout:
        errorMessage = '(수신시간초과)Receiving timeout occurred.';
        break;
      case DioExceptionType.sendTimeout:
        errorMessage = '(요청시간초과)Request send timeout.';
        break;
      case DioExceptionType.badResponse:
        errorMessage = dioError.name;
        break;
      case DioExceptionType.unknown:
        errorMessage = 'Unexpected error occurred.';
        break;
      default:
        errorMessage = 'Something went wrong';
        break;
    }
  }

  @override
  String toString() => errorMessage;
}
