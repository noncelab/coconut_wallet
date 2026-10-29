import 'dart:async';

import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/extensions/int_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/fiat_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

enum InputAssetType { fiat, btc } // 단위는 btc로 구분되지만 실제 vm에 저장되고 사용하는 단위는 satoshi 단위입니다.(int)

class P2PCalculatorViewModel extends ChangeNotifier {
  final ConnectivityProvider _connectivityProvider;
  final PreferenceProvider _preferenceProvider;
  final PriceProvider _priceProvider;
  final WalletProvider _walletProvider;
  final Future<int?> Function(FiatCode fiatCode) _fetchRestPrice;
  int _priceRequestGeneration = 0;
  bool _isDisposed = false;

  /// 현재 법정 화폐
  late FiatCode _fiatCode;
  FiatCode get fiatCode => _fiatCode;

  /// 수수료율 (%)
  double _feeRate = 1.0;
  double get premiumRate => _feeRate;

  /// 위쪽 위젯 인풋 타입
  InputAssetType _inputAssetType = InputAssetType.fiat;
  InputAssetType get inputAssetType => _inputAssetType;

  /// 입력 금액 (sats or fiat)
  int? _inputAmount;
  int? _resultAmount;
  int? get inputAmount => _resultAmount == null ? _inputAmount : calculateInputFromResult(_resultAmount!);
  int? get resultAmount => _resultAmount ?? (_inputAmount == null ? null : calculate(_inputAmount!));
  bool get isEditingResult => _resultAmount != null;

  late BitcoinUnit _currentUnit;
  BitcoinUnit get currentUnit => _currentUnit;

  /// 네트워크 연결 상태
  late bool _isNetworkOn;
  bool get isNetworkOn => _isNetworkOn;

  /// 오프라인 모드
  bool _isOfflineMode = false;
  bool get isOfflineMode => _isOfflineMode;

  /// 기준 BTC 가격
  int? _btcPrice;
  int? get btcPrice => _btcPrice;

  /// 기준 BTC 가격을 받은 시각. 계산서의 기준 시세 아래에 출처와 함께 표시한다.
  DateTime? _btcPriceAt;
  DateTime? get btcPriceAt => _btcPriceAt;

  /// 기준 시세 출처 이름
  String get priceSourceName => switch (_fiatCode) {
    FiatCode.KRW => t.utility.p2p_calculator.source_upbit,
    FiatCode.USD || FiatCode.EUR => t.utility.p2p_calculator.source_binance,
    FiatCode.JPY => t.utility.p2p_calculator.source_bitflyer,
    _ => t.utility.p2p_calculator.source_coingecko,
  };

  /// BTC 가격이 사용 가능한지 여부
  bool get isBtcPriceAvailable => _btcPrice != null && _btcPrice! > 0 && _isNetworkOn;

  String get inputCardPrefix =>
      _inputAssetType == InputAssetType.fiat
          ? _fiatCode.symbol
          : (_currentUnit.isBip177Unit ? _currentUnit.symbol : '');
  String get inputCardPostfix =>
      _inputAssetType == InputAssetType.fiat || _currentUnit.isBip177Unit ? '' : _currentUnit.symbol;
  String get resultCardPrefix => _getEffectiveResultPrefix();
  String get resultCardPostfix => _getEffectiveResultPostfix();

  /// 1 BTC의 법정화폐 환산 가격 (포맷팅된 문자열)
  String get formattedOneBtcPrice {
    if (!isBtcPriceAvailable) {
      return '1 BTC';
    }
    final fiatAmount = FiatUtil.calculateFiatAmount(100000000, _btcPrice!);
    return '${_fiatCode.symbol} ${fiatAmount.toThousandsSeparatedString()}';
  }

  /// WalletProvider 관련
  List<WalletItemBase> get wallets => _walletProvider.walletItemList;

  P2PCalculatorViewModel(
    this._preferenceProvider,
    this._connectivityProvider,
    this._priceProvider,
    this._walletProvider, {
    @visibleForTesting Future<int?> Function(FiatCode fiatCode)? restPriceFetcher,
  }) : _fetchRestPrice = restPriceFetcher ?? _fetchPriceForFiat {
    _connectivityProvider.addListener(_onConnectivityChanged);
    _priceProvider.addListener(_onPriceChanged);

    _fiatCode = _preferenceProvider.selectedFiat;
    _isNetworkOn = _connectivityProvider.isInternetOn;
    _currentUnit = _preferenceProvider.currentUnit;
    unawaited(setFiatCode(_fiatCode));
  }

  @override
  void dispose() {
    _isDisposed = true;
    _connectivityProvider.removeListener(_onConnectivityChanged);
    _priceProvider.removeListener(_onPriceChanged);
    _priceProvider.setCalculatorFiat(this, null);
    super.dispose();
  }

  void _onConnectivityChanged() {
    _isNetworkOn = _connectivityProvider.isInternetOn;
    notifyListeners();
  }

  void resetInput() {
    _inputAmount = null;
    _resultAmount = null;
    _feeRate = 1.0;
    notifyListeners();
  }

  void _onPriceChanged() {
    _takeSharedPriceIfNewer();
    notifyListeners();
  }

  /// 공유 시세가 지금 쓰는 시세(REST로 직접 받은 값 포함)보다 오래되지 않았으면 바꾼다.
  void _takeSharedPriceIfNewer() {
    final price = _priceProvider.getBitcoinPriceForFiat(_fiatCode);
    final receivedAt = _priceProvider.priceReceivedAt(_fiatCode);
    if (price == null) return;
    final current = _btcPriceAt;
    if (current != null && receivedAt != null && receivedAt.isBefore(current)) return;
    _btcPrice = price;
    _btcPriceAt = receivedAt;
  }

  void setInputAssetType(InputAssetType type) {
    _inputAssetType = type;
    notifyListeners();
  }

  void setPremiumRate(double rate) {
    _feeRate = rate;
    notifyListeners();
  }

  void setInputAmount(int? amount) {
    _inputAmount = amount;
    _resultAmount = null;
    notifyListeners();
  }

  void setResultAmount(int? amount) {
    _resultAmount = amount;
    _inputAmount = null;
    notifyListeners();
  }

  /// Invert the selected trade equation; swapping trade direction applies a different premium.
  int? calculateInputFromResult(int result) {
    final price = _getBtcPrice();
    final multiplier = 1 + (_inputAssetType == InputAssetType.fiat ? -_feeRate : _feeRate) / 100;
    if (price <= 0 || !multiplier.isFinite || multiplier <= 0 || result < 0) return null;
    final minorUnitsPrice = price * _fiatCode.minorUnitsPerWhole;
    final input =
        _inputAssetType == InputAssetType.fiat
            ? result * minorUnitsPrice / (100000000 * multiplier)
            : result * 100000000 / (minorUnitsPrice * multiplier);
    return input.isFinite ? input.round() : null;
  }

  void cycleBtcUnit() {
    vibrateExtraLight();
    _currentUnit = _currentUnit.next;
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
  /// [fiatMinorUnits]: 통화 최소단위(minor unit, 예: cent) 정수
  int calculateSatsFromFiat(int fiatMinorUnits) {
    final price = _getBtcPrice();
    if (price == 0) return 0;

    final minorUnitsPrice = price * _fiatCode.minorUnitsPerWhole;
    final discountMultiplier = 1.0 - (_feeRate / 100.0);
    if (!discountMultiplier.isFinite || discountMultiplier < 0) return 0;
    final btcAmount = (fiatMinorUnits * discountMultiplier) / minorUnitsPrice;
    return (btcAmount * 100000000).round();
  }

  /// Sats → Fiat 계산 (수수료 추가: × (1 + fee))
  /// 반환값은 통화 최소단위(minor unit, 예: cent) 정수
  int calculateFiatFromSats(int satsAmount) {
    final price = _getBtcPrice();
    if (price == 0) return 0;
    final minorUnitsPrice = price * _fiatCode.minorUnitsPerWhole;
    final premiumMultiplier = 1.0 + (_feeRate / 100.0);
    if (!premiumMultiplier.isFinite || premiumMultiplier <= 0) return 0;
    final btcAmount = satsAmount / 100000000;
    return (btcAmount * minorUnitsPrice * premiumMultiplier).round();
  }

  int _getBtcPrice() {
    if (_isNetworkOn && _btcPrice != null && _btcPrice! > 0) {
      return _btcPrice!;
    }
    return 0;
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
      // 각 통화 Quick Add의 두 번째 금액을 placeholder로 사용
      final placeholderAmount = kFiatQuickAddAmounts[_fiatCode]?[1] ?? 50;
      return placeholderAmount.toThousandsSeparatedString();
    } else {
      if (_currentUnit.isBasedOnSatoshi) {
        return 50000.toThousandsSeparatedString();
      } else {
        return formatBtc(50000);
      }
    }
  }

  String _getResultPlaceholder() {
    int inputValue;

    if (_inputAssetType == InputAssetType.fiat) {
      // Fiat 입력 모드: inputValue는 법정화폐 금액 (Quick Add 두 번째 금액과 동일하게)
      inputValue = kFiatQuickAddAmounts[_fiatCode]?[1] ?? 50;
      // Fiat → Sats (inputValue는 whole unit 기준이므로 minor unit으로 변환)
      final sats = calculateSatsFromFiat(inputValue * _fiatCode.minorUnitsPerWhole);
      return formatSatsResult(sats);
    } else {
      if (!_isNetworkOn) {
        return _getInputPlaceholder();
      }

      // BTC 입력 모드: inputValue는 sats 금액 (모든 통화 동일)
      inputValue = 50000; // 50,000 sats = 0.0005 BTC
      // Sats → Fiat
      final fiat = calculateFiatFromSats(inputValue);
      return formatFiatResult(fiat);
    }
  }

  String _getEffectiveResultPrefix() {
    if (_inputAssetType == InputAssetType.btc && !_isNetworkOn) {
      return _currentUnit.isBip177Unit ? _currentUnit.symbol : '';
    }

    return _inputAssetType == InputAssetType.fiat
        ? (_currentUnit.isBip177Unit ? _currentUnit.symbol : '')
        : _fiatCode.symbol;
  }

  String _getEffectiveResultPostfix() {
    if (_inputAssetType == InputAssetType.btc && !_isNetworkOn) {
      return _currentUnit.isBip177Unit ? '' : _currentUnit.symbol;
    }

    return _inputAssetType == InputAssetType.fiat ? (_currentUnit.isBip177Unit ? '' : _currentUnit.symbol) : '';
  }

  String formatSatsResult(int sats) {
    if (_currentUnit.isBasedOnSatoshi) {
      return sats.toThousandsSeparatedString();
    } else {
      return formatBtc(sats);
    }
  }

  String formatBtc(int sats) {
    var result = BalanceFormatUtil.formatSatoshiToReadableBitcoin(sats);
    final decimalSeparator = NumberFormatConfig.instance.decimalSeparator;
    if (result.endsWith(decimalSeparator)) {
      result = result.substring(0, result.length - decimalSeparator.length);
    }
    return result;
  }

  /// [fiatMinorUnits]: 통화 최소단위(minor unit, 예: cent) 정수
  String formatFiatResult(int fiatMinorUnits) {
    return FiatUtil.formatMinorUnits(fiatMinorUnits, _fiatCode);
  }

  /// 통화 변경 (fiat bottom sheet 선택 시 호출)
  /// 다른 통화를 고르면 입력과 프리미엄을 초기화하고 true를 돌려준다.
  bool selectFiat(FiatCode fiatCode) {
    if (fiatCode == _fiatCode) return false;
    resetInput();
    unawaited(setFiatCode(fiatCode));
    return true;
  }

  Future<void> setFiatCode(FiatCode fiatCode) async {
    if (_isDisposed) return;
    final generation = ++_priceRequestGeneration;
    _fiatCode = fiatCode;
    _priceProvider.setCalculatorFiat(this, fiatCode);

    // 거래소 웹소켓과 CoinGecko 폴링의 공유 시세를 사용한다.
    _btcPrice = null;
    _btcPriceAt = null;
    _takeSharedPriceIfNewer();

    // 공유 시세가 없거나 정상 주기를 넘겨 오래됐으면 새로 받는다. 못 받으면 마지막 시세를 계속 쓴다.
    if (_priceProvider.isPriceStale(fiatCode)) {
      if (!fiatCode.hasExchangeSource) {
        _priceProvider.refreshCoinGeckoNow();
      } else {
        final requestedAt = DateTime.now();
        final fetchedPrice = await _fetchRestPrice(fiatCode);
        if (_isDisposed || generation != _priceRequestGeneration) return;
        if (fetchedPrice != null && (_btcPriceAt == null || _btcPriceAt!.isBefore(requestedAt))) {
          _btcPrice = fetchedPrice;
          _btcPriceAt = DateTime.now();
        }
      }
    }

    notifyListeners();
  }

  /// 특정 Fiat에 대한 BTC 가격을 REST API로 가져옴
  static Future<int?> _fetchPriceForFiat(FiatCode fiatCode) async {
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

        case FiatCode.EUR:
          final response = await dio.get('https://api.binance.com/api/v3/ticker/price?symbol=BTCEUR');
          if (response.statusCode == 200) {
            final priceStr = response.data['price'];
            final price = double.tryParse(priceStr?.toString() ?? '');
            return price?.toInt();
          }
          return null;

        default:
          return null;
      }
    } catch (e) {
      Logger.error('Failed to fetch price for $fiatCode: $e');
      return null;
    }
  }

  String generateTransactionBill(
    String btcPriceStr,
    String priceSourceStr,
    String fiatAmountStr,
    String btcAmountStr,
    String billCreatedAt,
    String feeRateStr,
    String feeAmountStr,
    String feeSatsStr,
  ) {
    if (_inputAssetType == InputAssetType.fiat) {
      return t.utility.p2p_calculator.copy_format(
        currency: _fiatCode.name,
        currencyAmount: fiatAmountStr,
        btcUnit: _currentUnit.symbol,
        btcAmount: btcAmountStr,
        currencySymbol: _fiatCode.symbol,
        referencePrice: btcPriceStr,
        referencePriceSource: priceSourceStr,
        billCreatedAt: billCreatedAt,
        transactionPremiumRate: feeRateStr,
        transactionPremium: feeAmountStr,
        premiumToSats: feeSatsStr,
      );
    } else {
      return t.utility.p2p_calculator.copy_format(
        currency: _currentUnit.symbol,
        currencyAmount: btcAmountStr,
        btcUnit: _fiatCode.name,
        btcAmount: fiatAmountStr,
        currencySymbol: _fiatCode.symbol,
        referencePrice: btcPriceStr,
        referencePriceSource: priceSourceStr,
        billCreatedAt: billCreatedAt,
        transactionPremiumRate: feeRateStr,
        transactionPremium: feeAmountStr,
        premiumToSats: feeSatsStr,
      );
    }
  }

  void toggleP2PMode() {
    vibrateExtraLight();
    _isOfflineMode = !_isOfflineMode;
    notifyListeners();
  }
}
