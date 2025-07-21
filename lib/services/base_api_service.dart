import 'package:dio/dio.dart';
import 'package:coconut_wallet/constants/network_constants.dart';
import 'package:coconut_wallet/services/model/error/default_error_response.dart';
import 'package:coconut_wallet/utils/logger.dart';

/// API 서비스들의 공통 기능을 제공하는 추상 베이스 클래스
abstract class BaseApiService {
  late final Dio _dio;

  String get baseUrl;

  BaseApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: kHttpConnectionTimeout,
        receiveTimeout: kHttpReceiveTimeout,
        responseType: ResponseType.json,
        validateStatus: (status) {
          return status != null && (status < 400 || status == 429);
        },
      ),
    )..interceptors.add(CustomLogInterceptor());
  }

  Dio get dio => _dio;

  /// 공통 에러 핸들링 래퍼 메서드
  Future<T> handleApiCall<T>(
    Future<T> Function() apiCall, {
    String? operationName,
  }) async {
    try {
      return await apiCall();
    } on DioException catch (e) {
      return _handleDioException(e, operationName);
    } catch (e) {
      return _handleGenericException(e, operationName);
    }
  }

  /// DioException 전용 핸들러
  T _handleDioException<T>(DioException e, String? operationName) {
    final operation = operationName ?? 'API call';

    if (e.response?.statusCode == 429) {
      Logger.log('Too many requests for $operation');
      throw DefaultErrorResponse.fromJson(e.response?.data ?? {'error': 'TOO_MANY_REQUESTS'});
    }

    Logger.error("[$operation] DioException: ${e.message}");
    Logger.error("[$operation] Response data: ${e.response?.data}");

    if (e.response?.data != null) {
      throw Exception('Network error during $operation: ${e.response?.data}');
    }

    throw Exception('Network error during $operation: ${e.message}');
  }

  /// 일반 Exception 전용 핸들러
  T _handleGenericException<T>(dynamic e, String? operationName) {
    final operation = operationName ?? 'API call';
    Logger.error("[$operation] Unexpected error: $e");
    throw Exception('Unexpected error during $operation: ${e.toString()}');
  }
}

/// HTTP 요청/응답 로깅을 위한 공통 인터셉터
class CustomLogInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    Logger.log("Request [${options.method}] => PATH: ${options.path}");
    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    Logger.log("Response [${response.statusCode}] => DATA: ${response.data}");
    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    Logger.log("Error [${err.response?.statusCode}] => MESSAGE: ${err.message}");
    super.onError(err, handler);
  }
}
