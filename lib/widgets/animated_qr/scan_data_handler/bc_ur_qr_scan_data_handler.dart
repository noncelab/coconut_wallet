import 'package:coconut_wallet/utils/file_logger.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_fragmented_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/scan_data_handler_exceptions.dart';
import 'package:ur/ur_decoder.dart';

enum UrType {
  cryptoAccount('crypto-account'),
  cryptoPsbt('crypto-psbt'),
  psbt('psbt'),
  accountDescriptor('account-descriptor');

  final String value;
  const UrType(this.value);
}

class BcUrQrScanDataHandler implements IFragmentedQrScanDataHandler {
  URDecoder _urDecoder;
  int? _sequenceLength;
  final List<UrType>? expectedUrType;
  UrType? _currentUrType; // expectedUrType이 있으면 그 중 하나의 값이어야 한다.

  BcUrQrScanDataHandler({this.expectedUrType}) : _urDecoder = URDecoder();

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

    if (expectedUrType != null && _currentUrType == null) {
      (String, List<String>) result = URDecoder.parse(data);
      // INFO: validateFormat 결과가 false 일 때 joinData를 호출하지 않아야 합니다.
      // 만약 해당 상황에서 joinData 호출 시 StateError가 발생합니다.
      _currentUrType = expectedUrType!.firstWhere((type) => type.value == result.$1);
      _urDecoder.expectedType = _currentUrType!.value;
    }

    FileLogger.log('BcUrQrScanDataHandler', 'joinData', data);
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
      if (expectedUrType != null && !expectedUrType!.any((type) => type.value == result.$1)) {
        return false;
      }
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
