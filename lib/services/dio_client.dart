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
import 'package:coconut_wallet/services/model/response/electrum_domains_response.dart';

class DioClient {
  DioClient._internal()
      : _dio = Dio(
          BaseOptions(
            baseUrl: CoconutWalletApp.kApiHost,
            connectTimeout: kHttpConnectionTimeout,
            receiveTimeout: kHttpReceiveTimeout,
            responseType: ResponseType.json,
            validateStatus: (status) {
              return status != null && (status < 400 || status == 429);
            },
          ),
        )..interceptors.add(CustomLogInterceptor());

  static final DioClient _instance = DioClient._internal();

  factory DioClient() {
    return _instance;
  }

  final Dio _dio;

  Future<dynamic> sendFaucetRequest(FaucetRequest requestBody) async {
    assert(NetworkType.currentNetworkType.isTestnet);

    try {
      final response = await _dio.post('v1/faucet/request', data: requestBody.toJson());
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

  Future<FaucetStatusResponse> getFaucetStatus() async {
    assert(NetworkType.currentNetworkType.isTestnet);

    final response = await _dio.get('v1/faucet/status');
    return FaucetStatusResponse.fromJson(response.data);
  }

  Future<dynamic> getLatestAppVersion() async {
    try {
      String apiUrl = '';
      if (Platform.isAndroid) {
        apiUrl = 'v1/app/latest-version/android';
      } else if (Platform.isIOS) {
        apiUrl = 'v1/app/latest-version/ios';
      }

      final response = await _dio.get(apiUrl);
      return AppVersionResponse.fromString(response.data);
    } catch (e) {
      Logger.log("[ERROR] : $e");
      throw e.toString();
    }
  }

  Future<RecommendedFee> getRecommendedFee() async {
    final response = await _dio.get('v1/mocking/recommended-fee');
    return RecommendedFee.fromJson(response.data);
  }

  /// 추천 Electrum 서버를 조회합니다.
  Future<ElectrumDomain> getRecommendedElectrumDomain() async {
    assert(!NetworkType.currentNetworkType.isTestnet);

    final response = await _dio.get('v1/electrum/public-domains/recommend');
    return ElectrumDomain.fromJson(response.data);
  }

  /// 전체 Electrum 서버 목록을 조회합니다.
  Future<ElectrumDomainsResponse> getElectrumDomains() async {
    assert(!NetworkType.currentNetworkType.isTestnet);

    final response = await _dio.get('v1/electrum/public-domains');
    return ElectrumDomainsResponse.fromJson(response.data as List);
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
