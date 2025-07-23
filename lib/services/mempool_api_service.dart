import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/services/base_api_service.dart';
import 'package:dio/dio.dart';

class MempoolApiService extends BaseApiService {
  String _baseUrl = CoconutWalletApp.kMempoolHost;

  @override
  String get baseUrl => _baseUrl;

  set baseUrl(String value) {
    _baseUrl = value;
  }

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

  Uri getBlockUrl(int blockHeight) {
    return Uri.parse("$baseUrl/block/$blockHeight");
  }

  Uri getTxUrl(String transactionHash) {
    return Uri.parse("$baseUrl/tx/$transactionHash");
  }

  Uri getAddressUrl(String address) {
    return Uri.parse("$baseUrl/address/$address");
  }
}
