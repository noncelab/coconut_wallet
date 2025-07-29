import 'package:coconut_wallet/utils/bbqr_decoder.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_fragmented_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/scan_data_handler_exceptions.dart';

class BbQrScanDataHandler implements IFragmentedQrScanDataHandler {
  BbqrDecoder _bbqrDecoder;
  int? _sequenceLength;

  BbQrScanDataHandler() : _bbqrDecoder = BbqrDecoder();

  @override
  dynamic get result => _bbqrDecoder.result;

  @override
  double get progress => _bbqrDecoder.progress;

  @override
  bool isCompleted() {
    return _bbqrDecoder.isComplete;
  }

  @override
  bool joinData(String data) {
    if (_sequenceLength == null) {
      final sequenceLength = parseSequenceLength(data);
      if (sequenceLength == null) return false;
      _sequenceLength = sequenceLength;
    }
    Logger.log('--> [QR] joinData: $data');
    final receivePartResult = _bbqrDecoder.receivePart(data);
    if (!receivePartResult && validateFormat(data)) {
      final sequenceValidationResult = validateSequenceLength(data);
      if (!sequenceValidationResult) throw SequenceLengthMismatchException();
    }

    // 조각이 모두 모이면 JSON 파싱하여 result 설정
    if (_bbqrDecoder.isComplete && _bbqrDecoder.result == null) {
      _bbqrDecoder.parseJson();
    }

    return receivePartResult;
  }

  int? parseSequenceLength(String data) {
    try {
      if (!data.startsWith('B\$') || data.length < 8) return null;

      final header = data.substring(0, 8); // B$2J0700
      final totalStr = header.substring(4, 6); // "07"

      final total = int.parse(totalStr, radix: 36);

      return total;
    } catch (_) {
      return null;
    }
  }

  @override
  bool validateFormat(String data) {
    try {
      // BBQR 형식만 검증 (parseJson 호출하지 않음)
      if (!data.startsWith('B\$') || data.length < 8) return false;

      final header = data.substring(0, 8); // B$2J0700
      if (header.length != 8) return false;

      // encoding, dataType, total, index 형식 검증
      final encoding = header[2];
      final dataType = header[3];
      final totalStr = header.substring(4, 6);
      final indexStr = header.substring(6, 8);

      // encoding: 2(base32), Z(zlib+base32)
      if (encoding != '2' && encoding != 'Z') return false;

      // dataType: J(Json), P(PSBT), A(Address), M(Multisig Info), S(Seed)
      if (!['J', 'P', 'A', 'M', 'S'].contains(dataType)) return false;

      // total, index가 base36 숫자인지 확인
      try {
        int.parse(totalStr, radix: 36);
        int.parse(indexStr, radix: 36);
      } catch (_) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  void reset() {
    _sequenceLength = null;
    _bbqrDecoder = BbqrDecoder();
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
