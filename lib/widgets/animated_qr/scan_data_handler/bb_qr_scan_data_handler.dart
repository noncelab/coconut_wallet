import 'package:coconut_wallet/utils/bb_qr/bb_qr_decoder.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_fragmented_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/scan_data_handler_exceptions.dart';

class BbQrScanDataHandler implements IFragmentedQrScanDataHandler {
  BbQrDecoder _bbqrDecoder;
  int? _sequenceLength;
  String? _dataType; // BBQR 데이터 타입 저장
  dynamic _rawResult; // Tx Raw 데이터 저장 (hex)

  BbQrScanDataHandler() : _bbqrDecoder = BbQrDecoder();

  @override
  dynamic get result {
    final result = _rawResult ?? _bbqrDecoder.result;
    return result;
  }

  @override
  double get progress {
    final progress = _rawResult != null ? 1.0 : _bbqrDecoder.progress;
    return progress;
  }

  @override
  bool isCompleted() {
    final completed = _rawResult != null || _bbqrDecoder.isComplete;
    return completed;
  }

  @override
  bool joinData(String data) {
    // 먼저 Raw Tx 데이터인지 확인 (BBQR 헤더가 없는 경우)
    if (!data.startsWith('B\$')) {
      _rawResult = data;
      return true;
    }

    // BBQR 데이터 처리
    if (_sequenceLength == null) {
      final sequenceLength = parseSequenceLength(data);
      if (sequenceLength == null) return false;
      _sequenceLength = sequenceLength;

      if (data.startsWith('B\$') && data.length >= 8) {
        _dataType = data[3];
      }
    }

    final receivePartResult = _bbqrDecoder.receivePart(data);

    if (!receivePartResult && validateFormat(data)) {
      final sequenceValidationResult = validateSequenceLength(data);
      if (!sequenceValidationResult) throw SequenceLengthMismatchException();
    }

    if (_bbqrDecoder.isComplete && _bbqrDecoder.result == null) {
      if (_dataType == 'T') {
        _bbqrDecoder.parseHexData();
      } else {
        _bbqrDecoder.parseJson();
      }
    }

    return receivePartResult;
  }

  int? parseSequenceLength(String data) {
    try {
      if (!data.startsWith('B\$') || data.length < 8) return null;

      final header = data.substring(0, 8);
      final totalStr = header.substring(4, 6);

      final total = int.parse(totalStr, radix: 36);

      return total;
    } catch (_) {
      return null;
    }
  }

  @override
  bool validateFormat(String data) {
    try {
      // Raw Tx 데이터인 경우 true 반환
      if (data.startsWith('02000000')) {
        return true;
      }

      // BBQR 형식만 검증 (parseJson 호출하지 않음)
      if (!data.startsWith('B\$') || data.length < 8) return false;

      final header = data.substring(0, 8);
      if (header.length != 8) return false;

      // encoding, dataType, total, index 형식 검증
      final encoding = header[2];
      final dataType = header[3];
      final totalStr = header.substring(4, 6);
      final indexStr = header.substring(6, 8);

      // B$2J: json+base32, export wallet 형식
      // B$HT: hex+base32, psbt 형식
      // B$2T: transaction+base32, transaction 형식

      // encoding: 2(base32), Z(zlib+base32)
      if (encoding != '2' && encoding != 'Z') return false;
      // dataType: J(Json), P(PSBT), A(Address), M(Multisig Info), S(Seed), T(Transaction/Text)
      if (!['J', 'P', 'A', 'M', 'S', 'T'].contains(dataType)) return false;

      // total, index가 base36 숫자인지 확인
      try {
        int.parse(totalStr, radix: 36);
        int.parse(indexStr, radix: 36);
      } catch (e) {
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
    _dataType = null;
    _rawResult = null;
    _bbqrDecoder = BbQrDecoder();
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
