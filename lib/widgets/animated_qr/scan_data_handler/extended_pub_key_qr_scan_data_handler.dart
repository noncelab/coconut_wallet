import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';

class ExtendedPublicKeyQrScanDataHandler implements IQrScanDataHandler {
  String? _scannedResult;

  bool _isValidExtendedPublicKey(String text) {
    final cleanText = text.trim();

    if (cleanText.contains(RegExp(r'\s'))) return false;

    final lowerText = cleanText.toLowerCase();
    final bool hasValidPrefix =
        lowerText.startsWith('xpub') ||
        lowerText.startsWith('zpub') ||
        lowerText.startsWith('tpub') ||
        lowerText.startsWith('vpub');

    if (!hasValidPrefix || cleanText.length < 10) return false;

    return true;
  }

  String handle(dynamic data) {
    if (data is! String) throw 'Invalid data type';
    if (!_isValidExtendedPublicKey(data)) throw 'Invalid Extended Public Key format';
    return data.trim();
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
