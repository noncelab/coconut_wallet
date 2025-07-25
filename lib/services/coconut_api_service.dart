import 'dart:io';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/services/model/request/faucet_request.dart';
import 'package:coconut_wallet/services/model/error/default_error_response.dart';
import 'package:coconut_wallet/services/model/response/faucet_response.dart';
import 'package:coconut_wallet/services/model/response/faucet_status_response.dart';
import 'package:coconut_wallet/services/model/response/app_version_response.dart';
import 'package:coconut_wallet/services/base_api_service.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:flutter/foundation.dart';

class CoconutApiService extends BaseApiService {
  @override
  String get baseUrl => CoconutWalletApp.kCoconutApiHost;

  Future<FaucetResponse> sendFaucetRequest(FaucetRequest requestBody) async {
    _checkRegtestNetwork();

    return handleApiCall(
      () async {
        final response = await dio.post('/faucet/request', data: requestBody.toJson());

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
    _checkRegtestNetwork();

    return handleApiCall(
      () async {
        final response = await dio.get('/faucet/status');
        return FaucetStatusResponse.fromJson(response.data);
      },
      operationName: 'Faucet status',
    );
  }

  Future<AppVersionResponse> getLatestAppVersion() async {
    return handleApiCall(
      () async {
        String apiUrl = '';
        if (Platform.isAndroid) {
          apiUrl = '/app/latest-version/android';
        } else if (Platform.isIOS) {
          apiUrl = '/app/latest-version/ios';
        } else {
          throw Exception('Unsupported platform for app version check');
        }

        final response = await dio.get(apiUrl);
        return AppVersionResponse.fromString(response.data);
      },
      operationName: 'App version check',
    );
  }

  /// Regtest 테스트용 추천 수수료 조회
  ///
  /// Regtest 환경에서는 mempool 이 여유로워서 수수료율이 항상 1로 반환됨.
  /// 따라서 Rbf, Cpfp 등 추천 수수료율 조회할 때 임의로 서버에서 지정하고 이 값을 사용하도록 하기 위한 함수
  /// 실제로 사용할 경우에는 [NodeProvider.getRecommendedFees] 를 사용해야 함.
  @visibleForTesting
  Future<RecommendedFee> getRecommendedFee() async {
    return handleApiCall(
      () async {
        final response = await dio.get('/mocking/recommended-fee');
        return RecommendedFee.fromJson(response.data);
      },
      operationName: 'Recommended fee',
    );
  }

  void _checkRegtestNetwork() {
    if (NetworkType.currentNetworkType != NetworkType.regtest) {
      throw Exception('Faucet is not available on this network');
    }
  }
}
