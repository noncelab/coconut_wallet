import 'dart:async';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/utils/bb_qr/bb_qr_encoder.dart';
import 'package:flutter/material.dart';

enum QrScanDensity { slow, normal, fast }

class UnsignedTransactionQrViewModel extends ChangeNotifier {
  List<String> _bbqrParts = [];
  int _currentBbqrIndex = 0;
  Timer? _bbqrTimer;
  bool _isBbqrType = false;

  QrScanDensity _qrScanDensity = QrScanDensity.normal;
  double _sliderValue = 5.0;
  int? _lastSnappedValue;

  List<String> get bbqrParts => _bbqrParts;
  int get currentBbqrIndex => _currentBbqrIndex;
  bool get isBbqrType => _isBbqrType;
  bool get hasBbqrParts => _bbqrParts.isNotEmpty;
  QrScanDensity get qrScanDensity => _qrScanDensity;
  double get sliderValue => _sliderValue;

  /// BBQR 타입으로 초기화 (ColdCard인 경우)
  void initializeBbqr(String psbtBase64, WalletImportSource walletImportSource) {
    _isBbqrType = walletImportSource == WalletImportSource.coldCard;

    if (walletImportSource == WalletImportSource.coldCard) {
      _bbqrParts = BbQrEncoder().encodeBase64(psbtBase64);
      if (_isBbqrType) {
        startBbqrTimer();
      }
    }
    notifyListeners();
  }

  /// BBQR 인코딩 수행
  void encodeBbqr(String psbtBase64) {
    if (_bbqrParts.isEmpty) {
      _bbqrParts = BbQrEncoder().encodeBase64(psbtBase64);
      notifyListeners();
    }
  }

  /// BBQR 타입 토글
  void toggleBbqrType() {
    _isBbqrType = !_isBbqrType;
    if (_isBbqrType) {
      startBbqrTimer();
    } else {
      stopBbqrTimer();
    }
    notifyListeners();
  }

  /// BBQR 타이머 시작
  void startBbqrTimer() {
    _bbqrTimer?.cancel();
    if (_bbqrParts.isEmpty) {
      return;
    }
    _bbqrTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      _currentBbqrIndex = (_currentBbqrIndex + 1) % _bbqrParts.length;
      notifyListeners();
    });
  }

  /// BBQR 타이머 중지
  void stopBbqrTimer() {
    _bbqrTimer?.cancel();
    _bbqrTimer = null;
  }

  /// QR 스캔 밀도 초기화
  void initializeQrScanDensity(WalletImportSource walletImportSource, double screenWidth) {
    final isNarrowScreen = screenWidth < 360;

    switch (walletImportSource) {
      case WalletImportSource.coconutVault:
      case WalletImportSource.keystone:
        // 볼트와 키스톤은 스캔 성능이 우수하기 때문에 일반/좁은 화면 모두 _qrScanDensity: fast, padding: 16으로 설정
        _qrScanDensity = QrScanDensity.fast;
        break;
      case WalletImportSource.seedSigner:
      case WalletImportSource.extendedPublicKey:
        // 시드사이너는 좁은 화면에서 _qrScanDensity slow가 안정적임
        _qrScanDensity = isNarrowScreen ? QrScanDensity.slow : QrScanDensity.fast;
        break;

      case WalletImportSource.jade:
        // 제이드는 카메라 성능 최악
        _qrScanDensity = QrScanDensity.slow;
        break;
      case WalletImportSource.krux:
        _qrScanDensity = QrScanDensity.slow;
        break;
      default:
        _qrScanDensity = QrScanDensity.normal;
        break;
    }
    _sliderValue = _qrScanDensity.index * 5.0;
    notifyListeners();
  }

  /// 슬라이더 값 변경 (드래그 중)
  void updateSliderValue(double value) {
    _sliderValue = value;
    notifyListeners();
  }

  /// 슬라이더 값 변경 완료 (드래그 종료)
  void onSliderChangeEnd(double value) {
    final snapped = _getSnappedValue(value);
    if (_lastSnappedValue != snapped) {
      _lastSnappedValue = snapped;
      _sliderValue = snapped.toDouble();
      _qrScanDensity = _mapValueToDensity(snapped);
      notifyListeners();
    }
  }

  int _getSnappedValue(double value) {
    if (value <= 2.5) return 0;
    if (value <= 7.5) return 5;
    return 10;
  }

  QrScanDensity _mapValueToDensity(int val) {
    switch (val) {
      case 0:
        return QrScanDensity.slow;
      case 5:
        return QrScanDensity.normal;
      case 10:
      default:
        return QrScanDensity.fast;
    }
  }

  @override
  void dispose() {
    stopBbqrTimer();
    super.dispose();
  }
}
