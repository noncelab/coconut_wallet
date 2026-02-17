import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';

class ExtendedPublicKeyQrScanDataHandler implements IQrScanDataHandler {
  String? _scannedResult;

  bool _isValidExtendedPublicKey(String text) {
    try {
      ExtendedPublicKey.parse(text.trim());
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  bool validateFormat(String data) {
    return _isValidExtendedPublicKey(data);
  }

  @override
  bool joinData(String data) {
    if (validateFormat(data)) {
      _scannedResult = data.trim();
      return true;
    }
    return false;
  }

  @override
  bool isCompleted() {
    return _scannedResult != null;
  }

  @override
  double get progress => _scannedResult != null ? 1.0 : 0.0;

  @override
  get result => _scannedResult;

  @override
  void reset() {
    _scannedResult = null;
  }
}
