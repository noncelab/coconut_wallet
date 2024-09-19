import 'package:coconut_wallet/services/dio_client.dart';

class AppVersionRepository {
  final DioClient _dio = DioClient();

  // 앱 최신버전 가져오기
  Future<dynamic> getLatestAppVersion() async {
    return await _dio.getLatestAppVersion();
  }
}
