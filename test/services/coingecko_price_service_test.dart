import 'dart:async';

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/services/coingecko_price_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const fiats = [FiatCode.AED, FiatCode.CHF];

  CoinGeckoPriceService serviceWith(_FakeDio dio) => CoinGeckoPriceService(dio: dio, fiats: fiats);

  testWidgets('requests every target currency in one call and emits only the prices that came back', (tester) async {
    final dio = _FakeDio((_) => _ok({'chf': 67120.9}));
    final service = serviceWith(dio);
    final emitted = <Map<FiatCode, int>>[];
    service.priceStream.listen(emitted.add);

    service.start();
    await tester.pump();

    expect(dio.queries.single!['vs_currencies'], 'aed,chf');
    expect(emitted, [
      {FiatCode.CHF: 67120},
    ]);
    service.dispose();
  });

  testWidgets('backs off after failures and returns to the normal interval after a success', (tester) async {
    final results = [false, false, true, true];
    final dio = _FakeDio((call) => call <= results.length && results[call - 1] ? _ok({'aed': 1}) : _error());
    final service = serviceWith(dio);

    service.start();
    await tester.pump();
    expect(dio.requestCount, equals(1));

    await tester.pump(const Duration(seconds: 119));
    expect(dio.requestCount, equals(1), reason: 'first failure doubles the interval to 120s');
    await tester.pump(const Duration(seconds: 1));
    expect(dio.requestCount, equals(2));

    await tester.pump(const Duration(seconds: 239));
    expect(dio.requestCount, equals(2), reason: 'second failure doubles it again to 240s');
    await tester.pump(const Duration(seconds: 1));
    expect(dio.requestCount, equals(3));

    await tester.pump(const Duration(seconds: 60));
    expect(dio.requestCount, equals(4), reason: 'a success resets the interval to 60s');
    service.dispose();
  });

  testWidgets('caps the backoff at 10 minutes', (tester) async {
    final dio = _FakeDio((_) => _error());
    final service = serviceWith(dio);

    service.start();
    await tester.pump(const Duration(minutes: 60));
    final countAfterAnHour = dio.requestCount;
    await tester.pump(const Duration(minutes: 10));

    expect(dio.requestCount, countAfterAnHour + 1);
    service.dispose();
  });

  testWidgets('ignores a response that arrives after dispose and schedules nothing more', (tester) async {
    final pending = Completer<Response<dynamic>>();
    final dio = _FakeDio((_) => pending.future);
    final service = serviceWith(dio);
    final emitted = <Map<FiatCode, int>>[];
    service.priceStream.listen(emitted.add);

    service.start();
    await tester.pump();
    service.dispose();
    pending.complete(_response({'aed': 1, 'chf': 2}));
    await tester.pump(const Duration(minutes: 30));

    expect(emitted, isEmpty);
    expect(dio.requestCount, equals(1));
    expect(service.isRunning, isFalse);
  });
}

class _FakeDio extends Fake implements Dio {
  _FakeDio(this._respond);

  final Future<Response<dynamic>> Function(int call) _respond;
  final List<Map<String, dynamic>?> queries = [];

  int get requestCount => queries.length;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    queries.add(queryParameters);
    final response = await _respond(queries.length);
    return Response<T>(requestOptions: response.requestOptions, data: response.data as T, statusCode: 200);
  }
}

Response<dynamic> _response(Map<String, num> prices) =>
    Response(requestOptions: RequestOptions(), data: {'bitcoin': prices}, statusCode: 200);

Future<Response<dynamic>> _ok(Map<String, num> prices) async => _response(prices);

Future<Response<dynamic>> _error() async =>
    throw DioException.badResponse(
      statusCode: 429,
      requestOptions: RequestOptions(),
      response: Response(requestOptions: RequestOptions(), statusCode: 429),
    );
