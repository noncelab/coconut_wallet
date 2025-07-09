import 'package:coconut_wallet/utils/logger.dart';
import 'package:dio/dio.dart';

class SpeedAppLnInvoiceService {
  final _dio = Dio();

  Future<String> getLnInvoiceOfPow(int sats) async {
    try {
      final speedAppResponse = await _dio.get('https://speed.app/.well-known/lnurlp/powbitcoiner');
      if (speedAppResponse.data['callback'] == null) {
        throw Exception("callback is null");
      }

      int millisats = sats * 1000;
      final lnInvoiceResponse =
          await _dio.get("${speedAppResponse.data['callback']}?amount=$millisats");
      if (lnInvoiceResponse.data['status'] == "ERROR") {
        throw Exception(lnInvoiceResponse.data['reason'] ?? "status is ERROR");
      } else if (lnInvoiceResponse.data['pr'] == null) {
        throw Exception("pr is null");
      }

      return lnInvoiceResponse.data['pr'];
    } catch (e) {
      Logger.log("[ERROR] : $e");
      rethrow;
    }
  }
}
