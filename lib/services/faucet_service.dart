import 'package:coconut_wallet/services/model/request/faucet_request.dart';
import 'package:coconut_wallet/services/dio_client.dart';

class Faucet {
  final DioClient _dio = DioClient();

  // Faucet 요청하기
  Future<dynamic> getTestCoin(FaucetRequest requestBody) async {
    return await _dio.sendFaucetRequest(requestBody);
  }

  // Faucet 상태 불러오기
  Future<dynamic> getStatus() async {
    return await _dio.getFaucetStatus();
  }
}
