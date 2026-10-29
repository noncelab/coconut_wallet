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

  /// 홈 위젯에서 고른 통화. 선택 통화와 함께 조회 대상이 된다.
  Set<FiatCode> _homeWidgetFiats = {};
  final Map<Object, FiatCode> _calculatorFiats = {};
  late FiatCode _lastSelectedFiat;

  late final VoidCallback _connectivityListener;
  late final VoidCallback _preferenceListener;
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
    _preferenceListener = _onPreferenceChanged;
    _lastSelectedFiat = _preferenceProvider.selectedFiat;

    _connectivityProvider.addListener(_connectivityListener);
    _preferenceProvider.addListener(_preferenceListener);

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

  void _onPreferenceChanged() {
    final selectedFiat = _preferenceProvider.selectedFiat;
    if (selectedFiat == _lastSelectedFiat) return;
    _lastSelectedFiat = selectedFiat;
    _syncCoinGecko();
  }

  /// 홈 위젯 설정이 바뀔 때 호출한다. 선택 통화와 [fiats]만 조회한다.
  void setHomeWidgetFiats(Iterable<FiatCode> fiats) {
    final next = fiats.toSet();
    if (setEquals(next, _homeWidgetFiats)) return;
    _homeWidgetFiats = next;
    _syncCoinGecko();
  }

  /// 계산기 수명 동안 필요한 통화를 등록하고, 닫힐 때 null로 해제한다.
  void setCalculatorFiat(Object owner, FiatCode? fiat) {
    if (_calculatorFiats[owner] == fiat) return;
    if (fiat == null) {
      _calculatorFiats.remove(owner);
    } else {
      _calculatorFiats[owner] = fiat;
    }
    _syncCoinGecko();
  }

  /// CoinGecko 통화가 하나라도 필요할 때만 조회한다. 조회하면 대상 통화 전체를 함께 받는다.
  bool get _needsCoinGecko =>
      !_preferenceProvider.selectedFiat.hasExchangeSource ||
      _homeWidgetFiats.any((fiat) => !fiat.hasExchangeSource) ||
      _calculatorFiats.values.any((fiat) => !fiat.hasExchangeSource);

  void _syncCoinGecko() {
    if (_phase != _ConnectionPhase.active || _connectivityProvider.isInternetOn != true) return;
    if (!_needsCoinGecko) {
      _coinGeckoService?.stop();
      _bitcoinPrices.removeWhere((fiat, _) => !fiat.hasExchangeSource);
      return;
    }

    var service = _coinGeckoService;
    if (service == null) {
      service = _createCoinGeckoService();
      _coinGeckoService = service;
      _coinGeckoSubscription = service.priceStream.listen(
        _updateCoinGeckoPrices,
        onError: (error) => Logger.error('[CoinGecko] 스트림 오류: $error'),
      );
    }
    if (!service.isRunning) Logger.log('[CoinGecko] 폴링 시작');
    service.start();
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

      // 거래소 웹소켓이 없는 통화는 필요한 것만 CoinGecko 폴링
      _syncCoinGecko();
    } catch (e) {
      Logger.error('PriceProvider: 가격 채널 초기화 실패: $e');
      _phase = _ConnectionPhase.waitingNetwork;
    }
  }

  bool get _allChannelsConnected {
    final exchangeFiatCount = FiatCode.values.where((fiat) => fiat.hasExchangeSource).length;
    final isCoinGeckoReady = (_coinGeckoService?.isRunning ?? false) == _needsCoinGecko;
    return _webSocketServices.length == exchangeFiatCount && isCoinGeckoReady;
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

    _coinGeckoService?.stop();
  }

  void _disposeCoinGecko() {
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
      disposePriceSources();
      _disposeCoinGecko();
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
