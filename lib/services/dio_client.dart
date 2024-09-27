import 'dart:io';

import 'package:dio/dio.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/constants/endpoints.dart';
import 'package:coconut_wallet/model/request/faucet_request.dart';
import 'package:coconut_wallet/model/response/default_error_response.dart';
import 'package:coconut_wallet/model/response/faucet_response.dart';
import 'package:coconut_wallet/model/response/faucet_status_response.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/model/response/app_version_response.dart';

class DioClient {
  DioClient()
      : _dio = Dio(
          BaseOptions(
            baseUrl: PowWalletApp.kFaucetHost,
            connectTimeout:
                const Duration(milliseconds: Endpoints.connectionTimeout),
            receiveTimeout:
                const Duration(milliseconds: Endpoints.receiveTimeout),
            responseType: ResponseType.json,
            validateStatus: (status) {
              return status != null && (status < 400 || status == 429);
            },
          ),
        )..interceptors.add(CustomLogInterceptor());

  final Dio _dio;

  Future<dynamic> sendFaucetRequest(FaucetRequest requestBody) async {
    try {
      final response =
          await _dio.post('/faucet/request', data: requestBody.toJson());
      if (response.statusCode == 200 || response.statusCode == 201) {
        return FaucetResponse.fromJson(response.data);
      } else if (response.statusCode == 429) {
        Logger.log('Too many requests');
        return DefaultErrorResponse.fromJson(response.data);
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        Logger.log('Too many requests');
        return DefaultErrorResponse.fromJson(e.response?.data);
      }
    } catch (e) {
      Logger.log("[ERROR] : $e");
      throw e.toString();
    }
  }

  Future<dynamic> getFaucetStatus() async {
    try {
      final response = await _dio.get('/faucet/status');
      return FaucetStatusResponse.fromJson(response.data);
    } catch (e) {
      Logger.log("[ERROR] : $e");
      throw e.toString();
    }
  }

  Future<dynamic> getLatestAppVersion() async {
    try {
      String apiUrl = '';
      if (Platform.isAndroid) {
        apiUrl = '/app/latest-version/android';
      } else if (Platform.isIOS) {
        apiUrl = '/app/latest-version/ios';
      }

      final response = await _dio.get(apiUrl);
      return AppVersionResponse.fromString(response.data);
    } catch (e) {
      Logger.log("[ERROR] : $e");
      throw e.toString();
    }
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
    Logger.log(
        "Error [${err.response?.statusCode}] => MESSAGE: ${err.message}");
    super.onError(err, handler);
  }
}
