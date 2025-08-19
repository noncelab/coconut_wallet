import 'dart:convert';
import 'dart:io';
import 'package:base32/base32.dart';
import 'package:coconut_wallet/utils/logger.dart';

class BbQrDecoder {
  // ColdCard Q1 Export Wallet Data
  /// ex: B$2J0700... (B$[encoding][dataType][total][index][payload])
  /// B$: 고정 prefix (BBQR 시작을 표시)
  /// encoding: 압축 및 인코딩 형식: 2(base32), Z(zlib+base32)
  /// dataType: 데이터 유형: J(Json), P(PSBT), A(Address), M(Multisig Info), S(Seed)
  /// total: 전체 QR 조각 수(2자리 base36 숫자)
  /// index: 현재 QR 조각의 순서(2자리 base36 숫자)
  /// payload: 압축된 base32 인코딩 데이터
  final Map<int, List<int>> _chunks = {};
  int? _expectedTotal;
  bool _isComplete = false;
  dynamic _result;

  dynamic get result => _result;
  int? get expectedTotal => _expectedTotal;
  int get receivedCount => _chunks.length;
  bool get isComplete => _isComplete;

  /// 조각을 받아서 저장. 모든 조각이 모이면 true 반환
  bool receivePart(String part) {
    if (!part.startsWith('B\$') || part.length < 9 || _isComplete) {
      return false;
    }

    try {
      // encodingType: H = Hex, Z = Zlib compressed(wbits=10, no header) then Base32, 2 = Base32 using RFC 4648
      // fileType: T = TXN, P = PSBT, J = JSON ...
      String header = part.substring(0, 8);
      String encodingType = header.substring(2, 3);
      String fileType = header.substring(3, 4);
      String totalStr = header.substring(4, 6);
      String indexStr = header.substring(6, 8);
      int dataStartIndex = 8;

      final total = int.parse(totalStr, radix: 36);
      final index = int.parse(indexStr, radix: 36);

      if (total <= 0 || index < 0 || index >= total) {
        Logger.log('--> BbqrDecoder.receivePart: total mismatch $_expectedTotal vs $total');
        return false;
      }
      if (_chunks.containsKey(index)) {
        return false;
      }

      _expectedTotal ??= total;
      if (_expectedTotal != total) {
        return false;
      }

      final payloadData = part.substring(dataStartIndex);
      List<int> rawBytes;

      if (encodingType == 'H') {
        // HEX
        rawBytes = utf8.encode(payloadData);
      } else if (encodingType == '2') {
        // Base32
        rawBytes = base32.decode(payloadData);
      } else {
        // Zlib compressed(wbits=10, no header) then Base32
        final compressedBytes = base32.decode(payloadData);
        final decompressedBytes = ZLibCodec(raw: true, level: 9).decode(compressedBytes);
        rawBytes = decompressedBytes;
      }

      _chunks[index] = rawBytes;

      if (_chunks.length == _expectedTotal) {
        _isComplete = true;
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  /// 모든 조각이 모였는지 확인
  bool checkComplete() {
    return _isComplete;
  }

  /// 조각을 합쳐서 JSON 문자열 반환 (완성된 경우에만)
  String? getCombinedJsonString() {
    if (!_isComplete) return null;

    final combinedBytes = <int>[];
    for (int i = 0; i < _expectedTotal!; i++) {
      if (!_chunks.containsKey(i)) {
        return null;
      }
      combinedBytes.addAll(_chunks[i]!);
    }

    try {
      final result = utf8.decode(combinedBytes);
      return result;
    } catch (e) {
      return null;
    }
  }

  /// JSON 파싱 결과 반환 (완성된 경우에만)
  dynamic parseJson() {
    final jsonString = getCombinedJsonString();
    if (jsonString == null) {
      return null;
    }
    try {
      _result = json.decode(jsonString);
      return _result;
    } catch (e) {
      return null;
    }
  }

  /// Hex 데이터 파싱 결과 반환
  dynamic parseHexData() {
    if (!_isComplete) return null;

    final combinedBytes = <int>[];
    for (int i = 0; i < _expectedTotal!; i++) {
      if (!_chunks.containsKey(i)) {
        return null;
      }
      combinedBytes.addAll(_chunks[i]!);
    }

    try {
      _result = combinedBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');
      // 첫 바이트가 303230 이면 ASCII 문자열로 변환
      if (_result.startsWith('303230')) {
        _result = String.fromCharCodes(List.generate(_result.length ~/ 2, (i) {
          return int.parse(_result.substring(i * 2, i * 2 + 2), radix: 16);
        }));
      }
      return _result;
    } catch (e) {
      return null;
    }
  }

  /// 진행률 (0~1)
  double get progress {
    if (_expectedTotal == null || _expectedTotal == 0) return 0;
    final progress = (_chunks.length / _expectedTotal!).clamp(0, 1);
    return progress.toDouble();
  }

  /// 상태 초기화
  void reset() {
    _chunks.clear();
    _expectedTotal = null;
    _isComplete = false;
    _result = null;
  }
}
