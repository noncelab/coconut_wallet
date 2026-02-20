import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/services/web_socket_service.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

class PriceProvider extends ChangeNotifier {
  final ConnectivityProvider _connectivityProvider;
  final PreferenceProvider _preferenceProvider;
  late FiatCode _fiatCode;

  /// 통화별 웹소켓 서비스
  WebSocketService? _webSocketServiceKrw;
  WebSocketService? _webSocketServiceUsd;
  WebSocketService? _webSocketServiceJpy;

  late final VoidCallback _connectivityListener;
  late final VoidCallback _preferenceListener;
  bool _isPendingConnection = false;

  /// 통화별 가격 저장
  int? _bitcoinPriceKrw;
  int? _bitcoinPriceUsd;
  int? _bitcoinPriceJpy;

  int? get bitcoinPriceKrw => _bitcoinPriceKrw;
  int? get bitcoinPriceUsd => _bitcoinPriceUsd;
  int? get bitcoinPriceJpy => _bitcoinPriceJpy;

  /// 특정 통화의 BTC 가격 조회
  int? getBitcoinPriceForFiat(FiatCode fiatCode) {
    switch (fiatCode) {
      case FiatCode.KRW:
        return _bitcoinPriceKrw;
      case FiatCode.USD:
        return _bitcoinPriceUsd;
      case FiatCode.JPY:
        return _bitcoinPriceJpy;
    }
  }

  PriceProvider(this._connectivityProvider, this._preferenceProvider) {
    Logger.log('PriceProvider: Initialized with connectivity provider');
    _fiatCode = _preferenceProvider.selectedFiat;

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
      final hasAnyService =
          _webSocketServiceKrw != null || _webSocketServiceUsd != null || _webSocketServiceJpy != null;
      if (_isPendingConnection || !hasAnyService) {
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
      if (_fiatCode != _preferenceProvider.selectedFiat) {
        _fiatCode = _preferenceProvider.selectedFiat;
        initWebSocketService(force: true);
      }
    }
  }

  void initWebSocketService({bool force = false}) {
    // 네트워크 연결 상태 확인
    if (_connectivityProvider.isNetworkOn != true) {
      Logger.log('PriceProvider: 네트워크가 연결되지 않아 WebSocket 연결을 보류합니다.');
      _isPendingConnection = true;
      return;
    }

    if (force) {
      disposeWebSocketService();
    }

    // 이미 모든 WebSocket이 연결되어 있으면 스킵
    if (_webSocketServiceKrw != null && _webSocketServiceUsd != null && _webSocketServiceJpy != null) {
      Logger.log('PriceProvider: 모든 WebSocket이 이미 연결되어 있습니다.');
      return;
    }

    try {
      Logger.log('PriceProvider: 모든 통화의 WebSocket 초기화 중...');
      _isPendingConnection = false;

      // KRW 웹소켓 (Upbit)
      if (_webSocketServiceKrw == null) {
        _webSocketServiceKrw = WebSocketServiceFactory.create(FiatCode.KRW);
        _webSocketServiceKrw?.tickerStream.listen(
          (ticker) => updatePriceForFiat(FiatCode.KRW, ticker),
          onError: (error) => Logger.error('[KRW WebSocket] 스트림 오류: $error'),
        );
        Logger.log('[KRW WebSocket] Upbit 연결 완료');
      }

      // USD 웹소켓 (Binance)
      if (_webSocketServiceUsd == null) {
        _webSocketServiceUsd = WebSocketServiceFactory.create(FiatCode.USD);
        _webSocketServiceUsd?.tickerStream.listen(
          (ticker) => updatePriceForFiat(FiatCode.USD, ticker),
          onError: (error) => Logger.error('[USD WebSocket] 스트림 오류: $error'),
        );
        Logger.log('[USD WebSocket] Binance 연결 완료');
      }

      // JPY 웹소켓 (Bitflyer)
      if (_webSocketServiceJpy == null) {
        _webSocketServiceJpy = WebSocketServiceFactory.create(FiatCode.JPY);
        _webSocketServiceJpy?.tickerStream.listen(
          (ticker) => updatePriceForFiat(FiatCode.JPY, ticker),
          onError: (error) => Logger.error('[JPY WebSocket] 스트림 오류: $error'),
        );
        Logger.log('[JPY WebSocket] Bitflyer 연결 완료');
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

    switch (fiatCode) {
      case FiatCode.KRW:
        _bitcoinPriceKrw = ticker.tradePrice;
        break;
      case FiatCode.USD:
        _bitcoinPriceUsd = ticker.tradePrice;
        break;
      case FiatCode.JPY:
        _bitcoinPriceJpy = ticker.tradePrice;
        break;
    }

    notifyListeners();
  }

  void disposeWebSocketService() {
    // KRW WebSocket 정리
    if (_webSocketServiceKrw != null) {
      try {
        _webSocketServiceKrw?.dispose();
        Logger.log('[KRW WebSocket] 정리 완료');
      } catch (e) {
        Logger.error('[KRW WebSocket] 정리 중 오류: $e');
      } finally {
        _webSocketServiceKrw = null;
      }
    }

    // USD WebSocket 정리
    if (_webSocketServiceUsd != null) {
      try {
        _webSocketServiceUsd?.dispose();
        Logger.log('[USD WebSocket] 정리 완료');
      } catch (e) {
        Logger.error('[USD WebSocket] 정리 중 오류: $e');
      } finally {
        _webSocketServiceUsd = null;
      }
    }

    // JPY WebSocket 정리
    if (_webSocketServiceJpy != null) {
      try {
        _webSocketServiceJpy?.dispose();
        Logger.log('[JPY WebSocket] 정리 완료');
      } catch (e) {
        Logger.error('[JPY WebSocket] 정리 중 오류: $e');
      } finally {
        _webSocketServiceJpy = null;
      }
    }
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
    try {
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
    } catch (e) {
      Logger.error('PriceProvider: getFiatPrice 오류: $e');
      return '';
    }
  }

  // util: 통화 코드를 받아서 가격을 반환 (정수)
  int? getFiatAmount(int satoshiAmount, [FiatCode? fiatCode]) {
    try {
      final targetFiat = fiatCode ?? _preferenceProvider.selectedFiat;
      final price = _getPriceForFiat(targetFiat);

      if (price == null) {
        return null;
      }

      return FiatUtil.calculateFiatAmount(satoshiAmount, price);
    } catch (e) {
      Logger.error('PriceProvider: getFiatAmount 오류: $e');
      return null;
    }
  }

  /// 특정 통화의 가격 반환
  int? _getPriceForFiat(FiatCode fiatCode) {
    switch (fiatCode) {
      case FiatCode.KRW:
        return _bitcoinPriceKrw;
      case FiatCode.USD:
        return _bitcoinPriceUsd;
      case FiatCode.JPY:
        return _bitcoinPriceJpy;
    }
  }
}
