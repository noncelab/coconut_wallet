import 'dart:convert';

import 'package:coconut_wallet/utils/bb_qr/bb_qr_decoder.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/i_fragmented_qr_scan_data_handler.dart';
import 'package:coconut_wallet/widgets/animated_qr/scan_data_handler/scan_data_handler_exceptions.dart';

class BbQrScanDataHandler implements IFragmentedQrScanDataHandler {
  BbQrDecoder _bbqrDecoder;
  int? _sequenceLength;
  String? _dataType; // BBQR 데이터 타입 저장
  String? _psbtBase64;

  BbQrScanDataHandler() : _bbqrDecoder = BbQrDecoder();

  @override
  dynamic get result {
    return _psbtBase64 ?? _bbqrDecoder.result;
  }

  @override
  double get progress {
    return _psbtBase64 != null ? 1.0 : _bbqrDecoder.progress;
  }

  @override
  bool isCompleted() {
    return _psbtBase64 != null || _bbqrDecoder.isComplete;
  }

  @override
  bool joinData(String data) {
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
      if (_dataType == 'P') {
        _psbtBase64 = _getPsbtBase64();
      } else if (_dataType == 'T') {
        _bbqrDecoder.parseHexData();
      } else {
        _bbqrDecoder.parseJson();
      }
    }

    return receivePartResult;
  }

  String? _getPsbtBase64() {
    final hexData = _bbqrDecoder.parseHexData();
    if (hexData is! String || hexData.length.isOdd) return null;

    try {
      final bytes = List<int>.generate(
        hexData.length ~/ 2,
        (index) => int.parse(hexData.substring(index * 2, index * 2 + 2), radix: 16),
      );
      return base64Encode(bytes);
    } catch (_) {
      return null;
    }
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
      // BBQR 형식만 검증
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

      // encoding: 2(base32), Z(zlib+base32) H(hex)
      if (encoding != '2' && encoding != 'Z' && encoding != 'H') return false;
      // dataType: J(Json), P(PSBT), T(Transaction/Text)
      if (!['J', 'P', 'T'].contains(dataType)) return false;

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
    _psbtBase64 = null;
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
