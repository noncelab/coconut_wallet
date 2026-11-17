// - 10분 상한에서 다시 시작이 끼어도 직전 실패 뒤 10분에 다시 묻는지(서비스, 실제 PriceProvider)
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/services/coingecko_price_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../providers/price_provider_test.dart' show OwnedSocket, ScriptedConnectivity, ScriptedPreference, SocketBook;

class _FailingDio extends Fake implements Dio {
  int requestCount = 0;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    requestCount++;
    throw DioException.badResponse(
      statusCode: 429,
      requestOptions: RequestOptions(),
      response: Response(requestOptions: RequestOptions(), statusCode: 429),
    );
  }
}

/// 다음 요청이 나갈 때까지 1초씩 흘리고, 흘린 초를 돌려준다.
Future<int> _secondsUntilNextRequest(WidgetTester tester, _FailingDio dio, {int limit = 1500}) async {
  final before = dio.requestCount;
  var seconds = 0;
  while (dio.requestCount == before && seconds < limit) {
    await tester.pump(const Duration(seconds: 1));
    seconds++;
  }
  return seconds;
}

void main() {
  setUp(OwnedSocket.reset);

  testWidgets('a restart during the 10-minute backoff still retries 10 minutes after the last failure', (tester) async {
    final dio = _FailingDio();
    final service = CoinGeckoPriceService(dio: dio, fiats: const [FiatCode.THB]);

    service.start();
    await tester.pump();
    await tester.pump(const Duration(minutes: 60));
    await _secondsUntilNextRequest(tester, dio); // T0: 방금 실패, 다음 요청은 600초 뒤

    await tester.pump(const Duration(seconds: 590));
    service.stop();
    service.start();
    final afterRestart = await _secondsUntilNextRequest(tester, dio);
    service.dispose();

    expect(590 + afterRestart, 600);
  });

  testWidgets('pausing and resuming the app during the backoff does not push the retry back', (tester) async {
    final dio = _FailingDio();
    final connectivity = ScriptedConnectivity(online: true);
    final preference = ScriptedPreference(FiatCode.THB);
    final prices = PriceProvider(
      connectivity,
      preference,
      webSocketFactory: SocketBook().create,
      coinGeckoFactory: () => CoinGeckoPriceService(dio: dio),
    );

    await tester.pump();
    await tester.pump(const Duration(minutes: 60));
    await _secondsUntilNextRequest(tester, dio); // T0

    await tester.pump(const Duration(seconds: 590));
    prices.pausePriceSources();
    await tester.pump(const Duration(seconds: 5));
    prices.resumePriceSources(force: true);
    final afterResume = await _secondsUntilNextRequest(tester, dio);

    prices.dispose();
    connectivity.dispose();
    preference.dispose();
    await tester.pump();

    expect(595 + afterResume, 600);
  });

  testWidgets('a stop during the backoff sends nothing when the wait ends', (tester) async {
    final dio = _FailingDio();
    final service = CoinGeckoPriceService(dio: dio, fiats: const [FiatCode.THB]);

    service.start();
    await tester.pump();
    service.stop();
    await tester.pump(const Duration(minutes: 30));

    expect(dio.requestCount, 1);
    service.dispose();
  });
}
