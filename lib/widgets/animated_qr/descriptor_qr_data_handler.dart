import 'package:coconut_wallet/utils/descriptor_util.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/animated_qr/i_coconut_qr_data_handler.dart';

class DescriptorQRDataHandler implements ICoconutQrDataHandler {
  String? _result;

  @override
  Future<void> initialize(Map<String, dynamic> data) async {}

  @override
  bool isCompleted() {
    return _result != null;
  }

  @override
  bool joinData(String descriptor) {
    try {
      Logger.log('--> joinData');
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
