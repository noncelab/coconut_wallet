import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum InputAssetType { fiat, btc } // 단위는 btc로 구분되지만 실제 vm에 저장되고 사용하는 단위는 satoshi 단위입니다.(int)

class P2PCalculatorViewModel extends ChangeNotifier {
  final ConnectivityProvider _connectivityProvider;
  final PreferenceProvider _preferenceProvider;
  final PriceProvider _priceProvider;

  /// 현재 법정 화폐
  late FiatCode _fiatCode;
  FiatCode get fiatCode => _fiatCode;

  /// 수수료율 (%)
  double _feeRate = 1.0;
  double get feeRate => _feeRate;

  /// 위쪽 위젯 인풋 타입
  InputAssetType _inputAssetType = InputAssetType.fiat;
  InputAssetType get inputAssetType => _inputAssetType;

  /// 입력 금액 (sats or fiat)
  int? _inputAmount;
  int? get inputAmount => _inputAmount;

  /// BTC 단위 (true: BTC, false: sats)
  late bool _isBtcUnit;
  bool get isBtcUnit => _isBtcUnit;

  /// 네트워크 연결 상태
  late bool _isNetworkOn;
  bool get isNetworkOn => _isNetworkOn;

  /// 오프라인 모드
  bool _isOfflineMode = false;
  bool get isOfflineMode => _isOfflineMode;

  /// 기준 BTC 가격
  int? _btcPrice;
  int? get btcPrice => _btcPrice;

  /// BTC 가격이 사용 가능한지 여부
  bool get isBtcPriceAvailable => _btcPrice != null && _btcPrice! > 0 && _isNetworkOn;

  String get inputCardPrefix => _inputAssetType == InputAssetType.fiat ? _fiatCode.symbol : '';
  String get inputCardPostfix => _inputAssetType == InputAssetType.fiat ? '' : (isBtcUnit ? t.btc : t.sats);
  String get resultCardPrefix => _inputAssetType == InputAssetType.fiat ? '' : _fiatCode.symbol;
  String get resultCardPostfix => _inputAssetType == InputAssetType.fiat ? (isBtcUnit ? t.btc : t.sats) : '';

  /// 1 BTC의 법정화폐 환산 가격 (포맷팅된 문자열)
  String get formattedOneBtcPrice {
    if (!isBtcPriceAvailable) {
      return '1 BTC';
    }
    final fiatAmount = FiatUtil.calculateFiatAmount(100000000, _btcPrice!);
    return '${_fiatCode.symbol} ${fiatAmount.toThousandsSeparatedString()}';
  }

  P2PCalculatorViewModel(this._preferenceProvider, this._connectivityProvider, this._priceProvider) {
    _connectivityProvider.addListener(_onConnectivityChanged);
    _priceProvider.addListener(_onPriceChanged);

    _fiatCode = _preferenceProvider.selectedFiat;
    _btcPrice = _priceProvider.getBitcoinPriceForFiat(_fiatCode);
    _isNetworkOn = _connectivityProvider.isNetworkOn;
    _isBtcUnit = _preferenceProvider.isBtcUnit;
  }

  @override
  void dispose() {
    _connectivityProvider.removeListener(_onConnectivityChanged);
    _priceProvider.removeListener(_onPriceChanged);
    super.dispose();
  }

  void _onConnectivityChanged() {
    _isNetworkOn = _connectivityProvider.isNetworkOn;
    notifyListeners();
  }

  void _onPriceChanged() {
    // 현재 선택된 fiatCode에 맞는 가격만 업데이트
    _btcPrice = _priceProvider.getBitcoinPriceForFiat(_fiatCode);
    notifyListeners();
  }

  void setInputAssetType(InputAssetType type) {
    _inputAssetType = type;
    notifyListeners();
  }

  void setFeeRate(double rate) {
    _feeRate = rate;
    notifyListeners();
  }

  void setInputAmount(int? amount) {
    _inputAmount = amount;
    notifyListeners();
  }

  void toggleBtcUnit() {
    vibrateExtraLight();
    _isBtcUnit = !_isBtcUnit;
    notifyListeners();
  }

  void setIsOfflineMode(bool value) {
    _isOfflineMode = value;
    notifyListeners();
  }

  void toggleInputAssetType() {
    vibrateExtraLight();
    _inputAssetType = _inputAssetType == InputAssetType.fiat ? InputAssetType.btc : InputAssetType.fiat;
    notifyListeners();
  }

  /// 입력값을 계산하여 결과 반환
  /// - inputAssetType이 fiat: Fiat → Sats 계산
  /// - inputAssetType이 btc: Sats → Fiat 계산
  int calculate(int input) {
    if (_inputAssetType == InputAssetType.fiat) {
      return calculateSatsFromFiat(input);
    } else {
      return calculateFiatFromSats(input);
    }
  }

  /// Fiat → Sats 계산 (수수료 차감: × (1 - fee))
  int calculateSatsFromFiat(int fiatAmount) {
    final price = _getBtcPrice();
    if (price == 0) return 0;

    final discountMultiplier = 1.0 - (_feeRate / 100.0);
    final btcAmount = (fiatAmount * discountMultiplier) / price;
    return (btcAmount * 100000000).round();
  }

  /// Sats → Fiat 계산 (수수료 추가: × (1 + fee))
  int calculateFiatFromSats(int satsAmount) {
    final price = _getBtcPrice();
    if (price == 0) return 0;
    final premiumMultiplier = 1.0 + (_feeRate / 100.0);
    final btcAmount = satsAmount / 100000000;
    return (btcAmount * price * premiumMultiplier).round();
  }

  int _getBtcPrice() {
    if (_isNetworkOn && _btcPrice != null && _btcPrice! > 0) {
      return _btcPrice!;
    }
    switch (_fiatCode) {
      case FiatCode.KRW:
        return 20000000;
      case FiatCode.USD:
        return 20000;
      case FiatCode.JPY:
        return 2000000;
    }
  }

  String getPlaceholder({required bool isInputCard}) {
    if (isInputCard) {
      return _getInputPlaceholder();
    } else {
      return _getResultPlaceholder();
    }
  }

  String _getInputPlaceholder() {
    if (_inputAssetType == InputAssetType.fiat) {
      switch (_fiatCode) {
        case FiatCode.KRW:
          return '50,000';
        case FiatCode.USD:
          return '50';
        case FiatCode.JPY:
          return '5,000';
      }
    } else {
      if (_isBtcUnit) {
        return '0.0005 0000';
      } else {
        return '50,000';
      }
    }
  }

  String _getResultPlaceholder() {
    int inputValue;

    if (_inputAssetType == InputAssetType.fiat) {
      // Fiat 입력 모드: inputValue는 법정화폐 금액
      switch (_fiatCode) {
        case FiatCode.KRW:
          inputValue = 50000;
        case FiatCode.USD:
          inputValue = 50;
        case FiatCode.JPY:
          inputValue = 5000;
      }
      // Fiat → Sats
      final sats = calculateSatsFromFiat(inputValue);
      return formatSatsResult(sats);
    } else {
      // BTC 입력 모드: inputValue는 sats 금액 (모든 통화 동일)
      inputValue = 50000; // 50,000 sats = 0.0005 BTC
      // Sats → Fiat
      final fiat = calculateFiatFromSats(inputValue);
      return fiat.toThousandsSeparatedString();
    }
  }

  String formatSatsResult(int sats) {
    if (_isBtcUnit) {
      return BalanceFormatUtil.formatSatoshiToReadableBitcoin(sats, forceEightDecimals: true);
    } else {
      return sats.toThousandsSeparatedString();
    }
  }

  String formatFiatResult(int fiat) {
    return fiat.toThousandsSeparatedString();
  }

  Future<void> onFiatUnitChange() async {
    vibrateExtraLight();

    switch (_fiatCode) {
      case FiatCode.KRW:
        _fiatCode = FiatCode.USD;
        break;
      case FiatCode.USD:
        _fiatCode = FiatCode.JPY;
        break;
      case FiatCode.JPY:
        _fiatCode = FiatCode.KRW;
        break;
    }

    // PriceProvider가 웹소켓으로 실시간 제공하는 가격 사용
    _btcPrice = _priceProvider.getBitcoinPriceForFiat(_fiatCode);

    // 웹소켓 가격이 없으면 fallback으로 HTTP API 호출
    if (_btcPrice == null) {
      final fetchedPrice = await _fetchPriceForFiat(_fiatCode);
      if (fetchedPrice != null) {
        _btcPrice = fetchedPrice;
      }
    }

    notifyListeners();
  }

  /// 특정 Fiat에 대한 BTC 가격을 REST API로 가져옴
  Future<int?> _fetchPriceForFiat(FiatCode fiatCode) async {
    try {
      final dio = Dio(
        BaseOptions(connectTimeout: const Duration(seconds: 5), receiveTimeout: const Duration(seconds: 5)),
      );

      switch (fiatCode) {
        case FiatCode.KRW:
          final response = await dio.get('https://api.upbit.com/v1/ticker?markets=KRW-BTC');
          if (response.statusCode == 200 && response.data is List && response.data.isNotEmpty) {
            final tradePrice = response.data[0]['trade_price'];
            return (tradePrice is num) ? tradePrice.toInt() : null;
          }
          return null;

        case FiatCode.USD:
          final response = await dio.get('https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT');
          if (response.statusCode == 200) {
            final priceStr = response.data['price'];
            final price = double.tryParse(priceStr?.toString() ?? '');
            return price?.toInt();
          }
          return null;

        case FiatCode.JPY:
          final response = await dio.get('https://api.bitflyer.com/v1/ticker?product_code=BTC_JPY');
          if (response.statusCode == 200) {
            final ltp = response.data['ltp'];
            return (ltp is num) ? ltp.toInt() : null;
          }
          return null;
      }
    } catch (e) {
      Logger.error('Failed to fetch price for $fiatCode: $e');
      return null;
    }
  }

  String _generateTransactionBill(
    String btcPriceStr,
    String fiatAmountStr,
    String btcAmountStr,
    String referenceDateTime,
    String feeRateStr,
    String feeAmountStr,
    String feeSatsStr,
  ) {
    if (_inputAssetType == InputAssetType.fiat) {
      return t.utility.p2p_calculator.copy_format(
        currency: _fiatCode.name,
        currencyAmount: fiatAmountStr,
        btcUnit: isBtcUnit ? t.btc : t.sats,
        btcAmount: btcAmountStr,
        currencySymbol: _fiatCode.symbol,
        referencePrice: btcPriceStr,
        referenceTime: referenceDateTime,
        transactionFeeRate: feeRateStr,
        transactionFee: feeAmountStr,
        feeToSats: feeSatsStr,
      );
    } else {
      return t.utility.p2p_calculator.copy_format(
        currency: isBtcUnit ? t.btc : t.sats,
        currencyAmount: btcAmountStr,
        btcUnit: _fiatCode.name,
        btcAmount: fiatAmountStr,
        currencySymbol: _fiatCode.symbol,
        referencePrice: btcPriceStr,
        referenceTime: referenceDateTime,
        transactionFeeRate: feeRateStr,
        transactionFee: feeAmountStr,
        feeToSats: feeSatsStr,
      );
    }
  }

  void copyAll(
    String btcPriceStr,
    String fiatAmountStr,
    String btcAmountStr,
    String referenceDateTime,
    String feeRateStr,
    String feeAmountStr,
    String feeSatsStr,
  ) {
    if (inputAmount == null || inputAmount == 0) return;
    final bill = _generateTransactionBill(
      btcPriceStr,
      fiatAmountStr,
      btcAmountStr,
      referenceDateTime,
      feeRateStr,
      feeAmountStr,
      feeSatsStr,
    );
    Clipboard.setData(ClipboardData(text: bill));
  }

  void share() {
    if (inputAmount == null || inputAmount == 0) return;
    // TODO: Share 기능 구현
    // final now = DateTime.now();
    // final bill = _generateTransactionBill(now);
    // Share.share(bill);
  }
}
