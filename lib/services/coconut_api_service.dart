import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:dio/dio.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/constants/network_constants.dart';
import 'package:coconut_wallet/services/model/request/faucet_request.dart';
import 'package:coconut_wallet/services/model/error/default_error_response.dart';
import 'package:coconut_wallet/services/model/response/faucet_response.dart';
import 'package:coconut_wallet/services/model/response/faucet_status_response.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/services/model/response/app_version_response.dart';

class CoconutApiService {
  CoconutApiService()
      : _dio = Dio(
          BaseOptions(
            baseUrl: CoconutWalletApp.kFaucetHost,
            connectTimeout: kHttpConnectionTimeout,
            receiveTimeout: kHttpReceiveTimeout,
            responseType: ResponseType.json,
            validateStatus: (status) {
              return status != null && (status < 400 || status == 429);
            },
          ),
        )..interceptors.add(CustomLogInterceptor());

  final Dio _dio;

  /// 공통 에러 핸들링 래퍼 메서드
  Future<T> _handleApiCall<T>(
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

    throw Exception('Network error during $operation: ${e.message}');
  }

  /// 일반 Exception 전용 핸들러
  T _handleGenericException<T>(dynamic e, String? operationName) {
    final operation = operationName ?? 'API call';
    Logger.error("[$operation] Unexpected error: $e");
    throw Exception('Unexpected error during $operation: ${e.toString()}');
  }

  Future<FaucetResponse> sendFaucetRequest(FaucetRequest requestBody) async {
    if (NetworkType.currentNetworkType.toString() != 'regtest') {
      throw Exception('Faucet is not available on this network');
    }

    return _handleApiCall(
      () async {
        final response = await _dio.post('/faucet/request', data: requestBody.toJson());

        if (response.statusCode == 200 || response.statusCode == 201) {
          return FaucetResponse.fromJson(response.data);
        } else if (response.statusCode == 429) {
          throw DefaultErrorResponse.fromJson(response.data);
        }

        throw Exception('Unexpected status code: ${response.statusCode}');
      },
      operationName: 'Faucet request',
    );
  }

  Future<FaucetStatusResponse> getFaucetStatus() async {
    return _handleApiCall(
      () async {
        final response = await _dio.get('/faucet/status');
        return FaucetStatusResponse.fromJson(response.data);
      },
      operationName: 'Faucet status',
    );
  }

  Future<AppVersionResponse> getLatestAppVersion() async {
    return _handleApiCall(
      () async {
        String apiUrl = '';
        if (Platform.isAndroid) {
          apiUrl = '/app/latest-version/android';
        } else if (Platform.isIOS) {
          apiUrl = '/app/latest-version/ios';
        } else {
          throw Exception('Unsupported platform for app version check');
        }

        final response = await _dio.get(apiUrl);
        return AppVersionResponse.fromString(response.data);
      },
      operationName: 'App version check',
    );
  }

  Future<RecommendedFee> getRecommendedFee() async {
    return _handleApiCall(
      () async {
        final response = await _dio.get('/mocking/recommended-fee');
        return RecommendedFee.fromJson(response.data);
      },
      operationName: 'Recommended fee',
    );
  }
}

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
