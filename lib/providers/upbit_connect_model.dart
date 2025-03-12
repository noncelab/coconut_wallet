import 'package:coconut_wallet/enums/currency_enums.dart';
import 'package:coconut_wallet/services/web_socket_service.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

class UpbitConnectModel extends ChangeNotifier {
  /// Upbit 시세 조회용 웹소켓
  WebSocketService? _upbitWebSocketService;
  WebSocketService? get upbitWebSocketService => _upbitWebSocketService;

  int? _bitcoinPriceKrw;
  int? get bitcoinPriceKrw => _bitcoinPriceKrw;

  UpbitConnectModel() {
    initUpbitWebSocketService();
  }

  void initUpbitWebSocketService({bool force = false}) {
    if (force) {
      disposeUpbitWebSocketService();
    }
    Logger.log('[Upbit Web Socket] Initialized');

    _upbitWebSocketService ??= WebSocketService();
    _upbitWebSocketService?.tickerStream.listen((ticker) {
      _bitcoinPriceKrw = ticker?.tradePrice;
      notifyListeners();
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
