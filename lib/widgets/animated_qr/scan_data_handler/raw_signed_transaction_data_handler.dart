import 'package:coconut_wallet/utils/hex_util.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';

class RawSignedTransactionDataHandler implements IQrScanDataHandler {
  final String _version = '02000000';
  final String _segwitMarker = '0001';
  String? _rawSignedTransaction;

  @override
  bool isCompleted() {
    return _rawSignedTransaction != null;
  }

  @override
  bool joinData(String data) {
    if (!validateFormat(data)) return false;
    _rawSignedTransaction = data;
    return true;
  }

  @override
  double get progress => _rawSignedTransaction != null ? 1.0 : 0.0;

  @override
  void reset() {
    _rawSignedTransaction = null;
  }

  @override
  String? get result => _rawSignedTransaction;

  @override
  bool validateFormat(String data) {
    if (isHexString(data) && data.startsWith(_version) && data.substring(8).startsWith(_segwitMarker)) {
      return true;
    }
    return false;
  }
}
