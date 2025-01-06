import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app.dart';
import 'package:http/http.dart';

class RecommendFeeRepository {
  static Future<RecommendedFee> getRecommendFee() async {
    String urlString = '${PowWalletApp.kMempoolHost}/api/v1/fees/recommended';
    final url = Uri.parse(urlString);
    final response = await get(url);

    Map<String, dynamic> jsonMap = jsonDecode(response.body);

    return RecommendedFee.fromJson(jsonMap);
  }
}
