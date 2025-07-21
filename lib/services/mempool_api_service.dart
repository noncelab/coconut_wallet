import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/services/base_api_service.dart';

class MempoolApiService extends BaseApiService {
  @override
  String get baseUrl => CoconutWalletApp.kMempoolHost;

  Future<void> broadcastTransaction(String txHex) async {
    return handleApiCall(
      () async {
        final response = await dio.post('/api/tx', data: txHex);
        return response.data;
      },
      operationName: 'Broadcast transaction',
    );
  }
}
