import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class P2PCalculatorViewModel extends ChangeNotifier {
  final ConnectivityProvider _connectivityProvider;
  final PreferenceProvider _preferenceProvider;
  final PriceProvider _priceProvider;

  late String _referenceDateTimeString;
  String get referenceDateTimeString => _referenceDateTimeString;

  late bool _isUpdatingOnFeeChange;
  bool get isUpdatingOnFeeChange => _isUpdatingOnFeeChange;

  late DateTime _referenceDateTime;
  DateTime get referenceDateTime => _referenceDateTime;

  late FiatCode _currentFiatUnit;
  FiatCode get currentFiatUnit => _currentFiatUnit;

  late String _previousFeeValue;
  String get previousFeeValue => _previousFeeValue;

  late bool _isUpdatingAmounts;
  bool get isUpdatingAmounts => _isUpdatingAmounts;

  late bool _isValidatingFee;
  bool get isValidatingFee => _isValidatingFee;

  late bool _isInputChanged;
  bool get isInputChanged => _isInputChanged;

  late bool _isOfflineMode;
  bool get isOfflineMode => _isOfflineMode;

  late bool _isNetworkOn;
  bool get isNetworkOn => _isNetworkOn;

  late bool _isSwitched;
  bool get isSwitched => _isSwitched;

  late bool _isBtcUnit;
  bool get isBtcUnit => _isBtcUnit;

  int? _fiatPrice;
  int? get fiatPrice => _fiatPrice;

  int? _fixedBtcPrice; // 화면 진입 시점의 BTC 가격 (고정)
  int? get fixedBtcPrice => _fixedBtcPrice;

  P2PCalculatorViewModel(this._preferenceProvider, this._connectivityProvider, this._priceProvider) {
    _connectivityProvider.addListener(_onConnectivityChanged);

    // 화면 진입 시점에 한 번만 BTC 가격 가져오기
    _fixedBtcPrice = _priceProvider.currentBitcoinPrice;
    _isNetworkOn = _connectivityProvider.isNetworkOn;
    _currentFiatUnit = _preferenceProvider.selectedFiat;
    _isBtcUnit = _preferenceProvider.isBtcUnit;
    _referenceDateTime = DateTime.now();
    _referenceDateTimeString =
        '${_referenceDateTime.year}-${_referenceDateTime.month.toString().padLeft(2, '0')}-${_referenceDateTime.day.toString().padLeft(2, '0')} ${_referenceDateTime.hour.toString().padLeft(2, '0')}:${_referenceDateTime.minute.toString().padLeft(2, '0')}:${_referenceDateTime.second.toString().padLeft(2, '0')}';
    _isUpdatingOnFeeChange = false;
    _isUpdatingAmounts = false;
    _isValidatingFee = false;
    _isInputChanged = false;
    _isOfflineMode = false;
    _isSwitched = false;

    _previousFeeValue = '1.0';
  }

  void _onConnectivityChanged() {
    _isNetworkOn = _connectivityProvider.isNetworkOn;
    notifyListeners();
  }

  void setCurrentUnit(FiatCode fiatCode) {
    _currentFiatUnit = fiatCode;
    notifyListeners();
  }

  void setIsValidatingFee(bool value) {
    _isValidatingFee = value;
    notifyListeners();
  }

  void setPreviousFeeValue(String value) {
    _previousFeeValue = value;
    notifyListeners();
  }

  void setIsUpdatingAmounts(bool value) {
    _isUpdatingAmounts = value;
    notifyListeners();
  }

  void setIsUpdatingOnFeeChange(bool value) {
    _isUpdatingOnFeeChange = value;
    notifyListeners();
  }

  void setIsInputChanged(bool value) {
    _isInputChanged = value;
    notifyListeners();
  }

  void setFiatPrice(int? value) {
    _fiatPrice = value;
    notifyListeners();
  }

  void toggleSwitch() {
    _isSwitched = !_isSwitched;
    notifyListeners();
  }

  void toggleBtcUnit() {
    _isBtcUnit = !_isBtcUnit;
    notifyListeners();
  }

  void setIsOfflineMode(bool value) {
    _isOfflineMode = value;
    notifyListeners();
  }

  String getAmountString(double feeValue, {bool isFiat = false}) {
    // 입력이 변경되지 않았거나 fiatPrice가 없으면 빈 문자열 반환 (placeholder 표시)
    if (!isInputChanged || fiatPrice == null || fiatPrice == 0) {
      return '';
    }

    if (isFiat) {
      // fiat은 항상 세 자리마다 콤마를 붙여서 표시
      return fiatPrice!.toThousandsSeparatedString();
    } else {
      // 수수료 및 네트워크 상태를 고려하여 BTC/sats로 환산
      final isNetworkOn = _isNetworkOn;

      final feeRate = feeValue / 100.0;
      final discountMultiplier = 1.0 - feeRate;

      double btcAmount;
      if (isNetworkOn) {
        // 네트워크 ON: 기준시세(_fixedBtcPrice) 사용
        if (_fixedBtcPrice == null || _fixedBtcPrice == 0) {
          return '';
        }

        // (fiat / price) * (1 - fee)
        btcAmount = (fiatPrice! * discountMultiplier) / _fixedBtcPrice!;
      } else {
        // 네트워크 OFF: 20K BTC 가격 사용 (법정화폐별 상수)
        int btcPriceInFiat;
        switch (_currentFiatUnit) {
          case FiatCode.KRW:
            btcPriceInFiat = 26000000;
            break;
          case FiatCode.USD:
            btcPriceInFiat = 20000;
            break;
          case FiatCode.JPY:
            btcPriceInFiat = 3000000;
            break;
        }
        btcAmount = (fiatPrice! * discountMultiplier) / btcPriceInFiat;
      }

      if (isBtcUnit) {
        final satsAmount = (btcAmount * 100000000).round();
        // BTC 단위로 표시 (소수점 8자리)
        return BalanceFormatUtil.formatSatoshiToReadableBitcoin(satsAmount, forceEightDecimals: true);
      } else {
        // sats 단위로 표시 (정수)
        final satsAmount = (btcAmount * 100000000).round();
        return satsAmount.toThousandsSeparatedString();
      }
    }
  }

  /// BTC 금액으로부터 Fiat 금액 계산 (수수료 및 네트워크 상태 반영)
  /// fiat = round(btc × price × (1 + fee))
  int calculateFiatFromBtc(double feeValue, double btc) {
    final feeRate = feeValue / 100.0;
    final premiumMultiplier = 1.0 + feeRate;

    if (_isNetworkOn) {
      if (_fixedBtcPrice == null || _fixedBtcPrice == 0) return 0;
      // fiat = round(btc * price * (1 + fee))
      return (btc * _fixedBtcPrice! * premiumMultiplier).round();
    } else {
      int btcPriceInFiat;
      switch (_currentFiatUnit) {
        case FiatCode.KRW:
          btcPriceInFiat = 26000000;
          break;
        case FiatCode.USD:
          btcPriceInFiat = 20000;
          break;
        case FiatCode.JPY:
          btcPriceInFiat = 3000000;
          break;
      }
      return (btc * btcPriceInFiat * premiumMultiplier).round();
    }
  }

  /// 입력값에서 허용되지 않는 문자를 제거
  String sanitizeInput(String value, bool isFiat) {
    if (isFiat || !isBtcUnit) {
      // fiat 또는 sats: 숫자만 허용
      return value.replaceAll(RegExp(r'[^0-9]'), '');
    } else {
      // BTC 단위: 숫자와 소수점 하나만 허용
      final buffer = StringBuffer();
      bool dotSeen = false;
      for (final ch in value.split('')) {
        if (ch == '.' && !dotSeen) {
          buffer.write('.');
          dotSeen = true;
        } else if (RegExp(r'[0-9]').hasMatch(ch)) {
          buffer.write(ch);
        }
      }
      return buffer.toString();
    }
  }

  /// BTC 텍스트의 정수 부분에 콤마 포맷 적용
  String formatBtcTextWithCommas(String btcText) {
    final parts = btcText.split('.');
    final rawIntPart = parts[0].isEmpty ? '0' : parts[0];
    final hasDotOnly = parts.length == 2 && parts[1].isEmpty; // 예: '0.'
    final decPart = parts.length > 1 ? parts[1] : '';
    final intVal = int.tryParse(rawIntPart) ?? 0;
    final formattedInt = intVal.toThousandsSeparatedString();

    if (hasDotOnly) {
      // '0.' 처럼 끝에 점만 있는 경우 점 유지
      return '$formattedInt.';
    } else if (decPart.isEmpty) {
      return formattedInt;
    } else {
      return '$formattedInt.$decPart';
    }
  }

  String getPlaceholderText(double feeValue, bool isFiat, FiatCode selectedFiat) {
    // 위쪽 위젯인지 확인
    final isUpsideWidget = (isFiat && !isSwitched) || (!isFiat && isSwitched);

    // 위쪽 위젯은 고정 placeholder
    if (isUpsideWidget) {
      if (isFiat) {
        // Fiat 고정값
        switch (selectedFiat) {
          case FiatCode.KRW:
            return '50,000';
          case FiatCode.USD:
            return '50';
          case FiatCode.JPY:
            return '5000';
        }
      } else {
        // BTC/Sats 고정값
        if (isBtcUnit) {
          return '0.00050000';
        } else {
          return '50,000';
        }
      }
    }

    // 아래쪽 위젯은 위쪽 기준으로 계산
    final feeRate = feeValue / 100.0;

    // 위쪽 위젯의 기본값
    int baseFiatPrice = 0;
    double baseBtcAmount = 0;

    switch (selectedFiat) {
      case FiatCode.KRW:
        baseFiatPrice = 50000;
      case FiatCode.USD:
        baseFiatPrice = 50;
      case FiatCode.JPY:
        baseFiatPrice = 5000;
    }

    if (isBtcUnit) {
      baseBtcAmount = 0.0005;
    } else {
      baseBtcAmount = 50000 / 100000000; // 50,000 sats
    }

    // BTC 가격 결정
    int btcPriceInFiat;
    if (isNetworkOn && _fixedBtcPrice != null && _fixedBtcPrice != 0) {
      btcPriceInFiat = _fixedBtcPrice!;
    } else {
      switch (selectedFiat) {
        case FiatCode.KRW:
          btcPriceInFiat = 26000000;
        case FiatCode.USD:
          btcPriceInFiat = 20000;
        case FiatCode.JPY:
          btcPriceInFiat = 3000000;
      }
    }

    if (isFiat) {
      // 아래쪽이 Fiat: BTC/Sats 기준으로 Fiat 계산 (× (1 + fee))
      final premiumMultiplier = 1.0 + feeRate;
      final fiatAmount = (baseBtcAmount * btcPriceInFiat * premiumMultiplier).round();
      return fiatAmount.toThousandsSeparatedString();
    } else {
      // 아래쪽이 BTC/Sats: Fiat 기준으로 BTC/Sats 계산 (× (1 - fee))
      final discountMultiplier = 1.0 - feeRate;
      final btcAmount = (baseFiatPrice * discountMultiplier) / btcPriceInFiat;

      if (isBtcUnit) {
        return btcAmount.toStringAsFixed(8);
      } else {
        final satsAmount = (btcAmount * 100000000).floor();
        return satsAmount.toThousandsSeparatedString();
      }
    }
  }

  Future<void> onFiatUnitChange() async {
    vibrateExtraLight();
    switch (_currentFiatUnit) {
      case FiatCode.KRW:
        _currentFiatUnit = FiatCode.USD;
        break;
      case FiatCode.USD:
        _currentFiatUnit = FiatCode.JPY;
        break;
      default:
        _currentFiatUnit = FiatCode.KRW;
        break;
    }

    final fetchedPrice = await _fetchPriceForFiat(_currentFiatUnit);
    _fixedBtcPrice = fetchedPrice;
    // 가져오기에 성공하면 기준 시점도 업데이트
    if (fetchedPrice != null) {
      _referenceDateTime = DateTime.now();
      _referenceDateTimeString =
          '${_referenceDateTime.year}-${_referenceDateTime.month.toString().padLeft(2, '0')}-${_referenceDateTime.day.toString().padLeft(2, '0')} ${_referenceDateTime.hour.toString().padLeft(2, '0')}:${_referenceDateTime.minute.toString().padLeft(2, '0')}:${_referenceDateTime.second.toString().padLeft(2, '0')}';
    } else {}
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
          // Upbit REST API
          final response = await dio.get('https://api.upbit.com/v1/ticker?markets=KRW-BTC');
          if (response.statusCode == 200 && response.data is List && response.data.isNotEmpty) {
            final tradePrice = response.data[0]['trade_price'];
            return (tradePrice is num) ? tradePrice.toInt() : null;
          }
          return null;

        case FiatCode.USD:
          // Binance REST API
          final response = await dio.get('https://api.binance.com/api/v3/ticker/price?symbol=BTCUSDT');
          if (response.statusCode == 200) {
            final priceStr = response.data['price'];
            final price = double.tryParse(priceStr?.toString() ?? '');
            return price?.toInt();
          }
          return null;

        case FiatCode.JPY:
          // Bitflyer REST API
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

  List<Map<String, String>> getToolbarButtonData(bool isFeeFocused, bool isFiatFocused, bool isBtcFocused) {
    if (isFeeFocused) {
      // 수수료 입력 필드
      return [
        {'label': '+0.1 %', 'value': '0.1'},
        {'label': '+0.5 %', 'value': '0.5'},
        {'label': '+1.0 %', 'value': '1.0'},
        {'label': '+5.0 %', 'value': '5.0'},
      ];
    } else if (isFiatFocused) {
      // Fiat 입력 필드
      switch (_currentFiatUnit) {
        case FiatCode.KRW:
          return [
            {'label': '+10,000', 'value': '10000'},
            {'label': '+50,000', 'value': '50000'},
            {'label': '+100,000', 'value': '100000'},
            {'label': '+500,000', 'value': '500000'},
          ];
        case FiatCode.USD:
          return [
            {'label': '+10', 'value': '10'},
            {'label': '+50', 'value': '50'},
            {'label': '+100', 'value': '100'},
            {'label': '+500', 'value': '500'},
          ];
        case FiatCode.JPY:
          return [
            {'label': '+1,000', 'value': '1000'},
            {'label': '+5,000', 'value': '5000'},
            {'label': '+10,000', 'value': '10000'},
            {'label': '+50,000', 'value': '50000'},
          ];
      }
    } else if (isBtcFocused) {
      // BTC/Sats 입력 필드
      if (isBtcUnit) {
        return [
          {'label': '+0.0001', 'value': '0.0001'},
          {'label': '+0.0005', 'value': '0.0005'},
          {'label': '+0.001', 'value': '0.001'},
          {'label': '+0.005', 'value': '0.005'},
        ];
      } else {
        // sats
        return [
          {'label': '+10,000', 'value': '10000'},
          {'label': '+50,000', 'value': '50000'},
          {'label': '+100,000', 'value': '100000'},
          {'label': '+500,000', 'value': '500000'},
        ];
      }
    }
    return [];
  }
}
