import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_qr_scan_data_handler.dart';
import 'package:ur/ur_decoder.dart';

class BcUrQrScanDataHandler implements IQrScanDataHandler {
  URDecoder _urDecoder;
  BcUrQrScanDataHandler() : _urDecoder = URDecoder();

  @override
  dynamic get result => _urDecoder.result;

  @override
  double get progress => _urDecoder.estimatedPercentComplete();

  @override
  bool isCompleted() {
    Logger.log('--> BcUrQrScanDataHandler isCompleted: ${_urDecoder.isComplete()}');
    return _urDecoder.isComplete();
  }

  @override
  bool joinData(String data) {
    Logger.log('--> joinData: $data');
    return _urDecoder.receivePart(data);
  }

  @override
  bool validateFormat(String data) {
    var lowered = data.toLowerCase();

    // Validate URI scheme
    return lowered.startsWith('ur:');
  }

  @override
  void reset() {
    // 한번 Completed되면 다시 재사용 불가
    _urDecoder = URDecoder();
  }
}
