import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';

/// 콜드카드 - Signed QR 스캔용 (Raw Signed Bitcoin Transaction HEX)
class RawSignedBitcoinTransactionScanDataHandler implements IQrScanDataHandler {
  String? _result;

  @override
  bool isCompleted() {
    return _result != null;
  }

  @override
  bool joinData(String data) {
    try {
      if (!validateFormat(data)) {
        throw const FormatException("Invalid raw transaction hex format");
      }
      _result = data;
      return true;
    } catch (e) {
      Logger.error(e.toString());
      return false;
    }
  }

  @override
  void reset() {
    _result = null;
  }

  @override
  dynamic get result => _result;

  @override
  double get progress => isCompleted() ? 1.0 : 0.0;

  @override
  bool validateFormat(String data) {
    final hexPattern = RegExp(r'^[0-9a-fA-F]+$');
    return hexPattern.hasMatch(data);
  }
}
