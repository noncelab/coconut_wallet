import 'package:coconut_wallet/services/web_socket_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:flutter/material.dart';

class UpbitConnectModel extends ChangeNotifier {
  /// Upbit 시세 조회용 웹소켓
  WebSocketService? _upbitWebSocketService;
  WebSocketService? get upbitWebSocketService => _upbitWebSocketService;

  int? _bitcoinPriceKrw;
  int? get bitcoinPriceKrw => _bitcoinPriceKrw;

  // String? _bitcoinPriceKrwString;
  // String? get bitcoinPriceKrwString => _bitcoinPriceKrwString;

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
      // wallet_list_screen Consumer builder가 계속 호출되어서 주석처리함
      notifyListeners();
    });
  }

  // void setBitcoinPriceKrwString(int sendingAmount) {
  // _bitcoinPriceKrwString = addCommasToIntegerPart(
  //     FiatUtil.calculateFiatAmount(sendingAmount, bitcoinPriceKrw!)
  //         .toDouble());
  // }

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
}
