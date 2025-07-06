import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preference_provider.dart';
import 'package:coconut_wallet/services/web_socket_service.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

class PriceProvider extends ChangeNotifier {
  final ConnectivityProvider _connectivityProvider;
  final PreferenceProvider _preferenceProvider;

  /// 현재 통화별 웹소켓 서비스
  WebSocketService? _currentWebSocketService;
  WebSocketService? get currentWebSocketService => _currentWebSocketService;

  late final VoidCallback _connectivityListener;
  late final VoidCallback _preferenceListener;
  bool _isPendingConnection = false;

  /// 통화별 가격 저장
  int? _bitcoinPriceKrw;
  int? _bitcoinPriceUsd;

  int? get bitcoinPriceKrw => _bitcoinPriceKrw;
  int? get bitcoinPriceUsd => _bitcoinPriceUsd;

  /// 현재 선택된 통화의 가격
  int? get currentBitcoinPrice {
    switch (_preferenceProvider.selectedFiat) {
      case FiatCode.KRW:
        return _bitcoinPriceKrw;
      case FiatCode.USD:
        return _bitcoinPriceUsd;
    }
  }

  PriceProvider(this._connectivityProvider, this._preferenceProvider) {
    Logger.log('PriceProvider: Initialized with connectivity provider');

    _connectivityListener = _onConnectivityChanged;
    _preferenceListener = _onPreferenceChanged;

    _connectivityProvider.addListener(_connectivityListener);
    _preferenceProvider.addListener(_preferenceListener);

    _checkInitialNetworkState();
  }

  void _checkInitialNetworkState() {
    if (_connectivityProvider.isNetworkOn == true) {
      initWebSocketService();
    } else {
      _isPendingConnection = true;
      Logger.log('PriceProvider: Waiting for network connection');
    }
  }

  void _onConnectivityChanged() {
    final isNetworkOn = _connectivityProvider.isNetworkOn;

    if (isNetworkOn == true) {
      if (_isPendingConnection || _currentWebSocketService == null) {
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
    // 통화가 변경되었을 때 웹소켓 재연결
    if (_connectivityProvider.isNetworkOn == true) {
      initWebSocketService(force: true);
    }
  }

  void initWebSocketService({bool force = false}) {
    // 네트워크 연결 상태 확인
    if (_connectivityProvider.isNetworkOn != true) {
      Logger.log('PriceProvider: Network not connected');
      _isPendingConnection = true;
      return;
    }

    if (force) {
      disposeWebSocketService();
    }

    if (_currentWebSocketService != null) {
      Logger.log('PriceProvider: WebSocket already connected');
      return;
    }

    final selectedFiat = _preferenceProvider.selectedFiat;
    Logger.log('[${selectedFiat.code} WebSocket] Initialized');
    _isPendingConnection = false;

    _currentWebSocketService = WebSocketServiceFactory.create(selectedFiat);
    _currentWebSocketService?.tickerStream.listen((ticker) {
      _updatePrice(ticker);
      notifyListeners();
    }, onError: (error) {
      Logger.error('PriceProvider: WebSocket stream error: $error');
    });
  }

  void _updatePrice(PriceResponse? ticker) {
    if (ticker == null) return;

    switch (_preferenceProvider.selectedFiat) {
      case FiatCode.KRW:
        _bitcoinPriceKrw = ticker.tradePrice;
        break;
      case FiatCode.USD:
        _bitcoinPriceUsd = ticker.tradePrice;
        break;
    }
  }

  void disposeWebSocketService() {
    if (_currentWebSocketService != null) {
      _currentWebSocketService?.dispose();
      _currentWebSocketService = null;
      Logger.log('[${_preferenceProvider.selectedFiat.code} WebSocket] Disposed');
    }
  }

  @override
  void dispose() {
    _connectivityProvider.removeListener(_connectivityListener);
    _preferenceProvider.removeListener(_preferenceListener);
    _currentWebSocketService?.dispose();
    super.dispose();
  }

  // util: 통화 코드를 받아서 가격을 반환 (문자열)
  String getFiatPrice(int satoshiAmount, {FiatCode? fiatCode, bool showCurrencySymbol = true}) {
    final targetFiat = fiatCode ?? _preferenceProvider.selectedFiat;
    final price = _getPriceForFiat(targetFiat);

    if (price == null) {
      return '';
    }

    final amount = FiatUtil.calculateFiatAmount(satoshiAmount, price).toThousandsSeparatedString();

    if (showCurrencySymbol) {
      return '${targetFiat.symbol} $amount';
    } else {
      return amount;
    }
  }

  // util: 통화 코드를 받아서 가격을 반환 (정수)
  int? getFiatAmount(int satoshiAmount, [FiatCode? fiatCode]) {
    final targetFiat = fiatCode ?? _preferenceProvider.selectedFiat;
    final price = _getPriceForFiat(targetFiat);

    if (price == null) {
      return null;
    }

    return FiatUtil.calculateFiatAmount(satoshiAmount, price);
  }

  /// 특정 통화의 가격 반환
  int? _getPriceForFiat(FiatCode fiatCode) {
    switch (fiatCode) {
      case FiatCode.KRW:
        return _bitcoinPriceKrw;
      case FiatCode.USD:
        return _bitcoinPriceUsd;
    }
  }
}
