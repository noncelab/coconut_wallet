import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/services/web_socket_service.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

class PriceProvider extends ChangeNotifier {
  final ConnectivityProvider _connectivityProvider;

  /// Upbit 시세 조회용 웹소켓
  WebSocketService? _upbitWebSocketService;
  WebSocketService? get upbitWebSocketService => _upbitWebSocketService;

  late final VoidCallback _connectivityListener;
  bool _isPendingConnection = false;

  int? _bitcoinPriceKrw;
  int? get bitcoinPriceKrw => _bitcoinPriceKrw;

  PriceProvider(this._connectivityProvider) {
    Logger.log('UpbitConnectModel: Initialized with connectivity provider');

    _connectivityListener = _onConnectivityChanged;
    _connectivityProvider.addListener(_connectivityListener);

    _checkInitialNetworkState();
  }

  void _checkInitialNetworkState() {
    if (_connectivityProvider.isNetworkOn == true) {
      initUpbitWebSocketService();
    } else {
      _isPendingConnection = true;
      Logger.log('UpbitConnectModel: Waiting for network connection');
    }
  }

  void _onConnectivityChanged() {
    final isNetworkOn = _connectivityProvider.isNetworkOn;

    if (isNetworkOn == true) {
      if (_isPendingConnection || _upbitWebSocketService == null) {
        Logger.log('UpbitConnectModel: Network connected');
        _isPendingConnection = false;
        initUpbitWebSocketService();
      }
    } else if (isNetworkOn == false) {
      Logger.log('UpbitConnectModel: Network disconnected');
      _isPendingConnection = true;
      disposeUpbitWebSocketService();
    }
  }

  void initUpbitWebSocketService({bool force = false}) {
    // 네트워크 연결 상태 확인
    if (_connectivityProvider.isNetworkOn != true) {
      Logger.log('UpbitConnectModel: Network not connected');
      _isPendingConnection = true;
      return;
    }

    if (force) {
      disposeUpbitWebSocketService();
    }

    if (_upbitWebSocketService != null) {
      Logger.log('UpbitConnectModel: WebSocket already connected');
      return;
    }

    Logger.log('[Upbit Web Socket] Initialized');
    _isPendingConnection = false;

    _upbitWebSocketService = WebSocketService();
    _upbitWebSocketService?.tickerStream.listen((ticker) {
      _bitcoinPriceKrw = ticker?.tradePrice;
      notifyListeners();
    }, onError: (error) {
      Logger.error('UpbitConnectModel: WebSocket stream error: $error');
    });
  }

  void disposeUpbitWebSocketService() {
    if (upbitWebSocketService != null) {
      upbitWebSocketService?.dispose();
      _upbitWebSocketService = null;
      Logger.log('[Upbit Web Socket] Disposed');
    }
  }

  @override
  void dispose() {
    _connectivityProvider.removeListener(_connectivityListener);
    _upbitWebSocketService?.dispose();
    super.dispose();
  }

  // util: 통화 코드를 받아서 가격을 반환
  String getFiatPrice(int satoshiAmount, CurrencyCode fiatCode) {
    if (_bitcoinPriceKrw == null) {
      return '';
    }

    if (fiatCode.code == CurrencyCode.KRW.code) {
      return '${CurrencyCode.KRW.symbol} ${addCommasToIntegerPart(FiatUtil.calculateFiatAmount(satoshiAmount, bitcoinPriceKrw!).toDouble())}';
    }
    return '';
  }
}
