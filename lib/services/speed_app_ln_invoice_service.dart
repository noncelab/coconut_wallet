import 'package:coconut_wallet/utils/logger.dart';
import 'package:dio/dio.dart';

class SpeedAppLnInvoiceService {
  final _dio = Dio();

  Future<dynamic> getLnInvoiceOfPow(int amount) async {
    try {
      final speedAppResponse = await _dio.get('https://speed.app/.well-known/lnurlp/powbitcoiner');
      final lnInvoiceResponse =
          await _dio.get("${speedAppResponse.data['callback']}?amount=$amount");
      if (lnInvoiceResponse.data['status'] == "ERROR") {
        throw Exception(lnInvoiceResponse.data['reason']);
      }

      return lnInvoiceResponse.data['pr'];
    } catch (e) {
      Logger.log("[ERROR] : $e");
      throw Exception(e);
    }
  }
}
