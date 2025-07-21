import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/services/base_api_service.dart';
import 'package:dio/dio.dart';

class MempoolApiService extends BaseApiService {
  @override
  String get baseUrl => CoconutWalletApp.kMempoolHost;

  Future<String> broadcastTransaction(String txHex) async {
    return handleApiCall(
      () async {
        final response = await dio.post('/api/tx',
            data: txHex,
            options: Options(
              headers: {
                'Content-Type': 'text/plain',
              },
            ));
        return response.data;
      },
      operationName: 'Broadcast transaction',
    );
  }
}
