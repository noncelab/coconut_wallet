import 'dart:convert';

import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/services/network/dto/mempool_response_type.dart';
import 'package:http/http.dart';

class RecommendFeeService {
  static Future<RecommendedFee> getRecommendFee() async {
    String urlString =
        '${CoconutWalletApp.kMempoolHost}/api/v1/fees/recommended';
    final url = Uri.parse(urlString);
    final response = await get(url);

    Map<String, dynamic> jsonMap = jsonDecode(response.body);

    return RecommendedFee.fromJson(jsonMap);
  }
}
