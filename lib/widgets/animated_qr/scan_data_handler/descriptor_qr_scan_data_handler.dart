import 'package:coconut_wallet/utils/descriptor_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';

class DescriptorQrScanDataHandler implements IQrScanDataHandler {
  String? _result;

  @override
  bool isCompleted() {
    return _result != null;
  }

  @override
  bool joinData(String descriptor) {
    try {
      final normalizedDescriptor = DescriptorUtil.normalizeDescriptor(descriptor);
      _result = normalizedDescriptor;
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
}
