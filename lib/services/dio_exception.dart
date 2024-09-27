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

  String _handleStatusCode(int? statusCode) {
    switch (statusCode) {
      case 400:
        return '[400](잘못된 요청)Bad request.';
      case 401:
        return '[401](인증 실패)Authentication failed.';
      case 403:
        return '[403]The authenticated user is not allowed to access the specified API endpoint.';
      case 404:
        return '[404]The requested resource does not exist.';
      case 405:
        return '[405]Method not allowed. Please check the Allow header for the allowed HTTP methods.';
      case 415:
        return '[415]Unsupported media type. The requested content type or version number is invalid.';
      case 422:
        return '[422]Data validation failed.';
      case 429:
        return '[429]Too many requests.';
      case 500:
        return '[500]Internal server error.';
      default:
        return 'Oops something went wrong!';
    }
  }

  @override
  String toString() => errorMessage;
}
