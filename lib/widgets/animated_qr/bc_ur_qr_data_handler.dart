import 'package:coconut_wallet/widgets/animated_qr/i_coconut_qr_data_handler.dart';
import 'package:ur/ur_decoder.dart';

class BcUrQrDataHandler implements ICoconutQrDataHandler {
  URDecoder _urDecoder;
  BcUrQrDataHandler() : _urDecoder = URDecoder();

  @override
  dynamic get result => _urDecoder.result;

  @override
  Future<void> initialize(Map<String, dynamic> data) async {}

  @override
  bool isCompleted() {
    return _urDecoder.isComplete();
  }

  @override
  bool joinData(String data) {
    return _urDecoder.receivePart(data);
  }

  @override
  void reset() {
    _urDecoder = URDecoder();
  }
}
