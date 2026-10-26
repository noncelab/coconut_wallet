import 'dart:async';

import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/services/coingecko_price_service.dart';
import 'package:coconut_wallet/services/web_socket_service.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PriceProvider extends ChangeNotifier {
  final ConnectivityProvider _connectivityProvider;
  final PreferenceProvider _preferenceProvider;
  final WebSocketService Function(FiatCode fiatCode) _createWebSocket;
  final CoinGeckoPriceService Function() _createCoinGeckoService;
  late FiatCode _fiatCode;

  /// 통화별 웹소켓 서비스 (거래소 실시간 시세)
  final Map<FiatCode, WebSocketService> _webSocketServices = {};
  final List<StreamSubscription<PriceResponse?>> _tickerSubscriptions = [];

  /// 거래소 웹소켓이 없는 통화용 CoinGecko 폴링 서비스
  CoinGeckoPriceService? _coinGeckoService;
  StreamSubscription<Map<FiatCode, int>>? _coinGeckoSubscription;

  late final VoidCallback _connectivityListener;
  late final VoidCallback _preferenceListener;
  bool _isPendingConnection = false;
  bool _isSuspended = false;

  /// 통화별 가격 저장
  final Map<FiatCode, int> _bitcoinPrices = {};

  /// 특정 통화의 BTC 가격 조회
  int? getBitcoinPriceForFiat(FiatCode fiatCode) => _bitcoinPrices[fiatCode];

  PriceProvider(
    this._connectivityProvider,
    this._preferenceProvider, {
    @visibleForTesting WebSocketService Function(FiatCode fiatCode)? webSocketFactory,
    @visibleForTesting CoinGeckoPriceService Function()? coinGeckoFactory,
  }) : _createWebSocket = webSocketFactory ?? WebSocketServiceFactory.create,
       _createCoinGeckoService = coinGeckoFactory ?? CoinGeckoPriceService.new {
    Logger.log('PriceProvider: Initialized with connectivity provider');
    _fiatCode = _preferenceProvider.selectedFiat;

    _connectivityListener = _onConnectivityChanged;
    _preferenceListener = _onPreferenceChanged;

    _connectivityProvider.addListener(_connectivityListener);
    _preferenceProvider.addListener(_preferenceListener);

    _checkInitialNetworkState();
  }

  void _checkInitialNetworkState() {
    if (_connectivityProvider.isInternetOn == true) {
      initWebSocketService();
    } else {
      _isPendingConnection = true;
      Logger.log('PriceProvider: Waiting for network connection');
    }
  }

  void _onConnectivityChanged() {
    final isNetworkOn = _connectivityProvider.isInternetOn;

    if (isNetworkOn == true) {
      if (_isPendingConnection || _webSocketServices.isEmpty || _coinGeckoService == null) {
        Logger.log('PriceProvider: Network connected');
        _isPendingConnection = false;
        initWebSocketService();
      }
    } else if (isNetworkOn == false) {
      Logger.log('PriceProvider: Network disconnected');
      _isPendingConnection = true;
      disposeWebSocketService();
    }
  }

  void _onPreferenceChanged() {
    // 모든 통화의 가격을 유지하므로 선택 통화 변경 시 재연결은 불필요.
    // 연결이 끊긴 통화가 있으면 끊긴 것만 다시 연다.
    if (_fiatCode != _preferenceProvider.selectedFiat) {
      _fiatCode = _preferenceProvider.selectedFiat;
      if (_connectivityProvider.isInternetOn == true) {
        initWebSocketService();
      }
    }
  }

  void initWebSocketService({bool force = false}) {
    if (_isSuspended) return;

    // 네트워크 연결 상태 확인
    if (_connectivityProvider.isInternetOn != true) {
      Logger.log('PriceProvider: 네트워크가 연결되지 않아 WebSocket 연결을 보류합니다.');
      _isPendingConnection = true;
      return;
    }

    if (force) {
      disposeWebSocketService();
    }

    final exchangeFiats = FiatCode.values.where((fiat) => fiat.hasExchangeSource).toList();

    // 이미 모든 가격 채널이 연결되어 있으면 스킵
    if (_webSocketServices.length == exchangeFiats.length && _coinGeckoService != null) {
      Logger.log('PriceProvider: 모든 가격 채널이 이미 연결되어 있습니다.');
      return;
    }

    try {
      Logger.log('PriceProvider: 모든 통화의 가격 채널 초기화 중...');
      _isPendingConnection = false;

      for (final fiatCode in exchangeFiats) {
        if (_webSocketServices.containsKey(fiatCode)) continue;
        final service = _createWebSocket(fiatCode);
        _webSocketServices[fiatCode] = service;
        _tickerSubscriptions.add(
          service.tickerStream.listen(
            (ticker) => updatePriceForFiat(fiatCode, ticker),
            onError: (error) => Logger.error('[${fiatCode.code} WebSocket] 스트림 오류: $error'),
          ),
        );
        Logger.log('[${fiatCode.code} WebSocket] 연결 완료');
      }

      // 거래소 웹소켓이 없는 통화는 CoinGecko 폴링
      if (_coinGeckoService == null) {
        final service = _createCoinGeckoService();
        _coinGeckoService = service;
        _coinGeckoSubscription = service.priceStream.listen(
          _updateCoinGeckoPrices,
          onError: (error) => Logger.error('[CoinGecko] 스트림 오류: $error'),
        );
        service.start();
        Logger.log('[CoinGecko] 폴링 시작');
      }

      final selectedFiat = _preferenceProvider.selectedFiat;
      if (selectedFiat != _fiatCode) {
        _fiatCode = selectedFiat;
      }
    } catch (e) {
      Logger.error('PriceProvider: WebSocket 서비스 초기화 실패: $e');
      _isPendingConnection = true;
    }
  }

  /// fiatCode별로 거래소 ticker를 통해 실시간 가격 업데이트
  void updatePriceForFiat(FiatCode fiatCode, PriceResponse? ticker) {
    if (ticker == null) return;

    _bitcoinPrices[fiatCode] = ticker.tradePrice;
    notifyListeners();
  }

  void _updateCoinGeckoPrices(Map<FiatCode, int> prices) {
    _bitcoinPrices.addAll(prices);
    notifyListeners();
  }

  void pauseWebSocketService() {
    _isSuspended = true;
    disposeWebSocketService();
  }

  void resumeWebSocketService({bool force = false}) {
    _isSuspended = false;
    initWebSocketService(force: force);
  }

  void disposeWebSocketService() {
    for (final subscription in _tickerSubscriptions) {
      unawaited(subscription.cancel());
    }
    _tickerSubscriptions.clear();

    for (final entry in _webSocketServices.entries) {
      try {
        entry.value.dispose();
        Logger.log('[${entry.key.code} WebSocket] 정리 완료');
      } catch (e) {
        Logger.error('[${entry.key.code} WebSocket] 정리 중 오류: $e');
      }
    }
    _webSocketServices.clear();

    _coinGeckoSubscription?.cancel();
    _coinGeckoSubscription = null;
    _coinGeckoService?.dispose();
    _coinGeckoService = null;
  }

  @override
  void dispose() {
    _connectivityProvider.removeListener(_connectivityListener);
    _preferenceProvider.removeListener(_preferenceListener);
    try {
      disposeWebSocketService();
    } catch (e) {
      Logger.error('PriceProvider: dispose 중 WebSocket 오류: $e');
    }
    super.dispose();
  }

  // util: 통화 코드를 받아서 가격을 반환 (문자열)
  String getFiatPrice(int satoshiAmount, {FiatCode? fiatCode, bool showCurrencySymbol = true}) {
    final targetFiat = fiatCode ?? _preferenceProvider.selectedFiat;
    final price = getBitcoinPriceForFiat(targetFiat);

    if (price == null) {
      return '';
    }

    final amount = FiatUtil.calculateFiatAmount(satoshiAmount, price).toThousandsSeparatedString();

    return showCurrencySymbol ? '${targetFiat.symbol} $amount' : amount;
  }
}
