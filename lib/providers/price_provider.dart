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

/// 가격 채널 연결 상태
enum _ConnectionPhase {
  /// 연결 활성 상태 (채널 일부가 아직 안 열렸을 수 있음)
  active,

  /// 네트워크 부재 또는 초기화 실패로 연결 대기 중
  waitingNetwork,

  /// 앱이 백그라운드로 내려가 의도적으로 연결을 끊은 상태
  suspended,
}

class PriceProvider extends ChangeNotifier {
  final ConnectivityProvider _connectivityProvider;
  final PreferenceProvider _preferenceProvider;
  final WebSocketService Function(FiatCode fiatCode) _createWebSocket;
  final CoinGeckoPriceService Function() _createCoinGeckoService;

  /// 통화별 웹소켓 서비스 (거래소 실시간 시세)
  final Map<FiatCode, WebSocketService> _webSocketServices = {};
  final List<StreamSubscription<PriceResponse?>> _tickerSubscriptions = [];

  /// 거래소 웹소켓이 없는 통화용 CoinGecko 폴링 서비스
  CoinGeckoPriceService? _coinGeckoService;
  StreamSubscription<Map<FiatCode, int>>? _coinGeckoSubscription;

  late final VoidCallback _connectivityListener;
  _ConnectionPhase _phase = _ConnectionPhase.active;

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

    _connectivityListener = _onConnectivityChanged;

    // 가격 채널은 선택 통화와 무관하게 전 통화를 구독하므로 preference 리스너는 등록하지 않는다.
    _connectivityProvider.addListener(_connectivityListener);

    _checkInitialNetworkState();
  }

  void _checkInitialNetworkState() {
    if (_connectivityProvider.isInternetOn == true) {
      initPriceSources();
    } else {
      _phase = _ConnectionPhase.waitingNetwork;
      Logger.log('PriceProvider: Waiting for network connection');
    }
  }

  void _onConnectivityChanged() {
    final isNetworkOn = _connectivityProvider.isInternetOn;

    if (isNetworkOn == true) {
      if (_phase == _ConnectionPhase.waitingNetwork || !_allChannelsConnected) {
        Logger.log('PriceProvider: Network connected');
        initPriceSources();
      }
    } else if (isNetworkOn == false) {
      Logger.log('PriceProvider: Network disconnected');
      if (_phase != _ConnectionPhase.suspended) {
        _phase = _ConnectionPhase.waitingNetwork;
      }
      disposePriceSources();
    }
  }

  void initPriceSources({bool force = false}) {
    if (_phase == _ConnectionPhase.suspended) return;

    // 네트워크 연결 상태 확인
    if (_connectivityProvider.isInternetOn != true) {
      Logger.log('PriceProvider: 네트워크가 연결되지 않아 가격 채널 연결을 보류합니다.');
      _phase = _ConnectionPhase.waitingNetwork;
      return;
    }

    _phase = _ConnectionPhase.active;

    if (force) {
      disposePriceSources();
    }

    // 이미 모든 가격 채널이 연결되어 있으면 스킵
    if (_allChannelsConnected) {
      Logger.log('PriceProvider: 모든 가격 채널이 이미 연결되어 있습니다.');
      return;
    }

    try {
      Logger.log('PriceProvider: 모든 통화의 가격 채널 초기화 중...');

      for (final fiatCode in FiatCode.values.where((fiat) => fiat.hasExchangeSource)) {
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
    } catch (e) {
      Logger.error('PriceProvider: 가격 채널 초기화 실패: $e');
      _phase = _ConnectionPhase.waitingNetwork;
    }
  }

  bool get _allChannelsConnected {
    final exchangeFiatCount = FiatCode.values.where((fiat) => fiat.hasExchangeSource).length;
    return _webSocketServices.length == exchangeFiatCount && _coinGeckoService != null;
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

  void pausePriceSources() {
    _phase = _ConnectionPhase.suspended;
    disposePriceSources();
  }

  void resumePriceSources({bool force = false}) {
    _phase = _ConnectionPhase.active;
    initPriceSources(force: force);
  }

  void disposePriceSources() {
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
    try {
      disposePriceSources();
    } catch (e) {
      Logger.error('PriceProvider: dispose 중 가격 채널 오류: $e');
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
