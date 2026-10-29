import 'dart:async';

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:dio/dio.dart';

/// CoinGecko 무료 REST API로 거래소 웹소켓이 없는 통화들의 BTC 가격을 폴링한다.
/// 어떤 통화를 쓰는지 드러나지 않도록 대상 통화 전체를 한 요청으로 조회하고 [interval] 간격으로 갱신한다.
class CoinGeckoPriceService {
  static const Duration _interval = Duration(seconds: 60);
  static const Duration _maxBackoff = Duration(minutes: 10);

  final Dio _dio;
  final List<FiatCode> _fiats;

  Timer? _timer;
  Timer? _retryWait;
  Duration _currentInterval = _interval;
  bool _isDisposed = false;
  bool _isFetching = false;
  int _generation = 0;

  final StreamController<Map<FiatCode, int>> _priceController = StreamController.broadcast();
  Stream<Map<FiatCode, int>> get priceStream => _priceController.stream;

  CoinGeckoPriceService({Dio? dio, List<FiatCode>? fiats})
    : _fiats = fiats ?? FiatCode.values.where((fiat) => !fiat.hasExchangeSource).toList(),
      _dio =
          dio ??
          Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)));

  bool get isRunning => _timer != null;

  /// 실패 후 늘어난 간격이 아직 지나지 않았으면 바로 요청하지 않는다.
  bool get _isBackingOff => _retryWait != null;

  void start() {
    if (_isDisposed || _timer != null || _fiats.isEmpty) return;
    if (!_isBackingOff) unawaited(_fetch());
    _schedule(_currentInterval);
  }

  /// 멈춘 뒤 도착하는 응답은 반영하지 않는다.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _generation++;
  }

  void _schedule(Duration interval) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => unawaited(_fetch()));
  }

  Future<void> _fetch() async {
    if (_isDisposed || _isFetching || _fiats.isEmpty) return;
    final generation = _generation;
    _isFetching = true;

    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'https://api.coingecko.com/api/v3/simple/price',
        queryParameters: {'ids': 'bitcoin', 'vs_currencies': _fiats.map((fiat) => fiat.vsCurrency).join(',')},
      );

      final bitcoin = response.data?['bitcoin'];
      if (generation != _generation) return;
      if (bitcoin is Map) {
        final prices = <FiatCode, int>{};
        for (final fiat in _fiats) {
          final price = bitcoin[fiat.vsCurrency];
          if (price is num) prices[fiat] = price.toInt();
        }
        if (prices.isNotEmpty && !_priceController.isClosed) {
          _priceController.add(prices);
        }
        _resetBackoff();
      }
    } on DioException catch (e) {
      if (generation != _generation) return;
      // 429(rate limit) 등 일시적 실패는 백오프 후 다음 주기에 재시도
      Logger.log('CoinGeckoPriceService: 조회 실패 (${e.response?.statusCode ?? e.type})');
      _increaseBackoff();
    } catch (e) {
      if (generation != _generation) return;
      Logger.log('CoinGeckoPriceService: 조회 실패: $e');
      _increaseBackoff();
    } finally {
      _isFetching = false;
    }
  }

  void _increaseBackoff() {
    final next = _currentInterval * 2;
    _currentInterval = next > _maxBackoff ? _maxBackoff : next;
    _retryWait?.cancel();
    _retryWait = Timer(_currentInterval, () => _retryWait = null);
    if (_timer != null) _schedule(_currentInterval);
  }

  void _resetBackoff() {
    _retryWait?.cancel();
    _retryWait = null;
    if (_currentInterval != _interval) {
      _currentInterval = _interval;
      if (_timer != null) _schedule(_currentInterval);
    }
  }

  void dispose() {
    _isDisposed = true;
    stop();
    _retryWait?.cancel();
    _retryWait = null;
    _priceController.close();
  }
}
