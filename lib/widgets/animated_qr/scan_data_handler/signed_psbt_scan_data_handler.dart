import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/bb_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/bc_ur_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_fragmented_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/raw_signed_transaction_data_handler.dart';

/// 들어올 수 있는 데이터 타입
/// 1. bc_ur (fragmented QR)
/// 2. bb_qr (fragmented QR)
/// 3. raw hex string (single QR)
enum SignedPsbtScanDataType { ur, bbqr, raw }

class SignedPsbtScanDataHandler extends IFragmentedQrScanDataHandler {
  final BcUrQrScanDataHandler _bcUrQrScanDataHandler = BcUrQrScanDataHandler(
    expectedUrType: [UrType.cryptoPsbt, UrType.psbt],
  );
  final BbQrScanDataHandler _bbQrScanDataHandler = BbQrScanDataHandler();
  final RawSignedTransactionDataHandler _rawSignedTransactionDataHandler = RawSignedTransactionDataHandler();

  IQrScanDataHandler? _currentScanDataHandler;
  SignedPsbtScanDataType? _currentScanDataType;

  SignedPsbtScanDataType? get scanDataType => _currentScanDataType;

  @override
  bool isCompleted() {
    if (_currentScanDataType == null) {
      return false;
    }
    return _currentScanDataHandler!.isCompleted();
  }

  @override
  bool joinData(String data) {
    if (_currentScanDataType == null) {
      final validatedFormat = _getValidatedFormat(data);
      if (validatedFormat == null) return false;
      _setCurrentDataTypeAndHandler(validatedFormat);
    }

    return _currentScanDataHandler!.joinData(data);
  }

  @override
  double get progress => _currentScanDataHandler!.progress;

  @override
  void reset() {
    _bcUrQrScanDataHandler.reset();
    _bbQrScanDataHandler.reset();
    _rawSignedTransactionDataHandler.reset();
    _currentScanDataHandler = null;
    _currentScanDataType = null;
  }

  @override
  dynamic get result {
    if (_currentScanDataHandler == null) {
      return null;
    }
    return _currentScanDataHandler!.result;
  }

  @override
  int? get sequenceLength {
    if (_currentScanDataHandler == null) return null;
    if (_currentScanDataType is! IFragmentedQrScanDataHandler) return null;
    return (_currentScanDataHandler! as IFragmentedQrScanDataHandler).sequenceLength;
  }

  @override
  bool validateFormat(String data) {
    try {
      final validatedFormat = _getValidatedFormat(data);
      if (validatedFormat == null) return false;

      return true;
    } catch (e) {
      Logger.error('❌ [SignedPsbtScanDataHandler] validateFormat failed: $e');
      return false;
    }
  }

  // 현재 외부에서 사용하는 케이스가 없음
  @override
  bool validateSequenceLength(String data) {
    if (_currentScanDataHandler == null) {
      return false;
    }

    if (_currentScanDataHandler is! IFragmentedQrScanDataHandler) {
      return true;
    }

    return (_currentScanDataHandler! as IFragmentedQrScanDataHandler).validateSequenceLength(data);
  }

  SignedPsbtScanDataType? _getValidatedFormat(String data) {
    if (_bbQrScanDataHandler.validateFormat(data)) {
      return SignedPsbtScanDataType.bbqr;
    } else if (_bcUrQrScanDataHandler.validateFormat(data)) {
      return SignedPsbtScanDataType.ur;
    } else if (_rawSignedTransactionDataHandler.validateFormat(data)) {
      return SignedPsbtScanDataType.raw;
    }
    return null;
  }

  void _setCurrentDataTypeAndHandler(SignedPsbtScanDataType type) {
    _currentScanDataType = type;
    switch (type) {
      case SignedPsbtScanDataType.bbqr:
        _currentScanDataHandler = _bbQrScanDataHandler;
      case SignedPsbtScanDataType.ur:
        _currentScanDataHandler = _bcUrQrScanDataHandler;
      case SignedPsbtScanDataType.raw:
        _currentScanDataHandler = _rawSignedTransactionDataHandler;
    }
  }
}
