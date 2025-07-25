import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_fragmented_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/scan_data_handler_exceptions.dart';
import 'package:ur/ur_decoder.dart';

class BcUrQrScanDataHandler implements IFragmentedQrScanDataHandler {
  URDecoder _urDecoder;
  int? _sequenceLength;

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
    if (_sequenceLength == null) {
      final sequenceLength = parseSequenceLength(data);
      if (sequenceLength == null) return false;
      _sequenceLength = sequenceLength;
    }
    Logger.log('--> [QR] joinData: $data');
    final receivePartResult = _urDecoder.receivePart(data);
    if (!receivePartResult && validateFormat(data)) {
      final sequenceValidationResult = validateSequenceLength(data);
      if (!sequenceValidationResult) throw SequenceLengthMismatchException();
    }
    return receivePartResult;
  }

  int? parseSequenceLength(String data) {
    try {
      (String, List<String>) result = URDecoder.parse(data);
      final sequenceLength = URDecoder.parseSequenceComponent(result.$2[0]).$2;
      return sequenceLength;
    } catch (_) {
      return null;
    }
  }

  @override
  bool validateFormat(String data) {
    try {
      (String, List<String>) result = URDecoder.parse(data);
      URDecoder.parseSequenceComponent(result.$2[0]);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  void reset() {
    // 한번 Completed되면 다시 재사용 불가
    _sequenceLength = null;
    _urDecoder = URDecoder();
  }

  @override
  int? get sequenceLength => _sequenceLength;

  @override
  bool validateSequenceLength(String data) {
    if (_sequenceLength == null) {
      throw SequenceLengthNotInitializedException();
    }

    return _sequenceLength == parseSequenceLength(data);
  }
}
